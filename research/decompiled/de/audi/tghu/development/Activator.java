/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  org.osgi.framework.BundleActivator
 *  org.osgi.framework.BundleContext
 */
package de.audi.tghu.development;

import de.audi.tghu.development.app.AppActivator;
import de.audi.tghu.development.renderer.HMIActivator;
import de.audi.tghu.development.sm.SMActivator;
import org.osgi.framework.BundleActivator;
import org.osgi.framework.BundleContext;

public class Activator
implements BundleActivator {
    private BundleActivator appActivator = new AppActivator();
    private BundleActivator smActivator = new SMActivator();
    private BundleActivator hmiActivator = new HMIActivator();

    public void start(BundleContext bundleContext) throws Exception {
        this.appActivator.start(bundleContext);
        this.smActivator.start(bundleContext);
        this.hmiActivator.start(bundleContext);
    }

    public void stop(BundleContext bundleContext) throws Exception {
        this.appActivator.stop(bundleContext);
        this.smActivator.stop(bundleContext);
        this.hmiActivator.stop(bundleContext);
    }
}

