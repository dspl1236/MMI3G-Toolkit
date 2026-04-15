/*
 * DashScreen — Renders the digital dashboard on the 800x480 MMI display.
 *
 * LAYOUT (800 x 480):
 * ┌────────────────────────────────────────────────────────┐
 * │ DIGITAL DASH                        14.4V  6/9 GPS    │ <- status bar (32px)
 * ├──────────────────────┬─────────────────────────────────┤
 * │                      │                                 │
 * │      BOOST           │          RPM                    │
 * │      12.4 PSI        │          3,250                  │
 * │                      │                                 │ <- gauge area (384px)
 * ├──────────────────────┼─────────────────────────────────┤
 * │                      │                                 │
 * │      COOLANT         │          OIL TEMP               │
 * │      195°F           │          220°F                  │
 * │                      │                                 │
 * ├──────────────────────┴─────────────────────────────────┤
 * │  [GEM]      [DIAG]       [SCROLL]        [BACK]       │ <- soft keys (64px)
 * └────────────────────────────────────────────────────────┘
 *
 * SOFT KEY MAPPING:
 *   Top-left:     GEM — Opens original Green Engineering Menu
 *   Top-right:    DIAG — Quick diagnostic view (processes, memory)
 *   Bottom-left:  SCROLL — Cycle through gauge pages
 *   Bottom-right: BACK — Exit dashboard (return to normal MMI)
 *
 * GAUGE PAGES (cycle with SCROLL):
 *   Page 1: BOOST / RPM / COOLANT / OIL TEMP (performance)
 *   Page 2: SPEED / RPM / VOLTS / INTAKE TEMP (driving)
 *   Page 3: GPS ALT / GPS SATS / VOLTS / USB (system)
 *
 * RENDERING:
 *   The HMI framework on MMI3G uses a proprietary display layer,
 *   not AWT/Swing. The actual rendering calls will need to use
 *   whatever drawing API the ScreenRenderer and Widget classes
 *   expose. From the decompiled code, the framework appears to
 *   support:
 *     - Text rendering (labels, values)
 *     - Rectangle fills (backgrounds, gauge bars)
 *     - Image blitting (from /lsd/images/)
 *     - Repaint scheduling (RepaintThread)
 *
 *   The ConsoleScreen class shows how the GEM renders text output
 *   from scripts — it uses a ConsoleBuffer with fixed character
 *   positions on the 800x480 display.
 */
package de.audi.tghu.development.dash;

public class DashScreen {

    // Display constants
    public static final int SCREEN_W = 800;
    public static final int SCREEN_H = 480;
    public static final int STATUS_H = 32;
    public static final int SOFTKEY_H = 64;
    public static final int GAUGE_H = (SCREEN_H - STATUS_H - SOFTKEY_H) / 2;
    public static final int GAUGE_W = SCREEN_W / 2;

    // Gauge page state
    private int currentPage = 0;
    private static final int NUM_PAGES = 3;

    // Gauge page definitions
    // Each page has 4 gauges: [top-left, top-right, bottom-left, bottom-right]
    private static final String[][] PAGE_LABELS = {
        { "BOOST",   "RPM",      "COOLANT",  "OIL TEMP" },
        { "SPEED",   "RPM",      "VOLTS",    "INTAKE"   },
        { "GPS ALT", "GPS SATS", "VOLTS",    "USB DEV"  },
    };

    // Soft key labels
    private static final String[] SOFTKEY_LABELS = {
        "GEM", "DIAG", "PAGE", "BACK"
    };

    // Data source
    private DashEngine engine;

    // State
    private boolean showGEM = false;
    private boolean showDiag = false;

    public DashScreen(DashEngine engine) {
        this.engine = engine;
    }

    /**
     * Get gauge value for current page and position.
     * Position: 0=top-left, 1=top-right, 2=bottom-left, 3=bottom-right
     */
    public String getGaugeValue(int position) {
        switch (currentPage) {
            case 0: // Performance
                switch (position) {
                    case 0: return formatBoost(engine.getBoostPressure());
                    case 1: return formatRPM(engine.getEngineRPM());
                    case 2: return formatTemp(engine.getCoolantTemp());
                    case 3: return formatTemp(engine.getOilTemp());
                }
                break;
            case 1: // Driving
                switch (position) {
                    case 0: return formatSpeed(engine.getVehicleSpeed());
                    case 1: return formatRPM(engine.getEngineRPM());
                    case 2: return engine.getFormattedVoltage();
                    case 3: return formatTemp(engine.getIntakeTemp());
                }
                break;
            case 2: // System
                switch (position) {
                    case 0: return engine.getGpsAltitude() + " m";
                    case 1: return engine.getGpsSatsUsed() + "/" + engine.getGpsSatsVisible();
                    case 2: return engine.getFormattedVoltage();
                    case 3: return String.valueOf(engine.getUsbDevices());
                }
                break;
        }
        return "--";
    }

    public String getGaugeLabel(int position) {
        if (currentPage >= 0 && currentPage < PAGE_LABELS.length
            && position >= 0 && position < 4) {
            return PAGE_LABELS[currentPage][position];
        }
        return "";
    }

    public String getStatusBar() {
        return engine.getFormattedVoltage()
            + "  GPS:" + engine.getGpsSatsUsed()
            + "/" + engine.getGpsSatsVisible()
            + "  Page " + (currentPage + 1) + "/" + NUM_PAGES;
    }

    /**
     * Handle soft key press.
     * Returns: 0=handled, 1=open GEM, 2=exit dash
     */
    public int onSoftKey(int keyIndex) {
        switch (keyIndex) {
            case 0: // GEM
                showGEM = true;
                return 1; // Signal to switch to GEM renderer
            case 1: // DIAG
                showDiag = !showDiag;
                return 0;
            case 2: // PAGE
                currentPage = (currentPage + 1) % NUM_PAGES;
                return 0;
            case 3: // BACK
                return 2; // Signal to exit
        }
        return 0;
    }

    public void nextPage() {
        currentPage = (currentPage + 1) % NUM_PAGES;
    }

    public int getCurrentPage() { return currentPage; }
    public boolean isShowingGEM() { return showGEM; }
    public boolean isShowingDiag() { return showDiag; }

    public void setShowGEM(boolean b) { showGEM = b; }
    public void setShowDiag(boolean b) { showDiag = b; }

    // --- Formatting helpers ---

    private String formatRPM(int rpm) {
        if (rpm <= 0) return "--";
        if (rpm >= 1000) {
            return (rpm / 1000) + "," + String.valueOf((rpm % 1000) + 1000).substring(1);
        }
        return String.valueOf(rpm);
    }

    private String formatBoost(int raw) {
        if (raw <= 0) return "-- PSI";
        // Raw value format TBD from scanner results
        int whole = raw / 10;
        int frac = raw % 10;
        return whole + "." + frac + " PSI";
    }

    private String formatSpeed(int raw) {
        if (raw <= 0) return "-- MPH";
        // Raw value format TBD from scanner results
        return raw + " MPH";
    }

    private String formatTemp(int raw) {
        if (raw <= 0) return "-- F";
        // Raw value format TBD from scanner results
        return raw + "\u00B0F";
    }
}
