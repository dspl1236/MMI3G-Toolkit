/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.model;

import de.audi.tghu.development.model.ScreenElementModel;
import de.audi.tghu.development.renderer.ScreenRenderer;
import de.audi.tghu.development.widget.LabelWidget;
import de.audi.tghu.development.widget.Widget;

public class LabelModel
extends ScreenElementModel {
    public LabelModel() {
        super(5, 0);
        this.isValueKeySet = true;
    }

    public void updateData(int n, long l, Object object) {
    }

    public void performAction() {
    }

    public Widget getWidget(ScreenRenderer screenRenderer) {
        return new LabelWidget(this, screenRenderer);
    }
}

