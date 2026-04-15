/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.model;

import de.audi.tghu.development.EngineeringException;
import de.audi.tghu.development.eis.EngineeringInfoService;
import de.audi.tghu.development.model.ScreenElementModel;
import de.audi.tghu.development.renderer.ScreenRenderer;
import de.audi.tghu.development.widget.SliderWidget;
import de.audi.tghu.development.widget.Widget;

public class SliderModel
extends ScreenElementModel {
    private static final int KEYINDEX_VALUE = 0;
    private static final int KEYINDEX_MIN = 1;
    private static final int KEYINDEX_MAX = 2;
    public static final int LIMITS_ABSOLUTE = 0;
    public static final int LIMITS_INDEXED = 1;
    private int value;
    private int minValue;
    private int maxValue;
    private int defaultValue;
    private int limitType;
    private boolean isKeySet = false;

    public SliderModel() {
        super(2, 3);
    }

    public boolean areRequiredFieldsSet() {
        return this.isKeySet && this.isLabelSet;
    }

    public void setValueInt(int n, int n2, long l, long l2, long l3, int n3) {
        this.dataSource = n;
        this.namespace = n2;
        this.limitType = n3;
        if (n3 == 0) {
            this.keys = new long[1];
            this.keys[0] = l;
            this.maxValue = (int)l3;
            this.minValue = (int)l2;
        } else {
            this.keys[0] = l;
            this.keys[1] = l2;
            this.keys[2] = l3;
        }
        this.dataType = 0;
        this.isKeySet = true;
    }

    public int getDefaultValue() {
        return this.defaultValue;
    }

    public int getMaxValue() {
        return this.maxValue;
    }

    public int getMinValue() {
        return this.minValue;
    }

    public int getValue() {
        return this.value;
    }

    public void setDefaultValue(int n) {
        this.defaultValue = n;
    }

    public synchronized void setValue(int n) {
        this.value = n;
    }

    public void performAction() throws EngineeringException {
        if (this.isEditable()) {
            EngineeringInfoService.getInstance().storeInt(this.dataSource, this.namespace, this.keys[0], this.value);
        }
    }

    public void updateData(int n, long l, Object object) {
        if (n != this.namespace) {
            return;
        }
        int n2 = (Integer)object;
        if (l == this.keys[0]) {
            this.value = n2;
            this.isValueValid = true;
            if (this.widget != null) {
                this.widget.dataChanged();
            }
        } else if (this.limitType == 1) {
            if (l == this.keys[1]) {
                this.minValue = n2;
            } else if (l == this.keys[2]) {
                this.maxValue = n2;
            }
        }
    }

    public Widget getWidget(ScreenRenderer screenRenderer) {
        return new SliderWidget(this, screenRenderer);
    }
}

