/*
 * DashActivator — Registers the digital dashboard with the HMI framework.
 *
 * This activator starts the dash polling engine and registers
 * a custom screen renderer that intercepts the GEM display.
 */
package de.audi.tghu.development.dash;

import org.osgi.framework.BundleActivator;
import org.osgi.framework.BundleContext;

public class DashActivator implements BundleActivator {

    private DashEngine engine;
    private DashScreen screen;

    public void start(BundleContext ctx) throws Exception {
        // Initialize the polling engine for CAN bus data
        engine = DashEngine.getInstance();
        engine.start();

        // Initialize the dashboard screen renderer
        screen = new DashScreen(engine);

        System.out.println("[DASH] Digital Dashboard started");
    }

    public void stop(BundleContext ctx) throws Exception {
        if (engine != null) {
            engine.stop();
        }
        System.out.println("[DASH] Digital Dashboard stopped");
    }
}
