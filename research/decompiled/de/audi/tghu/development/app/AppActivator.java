/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  de.audi.atip.base.AbstractActivator
 *  org.dsi.ifc.admin.JDSIAdmin
 *  org.dsi.ifc.base.DSIBase
 *  org.dsi.ifc.persistence.DSIPersistence
 *  org.osgi.framework.BundleContext
 *  org.osgi.framework.ServiceReference
 *  org.osgi.framework.ServiceRegistration
 *  org.osgi.util.tracker.ServiceTracker
 *  org.osgi.util.tracker.ServiceTrackerCustomizer
 */
package de.audi.tghu.development.app;

import de.audi.atip.base.AbstractActivator;
import de.audi.tghu.development.app.DevelopmentApp;
import de.audi.tghu.development.eis.EngineeringInfoService;
import de.audi.tghu.development.manager.LogMan;
import de.audi.tghu.sim.persistence.FakePersistence;
import java.util.Hashtable;
import org.dsi.ifc.admin.JDSIAdmin;
import org.dsi.ifc.base.DSIBase;
import org.dsi.ifc.persistence.DSIPersistence;
import org.osgi.framework.BundleContext;
import org.osgi.framework.ServiceReference;
import org.osgi.framework.ServiceRegistration;
import org.osgi.util.tracker.ServiceTracker;
import org.osgi.util.tracker.ServiceTrackerCustomizer;

