/**
 * UDS (Unified Diagnostic Services) Protocol Constants
 * ISO 14229-1
 *
 * This class defines all UDS service IDs, sub-functions,
 * negative response codes, and data identifiers used in
 * VAG/Audi diagnostic communication.
 *
 * Java 1.4 compatible — no enums, no generics.
 */
package de.audi.mmi3g.diag.uds;

public class UDSConstants {

    // =========================================================
    // UDS Service IDs (request)
    // =========================================================

    /** DiagnosticSessionControl */
    public static final int SID_DIAGNOSTIC_SESSION_CONTROL = 0x10;
    /** ECUReset */
    public static final int SID_ECU_RESET = 0x11;
    /** ReadDTCInformation */
    public static final int SID_READ_DTC_INFO = 0x19;
    /** ReadDataByIdentifier */
    public static final int SID_READ_DATA_BY_ID = 0x22;
    /** ReadMemoryByAddress */
    public static final int SID_READ_MEMORY_BY_ADDR = 0x23;
    /** SecurityAccess */
    public static final int SID_SECURITY_ACCESS = 0x27;
    /** CommunicationControl */
    public static final int SID_COMMUNICATION_CONTROL = 0x28;
    /** WriteDataByIdentifier — NOT USED (safety) */
    public static final int SID_WRITE_DATA_BY_ID = 0x2E;
    /** RoutineControl — NOT USED (safety) */
    public static final int SID_ROUTINE_CONTROL = 0x31;
    /** RequestDownload — NOT USED (safety) */
    public static final int SID_REQUEST_DOWNLOAD = 0x34;
    /** TesterPresent */
    public static final int SID_TESTER_PRESENT = 0x3E;
    /** ClearDTCInformation */
    public static final int SID_CLEAR_DTC = 0x14;

    // Positive response = request SID + 0x40
    public static final int POSITIVE_RESPONSE_OFFSET = 0x40;

    // =========================================================
    // DiagnosticSessionControl sub-functions
    // =========================================================

    public static final int SESSION_DEFAULT = 0x01;
    public static final int SESSION_PROGRAMMING = 0x02;
    public static final int SESSION_EXTENDED = 0x03;

    // =========================================================
    // ReadDTCInformation sub-functions
    // =========================================================

    /** Report number of DTCs by status mask */
    public static final int RDTC_REPORT_NUM_BY_STATUS = 0x01;
    /** Report DTCs by status mask */
    public static final int RDTC_REPORT_BY_STATUS = 0x02;
    /** Report DTC snapshot identification */
    public static final int RDTC_REPORT_SNAPSHOT_ID = 0x03;
    /** Report DTC snapshot record by DTC number */
    public static final int RDTC_REPORT_SNAPSHOT_BY_DTC = 0x04;
    /** Report DTC extended data by DTC number */
    public static final int RDTC_REPORT_EXTENDED_DATA = 0x06;
    /** Report supported DTCs */
    public static final int RDTC_REPORT_SUPPORTED = 0x0A;

    // =========================================================
    // DTC Status Mask Bits
    // =========================================================

    /** Test failed */
    public static final int DTC_STATUS_TEST_FAILED = 0x01;
    /** Test failed this operation cycle */
    public static final int DTC_STATUS_TEST_FAILED_THIS_CYCLE = 0x02;
    /** Pending DTC */
    public static final int DTC_STATUS_PENDING = 0x04;
    /** Confirmed DTC */
    public static final int DTC_STATUS_CONFIRMED = 0x08;
    /** Test not completed since last clear */
    public static final int DTC_STATUS_NOT_COMPLETED_SINCE_CLEAR = 0x10;
    /** Test failed since last clear */
    public static final int DTC_STATUS_FAILED_SINCE_CLEAR = 0x20;
    /** Test not completed this cycle */
    public static final int DTC_STATUS_NOT_COMPLETED_THIS_CYCLE = 0x40;
    /** Warning indicator requested */
    public static final int DTC_STATUS_WARNING_INDICATOR = 0x80;

    /** Common mask: all confirmed and pending */
    public static final int DTC_STATUS_MASK_ALL = 0xFF;
    /** Common mask: confirmed only */
    public static final int DTC_STATUS_MASK_CONFIRMED = 0x08;
    /** Common mask: active faults */
    public static final int DTC_STATUS_MASK_ACTIVE = 0x09;

    // =========================================================
    // ClearDTC group definitions
    // =========================================================

    /** Clear all DTCs */
    public static final int CLEAR_ALL_DTCS = 0xFFFFFF;
    /** Clear powertrain DTCs */
    public static final int CLEAR_POWERTRAIN_DTCS = 0x000000;
    /** Clear chassis DTCs */
    public static final int CLEAR_CHASSIS_DTCS = 0x400000;
    /** Clear body DTCs */
    public static final int CLEAR_BODY_DTCS = 0x800000;
    /** Clear network DTCs */
    public static final int CLEAR_NETWORK_DTCS = 0xC00000;

    // =========================================================
    // Common Data Identifiers (DIDs) for ReadDataByIdentifier
    // =========================================================

