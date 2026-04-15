/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.model;

import de.audi.tghu.development.EngineeringException;
import de.audi.tghu.development.eis.EngineeringInfoService;
import de.audi.tghu.development.model.ScreenElementModel;
import de.audi.tghu.development.renderer.ScreenRenderer;
import de.audi.tghu.development.widget.ButtonWidget;
import de.audi.tghu.development.widget.Widget;

public class ButtonModel
extends ScreenElementModel {
    private static final int KEYINDEX_VALUE = 0;
    private String functionCall;

    public ButtonModel() {
        super(0, 1);
    }

    public boolean areRequiredFieldsSet() {
        return this.isValueKeySet && this.isLabelSet;
    }

    public void updateData(int n, long l, Object object) {
    }

    public void performAction() throws EngineeringException {
        if (!this.isEditable()) {
            return;
        }
        EngineeringInfoService.getInstance().storeString(this.dataSource, this.namespace, this.keys[0], this.functionCall);
    }

    public void setKeyValue(int n, int n2, long l, String string) {
        this.dataSource = n;
        this.namespace = n2;
        this.keys[0] = l;
        this.isValueKeySet = true;
        this.functionCall = string;
    }

    public String getFunctionCall() {
        return this.functionCall;
    }

    public Widget getWidget(ScreenRenderer screenRenderer) {
        return new ButtonWidget(this, screenRenderer);
    }
}

