/*
 * Decompiled with CFR 0.152.
 */
package de.audi.parser.element;

import de.audi.parser.ParseException;

public class ElementParser {
    protected static final String TYPE_INT = "int";
    protected static final String TYPE_STRING = "String";
    protected static final String PERSISTENCE = "per";
    protected static final String SYSTEM = "sys";
    protected static final String HORIZONTAL = "horizontal";
    protected static final String VERTICAL = "vertical";

    protected int getDataSource(String string) throws ParseException {
        int n = -1;
        if (string != null && string.length() != 0) {
            if (string.equals(PERSISTENCE)) {
                n = 0;
            } else if (string.equals(SYSTEM)) {
                n = 1;
            }
        }
        if (n == -1) {
            throw new ParseException("Invalid data source specified");
        }
        return n;
    }
}

