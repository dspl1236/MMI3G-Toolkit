/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  de.audi.tghu.hmi.view.HMITerminalImpl
 *  fi.hybrid.a2dg.Graphics2D
 *  fi.hybrid.a2dg.Paint
 *  fi.hybrid.hwg.Bitmap
 *  fi.hybrid.hwg.Composite
 *  fi.hybrid.hwg.Drawable
 *  fi.hybrid.hwg.Font
 *  fi.hybrid.hwg.Graphics
 *  fi.hybrid.hwg.TextElement
 */
package de.audi.tghu.development.widget;

import de.audi.tghu.development.EngineeringException;
import de.audi.tghu.development.model.ScreenElementModel;
import de.audi.tghu.development.model.SliderModel;
import de.audi.tghu.development.renderer.ScreenRenderer;
import de.audi.tghu.development.widget.Widget;
import de.audi.tghu.hmi.view.HMITerminalImpl;
import fi.hybrid.a2dg.Graphics2D;
import fi.hybrid.a2dg.Paint;
import fi.hybrid.hwg.Bitmap;
import fi.hybrid.hwg.Composite;
import fi.hybrid.hwg.Drawable;
import fi.hybrid.hwg.Font;
import fi.hybrid.hwg.Graphics;
import fi.hybrid.hwg.TextElement;

public class SliderWidget
extends Widget {
    protected boolean cursorCaptured = false;
    protected TextElement teValue;
    protected Bitmap bmpTrack;
    protected Bitmap bmpHandle;
    private int cachedValue;

    public SliderWidget(ScreenElementModel screenElementModel, ScreenRenderer screenRenderer) {
        super(screenElementModel, screenRenderer);
    }

    /*
     * WARNING - Removed try catching itself - possible behaviour change.
     */
    public boolean processKey(int n) throws EngineeringException {
        if (!this.model.isEditable()) {
            return false;
        }
        boolean bl = false;
        switch (n) {
            case 17: {
                if (!this.cursorCaptured) {
                    this.cursorCaptured = true;
                    SliderModel sliderModel = (SliderModel)this.model;
                    this.cachedValue = sliderModel.getValue();
                } else {
                    this.cursorCaptured = false;
                    ScreenElementModel screenElementModel = this.model;
                    synchronized (screenElementModel) {
                        SliderModel sliderModel = (SliderModel)this.model;
                        sliderModel.setValue(this.cachedValue);
                        this.model.performAction();
                    }
                }
                bl = true;
                break;
            }
            case 15: {
                if (!this.cursorCaptured) break;
                this.cursorCaptured = false;
                bl = true;
                break;
            }
        }
        return bl;
    }

    public boolean processEncoder(int n, int n2) {
        if (!this.model.isEditable()) {
            return false;
        }
        SliderModel sliderModel = (SliderModel)this.model;
        boolean bl = false;
        switch (n) {
            case 17: {
                if (!this.cursorCaptured) break;
                int n3 = this.cachedValue + n2;
                if (n3 < sliderModel.getMinValue()) {
                    n3 = sliderModel.getMinValue();
                }
                if (n3 > sliderModel.getMaxValue()) {
                    n3 = sliderModel.getMaxValue();
                }
                this.cachedValue = n3;
                bl = true;
                break;
            }
        }
        return bl;
    }

    public void render(Graphics graphics, Graphics2D graphics2D, Composite composite) {
        int n;
        super.render(graphics, graphics2D, composite);
        if (!this.isVisible()) {
            return;
        }
        SliderModel sliderModel = (SliderModel)this.model;
        this.renderLabel(graphics, graphics2D, composite);
        int n2 = this.rendererConfig.getCOLOR_LIGHT_GREEN();
        int n3 = this.rendererConfig.getCOLOR_DARK_GREEN();
        if (!sliderModel.isValueValid() || sliderModel.getMaxValue() == sliderModel.getMinValue()) {
            n2 = this.rendererConfig.getCOLOR_LIGHT_GRAY();
            n3 = this.rendererConfig.getCOLOR_MID_GRAY();
        }
        int n4 = this.rendererConfig.getSLIDER_BAR_WIDTH();
        int n5 = this.rendererConfig.getSLIDER_BAR_HEIGHT();
        int n6 = this.rendererConfig.getSLIDER_LEFT();
        int n7 = this.y + (this.rendererConfig.getLINE_HEIGHT() - n5) / 2;
        int n8 = this.rendererConfig.getSLIDER_HANDLE_WIDTH();
        int n9 = this.rendererConfig.getSLIDER_HANDLE_HEIGHT();
        int n10 = n6 + (n4 - n8) / 2;
        if (sliderModel.getMaxValue() - sliderModel.getMinValue() > 0) {
            n = this.cursorCaptured ? this.cachedValue - sliderModel.getMinValue() : sliderModel.getValue() - sliderModel.getMinValue();
            n10 = n6 + (n4 - n8) * n / (sliderModel.getMaxValue() - sliderModel.getMinValue());
        }
        n = this.y + (this.rendererConfig.getLINE_HEIGHT() - n9) / 2;
        if (this.bmpTrack == null) {
            this.bmpTrack = this.resMan.newBitmap(this.screenId, n4, n5, false);
            graphics2D.bindTarget(this.bmpTrack);
            graphics2D.setFill((Paint)this.rendererConfig.getPntWhite());
            graphics2D.fillRect(0, 0, n4, n5);
            graphics2D.releaseTarget();
        }
        if (this.bmpHandle == null) {
            this.bmpHandle = this.resMan.newBitmap(this.screenId, n8, n9, false);
            graphics2D.bindTarget(this.bmpHandle);
            graphics2D.setFill((Paint)this.rendererConfig.getPntWhite());
            graphics2D.fillRect(0, 0, n8, n9);
            graphics2D.releaseTarget();
        }
        this.bmpTrack.setModulateColor(n3);
        this.bmpTrack.setPosition(n6, n7);
        if (this.cursorCaptured) {
            this.bmpHandle.setModulateColor(this.rendererConfig.getCOLOR_WHITE());
        } else {
            this.bmpHandle.setModulateColor(n2);
        }
        this.bmpHandle.setPosition(n10, n);
        Font font = this.rendererConfig.getFont();
        if (this.cursorCaptured) {
            if (this.teValue == null) {
                this.teValue = this.resMan.newTextElement(this.screenId, font, Integer.toString(this.cachedValue), false);
            } else {
                this.teValue.setString(Integer.toString(this.cachedValue));
            }
        } else if (this.teValue == null) {
            this.teValue = this.resMan.newTextElement(this.screenId, font, Integer.toString(sliderModel.getValue()), false);
        } else {
            this.teValue.setString(Integer.toString(sliderModel.getValue()));
        }
        this.teValue.setColor(n2);
        int n11 = this.rendererConfig.getSLIDER_VALUE_LEFT();
        int n12 = this.getTextHeight();
        this.teValue.setPosition(n11, this.y + n12);
        composite.addDrawable((Drawable)this.bmpTrack, 1);
        composite.addDrawable((Drawable)this.bmpHandle, 0);
        composite.addDrawable((Drawable)this.teValue, 0);
    }

    public void cleanup(HMITerminalImpl hMITerminalImpl) {
        super.cleanup(hMITerminalImpl);
    }
}

