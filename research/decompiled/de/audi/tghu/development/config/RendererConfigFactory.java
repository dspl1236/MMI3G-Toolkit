/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  de.audi.tghu.hmi.view.HMITerminalImpl
 */
package de.audi.tghu.development.config;

import de.audi.tghu.development.config.AbstractRendererConfig;
import de.audi.tghu.development.config.RendererConfigBasic;
import de.audi.tghu.development.config.RendererConfigHigh;
import de.audi.tghu.development.manager.LogMan;
import de.audi.tghu.hmi.view.HMITerminalImpl;

public class RendererConfigFactory {
    private static AbstractRendererConfig rendererConfig = null;

    public static AbstractRendererConfig getRendererConfig(HMITerminalImpl hMITerminalImpl) {
        if (rendererConfig == null) {
            int n = hMITerminalImpl.getLayout().getDistance(1);
            int n2 = hMITerminalImpl.getLayout().getDistance(2);
            if (n == 800 && n2 == 480) {
                rendererConfig = RendererConfigHigh.getInstance(hMITerminalImpl.getTerminalID());
            } else if (n == 400 && n2 == 240) {
                rendererConfig = RendererConfigBasic.getInstance(hMITerminalImpl.getTerminalID());
            } else {
                LogMan.log("Unkown screen resolution! (" + n + ", " + n2 + ")");
            }
        }
        return rendererConfig;
    }
}

