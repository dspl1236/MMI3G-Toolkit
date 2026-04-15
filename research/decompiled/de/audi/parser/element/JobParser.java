/*
 * Decompiled with CFR 0.152.
 */
package de.audi.parser.element;

import de.audi.commons.tools.TokenReaderIFC;
import de.audi.parser.ParseException;
import de.audi.parser.element.ElementParser;
import de.audi.parser.element.ElementParserIFC;
import de.audi.tghu.development.model.JobModel;
import de.audi.tghu.development.model.ScreenElementModel;
import java.io.IOException;

public class JobParser
extends ElementParser
implements ElementParserIFC {
    public ScreenElementModel parseElement(String[] stringArray, TokenReaderIFC tokenReaderIFC) throws ParseException {
        JobModel jobModel = null;
        if (stringArray[0].toLowerCase().equals("job")) {
            jobModel = new JobModel();
            try {
                while (tokenReaderIFC.ready()) {
                    tokenReaderIFC.mark();
                    String[] stringArray2 = tokenReaderIFC.readTokens();
                    if (stringArray2.length <= 0) continue;
                    if (stringArray2[0].equals("label")) {
                        if (stringArray2.length != 2) {
                            throw new ParseException("wrong number of arguments for LABEL");
                        }
                        jobModel.setLabel(stringArray2[1]);
                        continue;
                    }
                    tokenReaderIFC.reset();
                    break;
                }
            }
            catch (IOException iOException) {
                throw new ParseException("Could not read the next TokenLine!");
            }
            if (!jobModel.areRequiredFieldsSet()) {
                throw new ParseException("required BUTTON elements missing");
            }
        } else {
            throw new ParseException("Wrong parser used: ButtonParser!");
        }
        return jobModel;
    }
}

