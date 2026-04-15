/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.model;

import de.audi.tghu.development.model.ScreenElementModel;
import de.audi.tghu.development.renderer.ScreenRenderer;
import de.audi.tghu.development.widget.LinkWidget;
import de.audi.tghu.development.widget.Widget;

public class LinkModel
extends ScreenElementModel {
    private int screenId;

    public LinkModel() {
        super(4, 0);
    }

    public LinkModel(String string, int n) {
        super(4, 0);
        this.isValueKeySet = true;
        this.isLabelSet = true;
        this.label = string;
        this.screenId = n;
    }

    public int getScreenId() {
        return this.screenId;
    }

    public void setScreenId(int n) {
        this.isValueKeySet = true;
        this.screenId = n;
    }

    public void updateData(int n, long l, Object object) {
    }

    public void performAction() {
    }

    public Widget getWidget(ScreenRenderer screenRenderer) {
        return new LinkWidget(this, screenRenderer.getLinkListener(), screenRenderer);
    }
}

