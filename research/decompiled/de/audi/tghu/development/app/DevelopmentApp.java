/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  de.audi.atip.base.Framework
 *  de.audi.atip.hmi.HMIApplication
 *  de.audi.atip.hmi.model.HMIModel
 *  de.audi.atip.hmi.model.LabelModel
 *  de.audi.atip.hmi.modelaccess.ButtonModelGUI
 *  de.audi.atip.log.LogChannel
 *  de.audi.atip.statemachine.ap.DevelopmentActionProxy
 *  org.osgi.framework.BundleContext
 *  org.osgi.framework.ServiceRegistration
 */
package de.audi.tghu.development.app;

import de.audi.atip.base.Framework;
import de.audi.atip.hmi.HMIApplication;
import de.audi.atip.hmi.model.HMIModel;
import de.audi.atip.hmi.model.LabelModel;
import de.audi.atip.hmi.modelaccess.ButtonModelGUI;
import de.audi.atip.log.LogChannel;
import de.audi.atip.statemachine.ap.DevelopmentActionProxy;
import de.audi.tghu.development.eis.EngineeringInfoService;
import de.audi.tghu.development.manager.LogMan;
import de.audi.tghu.development.renderer.ScreenRenderer;
import java.util.Hashtable;
import org.osgi.framework.BundleContext;
import org.osgi.framework.ServiceRegistration;

public class DevelopmentApp
implements HMIApplication,
DevelopmentActionProxy {
    public static final int DEVELOPMENT_MODULE_ID = 16;
    public static final int REPAINT_MODEL_ID = 161000;
    public static LabelModel repaintModel = new LabelModel(161000);
    private BundleContext eisBundleContext = null;
    private ServiceRegistration eisPersistenceServiceReg = null;
    private int osgiRegMode = -1;
    static /* synthetic */ Class class$org$dsi$ifc$persistence$DSIPersistenceListener;
    static /* synthetic */ Class class$org$dsi$ifc$base$DSIListener;

    public DevelopmentApp(BundleContext bundleContext, int n) {
        this.eisBundleContext = bundleContext;
        this.osgiRegMode = n;
    }

    public int getId() {
        return 16;
    }

    public HMIModel getModel(int n) {
        if (n == 161000) {
            return repaintModel;
        }
        return null;
    }

    public HMIModel[] getModels() {
        return null;
    }

    public ButtonModelGUI getVirtualButton(int n) {
        return null;
    }

    public ButtonModelGUI[] getVirtualButtons() {
        return null;
    }

    public void screenVisible(int n, int n2) {
        LogChannel logChannel = Framework.getLogChannel((String)"AppDev");
        logChannel.log(1000000, "AppDevelopment visible called.");
        this.hmiActivated(n2);
    }

    public void screenHidden(int n, int n2) {
        LogChannel logChannel = Framework.getLogChannel((String)"AppDev");
        logChannel.log(1000000, "AppDevelopment hidden called.");
        this.hmiDeactivated(n2);
    }

    public void popupVisible(int n, int n2) {
    }

    public void popupHidden(int n, int n2) {
    }

    public void popupRemoved(int n, int n2) {
    }

    public void hmiActivated(int n) {
        LogMan.log(1, "DevelopmentApp.hmiActivated()");
        this.registerDSIPersistenceListener();
        ScreenRenderer screenRenderer = ScreenRenderer.getInstance(n, "DevelopmentApp.hmiActivated()");
        screenRenderer.setDevApp(this);
    }

    public void hmiDeactivated(int n) {
        LogMan.log(1, "Stopping DevelopmentApp...");
        EngineeringInfoService.getInstance().clearAllListeners();
        EngineeringInfoService.getInstance().clearAllTimers();
    }

    public void sendRepaintEvent() {
        LogMan.log(1, "DevelopmentApp: send repaint");
        repaintModel.setText("");
    }

    private void registerDSIPersistenceListener() {
        if (this.eisPersistenceServiceReg != null) {
            LogMan.log("Warning: EISPersistenceListener already registered.");
            return;
        }
        Hashtable<String, Object> hashtable = new Hashtable<String, Object>();
        hashtable.put("DEVICE_NAME", (class$org$dsi$ifc$persistence$DSIPersistenceListener == null ? (class$org$dsi$ifc$persistence$DSIPersistenceListener = DevelopmentApp.class$("org.dsi.ifc.persistence.DSIPersistenceListener")) : class$org$dsi$ifc$persistence$DSIPersistenceListener).getName());
        hashtable.put("DEVICE_INSTANCE", new Integer(0));
        this.eisPersistenceServiceReg = this.osgiRegMode == 0 ? this.eisBundleContext.registerService((class$org$dsi$ifc$persistence$DSIPersistenceListener == null ? (class$org$dsi$ifc$persistence$DSIPersistenceListener = DevelopmentApp.class$("org.dsi.ifc.persistence.DSIPersistenceListener")) : class$org$dsi$ifc$persistence$DSIPersistenceListener).getName(), (Object)EngineeringInfoService.getInstance().getPersistenceListener(), hashtable) : this.eisBundleContext.registerService((class$org$dsi$ifc$base$DSIListener == null ? (class$org$dsi$ifc$base$DSIListener = DevelopmentApp.class$("org.dsi.ifc.base.DSIListener")) : class$org$dsi$ifc$base$DSIListener).getName(), (Object)EngineeringInfoService.getInstance().getPersistenceListener(), hashtable);
    }

    public HMIModel getModel(int n, int n2) {
        return this.getModel(n2);
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

