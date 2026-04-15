/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  de.audi.atip.base.AbstractActivator
 *  de.audi.atip.hmi.HMIBundle
 *  de.audi.atip.hmi.view.Screen
 *  de.audi.atip.i18n.I18NTarget
 *  org.osgi.framework.BundleContext
 *  org.osgi.framework.ServiceRegistration
 */
package de.audi.tghu.development.renderer;

import de.audi.atip.base.AbstractActivator;
import de.audi.atip.hmi.HMIBundle;
import de.audi.atip.hmi.view.Screen;
import de.audi.atip.i18n.I18NTarget;
import de.audi.tghu.development.app.DevelopmentScreenFactory;
import java.io.InputStream;
import java.util.Hashtable;
import java.util.Locale;
import org.osgi.framework.BundleContext;
import org.osgi.framework.ServiceRegistration;

public class HMIActivator
extends AbstractActivator
implements HMIBundle,
I18NTarget {
    private static final int MODULE_ID = 16;
    private ServiceRegistration svcRegD4;
    private ServiceRegistration svcRegRnsmid;
    private ServiceRegistration svcRegAU210;
    private ServiceRegistration svcRegBentley;
    static /* synthetic */ Class class$de$audi$atip$hmi$HMIBundle;

    public void start(BundleContext bundleContext) throws Exception {
        super.start(bundleContext);
        this.logTimestamp("before Activator");
        Hashtable<String, String> hashtable = new Hashtable<String, String>();
        hashtable.put("ApplicationName", "Development");
        hashtable.put("Skin", "D4");
        this.svcRegD4 = bundleContext.registerService((class$de$audi$atip$hmi$HMIBundle == null ? (class$de$audi$atip$hmi$HMIBundle = HMIActivator.class$("de.audi.atip.hmi.HMIBundle")) : class$de$audi$atip$hmi$HMIBundle).getName(), (Object)this, hashtable);
        Hashtable<String, String> hashtable2 = new Hashtable<String, String>();
        hashtable2.put("ApplicationName", "Development");
        hashtable2.put("Skin", "Rnsmid");
        this.svcRegRnsmid = bundleContext.registerService((class$de$audi$atip$hmi$HMIBundle == null ? (class$de$audi$atip$hmi$HMIBundle = HMIActivator.class$("de.audi.atip.hmi.HMIBundle")) : class$de$audi$atip$hmi$HMIBundle).getName(), (Object)this, hashtable2);
        Hashtable<String, String> hashtable3 = new Hashtable<String, String>();
        hashtable3.put("ApplicationName", "Development");
        hashtable3.put("Skin", "AU210");
        this.svcRegAU210 = bundleContext.registerService((class$de$audi$atip$hmi$HMIBundle == null ? (class$de$audi$atip$hmi$HMIBundle = HMIActivator.class$("de.audi.atip.hmi.HMIBundle")) : class$de$audi$atip$hmi$HMIBundle).getName(), (Object)this, hashtable3);
        Hashtable<String, String> hashtable4 = new Hashtable<String, String>();
        hashtable4.put("ApplicationName", "Development");
        hashtable4.put("Skin", "Bentley");
        this.svcRegBentley = bundleContext.registerService((class$de$audi$atip$hmi$HMIBundle == null ? (class$de$audi$atip$hmi$HMIBundle = HMIActivator.class$("de.audi.atip.hmi.HMIBundle")) : class$de$audi$atip$hmi$HMIBundle).getName(), (Object)this, hashtable4);
        this.logTimestamp("after Activator");
    }

    public void stop(BundleContext bundleContext) throws Exception {
        if (this.svcRegD4 != null) {
            this.svcRegD4.unregister();
            this.svcRegD4 = null;
        }
        if (this.svcRegRnsmid != null) {
            this.svcRegRnsmid.unregister();
            this.svcRegRnsmid = null;
        }
        if (this.svcRegAU210 != null) {
            this.svcRegAU210.unregister();
            this.svcRegAU210 = null;
        }
        if (this.svcRegBentley != null) {
            this.svcRegBentley.unregister();
            this.svcRegBentley = null;
        }
        super.stop(bundleContext);
    }

    public String getSkin() {
        return "Standard";
    }

    public int getId() {
        return 16;
    }

    public InputStream getImageInputStream(int n) {
        return DevelopmentScreenFactory.getInstance().getImageInputStream(n);
    }

    public String getText(int n) {
        return DevelopmentScreenFactory.getInstance().getText(n);
    }

    public void setLanguage(int n) {
    }

    public void resetLocale(Locale locale) {
    }

    public InputStream getImageInputStream(int n, int n2) {
        return null;
    }

    public String getImagePath(int n, int n2) {
        return null;
    }

    public Screen[] getPartialPopups(int n) {
        return null;
    }

    public Screen getScreen(int n, int n2) {
        return DevelopmentScreenFactory.getInstance().getScreen(n, n2);
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

