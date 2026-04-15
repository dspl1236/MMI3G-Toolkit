/**
 * UDS Client — High-level diagnostic service interface.
 *
 * Provides methods for all read-only diagnostic operations:
 * - ReadDTCInformation (service 0x19)
 * - ReadDataByIdentifier (service 0x22)
 * - ClearDTC (service 0x14) — safe, well-documented
 * - TesterPresent (service 0x3E)
 * - DiagnosticSessionControl (service 0x10)
 *
 * Does NOT implement any write/coding/control services.
 *
 * Java 1.4 compatible.
 */
package de.audi.mmi3g.diag.uds;

import de.audi.mmi3g.diag.transport.TransportLayer;
import java.util.Vector;

public class UDSClient {

    private TransportLayer transport;
    private int timeoutMs = 5000;
    private int currentSession = UDSConstants.SESSION_DEFAULT;

    public UDSClient(TransportLayer transport) {
        this.transport = transport;
    }

    public void setTimeout(int ms) {
        this.timeoutMs = ms;
    }

    // =========================================================
    // Low-level send/receive
    // =========================================================

    /**
     * Send a UDS request and wait for response.
     * Handles NRC 0x78 (Response Pending) automatically.
     */
    public UDSMessage sendRequest(int serviceId, byte[] data)
            throws DiagException {
        UDSMessage request = new UDSMessage(serviceId, data);
        byte[] rawRequest = request.toBytes();

        int retries = 0;
        while (retries < 10) {
            byte[] rawResponse = transport.sendAndReceive(rawRequest, timeoutMs);

            if (rawResponse == null || rawResponse.length == 0) {
                throw new DiagException("No response from ECU");
            }

            UDSMessage response = UDSMessage.parseResponse(rawResponse);
            if (response == null) {
                throw new DiagException("Invalid response");
            }

            if (response.isResponsePending()) {
                // ECU needs more time — wait and retry
                retries++;
                try { Thread.sleep(1000); } catch (Exception e) {}
                continue;
            }

            if (response.isNegative()) {
                throw new DiagException(
                    "ECU rejected: " + UDSConstants.getNRCName(response.getNRC()),
                    response.getNRC());
            }

            return response;
        }

        throw new DiagException("Response pending timeout");
    }

    // =========================================================
    // DiagnosticSessionControl (0x10)
    // =========================================================

    /**
     * Switch to a diagnostic session.
     */
    public void startSession(int sessionType) throws DiagException {
        sendRequest(UDSConstants.SID_DIAGNOSTIC_SESSION_CONTROL,
            new byte[]{(byte) sessionType});
        currentSession = sessionType;
    }

    /**
     * Switch to extended diagnostic session.
     * Required for some ReadDataByIdentifier operations.
     */
    public void startExtendedSession() throws DiagException {
        startSession(UDSConstants.SESSION_EXTENDED);
    }

    /**
     * Return to default session.
     */
    public void endSession() throws DiagException {
        startSession(UDSConstants.SESSION_DEFAULT);
    }

    // =========================================================
    // TesterPresent (0x3E)
    // =========================================================

    /**
     * Send TesterPresent to keep the session alive.
     */
    public void testerPresent() throws DiagException {
        sendRequest(UDSConstants.SID_TESTER_PRESENT,
            new byte[]{0x00});
    }

    // =========================================================
    // ReadDTCInformation (0x19)
    // =========================================================

    /**
     * Get the number of DTCs matching the status mask.
     * Returns [statusAvailabilityMask, formatIdentifier, count].
     */
    public int[] getDTCCount(int statusMask) throws DiagException {
        UDSMessage resp = sendRequest(UDSConstants.SID_READ_DTC_INFO,
            new byte[]{
                (byte) UDSConstants.RDTC_REPORT_NUM_BY_STATUS,
                (byte) statusMask
            });

        // Response: [subFunction, statusAvailability, format, countHigh, countLow]
        int[] result = new int[3];
        result[0] = resp.getByte(1); // status availability mask
        result[1] = resp.getByte(2); // DTC format (0x01 = ISO 14229)
        result[2] = resp.getWord(3); // DTC count
        return result;
    }

