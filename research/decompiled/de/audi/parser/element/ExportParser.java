/*
 * Decompiled with CFR 0.152.
 */
package de.audi.parser.element;

import de.audi.commons.tools.TokenReaderIFC;
import de.audi.parser.ParseException;
import de.audi.parser.element.ElementParser;
import de.audi.parser.element.ElementParserIFC;
import de.audi.tghu.development.model.ExportModel;
import de.audi.tghu.development.model.ScreenElementModel;
import java.io.IOException;

public class ExportParser
extends ElementParser
implements ElementParserIFC {
    public ScreenElementModel parseElement(String[] stringArray, TokenReaderIFC tokenReaderIFC) throws ParseException {
        ExportModel exportModel = null;
        if (stringArray[0].equalsIgnoreCase("export")) {
            exportModel = new ExportModel();
            String string = null;
            String string2 = null;
            String string3 = null;
            try {
                while (tokenReaderIFC.ready()) {
                    tokenReaderIFC.mark();
                    String[] stringArray2 = tokenReaderIFC.readTokens();
                    if (stringArray2.length <= 0) continue;
                    if (stringArray2[0].equalsIgnoreCase("label")) {
                        if (stringArray2.length != 2) {
                            throw new ParseException("wrong number of arguments for VALUE");
                        }
                        string = stringArray2[1];
                        continue;
                    }
                    if (stringArray2[0].equals("screen")) {
                        if (stringArray2.length != 2) {
                            throw new ParseException("wrong number of arguments for SCREEN");
                        }
                        string3 = stringArray2[1];
                        continue;
                    }
                    if (stringArray2[0].equals("scope")) {
                        if (stringArray2.length != 2) {
                            throw new ParseException("wrong number of arguments for SCOPE");
                        }
                        string2 = stringArray2[1];
                        continue;
                    }
                    tokenReaderIFC.reset();
                    break;
                }
                exportModel.setLabel(string);
                exportModel.setScreen(string3.toLowerCase());
                exportModel.setScope(string2);
            }
            catch (IOException iOException) {
                throw new ParseException("Could not read the next TokenLine!");
            }
            if (!exportModel.areRequiredFieldsSet()) {
                throw new ParseException("required EXPORT element missing");
            }
        } else {
            throw new ParseException("Wrong parser used: SliderParser!");
        }
        return exportModel;
    }
}

