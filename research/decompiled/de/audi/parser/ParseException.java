/*
 * Decompiled with CFR 0.152.
 */
package de.audi.parser;

public class ParseException
extends Exception {
    private int tokenIndex = 0;

    public ParseException(String string, int n) {
        super(string);
        this.tokenIndex = n;
    }

    public ParseException(String string) {
        super(string);
    }

    public int getTokenIndex() {
        return this.tokenIndex;
    }
}