    /** ECU part number (VW format) */
    public static final int DID_ECU_PART_NUMBER = 0xF187;
    /** ECU serial number */
    public static final int DID_ECU_SERIAL_NUMBER = 0xF18C;
    /** VW system name */
    public static final int DID_SYSTEM_NAME = 0xF197;
    /** VW ECU hardware number */
    public static final int DID_HW_NUMBER = 0xF191;
    /** VW ECU software number */
    public static final int DID_SW_NUMBER = 0xF1A2;
    /** VW ECU hardware version */
    public static final int DID_HW_VERSION = 0xF1A3;
    /** VW ECU software version */
    public static final int DID_SW_VERSION = 0xF1A5;
    /** VIN (Vehicle Identification Number) */
    public static final int DID_VIN = 0xF190;
    /** Workshop code / ASAM ODX file name */
    public static final int DID_WORKSHOP_CODE = 0xF198;
    /** Programming date */
    public static final int DID_PROGRAMMING_DATE = 0xF199;
    /** Coding value */
    public static final int DID_CODING = 0x0600;
    /** Long coding */
    public static final int DID_LONG_CODING = 0x0601;

    // =========================================================
    // OBD-II Standard PIDs (for engine live data)
    // =========================================================

    /** Engine RPM (value / 4) */
    public static final int PID_ENGINE_RPM = 0x010C;
    /** Vehicle speed (km/h) */
    public static final int PID_VEHICLE_SPEED = 0x010D;
    /** Coolant temperature (°C - 40) */
    public static final int PID_COOLANT_TEMP = 0x0105;
    /** Intake manifold pressure (kPa) */
    public static final int PID_INTAKE_MAP = 0x010B;
    /** Intake air temperature (°C - 40) */
    public static final int PID_INTAKE_AIR_TEMP = 0x010F;
    /** Throttle position (% * 255/100) */
    public static final int PID_THROTTLE_POS = 0x0111;
    /** Engine load (% * 255/100) */
    public static final int PID_ENGINE_LOAD = 0x0104;
    /** Fuel pressure (kPa * 3) */
    public static final int PID_FUEL_PRESSURE = 0x010A;
    /** Battery voltage */
    public static final int PID_BATTERY_VOLTAGE = 0x0142;
    /** Oil temperature */
    public static final int PID_OIL_TEMP = 0x015C;
    /** Boost pressure (hPa) */
    public static final int PID_BOOST_PRESSURE = 0x0170;

    // =========================================================
    // Negative Response Codes (NRC)
    // =========================================================

    public static final int NRC_GENERAL_REJECT = 0x10;
    public static final int NRC_SERVICE_NOT_SUPPORTED = 0x11;
    public static final int NRC_SUB_FUNCTION_NOT_SUPPORTED = 0x12;
    public static final int NRC_INCORRECT_MESSAGE_LENGTH = 0x13;
    public static final int NRC_BUSY_REPEAT_REQUEST = 0x21;
    public static final int NRC_CONDITIONS_NOT_CORRECT = 0x22;
    public static final int NRC_REQUEST_SEQUENCE_ERROR = 0x24;
    public static final int NRC_REQUEST_OUT_OF_RANGE = 0x31;
    public static final int NRC_SECURITY_ACCESS_DENIED = 0x33;
    public static final int NRC_INVALID_KEY = 0x35;
    public static final int NRC_EXCEEDED_NUMBER_OF_ATTEMPTS = 0x36;
    public static final int NRC_UPLOAD_DOWNLOAD_NOT_ACCEPTED = 0x70;
    public static final int NRC_RESPONSE_PENDING = 0x78;
    public static final int NRC_SERVICE_NOT_SUPPORTED_IN_SESSION = 0x7F;

    /** Negative response service ID */
    public static final int SID_NEGATIVE_RESPONSE = 0x7F;

    /**
     * Get human-readable name for a negative response code.
     */
    public static String getNRCName(int nrc) {
        switch (nrc) {
            case NRC_GENERAL_REJECT: return "General reject";
            case NRC_SERVICE_NOT_SUPPORTED: return "Service not supported";
            case NRC_SUB_FUNCTION_NOT_SUPPORTED: return "Sub-function not supported";
            case NRC_INCORRECT_MESSAGE_LENGTH: return "Incorrect message length";
            case NRC_BUSY_REPEAT_REQUEST: return "Busy, repeat request";
            case NRC_CONDITIONS_NOT_CORRECT: return "Conditions not correct";
            case NRC_REQUEST_SEQUENCE_ERROR: return "Request sequence error";
            case NRC_REQUEST_OUT_OF_RANGE: return "Request out of range";
            case NRC_SECURITY_ACCESS_DENIED: return "Security access denied";
            case NRC_INVALID_KEY: return "Invalid key";
            case NRC_EXCEEDED_NUMBER_OF_ATTEMPTS: return "Exceeded attempts";
            case NRC_RESPONSE_PENDING: return "Response pending";
            case NRC_SERVICE_NOT_SUPPORTED_IN_SESSION: return "Not supported in active session";
            default: return "Unknown NRC 0x" + Integer.toHexString(nrc);
        }
    }

    /**
     * Get human-readable DTC status description.
     */
    public static String getDTCStatusText(int status) {
        StringBuffer sb = new StringBuffer();
        if ((status & DTC_STATUS_TEST_FAILED) != 0) sb.append("ACTIVE ");
        if ((status & DTC_STATUS_CONFIRMED) != 0) sb.append("CONFIRMED ");
        if ((status & DTC_STATUS_PENDING) != 0) sb.append("PENDING ");
        if ((status & DTC_STATUS_WARNING_INDICATOR) != 0) sb.append("MIL ");
        if ((status & DTC_STATUS_FAILED_SINCE_CLEAR) != 0) sb.append("SINCE_CLR ");
        if (sb.length() == 0) sb.append("STORED");
        return sb.toString().trim();
    }
}
