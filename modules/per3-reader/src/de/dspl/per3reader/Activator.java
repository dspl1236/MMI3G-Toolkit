package de.dspl.per3reader;

import java.io.File;
import java.util.Hashtable;

import org.dsi.ifc.persistence.DSIPersistence;
import org.dsi.ifc.persistence.DSIPersistenceListener;
import org.osgi.framework.BundleActivator;
import org.osgi.framework.BundleContext;
import org.osgi.framework.ServiceReference;
import org.osgi.framework.ServiceRegistration;
import org.osgi.util.tracker.ServiceTracker;
import org.osgi.util.tracker.ServiceTrackerCustomizer;

/**
 * OSGi BundleActivator for the per3-reader module.
 *
 * Lifecycle:
 *   start(ctx):
 *     1. Open ServiceTracker on org.dsi.ifc.persistence.DSIPersistence.
 *     2. When a live DSIPersistence appears (addingService):
 *          a. Create Per3Reader wrapping it.
 *          b. Register Per3Reader as an OSGi service of type
 *             DSIPersistenceListener — the DSIPersistence implementation's
 *             own internal ServiceTracker picks it up and starts routing
 *             callbacks to us. (See FakePersistence.initialize() for the
 *             inverse side of this pattern.)
 *          c. Start the TriggerLoop thread watching the request directory.
 *
 *   stop(ctx):
 *     Shut down the loop, unregister the listener, release the service.
 *
 * Install: drop per3-reader.jar into /mnt/efs-system/lsd/ under a name
 * already in the bootclasspath (see lsd.sh). DSITracer.jar slot is the
 * documented extension point.
 */
public class Activator implements BundleActivator, ServiceTrackerCustomizer {

    public static final String PROP_TRIGGER_DIR = "de.dspl.per3reader.triggerdir";
    public static final String DEFAULT_TRIGGER_DIR = "/fs/sda1/per3req";
    public static final String FALLBACK_TRIGGER_DIR = "/tmp/per3req";

    private BundleContext ctx;
    private ServiceTracker dsiTracker;
    private ServiceReference dsiRef;
    private Per3Reader reader;
    private ServiceRegistration listenerReg;
    private TriggerLoop loop;

    public void start(BundleContext ctx) throws Exception {
        this.ctx = ctx;
        log("start(): opening DSIPersistence ServiceTracker");
        this.dsiTracker = new ServiceTracker(ctx,
                "org.dsi.ifc.persistence.DSIPersistence",
                this);
        this.dsiTracker.open();
        log("start(): tracker open — waiting for DSIPersistence service registration");
    }

    public void stop(BundleContext ctx) throws Exception {
        log("stop(): shutting down");
        if (this.loop != null) {
            this.loop.shutdown();
            this.loop = null;
        }
        if (this.listenerReg != null) {
            try { this.listenerReg.unregister(); } catch (Throwable t) { /* ignore */ }
            this.listenerReg = null;
        }
        this.reader = null;
        if (this.dsiRef != null) {
            ctx.ungetService(this.dsiRef);
            this.dsiRef = null;
        }
        if (this.dsiTracker != null) {
            this.dsiTracker.close();
            this.dsiTracker = null;
        }
        this.ctx = null;
    }

    // --- ServiceTrackerCustomizer ------------------------------------------

    public Object addingService(ServiceReference ref) {
        // Discriminate real DSIPersistence from the FakePer variant via the
        // DEVICE_NAME property — AppActivator uses the same mechanism.
        Object devName = ref.getProperty("DEVICE_NAME");
        if (devName != null && devName.toString().endsWith("[FakePer]")) {
            log("addingService: skipping FakePer variant");
            return null;
        }

        Object svc = this.ctx.getService(ref);
        if (!(svc instanceof DSIPersistence)) {
            this.ctx.ungetService(ref);
            return null;
        }

        log("addingService: got live DSIPersistence (device=" + devName + ")");
        this.dsiRef = ref;
        DSIPersistence dsi = (DSIPersistence) svc;
        this.reader = new Per3Reader(dsi);

        // Register our reader as a DSIPersistenceListener OSGi service so
        // the DSI implementation's internal tracker routes callbacks to us.
        Hashtable props = new Hashtable();
        props.put("DEVICE_NAME", "de.dspl.per3reader.Per3Reader");
        this.listenerReg = this.ctx.registerService(
                "org.dsi.ifc.persistence.DSIPersistenceListener",
                this.reader,
                props);
        log("addingService: registered as DSIPersistenceListener OSGi service");

        File dir = new File(pickTriggerDir());
        this.loop = new TriggerLoop(this.reader, dir);
        this.loop.start();
        log("addingService: trigger loop started, watching " + dir);
        return svc;
    }

    public void modifiedService(ServiceReference ref, Object service) {
        // No action — the service reference we hold is still valid.
    }

    public void removedService(ServiceReference ref, Object service) {
        log("removedService: DSIPersistence going away — stopping loop");
        if (this.loop != null) {
            this.loop.shutdown();
            this.loop = null;
        }
        if (this.listenerReg != null) {
            try { this.listenerReg.unregister(); } catch (Throwable t) { /* ignore */ }
            this.listenerReg = null;
        }
        this.reader = null;
        if (ref == this.dsiRef) {
            this.ctx.ungetService(ref);
            this.dsiRef = null;
        }
    }

    // --- Helpers ------------------------------------------------------------

    private static String pickTriggerDir() {
        String override = System.getProperty(PROP_TRIGGER_DIR);
        if (override != null && override.length() > 0) return override;
        File sd = new File(DEFAULT_TRIGGER_DIR).getParentFile();
        if (sd != null && sd.exists()) return DEFAULT_TRIGGER_DIR;
        return FALLBACK_TRIGGER_DIR;
    }

    private static void log(String msg) {
        System.err.println("[per3-reader] " + msg);
    }
}