    /**
     * Read all DTCs matching the status mask.
     * Returns a Vector of DTCEntry objects.
     */
    public Vector readDTCs(int statusMask) throws DiagException {
        UDSMessage resp = sendRequest(UDSConstants.SID_READ_DTC_INFO,
            new byte[]{
                (byte) UDSConstants.RDTC_REPORT_BY_STATUS,
                (byte) statusMask
            });

        Vector dtcList = new Vector();
        byte[] data = resp.getData();

        // Response: [subFunction, statusAvailability, DTC1_hi, DTC1_mid, DTC1_lo, DTC1_status, ...]
        if (data.length < 2) return dtcList;

        int statusAvailability = data[1] & 0xFF;

        // Parse DTC entries (4 bytes each: 3 bytes DTC + 1 byte status)
        for (int i = 2; i + 3 < data.length; i += 4) {
            int dtcNumber = ((data[i] & 0xFF) << 16)
                          | ((data[i + 1] & 0xFF) << 8)
                          | (data[i + 2] & 0xFF);
            int dtcStatus = data[i + 3] & 0xFF;

            if (dtcNumber != 0) {
                DTCEntry entry = new DTCEntry(dtcNumber, dtcStatus);
                dtcList.addElement(entry);
            }
        }

        return dtcList;
    }

    /**
     * Read freeze frame / snapshot data for a specific DTC.
     */
    public byte[] readDTCSnapshot(int dtcNumber, int recordNumber)
            throws DiagException {
        UDSMessage resp = sendRequest(UDSConstants.SID_READ_DTC_INFO,
            new byte[]{
                (byte) UDSConstants.RDTC_REPORT_SNAPSHOT_BY_DTC,
                (byte) ((dtcNumber >> 16) & 0xFF),
                (byte) ((dtcNumber >> 8) & 0xFF),
                (byte) (dtcNumber & 0xFF),
                (byte) recordNumber
            });
        return resp.getData();
    }

    // =========================================================
    // ClearDTC (0x14) — Safe operation
    // =========================================================

    /**
     * Clear all DTCs from this ECU.
     * This is safe — same as any OBD-II code reader "clear codes".
     */
    public void clearAllDTCs() throws DiagException {
        sendRequest(UDSConstants.SID_CLEAR_DTC,
            new byte[]{
                (byte) 0xFF, (byte) 0xFF, (byte) 0xFF  // All groups
            });
    }

    /**
     * Clear DTCs for a specific group.
     */
    public void clearDTCGroup(int group) throws DiagException {
        sendRequest(UDSConstants.SID_CLEAR_DTC,
            new byte[]{
                (byte) ((group >> 16) & 0xFF),
                (byte) ((group >> 8) & 0xFF),
                (byte) (group & 0xFF)
            });
    }

    // =========================================================
    // ReadDataByIdentifier (0x22)
    // =========================================================

    /**
     * Read a data identifier from the ECU.
     */
    public UDSMessage readDataById(int did) throws DiagException {
        return sendRequest(UDSConstants.SID_READ_DATA_BY_ID,
            new byte[]{
                (byte) ((did >> 8) & 0xFF),
                (byte) (did & 0xFF)
            });
    }

    /**
     * Read ECU part number as string.
     */
    public String readPartNumber() throws DiagException {
        UDSMessage resp = readDataById(UDSConstants.DID_ECU_PART_NUMBER);
        return resp.getString(2, resp.getData().length - 2);
    }

    /**
     * Read VIN.
     */
    public String readVIN() throws DiagException {
        UDSMessage resp = readDataById(UDSConstants.DID_VIN);
        return resp.getString(2, resp.getData().length - 2);
    }

    /**
     * Read ECU hardware version.
     */
    public String readHWVersion() throws DiagException {
        UDSMessage resp = readDataById(UDSConstants.DID_HW_VERSION);
        return resp.getString(2, resp.getData().length - 2);
    }

    /**
     * Read ECU software version.
     */
    public String readSWVersion() throws DiagException {
        UDSMessage resp = readDataById(UDSConstants.DID_SW_VERSION);
        return resp.getString(2, resp.getData().length - 2);
    }

