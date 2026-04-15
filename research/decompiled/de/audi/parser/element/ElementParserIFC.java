/*
 * Decompiled with CFR 0.152.
 */
package de.audi.parser.element;

import de.audi.commons.tools.TokenReaderIFC;
import de.audi.parser.ParseException;
import de.audi.tghu.development.model.ScreenElementModel;

public interface ElementParserIFC {
    public ScreenElementModel parseElement(String[] var1, TokenReaderIFC var2) throws ParseException;
}

