/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.model;

import de.audi.tghu.development.EngineeringException;
import de.audi.tghu.development.eis.EISListener;
import de.audi.tghu.development.model.ModelCallbackIFC;
import de.audi.tghu.development.renderer.ScreenRenderer;
import de.audi.tghu.development.widget.Widget;
import java.util.ArrayList;

public abstract class ScreenElementModel
implements EISListener {
    public static final int MODELTYPE_INVALID = -1;
    public static final int MODELTYPE_BUTTON = 0;
    public static final int MODELTYPE_CHOICE = 1;
    public static final int MODELTYPE_SLIDER = 2;
    public static final int MODELTYPE_KEYVALUE = 3;
    public static final int MODELTYPE_LINK = 4;
    public static final int MODELTYPE_LABEL = 5;
    public static final int MODELTYPE_TABLE = 6;
    public static final int MODELTYPE_SCRIPT = 7;
    public static final int MODELTYPE_BIOSCTRL = 8;
    public static final int MODELTYPE_EXPORT = 9;
    public static final int MODELTYPE_JOB = 10;
    public static final int MODELTYPE_RUNNER = 11;
    public static final int MODELTYPE_SLIDESHOW = 12;
    public static final int MODELTYPE_RETURN = 13;
    public static final int DATATYPE_INT = 0;
    public static final int DATATYPE_STRING = 3;
    public static final int DATATYPE_OBJECT = 4;
    public static final int DATATYPE_INTARRAY = 5;
    public static final int DATATYPE_STRING_LIST = 6;
    public static final int DATATYPE_INT_LIST = 7;
    protected static final String EMPTY_STRING = "";
    protected boolean isLabelSet;
    protected boolean isValueKeySet;
    protected boolean isValueValid;
    protected int modelType;
    protected boolean editable;
    protected int refreshInterval;
    protected String label;
    protected int dataSource;
    protected int namespace;
    protected long[] keys;
    protected int dataType;
    protected Widget widget;
    protected ArrayList lWidget;
    protected ModelCallbackIFC callbackHandler = null;

    protected ScreenElementModel(int n, int n2) {
        this.modelType = n;
        this.isLabelSet = false;
        this.isValueKeySet = false;
        this.isValueValid = false;
        this.keys = new long[n2];
        this.editable = true;
        this.refreshInterval = 0;
        this.widget = null;
        this.lWidget = new ArrayList();
    }

    public abstract void performAction() throws EngineeringException;

    public abstract Widget getWidget(ScreenRenderer var1);

    public abstract void updateData(int var1, long var2, Object var4);

    public void setCallbackObject(ModelCallbackIFC modelCallbackIFC) {
        this.callbackHandler = modelCallbackIFC;
    }

    public boolean areRequiredFieldsSet() {
        return this.isValueKeySet && this.isLabelSet;
    }

    public boolean isEditable() {
        return this.editable;
    }

    public String getLabel() {
        return this.label;
    }

    public int getRefreshInterval() {
        return this.refreshInterval;
    }

    public void setEditable(boolean bl) {
        this.editable = bl;
    }

    public void setLabel(String string) {
        this.isLabelSet = true;
        this.label = string;
    }

    public void setRefreshInterval(int n) {
        this.refreshInterval = n;
    }

    public int getModelType() {
        return this.modelType;
    }

    public int getDataSource() {
        return this.dataSource;
    }

    public void setDataSource(int n) {
        this.dataSource = n;
    }

    public int getNamespace() {
        return this.namespace;
    }

    public void setNamespace(int n) {
        this.namespace = n;
    }

    public long[] getKeys() {
        return this.keys;
    }

    public int getDataType() {
        return this.dataType;
    }

    public void setDataType(int n) {
        this.dataType = n;
    }

    public boolean isLabelSet() {
        return this.isLabelSet;
    }

    public boolean isValueValid() {
        return this.isValueValid;
    }

    public void setWidget(Widget widget) {
        this.widget = widget;
    }

    public void addWidget(Widget widget) {
        this.lWidget.add(widget);
    }
}

