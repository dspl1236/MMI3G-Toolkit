/*
 * Decompiled with CFR 0.152.
 */
package de.audi.parser;

public class LinkInfo {
    private final transient String linkName;
    private final transient int linkId;

    public LinkInfo(String string, int n) {
        this.linkName = string;
        this.linkId = n;
    }

    public int getLinkId() {
        return this.linkId;
    }

    public String getLinkName() {
        return this.linkName;
    }
}

