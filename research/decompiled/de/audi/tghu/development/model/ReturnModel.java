/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.model;

import de.audi.tghu.development.model.ScreenElementModel;
import de.audi.tghu.development.renderer.ScreenRenderer;
import de.audi.tghu.development.widget.ReturnWidget;
import de.audi.tghu.development.widget.Widget;

public class ReturnModel
extends ScreenElementModel {
    public ReturnModel() {
        super(13, 0);
    }

    public ReturnModel(String string) {
        super(13, 0);
        this.isValueKeySet = true;
        this.isLabelSet = true;
        this.label = string;
    }

    public void updateData(int n, long l, Object object) {
    }

    public void performAction() {
    }

    public Widget getWidget(ScreenRenderer screenRenderer) {
        return new ReturnWidget(this, screenRenderer);
    }
}

