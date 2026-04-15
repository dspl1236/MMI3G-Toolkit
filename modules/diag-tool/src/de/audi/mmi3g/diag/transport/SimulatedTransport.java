/**
 * Simulated Transport — For desktop testing.
 *
 * Simulates a car with common modules and realistic DTCs.
 * Allows testing the full diagnostic UI without a physical car.
 *
 * Java 1.4 compatible.
 */
package de.audi.mmi3g.diag.transport;

import de.audi.mmi3g.diag.uds.UDSConstants;
import java.util.Hashtable;
import java.util.Vector;

public class SimulatedTransport implements TransportLayer {

    private int connectedModule = -1;
    private Hashtable moduleData;  // module -> Vector of DTCs
    private boolean dtcsCleared = false;

    public SimulatedTransport() {
        moduleData = new Hashtable();
        initSimulatedData();
    }

    private void initSimulatedData() {
        // Engine ECU (01) — 2 DTCs
        Vector engine = new Vector();
        engine.addElement(new int[]{0x012A00, 0x29}); // P012A — Turbo boost pressure low
        engine.addElement(new int[]{0x030100, 0x08}); // P0301 — Cylinder 1 misfire (stored)
        moduleData.put(new Integer(0x01), engine);

        // Transmission (02) — clean
        moduleData.put(new Integer(0x02), new Vector());

        // ABS/ESP (03) — 1 DTC
        Vector abs = new Vector();
        abs.addElement(new int[]{0x012100, 0x29}); // C0121 — Wheel speed sensor
        moduleData.put(new Integer(0x03), abs);

        // HVAC (08) — clean
        moduleData.put(new Integer(0x08), new Vector());

        // Central Electrics (09) — 1 DTC
        Vector central = new Vector();
        central.addElement(new int[]{0xB10014, 0x08}); // B1001 — Interior light (stored)
        moduleData.put(new Integer(0x09), central);

        // Instrument Cluster (17) — clean
        moduleData.put(new Integer(0x17), new Vector());

        // Gateway (19) — clean
        moduleData.put(new Integer(0x19), new Vector());

        // MMI (5F) — 1 DTC
        Vector mmi = new Vector();
        mmi.addElement(new int[]{0xB200A4, 0x04}); // B200A — Navigation antenna (pending)
        moduleData.put(new Integer(0x5F), mmi);
    }

    public boolean connect(int moduleAddress) {
        if (moduleData.containsKey(new Integer(moduleAddress))) {
            connectedModule = moduleAddress;
            return true;
        }
        return false;
    }

    public void disconnect() {
        connectedModule = -1;
    }

    public boolean isConnected() {
        return connectedModule >= 0;
    }

    public String getName() {
        return "Simulated (Desktop Testing)";
    }

    public void close() {
        disconnect();
    }

    public byte[] sendAndReceive(byte[] request, int timeoutMs) {
        if (connectedModule < 0 || request == null || request.length < 1) {
            return null;
        }

        // Simulate some latency
        try { Thread.sleep(50); } catch (Exception e) {}

        int sid = request[0] & 0xFF;

        switch (sid) {
            case UDSConstants.SID_DIAGNOSTIC_SESSION_CONTROL:
                return positiveResponse(sid, new byte[]{request[1], 0x00, 0x19, 0x01, (byte)0xF4});

            case UDSConstants.SID_TESTER_PRESENT:
                return positiveResponse(sid, new byte[]{0x00});

            case UDSConstants.SID_READ_DTC_INFO:
                return handleReadDTC(request);

            case UDSConstants.SID_CLEAR_DTC:
                return handleClearDTC(request);

            case UDSConstants.SID_READ_DATA_BY_ID:
                return handleReadDataById(request);

            default:
                // Service not supported
                return negativeResponse(sid, UDSConstants.NRC_SERVICE_NOT_SUPPORTED);
        }
    }

