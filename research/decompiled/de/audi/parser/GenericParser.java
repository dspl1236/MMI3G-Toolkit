/*
 * Decompiled with CFR 0.152.
 */
package de.audi.parser;

import de.audi.commons.tools.TokenReader;
import de.audi.commons.tools.TokenReaderIFC;
import de.audi.tghu.development.manager.LogMan;

public class GenericParser {
    protected static TokenReaderIFC reader;

    public GenericParser() {
        reader = new TokenReader();
    }

    protected void parserLog(String string) {
        LogMan.log("Error in: " + reader.getFileName() + " at Line " + reader.getCurrentLine() + "\n" + string + "\n");
    }

    protected void parserLog(String string, int n) {
        LogMan.log("Error in: " + reader.getFileName() + " at Line " + reader.getCurrentLine() + "\n" + "Token = \"" + reader.getToken(n) + "\"\n" + string + "\n");
    }
}

