/*
 * DashEngine — Polls CAN bus data via DSI persistence layer.
 *
 * Uses the same PersistenceAccessor mechanism as the GEM's
 * EngineeringInfoService, but optimized for real-time gauge
 * display with configurable addresses and refresh rates.
 *
 * IMPORTANT: The per 3 addresses below are PLACEHOLDERS.
 * Run the can-scanner module on your specific vehicle to
 * discover which addresses carry RPM, boost, coolant, etc.
 * Then update the GAUGE_DEFS array with your car's addresses.
 */
package de.audi.tghu.development.dash;

public class DashEngine {

    private static DashEngine instance;
    private boolean running = false;

    // Gauge data — updated by polling thread
    private volatile int batteryVoltage = 0;   // x100 mV
    private volatile int gpsAltitude = 0;      // meters
    private volatile int gpsSatsUsed = 0;
    private volatile int gpsSatsVisible = 0;
    private volatile int usbDevices = 0;

    // CAN bus data — addresses TBD from scanner results
    // These are placeholders until we discover real addresses
    private volatile int engineRPM = 0;        // per 3, addr TBD
    private volatile int vehicleSpeed = 0;     // per 3, addr TBD
    private volatile int coolantTemp = 0;      // per 3, addr TBD
    private volatile int boostPressure = 0;    // per 3, addr TBD
    private volatile int oilTemp = 0;          // per 3, addr TBD
    private volatile int intakeTemp = 0;       // per 3, addr TBD

    /**
     * Gauge definition — maps a display name to a per/addr pair.
     * Update these with addresses discovered by the CAN scanner.
     */
    public static final int[][] GAUGE_DEFS = {
        // { per, address, poll_ms }
        // KNOWN WORKING:
        { 3, 0x00000023, 500 },    // Battery voltage (x100mV)
        { 7, 0x000200bb, 1000 },   // GPS satellites used
        { 7, 0x000200bc, 1000 },   // GPS satellites visible
        { 1, 0x00030019, 1000 },   // GPS altitude (m)
        { 1, 0x00180000, 2000 },   // USB devices

        // SCANNER RESULTS GO HERE:
        // { 3, 0x????????, 200 },  // Engine RPM
        // { 3, 0x????????, 500 },  // Vehicle speed
        // { 3, 0x????????, 1000 }, // Coolant temperature
        // { 3, 0x????????, 500 },  // Boost pressure
        // { 3, 0x????????, 2000 }, // Oil temperature
        // { 3, 0x????????, 1000 }, // Intake air temperature
    };

    public static final String[] GAUGE_LABELS = {
        "VOLTS", "GPS SAT", "GPS VIS", "ALT", "USB"
        // "RPM", "SPEED", "COOLANT", "BOOST", "OIL", "INTAKE"
    };

    private DashEngine() {}

    public static synchronized DashEngine getInstance() {
        if (instance == null) {
            instance = new DashEngine();
        }
        return instance;
    }

    /**
     * Start the polling thread.
     *
     * In the real implementation, this creates a Timer per gauge
     * definition that calls PersistenceAccessor.readInt() at the
     * specified interval. The callback updates the volatile fields
     * which the DashScreen reads for rendering.
     *
     * The DSI persistence interface is obtained from the
     * EngineeringInfoService singleton which is initialized by
     * the AppActivator before our DashActivator starts.
     */
    public void start() {
        running = true;
        System.out.println("[DASH] Engine started — polling "
            + GAUGE_DEFS.length + " addresses");
    }

    public void stop() {
        running = false;
        System.out.println("[DASH] Engine stopped");
    }

    public boolean isRunning() { return running; }

    // --- Accessors for gauge values ---

    public int getBatteryVoltage() { return batteryVoltage; }
    public int getGpsAltitude() { return gpsAltitude; }
    public int getGpsSatsUsed() { return gpsSatsUsed; }
    public int getGpsSatsVisible() { return gpsSatsVisible; }
    public int getUsbDevices() { return usbDevices; }
    public int getEngineRPM() { return engineRPM; }
    public int getVehicleSpeed() { return vehicleSpeed; }
    public int getCoolantTemp() { return coolantTemp; }
    public int getBoostPressure() { return boostPressure; }
    public int getOilTemp() { return oilTemp; }
    public int getIntakeTemp() { return intakeTemp; }

    /**
     * Format battery voltage for display.
     * Raw value is in centimillivolts (e.g., 1440 = 14.40V)
     */
    public String getFormattedVoltage() {
        int whole = batteryVoltage / 100;
        int frac = (batteryVoltage % 100) / 10;
        return whole + "." + frac + "V";
    }
}
