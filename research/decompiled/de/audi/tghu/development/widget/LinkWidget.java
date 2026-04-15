/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  de.audi.tghu.hmi.view.HMITerminalImpl
 *  fi.hybrid.a2dg.Graphics2D
 *  fi.hybrid.a2dg.Paint
 *  fi.hybrid.a2dg.Path
 *  fi.hybrid.hwg.Bitmap
 *  fi.hybrid.hwg.Composite
 *  fi.hybrid.hwg.Drawable
 *  fi.hybrid.hwg.Graphics
 */
package de.audi.tghu.development.widget;

import de.audi.tghu.development.model.LinkModel;
import de.audi.tghu.development.model.ScreenElementModel;
import de.audi.tghu.development.renderer.LinkListener;
import de.audi.tghu.development.renderer.ScreenRenderer;
import de.audi.tghu.development.widget.Widget;
import de.audi.tghu.hmi.view.HMITerminalImpl;
import fi.hybrid.a2dg.Graphics2D;
import fi.hybrid.a2dg.Paint;
import fi.hybrid.a2dg.Path;
import fi.hybrid.hwg.Bitmap;
import fi.hybrid.hwg.Composite;
import fi.hybrid.hwg.Drawable;
import fi.hybrid.hwg.Graphics;

public class LinkWidget
extends Widget {
    protected Path pShape;
    protected LinkListener listener;
    protected Bitmap bmpLink;

    public LinkWidget(ScreenElementModel screenElementModel, LinkListener linkListener, ScreenRenderer screenRenderer) {
        super(screenElementModel, screenRenderer);
        if (this.pShape == null) {
            this.pShape = this.rendererConfig.getLinkSymbol();
        }
        this.listener = linkListener;
    }

    public boolean processKey(int n) {
        boolean bl = false;
        switch (n) {
            case 17: {
                if (this.listener != null) {
                    this.listener.linkClicked(((LinkModel)this.model).getScreenId());
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
        if (this.bmpLink == null) {
            this.bmpLink = this.resMan.newBitmap(this.screenId, 20, 20, false);
            graphics2D.bindTarget(this.bmpLink);
            graphics2D.clear(this.rendererConfig.getCOLOR_TRANSPARENT());
            graphics2D.setStroke((Paint)this.rendererConfig.getPntLightGreen());
            graphics2D.setStrokeWidth(1.0f);
            graphics2D.strokePath(this.pShape);
            graphics2D.releaseTarget();
        }
        this.bmpLink.setPosition(this.rendererConfig.getLINK_LEFT(), this.y);
        composite.addDrawable((Drawable)this.bmpLink, 0);
    }

    public void cleanup(HMITerminalImpl hMITerminalImpl) {
        super.cleanup(hMITerminalImpl);
    }
}

