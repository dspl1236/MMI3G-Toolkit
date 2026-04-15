/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  de.audi.tghu.hmi.view.HMITerminalImpl
 *  fi.hybrid.a2dg.Graphics2D
 *  fi.hybrid.hwg.Composite
 *  fi.hybrid.hwg.Graphics
 *  org.dsi.ifc.base.DSIFatalException
 *  org.dsi.ifc.base.DSINonFatalException
 */
package de.audi.tghu.development.widget;

import de.audi.tghu.development.model.ScreenElementModel;
import de.audi.tghu.development.renderer.ScreenRenderer;
import de.audi.tghu.development.widget.Widget;
import de.audi.tghu.hmi.view.HMITerminalImpl;
import fi.hybrid.a2dg.Graphics2D;
import fi.hybrid.hwg.Composite;
import fi.hybrid.hwg.Graphics;
import org.dsi.ifc.base.DSIFatalException;
import org.dsi.ifc.base.DSINonFatalException;

public class ReturnWidget
extends Widget {
    public ReturnWidget(ScreenElementModel screenElementModel, ScreenRenderer screenRenderer) {
        super(screenElementModel, screenRenderer);
    }

    public boolean processKey(int n) {
        boolean bl = false;
        switch (n) {
            case 17: {
                try {
                    this.screenRenderer.leaveScreen();
                }
                catch (DSINonFatalException dSINonFatalException) {
                    dSINonFatalException.printStackTrace();
                }
                catch (DSIFatalException dSIFatalException) {
                    dSIFatalException.printStackTrace();
                }
                bl = true;
            }
        }
        return bl;
    }

    public boolean processEncoder(int n, int n2) {
        return false;
    }

    public void render(Graphics graphics, Graphics2D graphics2D, Composite composite) {
        super.render(graphics, graphics2D, composite);
        if (!this.isVisible()) {
            return;
        }
        this.renderLabel(graphics, graphics2D, composite);
    }

    public void cleanup(HMITerminalImpl hMITerminalImpl) {
        super.cleanup(hMITerminalImpl);
    }
}

