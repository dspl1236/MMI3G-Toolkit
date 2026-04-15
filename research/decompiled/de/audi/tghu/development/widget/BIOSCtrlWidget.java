/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  de.audi.tghu.hmi.view.HMITerminalImpl
 *  fi.hybrid.a2dg.Graphics2D
 *  fi.hybrid.hwg.Composite
 *  fi.hybrid.hwg.Drawable
 *  fi.hybrid.hwg.Font
 *  fi.hybrid.hwg.Graphics
 *  fi.hybrid.hwg.TextElement
 */
package de.audi.tghu.development.widget;

import de.audi.tghu.development.EngineeringException;
import de.audi.tghu.development.model.BIOSCtrlModel;
import de.audi.tghu.development.model.ScreenElementModel;
import de.audi.tghu.development.renderer.ScreenRenderer;
import de.audi.tghu.development.widget.Widget;
import de.audi.tghu.hmi.view.HMITerminalImpl;
import fi.hybrid.a2dg.Graphics2D;
import fi.hybrid.hwg.Composite;
import fi.hybrid.hwg.Drawable;
import fi.hybrid.hwg.Font;
import fi.hybrid.hwg.Graphics;
import fi.hybrid.hwg.TextElement;

public class BIOSCtrlWidget
extends Widget {
    protected TextElement teValue;
    private boolean cursorCaptured = false;
    private int cachedValue = 0;

    public BIOSCtrlWidget(ScreenElementModel screenElementModel, ScreenRenderer screenRenderer) {
        super(screenElementModel, screenRenderer);
    }

    /*
     * WARNING - Removed try catching itself - possible behaviour change.
     */
    public boolean processKey(int n) throws EngineeringException {
        if (!this.model.isEditable()) {
            return false;
        }
        BIOSCtrlModel bIOSCtrlModel = (BIOSCtrlModel)this.model;
        boolean bl = false;
        switch (n) {
            case 17: {
                if (!this.cursorCaptured) {
                    this.cursorCaptured = true;
                    this.cachedValue = bIOSCtrlModel.getCurrentEntryIndex();
                } else {
                    this.cursorCaptured = false;
                    BIOSCtrlModel bIOSCtrlModel2 = bIOSCtrlModel;
                    synchronized (bIOSCtrlModel2) {
                        bIOSCtrlModel.setCurrentEntryIndex(this.cachedValue);
                    }
                }
                bIOSCtrlModel.setCachedEntry();
                bIOSCtrlModel.performAction();
                bl = true;
                break;
            }
            case 15: {
                if (!this.cursorCaptured) break;
                this.cursorCaptured = false;
                bl = true;
            }
        }
        return bl;
    }

    public boolean processEncoder(int n, int n2) {
        if (!this.model.isEditable()) {
            return false;
        }
        BIOSCtrlModel bIOSCtrlModel = (BIOSCtrlModel)this.model;
        boolean bl = false;
        switch (n) {
            case 17: {
                if (!this.cursorCaptured) break;
                int n3 = this.cachedValue + n2;
                this.cachedValue = bIOSCtrlModel.getBounded(n3);
                bl = true;
            }
        }
        return bl;
    }

    public void render(Graphics graphics, Graphics2D graphics2D, Composite composite) {
        String string;
        int n;
        super.render(graphics, graphics2D, composite);
        if (!this.isVisible()) {
            return;
        }
        BIOSCtrlModel bIOSCtrlModel = (BIOSCtrlModel)this.model;
        this.renderLabel(graphics, graphics2D, composite);
        if (this.cursorCaptured) {
            n = this.cachedValue + 1;
            string = bIOSCtrlModel.getCachedEntry(n - 1).getName();
        } else {
            n = bIOSCtrlModel.getCurrentEntryIndex() + 1;
            string = bIOSCtrlModel.getEntry().getName();
        }
        if (this.teValue == null) {
            Font font = this.rendererConfig.getFont();
            this.teValue = this.resMan.newTextElement(this.screenId, font, "[" + string + "] " + (bIOSCtrlModel.getCurrentEntryIndex() + 1) + "/" + bIOSCtrlModel.getListSize(), false);
        } else {
            this.teValue.setString("[" + string + "] " + n + "/" + bIOSCtrlModel.getListSize());
        }
        if (bIOSCtrlModel.isValueValid()) {
            if (this.cursorCaptured) {
                this.teValue.setColor(this.rendererConfig.getCOLOR_WHITE());
            } else {
                this.teValue.setColor(this.rendererConfig.getCOLOR_LIGHT_GREEN());
            }
        } else {
            this.teValue.setColor(this.rendererConfig.getCOLOR_LIGHT_GRAY());
        }
        this.teValue.setPosition(this.x + this.rendererConfig.getKEYVALUE_LEFT(), this.y + this.getTextHeight());
        composite.addDrawable((Drawable)this.teValue, 0);
    }

    public void cleanup(HMITerminalImpl hMITerminalImpl) {
        super.cleanup(hMITerminalImpl);
    }
}

