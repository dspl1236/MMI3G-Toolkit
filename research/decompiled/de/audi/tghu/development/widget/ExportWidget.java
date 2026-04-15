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
 *  fi.hybrid.hwg.Font
 *  fi.hybrid.hwg.Graphics
 */
package de.audi.tghu.development.widget;

import de.audi.tghu.development.EngineeringException;
import de.audi.tghu.development.manager.LogMan;
import de.audi.tghu.development.model.ExportModel;
import de.audi.tghu.development.model.ModelCallbackIFC;
import de.audi.tghu.development.model.ScreenElementModel;
import de.audi.tghu.development.renderer.ScreenRenderer;
import de.audi.tghu.development.widget.Widget;
import de.audi.tghu.hmi.view.HMITerminalImpl;
import fi.hybrid.a2dg.Graphics2D;
import fi.hybrid.a2dg.Paint;
import fi.hybrid.a2dg.Path;
import fi.hybrid.hwg.Bitmap;
import fi.hybrid.hwg.Composite;
import fi.hybrid.hwg.Drawable;
import fi.hybrid.hwg.Font;
import fi.hybrid.hwg.Graphics;

public class ExportWidget
extends Widget
implements ModelCallbackIFC {
    protected Bitmap bmpShape;
    protected Bitmap bmpBorder;
    private Path p;
    private boolean running = false;

    public ExportWidget(ScreenElementModel screenElementModel, ScreenRenderer screenRenderer) {
        super(screenElementModel, screenRenderer);
    }

    public boolean processKey(int n) throws EngineeringException {
        if (!this.model.isEditable()) {
            return false;
        }
        boolean bl = false;
        switch (n) {
            case 17: {
                this.model.performAction();
                this.model.setCallbackObject(this);
                this.running = true;
                bl = true;
            }
        }
        return bl;
    }

    public boolean processEncoder(int n, int n2) {
        return false;
    }

    public void setState(boolean bl) {
        this.running = bl;
    }

    public void render(Graphics graphics, Graphics2D graphics2D, Composite composite) {
        int n;
        super.render(graphics, graphics2D, composite);
        if (!this.isVisible()) {
            return;
        }
        ExportModel exportModel = (ExportModel)this.model;
        if (!this.isVisible()) {
            return;
        }
        Font font = this.rendererConfig.getFont();
        if (this.teLabel == null) {
            this.teLabel = this.resMan.newTextElement(this.screenId, font, exportModel.getLabel(), false);
        } else {
            this.teLabel.setString(exportModel.getLabel());
        }
        int n2 = this.teLabel.getWidth() + 2 * this.rendererConfig.getBUTTON_BOX_WADDER();
        int n3 = this.rendererConfig.getFONT_SIZE() + 1;
        if (this.bmpShape == null) {
            this.bmpShape = this.resMan.newBitmap(this.screenId, n2, this.rendererConfig.getLINE_HEIGHT(), false);
            graphics2D.bindTarget(this.bmpShape);
            graphics2D.clear(this.rendererConfig.getCOLOR_TRANSPARENT());
            graphics2D.setFill((Paint)this.rendererConfig.getPntMidGray());
            n = this.rendererConfig.getBUTTON_BOX_ROUNDING();
            if (this.p == null) {
                this.p = this.resMan.newPath(this.screenId, 10, 26, false);
                this.p.appendRoundedRectangle(1.0f, (float)this.rendererConfig.getBUTTON_BOX_HSUB(), (float)(n2 - 2), (float)(this.rendererConfig.getLINE_HEIGHT() - this.rendererConfig.getBUTTON_BOX_HSUB() - 1), (float)n, (float)n);
            }
            graphics2D.fillPath(this.p);
            graphics2D.releaseTarget();
        } else if (this.running) {
            this.bmpShape.setOpacity(0.5f);
        } else {
            this.bmpShape.setOpacity(1.0f);
        }
        if (this.bmpBorder == null) {
            this.bmpBorder = this.resMan.newBitmap(this.screenId, n2, this.rendererConfig.getLINE_HEIGHT(), false);
            graphics2D.bindTarget(this.bmpBorder);
            graphics2D.clear(this.rendererConfig.getCOLOR_TRANSPARENT());
            graphics2D.setStroke((Paint)this.rendererConfig.getPntLightGreen());
            graphics2D.setStrokeWidth((float)this.rendererConfig.getBUTTON_BOX_WSTROKE());
            n = this.rendererConfig.getBUTTON_BOX_ROUNDING();
            if (this.p == null) {
                this.p = this.resMan.newPath(this.screenId, 10, 26, false);
                this.p.appendRoundedRectangle(1.0f, (float)this.rendererConfig.getBUTTON_BOX_HSUB(), (float)(n2 - 2), (float)(this.rendererConfig.getLINE_HEIGHT() - this.rendererConfig.getBUTTON_BOX_HSUB() - 1), (float)n, (float)n);
            }
            graphics2D.strokePath(this.p);
            graphics2D.releaseTarget();
        }
        this.bmpShape.setPosition(this.x, this.y);
        this.bmpShape.setModulateColor(this.rendererConfig.getCOLOR_WHITE());
        this.bmpBorder.setPosition(this.x, this.y);
        if (this.isSelected()) {
            this.bmpBorder.setModulateColor(this.rendererConfig.getCOLOR_WHITE());
        } else {
            this.bmpBorder.setModulateColor(this.rendererConfig.getCOLOR_LIGHT_GREEN());
        }
        if (this.isSelected()) {
            this.teLabel.setColor(this.rendererConfig.getCOLOR_WHITE());
        } else {
            this.teLabel.setColor(this.rendererConfig.getCOLOR_LIGHT_GREEN());
        }
        this.teLabel.setPosition(this.x + this.rendererConfig.getBUTTON_BOX_WADDER(), this.y + n3);
        composite.addDrawable((Drawable)this.bmpShape, 2);
        composite.addDrawable((Drawable)this.bmpBorder, 1);
        composite.addDrawable((Drawable)this.teLabel, 0);
    }

    public void cleanup(HMITerminalImpl hMITerminalImpl) {
        super.cleanup(hMITerminalImpl);
    }

    public void workDone() {
        this.running = false;
        LogMan.log("workDone in ExportWidget called");
    }
}

