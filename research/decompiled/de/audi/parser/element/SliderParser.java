/*
 * Decompiled with CFR 0.152.
 */
package de.audi.parser.element;

import de.audi.commons.tools.TokenReaderIFC;
import de.audi.parser.ParseException;
import de.audi.parser.element.ElementParser;
import de.audi.parser.element.ElementParserIFC;
import de.audi.tghu.development.model.ScreenElementModel;
import de.audi.tghu.development.model.SliderModel;
import java.io.IOException;

public class SliderParser
extends ElementParser
implements ElementParserIFC {
    public ScreenElementModel parseElement(String[] stringArray, TokenReaderIFC tokenReaderIFC) throws ParseException {
        SliderModel sliderModel = null;
        if (stringArray[0].toLowerCase().equals("slider")) {
            sliderModel = new SliderModel();
            long l = 0L;
            int n = 0;
            long l2 = 0L;
            long l3 = 0L;
            int n2 = 0;
            int n3 = -1;
            try {
                while (tokenReaderIFC.ready()) {
                    tokenReaderIFC.mark();
                    String[] stringArray2 = tokenReaderIFC.readTokens();
                    if (stringArray2.length <= 0) continue;
                    if (stringArray2[0].toLowerCase().equals("value")) {
                        if (stringArray2.length != 6) {
                            throw new ParseException("wrong number of arguments for value");
                        }
                        try {
                            n3 = this.getDataSource(stringArray2[1]);
                            n2 = Integer.decode(stringArray2[2]);
                            l = Long.decode(stringArray2[3]);
                            l3 = Long.decode(stringArray2[4]);
                            l2 = Long.decode(stringArray2[5]);
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
                        sliderModel.setLabel(stringArray2[1]);
                        continue;
                    }
                    if (stringArray2[0].equals("poll")) {
                        if (stringArray2.length != 2) {
                            throw new ParseException("wrong number of arguments for POLL");
                        }
                        try {
                            sliderModel.setRefreshInterval(Integer.decode(stringArray2[1]));
                            continue;
                        }
                        catch (NumberFormatException numberFormatException) {
                            throw new ParseException("POLL not a number");
                        }
                    }
                    if (stringArray2[0].toLowerCase().equals("limits")) {
                        if (stringArray2.length != 2) {
                            throw new ParseException("wrong number of arguments for LIMITS");
                        }
                        if (stringArray2[1].toLowerCase().equals("keys")) {
                            n = 1;
                            continue;
                        }
                        if (stringArray2[1].equals("absolute")) {
                            n = 0;
                            continue;
                        }
                        throw new ParseException("wrong parameter for LIMITS: " + stringArray2[1] + " expected: keys/absolute");
                    }
                    tokenReaderIFC.reset();
                    break;
                }
            }
            catch (IOException iOException) {
                throw new ParseException("Could not read the next TokenLine!");
            }
            sliderModel.setValueInt(n3, n2, l, l3, l2, n);
            if (!sliderModel.areRequiredFieldsSet()) {
                throw new ParseException("required SLIDER elements missing");
            }
        } else {
            throw new ParseException("Wrong parser used: SliderParser!");
        }
        return sliderModel;
    }
}

