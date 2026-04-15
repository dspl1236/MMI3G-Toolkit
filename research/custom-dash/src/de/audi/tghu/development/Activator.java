/*
 * MMI3G-Toolkit Digital Dashboard
 * Drop-in replacement for AppDevelopment.jar
 *
 * Instead of the Green Engineering Menu tree, this activator
 * renders a live gauges dashboard when CAR+BACK is pressed.
 * The top-left soft key opens the original GEM screen tree.
 *
 * INSTALLATION:
 *   1. Backup /mnt/efs-system/lsd/AppDevelopment.jar
 *   2. Copy this compiled JAR as AppDevelopment.jar
 *   3. Reboot MMI
 *   4. CAR+BACK now opens the digital dash
 *   5. Top-left soft key → original GEM
 *
 * COMPILATION:
 *   javac -source 1.5 -target 1.5 -bootclasspath <j9-rt.jar> \
 *     -cp osgi.jar:dsi.jar:atip.jar \
 *     src/de/audi/tghu/development/Activator.java
 *   jar cf AppDevelopment.jar -C src .
 *
 * The OSGi, DSI, and ATIP interfaces come from the original
 * lsd.jxe — they're available at runtime on the bootclasspath.
 * We only need them at compile time for type checking.
 *
 * ARCHITECTURE:
 *   Activator (BundleActivator)
 *     ├── DashApp (application logic)
 *     │     ├── Polls CAN data via DSI PersistenceAccessor
 *     │     ├── Manages gauge state and refresh timers
 *     │     └── Handles soft key input for mode switching
 *     ├── DashRenderer (HMI rendering)
 *     │     ├── Renders 4-gauge layout on 800x480 display
 *     │     ├── Gauge widgets: boost, RPM, coolant, voltage
 *     │     └── Status bar: GPS, USB, network
 *     └── DashSMM (state machine)
 *           └── Registers with HMI framework for CAR+BACK combo
 *
 * When the user presses the GEM soft key, DashRenderer delegates
 * to the original GEM ScreenRenderer which loads the ESD screen
 * tree from /engdefs/ as normal. This preserves full GEM access.
 */
package de.audi.tghu.development;

import de.audi.tghu.development.app.AppActivator;
import de.audi.tghu.development.dash.DashActivator;
import de.audi.tghu.development.renderer.HMIActivator;
import de.audi.tghu.development.sm.SMActivator;
import org.osgi.framework.BundleActivator;
import org.osgi.framework.BundleContext;

/**
 * Main entry point — registered as Bundle 53 (AppDevelopment).
 *
 * This replaces the stock Activator. The key change is that
 * DashActivator is started BEFORE the original AppActivator,
 * so the dash intercepts the HMI screen before the GEM tree
 * is rendered. The GEM remains accessible via soft key.
 */
public class Activator implements BundleActivator {

    // Original GEM activators — kept for GEM access
    private BundleActivator appActivator = new AppActivator();
    private BundleActivator smActivator = new SMActivator();
    private BundleActivator hmiActivator = new HMIActivator();

    // Our custom dashboard activator
    private BundleActivator dashActivator = new DashActivator();

    public void start(BundleContext bundleContext) throws Exception {
        // Start the original GEM components first (they register
        // ESD screens and the engineering info service)
        this.appActivator.start(bundleContext);
        this.smActivator.start(bundleContext);

        // Start our dashboard — it intercepts the HMI rendering
        // and shows the dash instead of the GEM tree
        this.dashActivator.start(bundleContext);

        // Start the original HMI last — our dash hooks in before it
        this.hmiActivator.start(bundleContext);
    }

    public void stop(BundleContext bundleContext) throws Exception {
        this.dashActivator.stop(bundleContext);
        this.hmiActivator.stop(bundleContext);
        this.appActivator.stop(bundleContext);
        this.smActivator.stop(bundleContext);
    }
}
