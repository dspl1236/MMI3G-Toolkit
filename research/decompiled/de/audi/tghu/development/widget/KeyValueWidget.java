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

import de.audi.tghu.development.model.KeyValueModel;
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

public class KeyValueWidget
extends Widget {
    protected TextElement teValue;

    public KeyValueWidget(ScreenElementModel screenElementModel, ScreenRenderer screenRenderer) {
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
        KeyValueModel keyValueModel = (KeyValueModel)this.model;
        this.renderLabel(graphics, graphics2D, composite);
        if (this.teValue == null) {
            Font font = this.rendererConfig.getFont();
            this.teValue = this.resMan.newTextElement(this.screenId, font, keyValueModel.getValue(), false);
        } else {
            this.teValue.setString(keyValueModel.getValue());
        }
        if (keyValueModel.isValueValid()) {
            this.teValue.setColor(this.rendererConfig.getCOLOR_LIGHT_GREEN());
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

