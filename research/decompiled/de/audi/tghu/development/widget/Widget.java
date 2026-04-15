/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  de.audi.tghu.hmi.view.HMITerminalImpl
 *  fi.hybrid.a2dg.Graphics2D
 *  fi.hybrid.hwg.Composite
 *  fi.hybrid.hwg.Drawable
 *  fi.hybrid.hwg.Graphics
 *  fi.hybrid.hwg.TextElement
 */
package de.audi.tghu.development.widget;

import de.audi.tghu.development.EngineeringException;
import de.audi.tghu.development.config.AbstractRendererConfig;
import de.audi.tghu.development.manager.ResMan;
import de.audi.tghu.development.model.ScreenElementModel;
import de.audi.tghu.development.renderer.ScreenRenderer;
import de.audi.tghu.hmi.view.HMITerminalImpl;
import fi.hybrid.a2dg.Graphics2D;
import fi.hybrid.hwg.Composite;
import fi.hybrid.hwg.Drawable;
import fi.hybrid.hwg.Graphics;
import fi.hybrid.hwg.TextElement;

public abstract class Widget {
    protected static final int LAYERID_NONE = -1;
    protected int x = 0;
    protected int y = 0;
    protected boolean visible;
    protected boolean selected;
    protected ScreenElementModel model;
    protected int layerId;
    protected Composite comp;
    protected int screenId;
    protected String sLabel;
    protected TextElement teLabel;
    public ScreenRenderer screenRenderer;
    public ResMan resMan;
    public AbstractRendererConfig rendererConfig;
    static int counter = 0;

    public Widget(ScreenElementModel screenElementModel, ScreenRenderer screenRenderer) {
        this.layerId = screenRenderer.getLayerId();
        this.screenId = screenRenderer.getCurrentScreenId();
        this.screenRenderer = screenRenderer;
        this.rendererConfig = this.screenRenderer.rendererConfig;
        this.resMan = this.screenRenderer.resMan;
        this.visible = true;
        this.model = screenElementModel;
        if (screenElementModel != null) {
            screenElementModel.setWidget(this);
        }
    }

    public void setLabel(String string) {
        this.sLabel = string;
    }

    protected int getTextHeight() {
        int n = this.rendererConfig.getFONT_SIZE();
        return n - n / 10;
    }

    public abstract boolean processKey(int var1) throws EngineeringException;

    public abstract boolean processEncoder(int var1, int var2);

    public void render(Graphics graphics, Graphics2D graphics2D, Composite composite) {
        this.comp = composite;
    }

    protected void renderLabel(Graphics graphics, Graphics2D graphics2D, Composite composite) {
        if (!this.isVisible()) {
            return;
        }
        String string = this.sLabel;
        if (this.model != null) {
            string = this.model.getLabel();
        }
        if (this.teLabel == null) {
            this.teLabel = this.resMan.newTextElement(this.screenId, this.rendererConfig.getFont(), string, false);
            this.teLabel.setPosition(this.x, this.y + this.getTextHeight());
        } else {
            this.teLabel.setString(string);
        }
        if (this.isSelected()) {
            this.teLabel.setColor(this.rendererConfig.getCOLOR_WHITE());
        } else {
            this.teLabel.setColor(this.rendererConfig.getCOLOR_LIGHT_GREEN());
        }
        composite.addDrawable((Drawable)this.teLabel, 0);
    }

    public void setPos(int n, int n2) {
        this.x = n;
        this.y = n2;
    }

    public boolean isSelected() {
        return this.selected;
    }

    public boolean isVisible() {
        return this.visible;
    }

    public int getX() {
        return this.x;
    }

    public int getY() {
        return this.y;
    }

    public void setSelected(boolean bl) {
        this.selected = bl;
    }

    public void setVisible(boolean bl) {
        this.visible = bl;
    }

    public void dataChanged() {
        this.screenRenderer.sendRepaintEvent(this.layerId);
    }

    public void cleanup(HMITerminalImpl hMITerminalImpl) {
        if (this.comp != null) {
            this.comp.clearDrawables();
        }
    }
}