    /**
     * Read system name.
     */
    public String readSystemName() throws DiagException {
        UDSMessage resp = readDataById(UDSConstants.DID_SYSTEM_NAME);
        return resp.getString(2, resp.getData().length - 2);
    }

    /**
     * Read a live data value (engine RPM, coolant temp, etc.).
     * Returns raw bytes — caller must apply scaling.
     */
    public byte[] readLiveData(int pid) throws DiagException {
        UDSMessage resp = readDataById(pid);
        return resp.getData();
    }

    // =========================================================
    // ECU Identification — Read all available info
    // =========================================================

    /**
     * Read complete ECU identification.
     * Returns an ECUInfo object with all available fields.
     */
    public ECUInfo readECUInfo() {
        ECUInfo info = new ECUInfo();

        // Try each DID — some may not be supported by every ECU
        try { info.partNumber = readPartNumber(); } catch (DiagException e) {}
        try { info.hwVersion = readHWVersion(); } catch (DiagException e) {}
        try { info.swVersion = readSWVersion(); } catch (DiagException e) {}
        try { info.systemName = readSystemName(); } catch (DiagException e) {}
        try { info.vin = readVIN(); } catch (DiagException e) {}
        try {
            UDSMessage resp = readDataById(UDSConstants.DID_ECU_SERIAL_NUMBER);
            info.serialNumber = resp.getString(2, resp.getData().length - 2);
        } catch (DiagException e) {}
        try {
            UDSMessage resp = readDataById(UDSConstants.DID_SW_NUMBER);
            info.swNumber = resp.getString(2, resp.getData().length - 2);
        } catch (DiagException e) {}

        return info;
    }

    // =========================================================
    // Inner Classes
    // =========================================================

    /**
     * Represents a single DTC entry.
     */
    public static class DTCEntry {
        public int dtcNumber;
        public int status;

        public DTCEntry(int dtcNumber, int status) {
            this.dtcNumber = dtcNumber;
            this.status = status;
        }

        /** Get DTC as standard P/B/C/U code string (e.g., "P0301") */
        public String getDTCString() {
            char prefix;
            int firstChar = (dtcNumber >> 14) & 0x03;
            switch (firstChar) {
                case 0: prefix = 'P'; break; // Powertrain
                case 1: prefix = 'C'; break; // Chassis
                case 2: prefix = 'B'; break; // Body
                case 3: prefix = 'U'; break; // Network
                default: prefix = '?';
            }
            int code = dtcNumber & 0x3FFF;
            String hex = Integer.toHexString(code).toUpperCase();
            while (hex.length() < 4) hex = "0" + hex;
            return "" + prefix + hex;
        }

        /** Get raw DTC as hex string */
        public String getDTCHex() {
            String h = Integer.toHexString(dtcNumber).toUpperCase();
            while (h.length() < 6) h = "0" + h;
            return h;
        }

        /** Get status description */
        public String getStatusText() {
            return UDSConstants.getDTCStatusText(status);
        }

        public String toString() {
            return getDTCString() + " [" + getDTCHex() + "] " + getStatusText();
        }
    }

    /**
     * Holds ECU identification information.
     */
    public static class ECUInfo {
        public String partNumber = "";
        public String hwVersion = "";
        public String swVersion = "";
        public String swNumber = "";
        public String systemName = "";
        public String serialNumber = "";
        public String vin = "";

        public String toString() {
            StringBuffer sb = new StringBuffer();
            if (systemName.length() > 0) sb.append("System: " + systemName + "\n");
            if (partNumber.length() > 0) sb.append("Part#:  " + partNumber + "\n");
            if (swVersion.length() > 0) sb.append("SW:     " + swVersion + "\n");
            if (hwVersion.length() > 0) sb.append("HW:     " + hwVersion + "\n");
            if (swNumber.length() > 0) sb.append("SW#:    " + swNumber + "\n");
            if (serialNumber.length() > 0) sb.append("Serial: " + serialNumber + "\n");
            if (vin.length() > 0) sb.append("VIN:    " + vin + "\n");
            return sb.toString();
        }
    }
}
