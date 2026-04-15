/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  de.audi.tghu.hmi.view.HMITerminalImpl
 *  fi.hybrid.a2dg.Graphics2D
 *  fi.hybrid.a2dg.Paint
 *  fi.hybrid.a2dg.Path
 *  fi.hybrid.a2dg.SolidPaint
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
import fi.hybrid.a2dg.SolidPaint;
import fi.hybrid.hwg.Bitmap;
import fi.hybrid.hwg.Composite;
import fi.hybrid.hwg.Drawable;
import fi.hybrid.hwg.Graphics;

public class PathWidget
extends Widget {
    protected Path p;
    protected SolidPaint stroke;
    protected SolidPaint fill;
    protected int strokeWidth;
    protected Bitmap bmpPath;

    public PathWidget(Path path, SolidPaint solidPaint, SolidPaint solidPaint2, int n, ScreenRenderer screenRenderer) {
        super(null, screenRenderer);
        this.p = path;
        this.stroke = solidPaint;
        this.fill = solidPaint2;
        this.strokeWidth = n;
    }

    protected PathWidget(int n, ScreenRenderer screenRenderer, int n2) {
        super(null, screenRenderer);
    }

    protected void _set(Path path, SolidPaint solidPaint, SolidPaint solidPaint2, int n) {
        this.p = path;
        this.stroke = solidPaint;
        this.fill = solidPaint2;
        this.strokeWidth = n;
    }

    public void setPos(int n, int n2) {
        this.x = n;
        this.y = n2;
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
        if (this.bmpPath == null) {
            float[] fArray = new float[4];
            this.p.getBoundingBox(fArray);
            int n = Math.round(fArray[2]);
            int n2 = Math.round(fArray[3]);
            if (this.bmpPath == null) {
                this.bmpPath = this.resMan.newBitmap(this.screenId, n, n2, true);
            }
            graphics2D.bindTarget(this.bmpPath);
            graphics2D.clear(this.rendererConfig.getCOLOR_TRANSPARENT());
            graphics2D.setStroke((Paint)this.stroke);
            graphics2D.setFill((Paint)this.fill);
            graphics2D.setStrokeWidth((float)this.strokeWidth);
            graphics2D.fillPath(this.p);
            graphics2D.releaseTarget();
        }
        this.bmpPath.setPosition(this.x, this.y);
        composite.addDrawable((Drawable)this.bmpPath, 0);
    }

    public void cleanup(HMITerminalImpl hMITerminalImpl) {
        super.cleanup(hMITerminalImpl);
    }
}

