/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.model;

import de.audi.tghu.development.EngineeringException;
import de.audi.tghu.development.model.ScreenElementModel;
import de.audi.tghu.development.renderer.ScreenRenderer;
import de.audi.tghu.development.widget.SlideShowWidget;
import de.audi.tghu.development.widget.Widget;

public class SlideShowModel
extends ScreenElementModel {
    public SlideShowModel() {
        super(12, 0);
    }

    public SlideShowModel(int n, int n2) {
        super(n, n2);
    }

    public boolean areRequiredFieldsSet() {
        return this.isLabelSet;
    }

    public void performAction() throws EngineeringException {
        this.widget.screenRenderer.enterSlideShowScreen();
    }

    public void updateData(int n, long l, Object object) {
    }

    public Widget getWidget(ScreenRenderer screenRenderer) {
        return new SlideShowWidget(this, screenRenderer);
    }
}

