/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.model;

import de.audi.tghu.development.EngineeringException;
import de.audi.tghu.development.eis.EngineeringInfoService;
import de.audi.tghu.development.manager.LogMan;
import de.audi.tghu.development.model.ScreenElementModel;
import de.audi.tghu.development.renderer.ScreenRenderer;
import de.audi.tghu.development.widget.BIOSCtrlWidget;
import de.audi.tghu.development.widget.Widget;
import java.text.DecimalFormat;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;

public class BIOSCtrlModel
extends ScreenElementModel {
    private static final int KEYINDEX_VALUE = 0;
    private String sValue;
    private int iValue;
    private List entryList = new ArrayList(10);
    private int currentEntryIndex = -1;
    private double factor = 0.0;
    private String sFormat = null;

    public int getListSize() {
        return this.entryList.size();
    }

    public int getCurrentEntryIndex() {
        return this.currentEntryIndex;
    }

    public void setCurrentEntryIndex(int n) {
        this.currentEntryIndex = n;
    }

    public BIOSCtrlModel() {
        super(8, 1);
        this.setEditable(true);
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

    public void addEntry(String string, String string2) {
        this.entryList.add(new Entry(string, string2));
    }

    public Entry getCachedEntry(int n) {
        if (n == -1) {
            return new Entry("undefined", "undefined");
        }
        return (Entry)this.entryList.get(n);
    }

    public Entry getEntry() {
        if (this.currentEntryIndex == -1) {
            return new Entry("undefined", "undefined");
        }
        return (Entry)this.entryList.get(this.currentEntryIndex);
    }

    public int getBounded(int n) {
        int n2 = this.entryList.size();
        while (n < 0) {
            n = n2 + n;
        }
        return n %= n2;
    }

    public void setCachedEntry() {
        if (this.currentEntryIndex == -1) {
            this.setValue("undefined");
        } else {
            this.currentEntryIndex = this.getBounded(this.currentEntryIndex);
            Entry entry = (Entry)this.entryList.get(this.currentEntryIndex);
            if (entry != null) {
                this.setValue((String)entry.getValue());
            }
        }
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
                    DecimalFormat decimalFormat = new DecimalFormat();
                    decimalFormat.applyPattern(this.sFormat);
                    string = decimalFormat.format((double)this.iValue * this.factor);
                }
                return string;
            }
        }
        return "Error: unknown TYPE";
    }

    public void setValue(String string) {
        if (this.dataType == 0) {
            try {
                this.iValue = Integer.parseInt(string);
            }
            catch (Exception exception) {}
        } else {
            this.sValue = string;
        }
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
                LogMan.log(3, "BIOSCtrlModel.storeValue(): unknown data type " + this.dataType);
                throw new EngineeringException("BIOSCtrlModel.storeValue(): unknown data type " + this.dataType);
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
        LogMan.log(3, "update Data for BIOSWidget");
        boolean bl = false;
        switch (this.dataType) {
            case 0: {
                try {
                    this.iValue = (Integer)object;
                }
                catch (Exception exception) {
                    // empty catch block
                }
                Iterator iterator = this.entryList.iterator();
                while (iterator.hasNext()) {
                    Entry entry = (Entry)iterator.next();
                    try {
                        int n2 = 0;
                        try {
                            n2 = new Integer((String)entry.getValue());
                        }
                        catch (Exception exception) {
                            // empty catch block
                        }
                        LogMan.log(3, "entryValue = " + n2);
                        if (n2 != this.iValue) continue;
                        this.iValue = n2;
                        this.currentEntryIndex = this.entryList.indexOf(entry);
                        bl = true;
                    }
                    catch (ClassCastException classCastException) {
                        classCastException.printStackTrace();
                    }
                }
                if (!bl) {
                    this.currentEntryIndex = -1;
                    this.isValueValid = false;
                } else {
                    this.isValueValid = true;
                }
                LogMan.log(3, "BIOSCtrlModel.updateData(): value set to " + this.iValue);
                if (this.widget == null) break;
                this.widget.dataChanged();
                break;
            }
            case 3: {
                this.sValue = (String)object;
                Iterator iterator = this.entryList.iterator();
                while (iterator.hasNext()) {
                    Entry entry = (Entry)iterator.next();
                    if (!this.sValue.equals((String)entry.getValue())) continue;
                    this.currentEntryIndex = this.entryList.indexOf(entry);
                    bl = true;
                }
                if (!bl) {
                    this.currentEntryIndex = -1;
                    this.isValueValid = false;
                } else {
                    this.isValueValid = true;
                }
                LogMan.log(3, "BIOSCtrlModel.updateData(): value set to " + this.sValue);
                if (this.widget == null) break;
                this.widget.dataChanged();
                break;
            }
            default: {
                LogMan.log(3, "BIOSCtrlModel.updateData(): invalid data type " + this.dataType);
                this.widget.screenRenderer.enterErrorScreen("BIOSCtrlModel.updateData(): invalid data type " + this.dataType, null);
            }
        }
    }

    public Widget getWidget(ScreenRenderer screenRenderer) {
        return new BIOSCtrlWidget(this, screenRenderer);
    }

    public class Entry {
        private String name;
        private Object value;

        public Entry(String string, Object object) {
            this.name = string;
            this.value = object;
        }

        public String getName() {
            return this.name;
        }

        public Object getValue() {
            return this.value;
        }
    }
}

