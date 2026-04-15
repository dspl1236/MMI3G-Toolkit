/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.model;

import de.audi.tghu.development.EngineeringException;
import de.audi.tghu.development.eis.EngineeringInfoService;
import de.audi.tghu.development.manager.LogMan;
import de.audi.tghu.development.model.ScreenElementModel;
import de.audi.tghu.development.renderer.ScreenRenderer;
import de.audi.tghu.development.widget.ChoiceWidget;
import de.audi.tghu.development.widget.Widget;

public class ChoiceModel
extends ScreenElementModel {
    private static final int KEYINDEX_VALUE = 0;
    private boolean checked;

    public ChoiceModel() {
        super(1, 1);
    }

    public void setKeyValue(int n, int n2, long l) {
        this.dataSource = n;
        this.namespace = n2;
        this.keys[0] = l;
        this.isValueKeySet = true;
    }

    public boolean isChecked() {
        return this.checked;
    }

    public void setChecked(boolean bl) {
        this.checked = bl;
    }

    public void performAction() throws EngineeringException {
        if (!this.isEditable()) {
            return;
        }
        int n = this.checked ? 1 : 0;
        switch (this.dataType) {
            case 0: {
                EngineeringInfoService.getInstance().storeInt(this.dataSource, this.namespace, this.keys[0], n);
                break;
            }
            default: {
                LogMan.log(3, "ChoiceModel.storeValue(): invalid data type " + this.dataType);
                throw new EngineeringException("ChoiceModel.storeValue(): unknown data type " + this.dataType);
            }
        }
    }

    public void updateData(int n, long l, Object object) {
        if (n != this.namespace) {
            return;
        }
        if (l != this.keys[0]) {
            return;
        }
        switch (this.dataType) {
            case 0: {
                this.checked = (Integer)object != 0;
                this.isValueValid = true;
                LogMan.log(3, "ChoiceModel.updateData(): value set to " + this.checked);
                if (this.widget == null) break;
                this.widget.dataChanged();
                break;
            }
            default: {
                LogMan.log(3, "ChoiceModel.updateData(): invalid data type " + this.dataType);
            }
        }
    }

    public Widget getWidget(ScreenRenderer screenRenderer) {
        return new ChoiceWidget(this, screenRenderer);
    }
}

