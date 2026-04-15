/*
 * Decompiled with CFR 0.152.
 */
package de.audi.parser.element;

import de.audi.commons.tools.TokenReaderIFC;
import de.audi.parser.ParseException;
import de.audi.parser.element.ElementParser;
import de.audi.parser.element.ElementParserIFC;
import de.audi.tghu.development.model.ScreenElementModel;
import de.audi.tghu.development.model.SlideShowModel;
import java.io.IOException;

public class SlideshowParser
extends ElementParser
implements ElementParserIFC {
    public ScreenElementModel parseElement(String[] stringArray, TokenReaderIFC tokenReaderIFC) throws ParseException {
        SlideShowModel slideShowModel = null;
        if (stringArray[0].equalsIgnoreCase("slideShow")) {
            slideShowModel = new SlideShowModel();
            try {
                while (tokenReaderIFC.ready()) {
                    tokenReaderIFC.mark();
                    String[] stringArray2 = tokenReaderIFC.readTokens();
                    if (stringArray2.length <= 0) continue;
                    if (stringArray2[0].equals("label")) {
                        if (stringArray2.length != 2) {
                            throw new ParseException("wrong number of arguments for LABEL");
                        }
                        slideShowModel.setLabel(stringArray2[1]);
                        continue;
                    }
                    tokenReaderIFC.reset();
                    break;
                }
            }
            catch (IOException iOException) {
                throw new ParseException("Could not read the next TokenLine!");
            }
            if (!slideShowModel.areRequiredFieldsSet()) {
                throw new ParseException("required SlideShow elements missing");
            }
        } else {
            throw new ParseException("Wrong parser used: SlideShowParser!");
        }
        return slideShowModel;
    }
}

