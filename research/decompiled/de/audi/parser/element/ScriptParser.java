/*
 * Decompiled with CFR 0.152.
 */
package de.audi.parser.element;

import de.audi.commons.tools.TokenReaderIFC;
import de.audi.parser.ParseException;
import de.audi.parser.element.ElementParser;
import de.audi.parser.element.ElementParserIFC;
import de.audi.tghu.development.model.ScreenElementModel;
import de.audi.tghu.development.model.ScriptModel;
import java.io.IOException;

public class ScriptParser
extends ElementParser
implements ElementParserIFC {
    public ScreenElementModel parseElement(String[] stringArray, TokenReaderIFC tokenReaderIFC) throws ParseException {
        ScriptModel scriptModel = null;
        if (stringArray[0].toLowerCase().equals("script")) {
            scriptModel = new ScriptModel();
            try {
                while (tokenReaderIFC.ready()) {
                    tokenReaderIFC.mark();
                    String[] stringArray2 = tokenReaderIFC.readTokens();
                    if (stringArray2.length <= 0) continue;
                    if (stringArray2[0].toLowerCase().equals("value")) {
                        if (stringArray2.length != 5) {
                            throw new ParseException("wrong number of arguments for value");
                        }
                        try {
                            scriptModel.setKeyValue(this.getDataSource(stringArray2[1]), Integer.decode(stringArray2[2]), Long.decode(stringArray2[3]), stringArray2[4]);
                            continue;
                        }
                        catch (NumberFormatException numberFormatException) {
                            throw new ParseException("NAMESPACE or KEY param not a number");
                        }
                    }
                    if (stringArray2[0].equals("label")) {
                        if (stringArray2.length != 2) {
                            throw new ParseException("wrong number of arguments for LABEL");
                        }
                        scriptModel.setLabel(stringArray2[1]);
                        continue;
                    }
                    if (stringArray2[0].equals("poll")) {
                        if (stringArray2.length != 2) {
                            throw new ParseException("wrong number of arguments for POLL");
                        }
                        try {
                            scriptModel.setRefreshInterval(Integer.decode(stringArray2[1]));
                            continue;
                        }
                        catch (NumberFormatException numberFormatException) {
                            throw new ParseException("POLL not a number");
                        }
                    }
                    tokenReaderIFC.reset();
                    break;
                }
            }
            catch (IOException iOException) {
                throw new ParseException("Could not read the next TokenLine!");
            }
            if (!scriptModel.areRequiredFieldsSet()) {
                throw new ParseException("required BUTTON elements missing");
            }
        } else {
            throw new ParseException("Wrong parser used: ButtonParser!");
        }
        return scriptModel;
    }
}

