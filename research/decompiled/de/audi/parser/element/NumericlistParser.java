/*
 * Decompiled with CFR 0.152.
 */
package de.audi.parser.element;

import de.audi.commons.tools.TokenReaderIFC;
import de.audi.parser.ParseException;
import de.audi.parser.element.ElementParser;
import de.audi.parser.element.ElementParserIFC;
import de.audi.tghu.development.model.ScreenElementModel;
import de.audi.tghu.development.model.TableColumnModel;
import de.audi.tghu.development.model.TableModel;
import java.io.IOException;
import java.util.ArrayList;

public class NumericlistParser
extends ElementParser
implements ElementParserIFC {
    public ScreenElementModel parseElement(String[] stringArray, TokenReaderIFC tokenReaderIFC) throws ParseException {
        TableModel tableModel = null;
        TableColumnModel tableColumnModel = null;
        ArrayList<TableColumnModel> arrayList = null;
        int n = 0;
        if (stringArray[0].toLowerCase().equals("numericlist")) {
            TableColumnModel[] tableColumnModelArray;
            tableModel = new TableModel();
            try {
                while (tokenReaderIFC.ready()) {
                    tokenReaderIFC.mark();
                    String[] stringArray2 = tokenReaderIFC.readTokens();
                    if (stringArray2.length <= 0) continue;
                    if (stringArray2[0].toLowerCase().equals("content")) {
                        if (stringArray2.length != 4) {
                            throw new ParseException("wrong number of arguments for content");
                        }
                        try {
                            tableModel.setKeyValue(this.getDataSource(stringArray2[1]), Integer.decode(stringArray2[2]), Long.decode(stringArray2[3]));
                            tableModel.setMaxRows(1);
                            tableModel.setOrientation(1);
                            continue;
                        }
                        catch (NumberFormatException numberFormatException) {
                            throw new ParseException("NAMESPACE or KEY param not a number");
                        }
                    }
                    if (stringArray2[0].toLowerCase().equals("label")) {
                        if (stringArray2.length != 2) {
                            throw new ParseException("wrong number of arguments for LABEL");
                        }
                        tableModel.setLabel(stringArray2[1]);
                        continue;
                    }
                    if (stringArray2[0].toLowerCase().equals("poll")) {
                        if (stringArray2.length != 2) {
                            throw new ParseException("wrong number of arguments for POLL");
                        }
                        try {
                            tableModel.setRefreshInterval(Integer.decode(stringArray2[1]));
                            continue;
                        }
                        catch (NumberFormatException numberFormatException) {
                            throw new ParseException("POLL not a number");
                        }
                    }
                    if (stringArray2[0].toLowerCase().equals("row")) {
                        if (arrayList == null) {
                            arrayList = new ArrayList<TableColumnModel>();
                        }
                        tableColumnModel = new TableColumnModel();
                        if (stringArray2.length == 2) {
                            try {
                                tableColumnModel.setLabel(stringArray2[1]);
                                arrayList.add(tableColumnModel);
                                ++n;
                                continue;
                            }
                            catch (NumberFormatException numberFormatException) {
                                throw new ParseException("NAMESPACE or KEY param not a number");
                            }
                        }
                        if (stringArray2.length == 4) {
                            try {
                                double d;
                                tableColumnModel.setLabel(stringArray2[1]);
                                try {
                                    d = Double.parseDouble(stringArray2[2]);
                                }
                                catch (NumberFormatException numberFormatException) {
                                    throw new ParseException("FACTOR param not a number in row: " + n);
                                }
                                tableColumnModel.setFormat(d, stringArray2[3]);
                                arrayList.add(tableColumnModel);
                                ++n;
                                continue;
                            }
                            catch (NumberFormatException numberFormatException) {
                                throw new ParseException("NAMESPACE or KEY param not a number");
                            }
                        }
                        throw new ParseException("wrong number of arguments for content");
                    }
                    tokenReaderIFC.reset();
                    break;
                }
            }
            catch (IOException iOException) {
                throw new ParseException("Could not read the next TokenLine!");
            }
            if (arrayList != null && arrayList.size() > 0) {
                int n2 = arrayList.size();
                tableColumnModelArray = new TableColumnModel[n2];
                for (int i = 0; i < n2; ++i) {
                    tableColumnModelArray[i] = (TableColumnModel)arrayList.get(i);
                }
            } else {
                throw new ParseException("required for NUMERIC LIST: at least 1 row");
            }
            arrayList = null;
            tableModel.setColumns(tableColumnModelArray);
            tableModel.setTLVCoding(false);
            if (!tableModel.areRequiredFieldsSet()) {
                throw new ParseException("required NumericList elements missing");
            }
        } else {
            throw new ParseException("Wrong parser used: NumericlistParser!");
        }
        return tableModel;
    }
}

