/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  de.audi.tghu.hmi.view.HMITerminalImpl
 *  fi.hybrid.a2dg.Graphics2D
 *  fi.hybrid.hwg.Composite
 *  fi.hybrid.hwg.Graphics
 */
package de.audi.tghu.development.widget;

import de.audi.tghu.development.model.ScreenElementModel;
import de.audi.tghu.development.renderer.ScreenRenderer;
import de.audi.tghu.development.widget.Widget;
import de.audi.tghu.hmi.view.HMITerminalImpl;
import fi.hybrid.a2dg.Graphics2D;
import fi.hybrid.hwg.Composite;
import fi.hybrid.hwg.Graphics;

public class LabelWidget
extends Widget {
    public LabelWidget(ScreenElementModel screenElementModel, ScreenRenderer screenRenderer) {
        super(screenElementModel, screenRenderer);
    }

    public boolean processKey(int n) {
        return false;
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

