/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.eis;

public class ExportKey {
    private String label;
    private int namespace;
    private long key;
    private int type;

    public ExportKey(int n, long l) {
        this(null, 0, n, l);
    }

    public ExportKey(String string, int n, int n2, long l) {
        this.label = string;
        this.type = n;
        this.namespace = n2;
        this.key = l;
    }

    public String getLabel() {
        return this.label;
    }

    public int getType() {
        return this.type;
    }

    public long getKey() {
        return this.key;
    }

    public int getNamespace() {
        return this.namespace;
    }

    public boolean equals(ExportKey exportKey) {
        boolean bl = false;
        if (exportKey.key == this.key && exportKey.namespace == this.namespace) {
            bl = true;
        }
        return bl;
    }

    public String toString() {
        return " ns = " + Integer.toHexString(this.namespace) + " / key = " + Long.toHexString(this.key);
    }
}

