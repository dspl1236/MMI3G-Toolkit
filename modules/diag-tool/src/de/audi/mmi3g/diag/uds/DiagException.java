/**
 * Diagnostic communication exception.
 * Java 1.4 compatible.
 */
package de.audi.mmi3g.diag.uds;

public class DiagException extends Exception {

    private int nrc = -1;

    public DiagException(String message) {
        super(message);
    }

    public DiagException(String message, int nrc) {
        super(message);
        this.nrc = nrc;
    }

    /** Get the UDS Negative Response Code, or -1 if not applicable. */
    public int getNRC() { return nrc; }

    /** True if this was a "service not supported" response. */
    public boolean isNotSupported() {
        return nrc == UDSConstants.NRC_SERVICE_NOT_SUPPORTED
            || nrc == UDSConstants.NRC_SUB_FUNCTION_NOT_SUPPORTED;
    }

    /** True if this was a security access issue. */
    public boolean isSecurityDenied() {
        return nrc == UDSConstants.NRC_SECURITY_ACCESS_DENIED;
    }
}