public class AppActivator
extends AbstractActivator
implements ServiceTrackerCustomizer {
    private static final String PROPERTY_KEY_DSI_REGMODE = "de.audi.tghu.engineering.dsi_regmode";
    static final int DSIREGMODE_CLASSIC = 0;
    static final int DSIREGMODE_NEW = 1;
    private static final String[] DEVELOPMENT_SVC = new String[]{(class$de$audi$atip$hmi$HMIApplication == null ? (class$de$audi$atip$hmi$HMIApplication = AppActivator.class$("de.audi.atip.hmi.HMIApplication")) : class$de$audi$atip$hmi$HMIApplication).getName(), (class$de$audi$atip$statemachine$ActionProxy == null ? (class$de$audi$atip$statemachine$ActionProxy = AppActivator.class$("de.audi.atip.statemachine.ActionProxy")) : class$de$audi$atip$statemachine$ActionProxy).getName()};
    private DevelopmentApp developmentApp;
    private ServiceRegistration developmentSvcReg;
    private ServiceTracker dsiServiceTracker;
    private ServiceTracker dsiAdminTracker;
    private ServiceReference dsiAdminRef;
    private ServiceReference dsiPersistenceRef;
    private JDSIAdmin dsiAdmin = null;
    static /* synthetic */ Class class$de$audi$atip$hmi$HMIApplication;
    static /* synthetic */ Class class$de$audi$atip$statemachine$ActionProxy;
    static /* synthetic */ Class class$org$dsi$ifc$base$DSIBase;
    static /* synthetic */ Class class$org$dsi$ifc$persistence$DSIPersistence;
    static /* synthetic */ Class class$org$dsi$ifc$admin$JDSIAdmin;

    public void start(BundleContext bundleContext) throws Exception {
        try {
            super.start(bundleContext);
            this.logTimestamp("before Activator");
            String string = System.getProperty(PROPERTY_KEY_DSI_REGMODE, "new");
            int n = string.equalsIgnoreCase("classic") ? 0 : 1;
            LogMan.log("AppDevelopment Activator: dsi registration mode = " + n);
            FakePersistence fakePersistence = new FakePersistence();
            EngineeringInfoService.getInstance().setFakePersistence(fakePersistence);
            fakePersistence.initialize(bundleContext);
            this.developmentApp = new DevelopmentApp(bundleContext, n);
            Hashtable<String, Object> hashtable = new Hashtable<String, Object>();
            hashtable.put("moduleID", new Integer(this.developmentApp.getId()));
            hashtable.put("applicationName", "Development");
            this.developmentSvcReg = this.bundleContext.registerService(DEVELOPMENT_SVC, (Object)this.developmentApp, hashtable);
            this.dsiServiceTracker = n == 0 ? new ServiceTracker(bundleContext, (class$org$dsi$ifc$base$DSIBase == null ? (class$org$dsi$ifc$base$DSIBase = AppActivator.class$("org.dsi.ifc.base.DSIBase")) : class$org$dsi$ifc$base$DSIBase).getName(), (ServiceTrackerCustomizer)this) : new ServiceTracker(bundleContext, (class$org$dsi$ifc$persistence$DSIPersistence == null ? (class$org$dsi$ifc$persistence$DSIPersistence = AppActivator.class$("org.dsi.ifc.persistence.DSIPersistence")) : class$org$dsi$ifc$persistence$DSIPersistence).getName(), (ServiceTrackerCustomizer)this);
            this.dsiServiceTracker.open();
            this.dsiAdminTracker = new ServiceTracker(bundleContext, (class$org$dsi$ifc$admin$JDSIAdmin == null ? (class$org$dsi$ifc$admin$JDSIAdmin = AppActivator.class$("org.dsi.ifc.admin.JDSIAdmin")) : class$org$dsi$ifc$admin$JDSIAdmin).getName(), new ServiceTrackerCustomizer(){

                public Object addingService(ServiceReference serviceReference) {
                    AppActivator.this.dsiAdminRef = serviceReference;
                    if (serviceReference != null) {
                        AppActivator.this.dsiAdmin = (JDSIAdmin)AppActivator.this.bundleContext.getService(serviceReference);
                        try {
                            AppActivator.this.dsiAdmin.startService((class$org$dsi$ifc$persistence$DSIPersistence == null ? (class$org$dsi$ifc$persistence$DSIPersistence = AppActivator.class$("org.dsi.ifc.persistence.DSIPersistence")) : class$org$dsi$ifc$persistence$DSIPersistence).getName(), 0);
                        }
                        catch (Throwable throwable) {
                            LogMan.log("AppDevelopment Activator: failed to start persistence service, reason: " + throwable.getMessage());
                        }
                        return AppActivator.this.dsiAdmin;
                    }
                    return null;
                }

                public void modifiedService(ServiceReference serviceReference, Object object) {
                    if (serviceReference == AppActivator.this.dsiAdminRef) {
                        AppActivator.this.dsiAdmin = null;
                    }
                }

                public void removedService(ServiceReference serviceReference, Object object) {
                    if (serviceReference == AppActivator.this.dsiAdminRef) {
                        AppActivator.this.dsiAdmin = null;
                    }
                }
            });
            this.dsiAdminTracker.open();
            LogMan.log("AppDevelopment initialized.");
            this.logTimestamp("after Activator");
        }
        catch (Exception exception) {
            exception.printStackTrace();
            throw exception;
        }
    }

    public void stop(BundleContext bundleContext) throws Exception {
        this.dsiAdminTracker.close();
        this.dsiServiceTracker.close();
        this.dsiAdminTracker = null;
        this.dsiServiceTracker = null;
        if (this.dsiAdminRef != null) {
            bundleContext.ungetService(this.dsiAdminRef);
            this.dsiAdminRef = null;
        }
        this.dsiAdmin = null;
        EngineeringInfoService.getInstance().setPersistence(null);
        EngineeringInfoService.getInstance().setFakePersistence(null);
        if (this.dsiPersistenceRef != null) {
            bundleContext.ungetService(this.dsiPersistenceRef);
            this.dsiPersistenceRef = null;
        }
        this.developmentSvcReg.unregister();
        this.developmentSvcReg = null;
        this.developmentApp = null;
        super.stop(bundleContext);
    }

    public Object addingService(ServiceReference serviceReference) {
        String string = (String)serviceReference.getProperty("DEVICE_NAME");
        if (string == null) {
            LogMan.log("no deviceName specified for DSI Service");
            return null;
        }
        if (string.equals((class$org$dsi$ifc$persistence$DSIPersistence == null ? (class$org$dsi$ifc$persistence$DSIPersistence = AppActivator.class$("org.dsi.ifc.persistence.DSIPersistence")) : class$org$dsi$ifc$persistence$DSIPersistence).getName() + "[FakePer]")) {
            try {
                DSIBase dSIBase = (DSIBase)this.bundleContext.getService(serviceReference);
                EngineeringInfoService.getInstance().setFakePersistence((DSIPersistence)dSIBase);
                return dSIBase;
            }
            catch (ClassCastException classCastException) {
                this.bundleContext.ungetService(serviceReference);
                LogMan.log("deviceName does not match DSI Service");
                return null;
            }
        }
        if (string.equals((class$org$dsi$ifc$persistence$DSIPersistence == null ? (class$org$dsi$ifc$persistence$DSIPersistence = AppActivator.class$("org.dsi.ifc.persistence.DSIPersistence")) : class$org$dsi$ifc$persistence$DSIPersistence).getName())) {
            LogMan.log("AppDevelopment Activator: H/B DSIPersistence found!");
            try {
                this.dsiPersistenceRef = serviceReference;
                DSIBase dSIBase = (DSIBase)this.bundleContext.getService(serviceReference);
                EngineeringInfoService.getInstance().setPersistence((DSIPersistence)dSIBase);
                return dSIBase;
            }
            catch (ClassCastException classCastException) {
                this.bundleContext.ungetService(serviceReference);
                LogMan.log("deviceName does not match DSI Service");
                return null;
            }
        }
        return null;
    }

    public void modifiedService(ServiceReference serviceReference, Object object) {
        String string = (String)serviceReference.getProperty("DEVICE_NAME");
        if (string == null) {
            LogMan.log("no deviceName specified for DSI Service");
            return;
        }
        if (string.equals((class$org$dsi$ifc$persistence$DSIPersistence == null ? (class$org$dsi$ifc$persistence$DSIPersistence = AppActivator.class$("org.dsi.ifc.persistence.DSIPersistence")) : class$org$dsi$ifc$persistence$DSIPersistence).getName() + "[FakePer]")) {
            EngineeringInfoService.getInstance().setFakePersistence((DSIPersistence)object);
            this.bundleContext.ungetService(serviceReference);
        } else if (string.equals((class$org$dsi$ifc$persistence$DSIPersistence == null ? (class$org$dsi$ifc$persistence$DSIPersistence = AppActivator.class$("org.dsi.ifc.persistence.DSIPersistence")) : class$org$dsi$ifc$persistence$DSIPersistence).getName())) {
            EngineeringInfoService.getInstance().setPersistence((DSIPersistence)object);
            this.bundleContext.ungetService(serviceReference);
        } else {
            this.bundleContext.ungetService(serviceReference);
        }
    }

    public void removedService(ServiceReference serviceReference, Object object) {
        String string = (String)serviceReference.getProperty("DEVICE_NAME");
        if (string == null) {
            LogMan.log("no deviceName specified for DSI Service");
            return;
        }
        if (string.equals((class$org$dsi$ifc$persistence$DSIPersistence == null ? (class$org$dsi$ifc$persistence$DSIPersistence = AppActivator.class$("org.dsi.ifc.persistence.DSIPersistence")) : class$org$dsi$ifc$persistence$DSIPersistence).getName() + "[FakePer]")) {
            EngineeringInfoService.getInstance().setFakePersistence(null);
            this.bundleContext.ungetService(serviceReference);
        } else if (string.equals((class$org$dsi$ifc$persistence$DSIPersistence == null ? (class$org$dsi$ifc$persistence$DSIPersistence = AppActivator.class$("org.dsi.ifc.persistence.DSIPersistence")) : class$org$dsi$ifc$persistence$DSIPersistence).getName())) {
            EngineeringInfoService.getInstance().setPersistence(null);
            this.dsiPersistenceRef = null;
            this.bundleContext.ungetService(serviceReference);
        } else {
            this.bundleContext.ungetService(serviceReference);
        }
    }

    static /* synthetic */ Class class$(String string) {
        try {
            return Class.forName(string);
        }
        catch (ClassNotFoundException classNotFoundException) {
            throw new NoClassDefFoundError(classNotFoundException.getMessage());
        }
    }
}

