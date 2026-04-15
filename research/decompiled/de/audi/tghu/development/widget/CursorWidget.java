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

public class CursorWidget
extends Widget {
    protected Path cursorPath;
    protected float[] cursorPoly;
    protected byte[] cursorCmds;
    protected int line;
    protected Bitmap bmpCursor;

    public CursorWidget(ScreenRenderer screenRenderer) {
        super(null, screenRenderer);
        if (this.cursorPath == null || this.cursorCmds == null || this.cursorPoly == null) {
            this.cursorPath = this.resMan.newPath(this.screenId, 6, 8, true);
            this.cursorCmds = new byte[]{2, 4, 4, 4, 0};
            this.cursorPoly = this.rendererConfig.getCursorPoly();
            this.cursorPath.append(this.cursorCmds, this.cursorPoly);
        }
    }

    public void setPosition(int n) {
        this.line = n;
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
        if (this.bmpCursor == null) {
            this.bmpCursor = this.resMan.newBitmap(this.screenId, 20, 20, true);
            graphics2D.bindTarget(this.bmpCursor);
            graphics2D.clear(this.rendererConfig.getCOLOR_TRANSPARENT());
            graphics2D.setFill((Paint)this.rendererConfig.getPntLightGreen());
            graphics2D.setStroke((Paint)this.rendererConfig.getPntLightGreen());
            graphics2D.setStrokeWidth(1.0f);
            graphics2D.strokePath(this.cursorPath);
            graphics2D.fillPath(this.cursorPath);
            graphics2D.releaseTarget();
        }
        this.bmpCursor.setPosition(this.rendererConfig.getCURSOR_X(), this.rendererConfig.getCURSOR_TOP() + this.line * this.rendererConfig.getLINE_HEIGHT());
        composite.addDrawable((Drawable)this.bmpCursor, 0);
    }

    public void cleanup(HMITerminalImpl hMITerminalImpl) {
        super.cleanup(hMITerminalImpl);
    }
}

