/**
 * Module Scanner — Auto-Scan all ECUs like VCDS.
 *
 * Iterates through known VAG module addresses, attempts
 * to connect to each, reads identification and DTCs.
 * Produces a complete vehicle diagnostic report.
 *
 * Java 1.4 compatible.
 */
package de.audi.mmi3g.diag.scanner;

import de.audi.mmi3g.diag.uds.UDSClient;
import de.audi.mmi3g.diag.uds.UDSConstants;
import de.audi.mmi3g.diag.uds.DiagException;
import de.audi.mmi3g.diag.transport.TransportLayer;
import java.util.Vector;

public class ModuleScanner {

    private TransportLayer transport;
    private ScanListener listener;
    private Vector results;
    private boolean cancelled = false;

    public ModuleScanner(TransportLayer transport) {
        this.transport = transport;
        this.results = new Vector();
    }

    /**
     * Set a listener for scan progress callbacks.
     */
    public void setListener(ScanListener listener) {
        this.listener = listener;
    }

    /**
     * Cancel a running scan.
     */
    public void cancel() {
        this.cancelled = true;
    }

    /**
     * Run a full auto-scan of all known modules.
     * Returns a Vector of ScanResult objects.
     */
    public Vector autoScan() {
        results.clear();
        cancelled = false;

        int total = VAGModules.MODULE_LIST.length;

        for (int i = 0; i < total && !cancelled; i++) {
            int address = VAGModules.MODULE_LIST[i][0];
            String name = VAGModules.getModuleName(address);

            if (listener != null) {
                listener.onScanProgress(address, name, i + 1, total);
            }

            ScanResult result = scanModule(address);
            if (result != null) {
                results.addElement(result);
                if (listener != null) {
                    listener.onModuleFound(result);
                }
            }
        }

        if (listener != null) {
            listener.onScanComplete(results);
        }

        return results;
    }

    /**
     * Scan a single module.
     * Returns null if the module doesn't respond.
     */
    public ScanResult scanModule(int address) {
        ScanResult result = new ScanResult();
        result.address = address;
        result.name = VAGModules.getModuleName(address);

        // Try to connect
        if (!transport.connect(address)) {
            return null; // Module not present
        }

        try {
            UDSClient client = new UDSClient(transport);
            client.setTimeout(3000);

            result.responding = true;

            // Read ECU identification
            try {
                result.info = client.readECUInfo();
            } catch (Exception e) {
                // Some modules don't support all DIDs
            }

            // Read DTC count
            try {
                int[] counts = client.getDTCCount(UDSConstants.DTC_STATUS_MASK_ALL);
                result.dtcCount = counts[2];
            } catch (DiagException e) {
                result.dtcCount = -1; // Can't read DTCs
            }

            // If there are DTCs, read them
            if (result.dtcCount > 0) {
                try {
                    result.dtcs = client.readDTCs(UDSConstants.DTC_STATUS_MASK_ALL);
                } catch (DiagException e) {
                    // Count succeeded but listing failed
                }
            }

        } catch (Exception e) {
            result.error = e.getMessage();
        } finally {
            transport.disconnect();
        }

        return result;
    }

    /**
     * Get total DTC count across all scanned modules.
     */
    public int getTotalDTCCount() {
        int total = 0;
        for (int i = 0; i < results.size(); i++) {
            ScanResult r = (ScanResult) results.elementAt(i);
            if (r.dtcCount > 0) total += r.dtcCount;
        }
        return total;
    }

    /**
     * Get the scan results.
     */
    public Vector getResults() {
        return results;
    }

    // =========================================================
    // Result and Listener classes
    // =========================================================

    /**
     * Result of scanning a single module.
     */
    public static class ScanResult {
        public int address;
        public String name;
        public boolean responding = false;
        public UDSClient.ECUInfo info;
        public int dtcCount = 0;
        public Vector dtcs;  // Vector of UDSClient.DTCEntry
        public String error;

        public String toString() {
            StringBuffer sb = new StringBuffer();
            String hex = Integer.toHexString(address).toUpperCase();
            if (hex.length() < 2) hex = "0" + hex;

            sb.append(hex + " - " + name);

            if (!responding) {
                sb.append(" [No response]");
                return sb.toString();
            }

            if (info != null && info.partNumber.length() > 0) {
                sb.append(" (" + info.partNumber.trim() + ")");
            }

            if (dtcCount > 0) {
                sb.append(" — " + dtcCount + " fault(s)!");
            } else if (dtcCount == 0) {
                sb.append(" — No faults");
            }

            return sb.toString();
        }

        /** Get a full report for this module. */
        public String getFullReport() {
            StringBuffer sb = new StringBuffer();
            String hex = Integer.toHexString(address).toUpperCase();
            if (hex.length() < 2) hex = "0" + hex;

            sb.append("Module " + hex + ": " + name + "\n");
            sb.append("-----------------------------\n");

            if (info != null) {
                sb.append(info.toString());
            }

            if (dtcCount == 0) {
                sb.append("No fault codes stored.\n");
            } else if (dtcCount > 0) {
                sb.append(dtcCount + " Fault code(s):\n");
                if (dtcs != null) {
                    for (int i = 0; i < dtcs.size(); i++) {
                        UDSClient.DTCEntry dtc =
                            (UDSClient.DTCEntry) dtcs.elementAt(i);
                        sb.append("  " + dtc.toString() + "\n");
                    }
                }
            } else {
                sb.append("DTC read not supported.\n");
            }

            if (error != null) {
                sb.append("Error: " + error + "\n");
            }

            return sb.toString();
        }
    }

    /**
     * Listener interface for scan progress.
     */
    public interface ScanListener {
        void onScanProgress(int address, String name, int current, int total);
        void onModuleFound(ScanResult result);
        void onScanComplete(Vector results);
    }
}
