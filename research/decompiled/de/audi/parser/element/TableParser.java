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

public class TableParser
extends ElementParser
implements ElementParserIFC {
    private static final int EXPECT_QUOTE_OPEN = 0;
    private static final int EXPECT_LABEL = 1;
    private static final int EXPECT_TYPE = 2;
    private static final int EXPECT_WIDTH = 3;
    private static final int EXPECT_FACTOR = 4;
    private static final int EXPECT_FORMAT = 5;
    private static final int EXPECT_QUOTE_CLOSE = 6;

    public ScreenElementModel parseElement(String[] stringArray, TokenReaderIFC tokenReaderIFC) throws ParseException {
        TableModel tableModel = null;
        if (stringArray[0].toLowerCase().equals("table")) {
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
                    if (stringArray2[0].toLowerCase().equals("maxrows")) {
                        if (stringArray2.length != 2) {
                            throw new ParseException("wrong number of arguments for MAXROWS");
                        }
                        try {
                            tableModel.setMaxRows(Integer.decode(stringArray2[1]));
                            continue;
                        }
                        catch (NumberFormatException numberFormatException) {
                            throw new ParseException("MAXROWS not a number");
                        }
                    }
                    if (stringArray2[0].toLowerCase().equals("orientation")) {
                        if (stringArray2.length != 2) {
                            throw new ParseException("wrong number of arguments for ORIENTATION");
                        }
                        if (stringArray2[1].toLowerCase().equals("horizontal")) {
                            tableModel.setOrientation(0);
                            continue;
                        }
                        if (stringArray2[1].toLowerCase().equals("vertical")) {
                            tableModel.setOrientation(1);
                            continue;
                        }
                        throw new ParseException("wrong value for key ORIENTATION: " + stringArray2[1]);
                    }
                    if (stringArray2[0].equals("columns")) {
                        TableColumnModel[] tableColumnModelArray = this.parseColumnDefs(stringArray2);
                        if (tableColumnModelArray == null) continue;
                        tableModel.setColumns(tableColumnModelArray);
                        continue;
                    }
                    tokenReaderIFC.reset();
                    break;
                }
            }
            catch (IOException iOException) {
                throw new ParseException("Could not read the next TokenLine!");
            }
            if (!tableModel.areRequiredFieldsSet()) {
                throw new ParseException("required TABLE elements missing");
            }
            if (!tableModel.maxrowsAreOK()) {
                throw new ParseException("element TABLE contains illegal MAXROW");
            }
        } else {
            throw new ParseException("Wrong parser used: TableParser!");
        }
        tableModel.setTLVCoding(true);
        return tableModel;
    }

    private TableColumnModel[] parseColumnDefs(String[] stringArray) throws ParseException {
        int n;
        ArrayList<TableColumnModel> arrayList = new ArrayList<TableColumnModel>();
        TableColumnModel tableColumnModel = null;
        int n2 = 0;
        int n3 = 0;
        double d = 1.0;
        if (stringArray.length < 3) {
            throw new ParseException("not enough arguments for ORIENTATION");
        }
        for (n = 1; n < stringArray.length; ++n) {
            if (n2 == 0) {
                ++n3;
                if (stringArray[n].equals("(")) {
                    n2 = 1;
                    continue;
                }
                throw new ParseException("no open bracket/space in col def #" + n3 + " token is: " + stringArray[n]);
            }
            if (n2 == 1) {
                tableColumnModel = new TableColumnModel();
                tableColumnModel.setLabel(stringArray[n]);
                n2 = 2;
                continue;
            }
            if (n2 == 2) {
                if (tableColumnModel == null) {
                    throw new ParseException("internal parse error in EXPECT TYPE in column definition #" + n3);
                }
                if (stringArray[n].equals("String")) {
                    tableColumnModel.setDatatype(3);
                    n2 = 3;
                    continue;
                }
                if (stringArray[n].equals("int")) {
                    tableColumnModel.setDatatype(0);
                    n2 = 3;
                    continue;
                }
                throw new ParseException("wrong type in column definition #" + n3);
            }
            if (n2 == 3) {
                int n4;
                if (tableColumnModel == null) {
                    throw new ParseException("internal parse error in EXPECT WIDTH in column definition #" + n3);
                }
                n2 = 4;
                try {
                    n4 = Integer.parseInt(stringArray[n]);
                }
                catch (NumberFormatException numberFormatException) {
                    throw new ParseException("width not a number in column definition #" + n3);
                }
                tableColumnModel.setWidth(n4);
                continue;
            }
            if (n2 == 4) {
                if (tableColumnModel == null) {
                    throw new ParseException("internal parse error in EXPECT FACTOR in column definition #" + n3);
                }
                if (!stringArray[n].equals(")")) {
                    try {
                        d = Double.parseDouble(stringArray[n]);
                    }
                    catch (NumberFormatException numberFormatException) {
                        throw new ParseException("no number/factor in col def #" + n3 + " token is: " + stringArray[n]);
                    }
                    if (tableColumnModel.getDatatype() == 3) {
                        throw new ParseException("factor/format not allowed with STRING col def #" + n3 + " token is: " + stringArray[n]);
                    }
                    n2 = 5;
                    continue;
                }
                if (stringArray[n].equals(")")) {
                    n2 = 0;
                    arrayList.add(tableColumnModel);
                    continue;
                }
                throw new ParseException("no closed bracket/space in col def #" + n3 + " token is: " + stringArray[n]);
            }
            if (n2 == 5) {
                if (tableColumnModel == null) {
                    throw new ParseException("internal parse error in EXPECT FORMAT in column definition #" + n3);
                }
                if (!stringArray[n].equals(")")) {
                    tableColumnModel.setFormat(d, stringArray[n]);
                    n2 = 6;
                    continue;
                }
                if (stringArray[n].equals(")")) {
                    throw new ParseException("format string missing in column definition #" + n3);
                }
                throw new ParseException("no closed bracket/space in col def #" + n3 + " token is: " + stringArray[n]);
            }
            if (n2 == 6) {
                if (stringArray[n].equals(")")) {
                    n2 = 0;
                    arrayList.add(tableColumnModel);
                    continue;
                }
                throw new ParseException("no closed bracket/space in col def #" + n3 + " token is: " + stringArray[n]);
            }
            throw new ParseException("internal parse error: wrong internal state");
        }
        n = arrayList.size();
        if (n > 0) {
            TableColumnModel[] tableColumnModelArray = new TableColumnModel[n];
            for (int i = 0; i < n; ++i) {
                tableColumnModelArray[i] = (TableColumnModel)arrayList.get(i);
            }
            return tableColumnModelArray;
        }
        return null;
    }
}

