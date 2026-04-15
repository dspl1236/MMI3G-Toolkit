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

import de.audi.tghu.development.EngineeringException;
import de.audi.tghu.development.model.ChoiceModel;
import de.audi.tghu.development.model.ScreenElementModel;
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

public class ChoiceWidget
extends Widget {
    protected Path pFrame;
    protected Path pCheck;
    protected Bitmap bmpChecked;
    protected Bitmap bmpUnchecked;

    public ChoiceWidget(ScreenElementModel screenElementModel, ScreenRenderer screenRenderer) {
        super(screenElementModel, screenRenderer);
        if (this.pFrame == null) {
            this.pFrame = this.rendererConfig.getPFrame();
        }
        if (this.pCheck == null) {
            this.pCheck = this.rendererConfig.getPCheck();
        }
    }

    public boolean processKey(int n) throws EngineeringException {
        if (!this.model.isEditable()) {
            return false;
        }
        ChoiceModel choiceModel = (ChoiceModel)this.model;
        boolean bl = false;
        switch (n) {
            case 17: {
                boolean bl2 = !choiceModel.isChecked();
                choiceModel.setChecked(bl2);
                choiceModel.performAction();
                bl = true;
            }
        }
        return bl;
    }

    public boolean processEncoder(int n, int n2) {
        return false;
    }

    public void render(Graphics graphics, Graphics2D graphics2D, Composite composite) {
        SolidPaint solidPaint;
        int n;
        int n2;
        float[] fArray;
        super.render(graphics, graphics2D, composite);
        if (!this.isVisible()) {
            return;
        }
        ChoiceModel choiceModel = (ChoiceModel)this.model;
        this.renderLabel(graphics, graphics2D, composite);
        if (this.bmpChecked == null) {
            fArray = new float[4];
            this.pFrame.getBoundingBox(fArray);
            n2 = Math.round(fArray[2]);
            n = Math.round(fArray[3]);
            this.bmpChecked = this.resMan.newBitmap(this.screenId, n2, n, false);
            graphics2D.bindTarget(this.bmpChecked);
            graphics2D.clear(this.rendererConfig.getCOLOR_TRANSPARENT());
            solidPaint = this.rendererConfig.getPntWhite();
            graphics2D.setStroke((Paint)solidPaint);
            graphics2D.setFill((Paint)solidPaint);
            graphics2D.setStrokeWidth(2.0f);
            graphics2D.strokePath(this.pFrame);
            graphics2D.fillPath(this.pCheck);
            graphics2D.releaseTarget();
        }
        if (this.bmpUnchecked == null) {
            fArray = new float[4];
            this.pFrame.getBoundingBox(fArray);
            n2 = Math.round(fArray[2]);
            n = Math.round(fArray[3]);
            this.bmpUnchecked = this.resMan.newBitmap(this.screenId, n2, n, false);
            graphics2D.bindTarget(this.bmpUnchecked);
            graphics2D.clear(this.rendererConfig.getCOLOR_TRANSPARENT());
            solidPaint = this.rendererConfig.getPntWhite();
            graphics2D.setStroke((Paint)solidPaint);
            graphics2D.setFill((Paint)solidPaint);
            graphics2D.setStrokeWidth(2.0f);
            graphics2D.strokePath(this.pFrame);
            graphics2D.releaseTarget();
        }
        if (choiceModel.isValueValid()) {
            this.bmpChecked.setModulateColor(this.rendererConfig.getCOLOR_LIGHT_GREEN());
            this.bmpUnchecked.setModulateColor(this.rendererConfig.getCOLOR_LIGHT_GREEN());
        } else {
            this.bmpChecked.setModulateColor(this.rendererConfig.getCOLOR_LIGHT_GRAY());
            this.bmpUnchecked.setModulateColor(this.rendererConfig.getCOLOR_LIGHT_GRAY());
        }
        this.bmpChecked.setPosition(this.rendererConfig.getCHOICE_LEFT(), this.y);
        this.bmpUnchecked.setPosition(this.rendererConfig.getCHOICE_LEFT(), this.y);
        if (choiceModel.isChecked()) {
            composite.addDrawable((Drawable)this.bmpChecked, 0);
        } else {
            composite.addDrawable((Drawable)this.bmpUnchecked, 0);
        }
    }

    public void cleanup(HMITerminalImpl hMITerminalImpl) {
        super.cleanup(hMITerminalImpl);
    }
}

