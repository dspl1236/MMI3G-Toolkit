/*
 * Decompiled with CFR 0.152.
 */
package de.audi.parser.element;

import de.audi.commons.tools.TokenReaderIFC;
import de.audi.parser.ParseException;
import de.audi.parser.element.ElementParser;
import de.audi.parser.element.ElementParserIFC;
import de.audi.tghu.development.model.KeyValueModel;
import de.audi.tghu.development.model.ScreenElementModel;
import java.io.IOException;

public class KeyvalueParser
extends ElementParser
implements ElementParserIFC {
    /*
     * Enabled aggressive block sorting
     * Enabled unnecessary exception pruning
     * Enabled aggressive exception aggregation
     */
    public ScreenElementModel parseElement(String[] stringArray, TokenReaderIFC tokenReaderIFC) throws ParseException {
        KeyValueModel keyValueModel = null;
        if (!stringArray[0].toLowerCase().equals("keyvalue")) {
            throw new ParseException("Wrong parser used: KeyvalueParser!");
        }
        keyValueModel = new KeyValueModel();
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
                        if (stringArray2[1].equals("int")) {
                            keyValueModel.setValueInt(this.getDataSource(stringArray2[2]), Integer.decode(stringArray2[3]), Long.decode(stringArray2[4]));
                        }
                        if (!stringArray2[1].equals("String")) continue;
                        keyValueModel.setValueString(this.getDataSource(stringArray2[2]), Integer.decode(stringArray2[3]), Long.decode(stringArray2[4]));
                        continue;
                    }
                    catch (NumberFormatException numberFormatException) {
                        throw new ParseException("VALUE params not a number");
                    }
                }
                if (stringArray2[0].equals("label")) {
                    if (stringArray2.length != 2) {
                        throw new ParseException("wrong number of arguments for LABEL");
                    }
                    keyValueModel.setLabel(stringArray2[1]);
                    continue;
                }
                if (stringArray2[0].equals("poll")) {
                    if (stringArray2.length != 2) {
                        throw new ParseException("wrong number of arguments for POLL: " + stringArray2.length);
                    }
                    try {
                        keyValueModel.setRefreshInterval(Integer.decode(stringArray2[1]));
                        continue;
                    }
                    catch (NumberFormatException numberFormatException) {
                        throw new ParseException("POLL not a number");
                    }
                }
                if (stringArray2[0].equals("format")) {
                    if (stringArray2.length != 3) {
                        throw new ParseException("wrong number of arguments for FORMAT: " + stringArray2.length);
                    }
                    try {
                        keyValueModel.setFormat(Double.parseDouble(stringArray2[1]), stringArray2[2]);
                        continue;
                    }
                    catch (NumberFormatException numberFormatException) {
                        throw new ParseException("FORMAT not a number");
                    }
                }
                tokenReaderIFC.reset();
                break;
            }
        }
        catch (IOException iOException) {
            throw new ParseException("Could not read the next TokenLine!");
        }
        catch (ArrayIndexOutOfBoundsException arrayIndexOutOfBoundsException) {
            throw new ParseException("Missing Parameters");
        }
        if (!keyValueModel.areRequiredFieldsSet()) {
            throw new ParseException("Required KEYVALUE elements missing");
        }
        return keyValueModel;
    }
}

