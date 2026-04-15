/**
 * DiagApp — MMI3G Diagnostic Application
 *
 * Console-based diagnostic tool that runs on the J9 JVM.
 * Displays through the GEM script console (stdout).
 *
 * Features:
 * - Auto-Scan: Scan all modules, report DTCs
 * - Module Info: Read ECU identification
 * - Read DTCs: View fault codes for any module
 * - Clear DTCs: Clear fault codes (safe operation)
 * - Live Data: Read measurement values (when available)
 *
 * Usage:
 *   j9 -Xbootclasspath:/lsd/lsd.jxe -cp diag.jar \
 *     de.audi.mmi3g.diag.DiagApp [--simulate]
 *
 * Java 1.4 compatible.
 */
package de.audi.mmi3g.diag;

import de.audi.mmi3g.diag.uds.UDSClient;
import de.audi.mmi3g.diag.uds.UDSConstants;
import de.audi.mmi3g.diag.uds.DiagException;
import de.audi.mmi3g.diag.transport.TransportLayer;
import de.audi.mmi3g.diag.transport.SimulatedTransport;
import de.audi.mmi3g.diag.scanner.ModuleScanner;
import de.audi.mmi3g.diag.scanner.VAGModules;
import java.util.Vector;

public class DiagApp implements ModuleScanner.ScanListener {

    private TransportLayer transport;
    private ModuleScanner scanner;
    private Vector lastScanResults;
    private boolean simulate = false;

    public DiagApp(boolean simulate) {
        this.simulate = simulate;
        if (simulate) {
            this.transport = new SimulatedTransport();
        } else {
            // TODO: Auto-detect available transport
            // Try VNCI DoIP first, then /dev/can, then V850 HPIPC
            println("ERROR: No transport available.");
            println("Run with --simulate for desktop testing.");
            println("");
            println("Future transports:");
            println("  VNCI 6154a via DoIP (USB Ethernet)");
            println("  Direct CAN via /dev/can");
            println("  V850 IOC via HPIPC shared memory");
            this.transport = new SimulatedTransport();
            this.simulate = true;
        }

        this.scanner = new ModuleScanner(transport);
        this.scanner.setListener(this);
    }

    public void run() {
        showBanner();
        mainMenu();
    }

    // =========================================================
    // UI — Banner and Menus
    // =========================================================

    private void showBanner() {
        println("========================================");
        println("  MMI3G DIAGNOSTIC TOOL");
        println("  github.com/dspl1236/MMI3G-Toolkit");
        println("========================================");
        if (simulate) {
            println("  MODE: Simulation (desktop testing)");
        } else {
            println("  MODE: " + transport.getName());
        }
        println("========================================");
        println("");
    }

    private void mainMenu() {
        println("[1] Auto-Scan All Modules");
        println("[2] Scan Single Module");
        println("[3] Read DTCs from Module");
        println("[4] Clear DTCs from Module");
        println("[5] Read ECU Information");
        println("[6] Full Vehicle Report");
        println("");

        // In GEM console mode, we can't easily read input
        // so run the auto-scan automatically
        println("Starting Auto-Scan...");
        println("");

        autoScan();
    }

    // =========================================================
    // Auto-Scan
    // =========================================================

