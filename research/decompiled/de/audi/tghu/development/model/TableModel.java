/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.model;

import de.audi.tghu.development.EngineeringException;
import de.audi.tghu.development.manager.LogMan;
import de.audi.tghu.development.model.DecoderConsumer;
import de.audi.tghu.development.model.IntArrayDecoder;
import de.audi.tghu.development.model.ScreenElementModel;
import de.audi.tghu.development.model.TLVDecoder;
import de.audi.tghu.development.model.TableColumnModel;
import de.audi.tghu.development.renderer.ScreenRenderer;
import de.audi.tghu.development.widget.LabelWidget;
import de.audi.tghu.development.widget.TableHeadingWidget;
import de.audi.tghu.development.widget.TableRowWidget;
import de.audi.tghu.development.widget.Widget;
import java.text.DecimalFormat;
import java.util.ArrayList;
import java.util.Iterator;

public class TableModel
extends ScreenElementModel {
    private static final int KEYINDEX_VALUE = 0;
    public static final int ORIENTATION_HORIZONTAL = 0;
    public static final int ORIENTATION_VERTICAL = 1;
    private static final String UNSUPPORTED_TYPE_VALUE = "???";
    private boolean isMaxRowsSet = false;
    private boolean isColumnsSet = false;
    private int maxRows = 0;
    private int orientation = 0;
    private boolean useTLVCoding = true;
    private TableColumnModel[] columns;
    private ArrayList data;
    private TLVValueConsumer valueConsumer;
    private IntValueConsumer arrayConsumer;
    static final DecimalFormat DF = new DecimalFormat();

    public TableModel() {
        super(6, 1);
        this.dataType = 4;
        this.valueConsumer = new TLVValueConsumer();
        this.arrayConsumer = new IntValueConsumer();
    }

    public boolean areRequiredFieldsSet() {
        return this.isValueKeySet && this.isLabelSet && this.isMaxRowsSet && this.isColumnsSet;
    }

    public boolean maxrowsAreOK() {
        return (this.orientation == 0 || this.orientation == 1 && this.maxRows == 1) && this.maxRows > 0;
    }

    public void setKeyValue(int n, int n2, long l) {
        this.dataSource = n;
        this.namespace = n2;
        this.keys[0] = l;
        this.isValueKeySet = true;
    }

    public void setMaxRows(int n) {
        this.maxRows = n;
        this.isMaxRowsSet = true;
    }

    public int getMaxRows() {
        return this.maxRows;
    }

    public void setColumns(TableColumnModel[] tableColumnModelArray) {
        this.columns = tableColumnModelArray;
        this.isColumnsSet = true;
    }

    public TableColumnModel[] getColumns() {
        return this.columns;
    }

    public String getCell(int n, int n2) {
        if (this.data == null || n >= this.data.size()) {
            return null;
        }
        String[] stringArray = (String[])this.data.get(n);
        if (n2 >= stringArray.length) {
            return null;
        }
        return stringArray[n2];
    }

    public void setOrientation(int n) {
        this.orientation = n;
    }

    public int getOrientation() {
        return this.orientation;
    }

    public void setTLVCoding(boolean bl) {
        this.useTLVCoding = bl;
        this.dataType = this.useTLVCoding ? 4 : 5;
    }

    public boolean isTLVCoding() {
        return this.useTLVCoding;
    }

    public void performAction() throws EngineeringException {
    }

    public void updateData(int n, long l, Object object) {
        if (n != this.namespace) {
            LogMan.log(3, "did not updateData in Table Model -> ns != namespace");
            return;
        }
        if (l == this.keys[0]) {
            Iterator iterator;
            if (this.useTLVCoding) {
                this.valueConsumer.initialize();
                iterator = new TLVDecoder((byte[])object, this.valueConsumer);
                ((TLVDecoder)((Object)iterator)).decode();
            } else {
                this.arrayConsumer.initialize();
                iterator = new IntArrayDecoder((int[])object, this.arrayConsumer);
                ((IntArrayDecoder)((Object)iterator)).decode();
            }
            this.isValueValid = true;
            if (this.lWidget != null) {
                iterator = this.lWidget.iterator();
                while (iterator.hasNext()) {
                    Widget widget = (Widget)iterator.next();
                    if (widget == null) continue;
                    widget.dataChanged();
                }
            }
        }
    }

    public Widget getWidget(ScreenRenderer screenRenderer) {
        int n = screenRenderer.getLayerId();
        screenRenderer.getWidgetList().add(new LabelWidget(this, screenRenderer));
        screenRenderer.setLayerId(n++);
        if (this.getOrientation() == 0) {
            screenRenderer.getWidgetList().add(new TableHeadingWidget(this, screenRenderer));
            screenRenderer.setLayerId(n++);
            for (int i = 0; i < this.getMaxRows(); ++i) {
                screenRenderer.setLayerId(n + i);
                screenRenderer.getWidgetList().add(new TableRowWidget(this, i, screenRenderer));
            }
        } else {
            TableColumnModel[] tableColumnModelArray = this.getColumns();
            for (int i = 0; i < tableColumnModelArray.length; ++i) {
                screenRenderer.setLayerId(n + i);
                TableRowWidget tableRowWidget = new TableRowWidget(this, i, screenRenderer);
                screenRenderer.getWidgetList().add(tableRowWidget);
            }
        }
        return null;
    }

    class TLVValueConsumer
    implements DecoderConsumer {
        private int column;
        private int rows;
        private String[] row;

        TLVValueConsumer() {
        }

        public void initialize() {
            this.column = 0;
            this.rows = 0;
            if (TableModel.this.data == null) {
                TableModel.this.data = new ArrayList();
            } else {
                TableModel.this.data.clear();
            }
        }

        public void consumeElement(int n, Object object) {
            if (this.rows >= TableModel.this.maxRows) {
                return;
            }
            if (this.column == 0) {
                this.row = new String[TableModel.this.columns.length];
            }
            block0 : switch (TableModel.this.columns[this.column].getDatatype()) {
                case 0: {
                    DecimalFormat decimalFormat = new DecimalFormat();
                    String string = TableModel.this.columns[this.column].getFormat();
                    if (string == null) {
                        string = "";
                    }
                    decimalFormat.applyPattern(string);
                    double d = TableModel.this.columns[this.column].getFactor();
                    switch (n) {
                        case 1: {
                            this.row[this.column] = decimalFormat.format((double)((Byte)object).byteValue() * d);
                            break block0;
                        }
                        case 2: {
                            this.row[this.column] = decimalFormat.format((double)((Short)object).shortValue() * d);
                            break block0;
                        }
                        case 3: {
                            this.row[this.column] = decimalFormat.format((double)((Integer)object).intValue() * d);
                            break block0;
                        }
                        case 5: {
                            this.row[this.column] = decimalFormat.format((double)((Short)object).shortValue() * d);
                            break block0;
                        }
                        case 6: {
                            this.row[this.column] = decimalFormat.format((double)((Integer)object).intValue() * d);
                            break block0;
                        }
                        case 7: {
                            this.row[this.column] = decimalFormat.format((double)((Long)object).longValue() * d);
                            break block0;
                        }
                    }
                    this.row[this.column] = TableModel.UNSUPPORTED_TYPE_VALUE;
                    break;
                }
                case 3: {
                    this.row[this.column] = String.valueOf(object);
                    break;
                }
                default: {
                    this.row[this.column] = TableModel.UNSUPPORTED_TYPE_VALUE;
                }
            }
            ++this.column;
            if (this.column >= TableModel.this.columns.length) {
                this.column = 0;
                TableModel.this.data.add(this.row);
                ++this.rows;
            }
        }
    }

    class IntValueConsumer
    implements DecoderConsumer {
        private int column;
        private int rows;
        private String[] row;

        IntValueConsumer() {
        }

        public void initialize() {
            this.column = 0;
            this.rows = 0;
            if (TableModel.this.data == null) {
                TableModel.this.data = new ArrayList();
            } else {
                TableModel.this.data.clear();
            }
        }

        public void consumeElement(int n, Object object) {
            if (this.rows >= TableModel.this.maxRows) {
                return;
            }
            if (this.column == 0) {
                this.row = new String[TableModel.this.columns.length];
            }
            switch (n) {
                case 3: {
                    String string = TableModel.this.columns[this.column].getFormat();
                    if (string == null) {
                        string = "";
                    }
                    DF.applyPattern(string);
                    double d = TableModel.this.columns[this.column].getFactor();
                    this.row[this.column] = DF.format((double)((Integer)object).intValue() * d);
                    break;
                }
                default: {
                    this.row[this.column] = TableModel.UNSUPPORTED_TYPE_VALUE;
                }
            }
            ++this.column;
            if (this.column >= TableModel.this.columns.length) {
                this.column = 0;
                TableModel.this.data.add(this.row);
                ++this.rows;
            }
        }
    }
}

