/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.model;

import de.audi.tghu.development.EngineeringException;
import de.audi.tghu.development.eis.EngineeringInfoService;
import de.audi.tghu.development.manager.LogMan;
import de.audi.tghu.development.model.ScreenElementModel;
import de.audi.tghu.development.renderer.ScreenRenderer;
import de.audi.tghu.development.widget.KeyValueWidget;
import de.audi.tghu.development.widget.Widget;
import java.text.DecimalFormat;

public class KeyValueModel
extends ScreenElementModel {
    private static final int KEYINDEX_VALUE = 0;
    private String sValue;
    private int iValue;
    private double factor = 0.0;
    private String sFormat = null;
    DecimalFormat df = null;

    public KeyValueModel() {
        super(3, 1);
    }

    public void setValueInt(int n, int n2, long l) {
        this.dataSource = n;
        this.namespace = n2;
        this.keys[0] = l;
        this.isValueKeySet = true;
        this.dataType = 0;
    }

    public void setValueString(int n, int n2, long l) {
        this.dataSource = n;
        this.namespace = n2;
        this.keys[0] = l;
        this.isValueKeySet = true;
        this.dataType = 3;
    }

    public String getValue() {
        switch (this.dataType) {
            case 3: {
                if (this.sValue == null) {
                    return "";
                }
                return this.sValue;
            }
            case 0: {
                if (this.sFormat == null) {
                    return Integer.toString(this.iValue);
                }
                String string = null;
                if (this.sFormat.equals("hex")) {
                    int n;
                    int n2;
                    this.factor = Math.abs(this.factor);
                    if (this.factor > 7.0) {
                        this.factor = 7.0;
                    }
                    string = (n2 = 1 << 4 * (n = (int)Math.round(this.factor))) > this.iValue ? Integer.toHexString(n2 | this.iValue).substring(1) : Integer.toHexString(this.iValue);
                    string = string.toUpperCase();
                } else {
                    if (this.df == null) {
                        this.df = new DecimalFormat(this.sFormat);
                    }
                    string = this.df.format((double)this.iValue * this.factor);
                }
                return string;
            }
        }
        return "Error: unknown TYPE";
    }

    public void setValue(String string) {
        this.sValue = string;
    }

    public void setValue(int n) {
        this.iValue = n;
    }

    public void setFormat(double d, String string) {
        this.factor = d;
        this.sFormat = string;
    }

    public void performAction() throws EngineeringException {
        if (!this.isEditable()) {
            return;
        }
        switch (this.dataType) {
            case 0: {
                EngineeringInfoService.getInstance().storeInt(this.dataSource, this.namespace, this.keys[0], this.iValue);
                break;
            }
            case 3: {
                EngineeringInfoService.getInstance().storeString(this.dataSource, this.namespace, this.keys[0], this.sValue);
                break;
            }
            default: {
                LogMan.log("KeyValueModel.storeValue(): unknown data type " + this.dataType);
                throw new EngineeringException("KeyValueModel.storeValue(): unknown data type " + this.dataType);
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
                this.iValue = (Integer)object;
                this.isValueValid = true;
                LogMan.log(3, "KeyValueModel.updateData(): value set to " + this.iValue);
                if (this.widget == null) break;
                this.widget.dataChanged();
                break;
            }
            case 3: {
                this.sValue = (String)object;
                this.isValueValid = true;
                LogMan.log(3, "KeyValueModel.updateData(): value set to " + this.sValue);
                if (this.widget == null) break;
                this.widget.dataChanged();
                break;
            }
            default: {
                LogMan.log("KeyValueModel.updateData(): invalid data type " + this.dataType);
                this.widget.screenRenderer.enterErrorScreen("KeyValueModel.updateData(): invalid data type " + this.dataType, null);
            }
        }
    }

    public Widget getWidget(ScreenRenderer screenRenderer) {
        return new KeyValueWidget(this, screenRenderer);
    }
}