    private byte[] handleReadDTC(byte[] request) {
        if (request.length < 3) return negativeResponse(request[0] & 0xFF, UDSConstants.NRC_INCORRECT_MESSAGE_LENGTH);

        int subFunction = request[1] & 0xFF;
        int statusMask = request[2] & 0xFF;

        Vector dtcs = dtcsCleared ? new Vector() :
            (Vector) moduleData.get(new Integer(connectedModule));
        if (dtcs == null) dtcs = new Vector();

        if (subFunction == UDSConstants.RDTC_REPORT_NUM_BY_STATUS) {
            // Count DTCs
            int count = 0;
            for (int i = 0; i < dtcs.size(); i++) {
                int[] dtc = (int[]) dtcs.elementAt(i);
                if ((dtc[1] & statusMask) != 0) count++;
            }
            return positiveResponse(UDSConstants.SID_READ_DTC_INFO,
                new byte[]{(byte) subFunction, (byte) 0xFF, 0x01,
                    (byte) ((count >> 8) & 0xFF), (byte) (count & 0xFF)});
        }

        if (subFunction == UDSConstants.RDTC_REPORT_BY_STATUS) {
            // List DTCs
            Vector matching = new Vector();
            for (int i = 0; i < dtcs.size(); i++) {
                int[] dtc = (int[]) dtcs.elementAt(i);
                if ((dtc[1] & statusMask) != 0) {
                    matching.addElement(dtc);
                }
            }

            byte[] data = new byte[2 + matching.size() * 4];
            data[0] = (byte) subFunction;
            data[1] = (byte) 0xFF; // status availability
            for (int i = 0; i < matching.size(); i++) {
                int[] dtc = (int[]) matching.elementAt(i);
                int offset = 2 + i * 4;
                data[offset] = (byte) ((dtc[0] >> 16) & 0xFF);
                data[offset + 1] = (byte) ((dtc[0] >> 8) & 0xFF);
                data[offset + 2] = (byte) (dtc[0] & 0xFF);
                data[offset + 3] = (byte) dtc[1];
            }
            return positiveResponse(UDSConstants.SID_READ_DTC_INFO, data);
        }

        return negativeResponse(UDSConstants.SID_READ_DTC_INFO,
            UDSConstants.NRC_SUB_FUNCTION_NOT_SUPPORTED);
    }

    private byte[] handleClearDTC(byte[] request) {
        dtcsCleared = true;
        return positiveResponse(UDSConstants.SID_CLEAR_DTC, new byte[0]);
    }

    private byte[] handleReadDataById(byte[] request) {
        if (request.length < 3) return negativeResponse(request[0] & 0xFF, UDSConstants.NRC_INCORRECT_MESSAGE_LENGTH);

        int did = ((request[1] & 0xFF) << 8) | (request[2] & 0xFF);

        switch (did) {
            case UDSConstants.DID_ECU_PART_NUMBER:
                return didResponse(did, getSimPartNumber());
            case UDSConstants.DID_VIN:
                return didResponse(did, "WAUZZZ4G8DN012345".getBytes());
            case UDSConstants.DID_SYSTEM_NAME:
                return didResponse(did, getSimSystemName());
            case UDSConstants.DID_HW_VERSION:
                return didResponse(did, "H12".getBytes());
            case UDSConstants.DID_SW_VERSION:
                return didResponse(did, "0942".getBytes());
            default:
                return negativeResponse(UDSConstants.SID_READ_DATA_BY_ID,
                    UDSConstants.NRC_REQUEST_OUT_OF_RANGE);
        }
    }

    private byte[] getSimPartNumber() {
        switch (connectedModule) {
            case 0x01: return "06E906016S ".getBytes();
            case 0x02: return "0BK300040L ".getBytes();
            case 0x03: return "4G0614517R ".getBytes();
            case 0x09: return "4H0907064BT".getBytes();
            case 0x17: return "4G8920900E ".getBytes();
            case 0x19: return "4G0907468AC".getBytes();
            case 0x5F: return "4G0906961FB".getBytes();
            default: return "000000000  ".getBytes();
        }
    }

    private byte[] getSimSystemName() {
        switch (connectedModule) {
            case 0x01: return "SIMOS 8.6".getBytes();
            case 0x02: return "AL551 TCU".getBytes();
            case 0x03: return "MK60EC1".getBytes();
            case 0x09: return "BCM PQ35".getBytes();
            case 0x17: return "KOMBI C7".getBytes();
            case 0x19: return "GW C7".getBytes();
            case 0x5F: return "MMI3GP HN+R".getBytes();
            default: return "Unknown".getBytes();
        }
    }

    // --- Response builders ---

    private byte[] positiveResponse(int sid, byte[] data) {
        byte[] resp = new byte[1 + data.length];
        resp[0] = (byte) (sid + UDSConstants.POSITIVE_RESPONSE_OFFSET);
        System.arraycopy(data, 0, resp, 1, data.length);
        return resp;
    }

    private byte[] negativeResponse(int sid, int nrc) {
        return new byte[]{
            (byte) UDSConstants.SID_NEGATIVE_RESPONSE,
            (byte) sid,
            (byte) nrc
        };
    }

    private byte[] didResponse(int did, byte[] value) {
        byte[] data = new byte[2 + value.length];
        data[0] = (byte) ((did >> 8) & 0xFF);
        data[1] = (byte) (did & 0xFF);
        System.arraycopy(value, 0, data, 2, value.length);
        return positiveResponse(UDSConstants.SID_READ_DATA_BY_ID, data);
    }
}