    private void autoScan() {
        println("========================================");
        println("  AUTO-SCAN — Scanning all modules...");
        println("========================================");
        println("");

        lastScanResults = scanner.autoScan();

        // Summary
        println("");
        println("========================================");
        println("  SCAN COMPLETE");
        println("========================================");

        int modulesFound = 0;
        int totalDTCs = 0;

        for (int i = 0; i < lastScanResults.size(); i++) {
            ModuleScanner.ScanResult r =
                (ModuleScanner.ScanResult) lastScanResults.elementAt(i);
            if (r.responding) modulesFound++;
            if (r.dtcCount > 0) totalDTCs += r.dtcCount;
        }

        println("  Modules responding: " + modulesFound);
        println("  Total fault codes:  " + totalDTCs);
        println("");

        // Show summary for each module
        for (int i = 0; i < lastScanResults.size(); i++) {
            ModuleScanner.ScanResult r =
                (ModuleScanner.ScanResult) lastScanResults.elementAt(i);
            if (r.responding) {
                String hex = Integer.toHexString(r.address).toUpperCase();
                if (hex.length() < 2) hex = "0" + hex;

                String status;
                if (r.dtcCount > 0) {
                    status = r.dtcCount + " FAULT(S)";
                } else if (r.dtcCount == 0) {
                    status = "OK";
                } else {
                    status = "???";
                }

                String pn = "";
                if (r.info != null && r.info.partNumber.length() > 0) {
                    pn = " " + r.info.partNumber.trim();
                }

                println("  " + hex + " " + padRight(r.name, 22)
                    + padRight(status, 14) + pn);
            }
        }

        // Show DTCs details
        if (totalDTCs > 0) {
            println("");
            println("========================================");
            println("  FAULT CODES FOUND:");
            println("========================================");

            for (int i = 0; i < lastScanResults.size(); i++) {
                ModuleScanner.ScanResult r =
                    (ModuleScanner.ScanResult) lastScanResults.elementAt(i);
                if (r.dtcCount > 0 && r.dtcs != null) {
                    String hex = Integer.toHexString(r.address).toUpperCase();
                    if (hex.length() < 2) hex = "0" + hex;
                    println("");
                    println("  [" + hex + "] " + r.name + ":");

                    for (int j = 0; j < r.dtcs.size(); j++) {
                        UDSClient.DTCEntry dtc =
                            (UDSClient.DTCEntry) r.dtcs.elementAt(j);
                        println("    " + dtc.getDTCString()
                            + " — " + dtc.getStatusText());
                    }
                }
            }
        } else {
            println("");
            println("  No fault codes found. Vehicle is clean!");
        }

        println("");
        println("========================================");
    }

    // =========================================================
    // Full Vehicle Report (save to SD)
    // =========================================================

    private void fullReport() {
        if (lastScanResults == null) {
            autoScan();
        }

        println("");
        println("========================================");
        println("  FULL VEHICLE DIAGNOSTIC REPORT");
        println("========================================");

        for (int i = 0; i < lastScanResults.size(); i++) {
            ModuleScanner.ScanResult r =
                (ModuleScanner.ScanResult) lastScanResults.elementAt(i);
            if (r.responding) {
                println("");
                println(r.getFullReport());
            }
        }
    }

    // =========================================================
    // ScanListener callbacks
    // =========================================================

    public void onScanProgress(int address, String name,
            int current, int total) {
        String hex = Integer.toHexString(address).toUpperCase();
        if (hex.length() < 2) hex = "0" + hex;
        println("  [" + current + "/" + total + "] Scanning "
            + hex + " " + name + "...");
    }

    public void onModuleFound(ModuleScanner.ScanResult result) {
        if (result.responding) {
            String status = (result.dtcCount > 0) ?
                " — " + result.dtcCount + " fault(s)!" : " — OK";
            println("    FOUND" + status);
        }
    }

    public void onScanComplete(Vector results) {
        // Summary handled in autoScan()
    }

    // =========================================================
    // Utilities
    // =========================================================

    private static void println(String s) {
        System.out.println(s);
    }

    private static String padRight(String s, int width) {
        while (s.length() < width) s = s + " ";
        return s;
    }

    // =========================================================
    // Main entry point
    // =========================================================

    public static void main(String[] args) {
        boolean simulate = false;

        for (int i = 0; i < args.length; i++) {
            if ("--simulate".equals(args[i]) || "-s".equals(args[i])) {
                simulate = true;
            }
        }

        DiagApp app = new DiagApp(simulate);
        app.run();
    }
}
