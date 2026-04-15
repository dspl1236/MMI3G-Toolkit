/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  de.audi.tghu.hmi.view.HMITerminalImpl
 *  fi.hybrid.a2dg.Graphics2D
 *  fi.hybrid.hwg.Composite
 *  fi.hybrid.hwg.Drawable
 *  fi.hybrid.hwg.Font
 *  fi.hybrid.hwg.Graphics
 *  fi.hybrid.hwg.TextElement
 */
package de.audi.tghu.development.widget;

import de.audi.tghu.development.EngineeringException;
import de.audi.tghu.development.config.RendererConfigBasic;
import de.audi.tghu.development.model.ScreenElementModel;
import de.audi.tghu.development.model.TableColumnModel;
import de.audi.tghu.development.model.TableModel;
import de.audi.tghu.development.renderer.ScreenRenderer;
import de.audi.tghu.development.widget.Widget;
import de.audi.tghu.hmi.view.HMITerminalImpl;
import fi.hybrid.a2dg.Graphics2D;
import fi.hybrid.hwg.Composite;
import fi.hybrid.hwg.Drawable;
import fi.hybrid.hwg.Font;
import fi.hybrid.hwg.Graphics;
import fi.hybrid.hwg.TextElement;

public class TableRowWidget
extends Widget {
    protected int rowid;
    protected Composite[] cmpColumnValues;
    protected TextElement[] teColumnValues;

    public TableRowWidget(ScreenElementModel screenElementModel, int n, ScreenRenderer screenRenderer) {
        super(screenElementModel, screenRenderer);
        this.rowid = n;
        screenElementModel.addWidget(this);
    }

    public boolean processKey(int n) throws EngineeringException {
        return false;
    }

    public boolean processEncoder(int n, int n2) {
        return false;
    }

    public void render(Graphics graphics, Graphics2D graphics2D, Composite composite) {
        super.render(graphics, graphics2D, composite);
        if (!this.isVisible()) {
            return;
        }
        TableModel tableModel = (TableModel)this.model;
        TableColumnModel[] tableColumnModelArray = tableModel.getColumns();
        int n = this.x + this.rendererConfig.getTABLE_LEFT();
        int n2 = this.getTextHeight();
        if (tableModel.getOrientation() == 0) {
            int n3 = this.rendererConfig.getCOLOR_LIGHT_GREEN();
            if (this.isSelected()) {
                n3 = this.rendererConfig.getCOLOR_WHITE();
            }
            if (!tableModel.isValueValid()) {
                n3 = this.rendererConfig.getCOLOR_LIGHT_GRAY();
            }
            if (this.cmpColumnValues == null) {
                this.cmpColumnValues = new Composite[tableColumnModelArray.length];
            }
            if (this.teColumnValues == null) {
                this.teColumnValues = new TextElement[tableColumnModelArray.length];
            }
            for (int i = 0; i < tableColumnModelArray.length; ++i) {
                String string = tableModel.getCell(this.rowid, i);
                String string2 = string != null ? string : "";
                int n4 = tableColumnModelArray[i].getWidth();
                if (this.rendererConfig instanceof RendererConfigBasic) {
                    n4 /= 2;
                }
                if (this.cmpColumnValues[i] == null) {
                    this.cmpColumnValues[i] = this.resMan.newComposite(this.screenId, n4, this.rendererConfig.getLINE_HEIGHT());
                    this.cmpColumnValues[i].setPosition(n, this.y);
                }
                Font font = this.rendererConfig.getFont();
                if (this.teColumnValues[i] == null) {
                    this.teColumnValues[i] = this.resMan.newTextElement(this.screenId, font, string2, false);
                    this.teColumnValues[i].setPosition(0, n2);
                } else {
                    this.teColumnValues[i].setString(string2);
                }
                this.teColumnValues[i].setColor(n3);
                this.cmpColumnValues[i].addDrawable((Drawable)this.teColumnValues[i], 0);
                composite.addDrawable((Drawable)this.cmpColumnValues[i], 0);
                n += n4 + this.rendererConfig.getTABLE_COL_SPACE();
            }
        } else {
            String string;
            int n5 = this.rendererConfig.getCOLOR_LIGHT_GREEN();
            if (this.isSelected()) {
                n5 = this.rendererConfig.getCOLOR_WHITE();
            }
            int n6 = this.rendererConfig.getCOLOR_LIGHT_GREEN();
            if (!tableModel.isValueValid()) {
                n6 = this.rendererConfig.getCOLOR_LIGHT_GRAY();
            }
            String string3 = tableModel.getCell(0, this.rowid);
            if (this.teColumnValues == null) {
                this.teColumnValues = new TextElement[2];
            }
            Font font = this.rendererConfig.getFont();
            if (this.teColumnValues[0] == null) {
                this.teColumnValues[0] = this.resMan.newTextElement(this.screenId, font, tableColumnModelArray[this.rowid].getLabel(), false);
                this.teColumnValues[0].setPosition(n, this.y + n2);
            } else {
                this.teColumnValues[0].setString(tableColumnModelArray[this.rowid].getLabel());
            }
            this.teColumnValues[0].setColor(n5);
            n = this.x + this.rendererConfig.getTABLE_VERT_LEFT();
            String string4 = string = string3 != null ? string3 : "";
            if (this.teColumnValues[1] == null) {
                this.teColumnValues[1] = this.resMan.newTextElement(this.screenId, font, string, false);
                this.teColumnValues[1].setPosition(n, this.y + n2);
            } else {
                this.teColumnValues[1].setString(string);
            }
            this.teColumnValues[1].setColor(n6);
            composite.addDrawable((Drawable)this.teColumnValues[0], 0);
            composite.addDrawable((Drawable)this.teColumnValues[1], 0);
        }
    }

    public void cleanup(HMITerminalImpl hMITerminalImpl) {
        super.cleanup(hMITerminalImpl);
    }
}

