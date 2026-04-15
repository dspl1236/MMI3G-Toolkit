/**
 * UDS Message — Represents a single UDS request or response.
 * Java 1.4 compatible.
 */
package de.audi.mmi3g.diag.uds;

public class UDSMessage {

    private int serviceId;
    private byte[] data;
    private boolean isResponse;
    private boolean isNegative;
    private int nrc;

    /**
     * Create a UDS request message.
     */
    public UDSMessage(int serviceId, byte[] data) {
        this.serviceId = serviceId;
        this.data = (data != null) ? data : new byte[0];
        this.isResponse = false;
        this.isNegative = false;
        this.nrc = 0;
    }

    /**
     * Parse a UDS response from raw bytes.
     */
    public static UDSMessage parseResponse(byte[] raw) {
        if (raw == null || raw.length < 1) {
            return null;
        }

        UDSMessage msg = new UDSMessage(0, null);
        msg.isResponse = true;

        if ((raw[0] & 0xFF) == UDSConstants.SID_NEGATIVE_RESPONSE) {
            // Negative response: 0x7F [service] [NRC]
            msg.isNegative = true;
            if (raw.length >= 2) msg.serviceId = raw[1] & 0xFF;
            if (raw.length >= 3) msg.nrc = raw[2] & 0xFF;
            msg.data = new byte[0];
        } else {
            // Positive response: [service + 0x40] [data...]
            msg.serviceId = (raw[0] & 0xFF) - UDSConstants.POSITIVE_RESPONSE_OFFSET;
            msg.isNegative = false;
            if (raw.length > 1) {
                msg.data = new byte[raw.length - 1];
                System.arraycopy(raw, 1, msg.data, 0, raw.length - 1);
            } else {
                msg.data = new byte[0];
            }
        }

        return msg;
    }

    /**
     * Serialize this request to raw bytes for transmission.
     */
    public byte[] toBytes() {
        byte[] result = new byte[1 + data.length];
        result[0] = (byte) serviceId;
        if (data.length > 0) {
            System.arraycopy(data, 0, result, 1, data.length);
        }
        return result;
    }

    // --- Getters ---

    public int getServiceId() { return serviceId; }
    public byte[] getData() { return data; }
    public boolean isResponse() { return isResponse; }
    public boolean isNegative() { return isNegative; }
    public int getNRC() { return nrc; }

    public boolean isResponsePending() {
        return isNegative && nrc == UDSConstants.NRC_RESPONSE_PENDING;
    }

    /**
     * Get a specific byte from the response data.
     */
    public int getByte(int index) {
        if (index >= 0 && index < data.length) {
            return data[index] & 0xFF;
        }
        return -1;
    }

    /**
     * Get a 16-bit value from response data (big-endian).
     */
    public int getWord(int index) {
        if (index >= 0 && index + 1 < data.length) {
            return ((data[index] & 0xFF) << 8) | (data[index + 1] & 0xFF);
        }
        return -1;
    }

    /**
     * Get a 24-bit value from response data (big-endian).
     * Used for DTC numbers.
     */
    public int getDTC(int index) {
        if (index >= 0 && index + 2 < data.length) {
            return ((data[index] & 0xFF) << 16)
                 | ((data[index + 1] & 0xFF) << 8)
                 | (data[index + 2] & 0xFF);
        }
        return -1;
    }

    /**
     * Get ASCII string from response data.
     */
    public String getString(int offset, int length) {
        if (offset >= 0 && offset + length <= data.length) {
            return new String(data, offset, length).trim();
        }
        return "";
    }

    /**
     * Get hex string of the full response data.
     */
    public String toHexString() {
        StringBuffer sb = new StringBuffer();
        if (isNegative) {
            sb.append("7F ");
            sb.append(hexByte(serviceId));
            sb.append(" ");
            sb.append(hexByte(nrc));
        } else if (isResponse) {
            sb.append(hexByte(serviceId + UDSConstants.POSITIVE_RESPONSE_OFFSET));
            for (int i = 0; i < data.length; i++) {
                sb.append(" ");
                sb.append(hexByte(data[i] & 0xFF));
            }
        } else {
            sb.append(hexByte(serviceId));
            for (int i = 0; i < data.length; i++) {
                sb.append(" ");
                sb.append(hexByte(data[i] & 0xFF));
            }
        }
        return sb.toString();
    }

    private static String hexByte(int b) {
        String h = Integer.toHexString(b & 0xFF).toUpperCase();
        return h.length() < 2 ? "0" + h : h;
    }

    public String toString() {
        if (isNegative) {
            return "NEG[SID=0x" + Integer.toHexString(serviceId)
                + " NRC=" + UDSConstants.getNRCName(nrc) + "]";
        }
        return (isResponse ? "RSP" : "REQ")
            + "[SID=0x" + Integer.toHexString(serviceId)
            + " len=" + data.length + "]";
    }
}
