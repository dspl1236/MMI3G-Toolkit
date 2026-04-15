/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.model;

public class TableColumnModel {
    String label;
    int datatype;
    int width;
    private double factor = 1.0;
    String format = "";

    public String getLabel() {
        return this.label;
    }

    public int getDatatype() {
        return this.datatype;
    }

    public int getWidth() {
        return this.width;
    }

    public String getFormat() {
        return this.format;
    }

    public double getFactor() {
        return this.factor;
    }

    public void setDatatype(int n) {
        this.datatype = n;
    }

    public void setFormat(double d, String string) {
        this.format = string;
        this.factor = d;
    }

    public void setLabel(String string) {
        this.label = string;
    }

    public void setWidth(int n) {
        this.width = n;
    }
}

