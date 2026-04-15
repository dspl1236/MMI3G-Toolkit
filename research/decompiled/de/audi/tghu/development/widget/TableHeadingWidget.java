/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  de.audi.tghu.hmi.view.HMITerminalImpl
 *  fi.hybrid.a2dg.Graphics2D
 *  fi.hybrid.hwg.Bitmap
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
import fi.hybrid.hwg.Bitmap;
import fi.hybrid.hwg.Composite;
import fi.hybrid.hwg.Drawable;
import fi.hybrid.hwg.Font;
import fi.hybrid.hwg.Graphics;
import fi.hybrid.hwg.TextElement;

public class TableHeadingWidget
extends Widget {
    protected Bitmap bmpBgnd;
    protected Composite[] cmpColumnLabels;
    protected TextElement[] teColumnLabels;

    public TableHeadingWidget(ScreenElementModel screenElementModel, ScreenRenderer screenRenderer) {
        super(screenElementModel, screenRenderer);
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
        int n = this.getTextHeight();
        TableModel tableModel = (TableModel)this.model;
        TableColumnModel[] tableColumnModelArray = tableModel.getColumns();
        if (this.teColumnLabels == null || tableColumnModelArray.length != this.teColumnLabels.length) {
            this.teColumnLabels = new TextElement[tableColumnModelArray.length];
        }
        int n2 = this.x + this.rendererConfig.getTABLE_LEFT();
        if (tableModel.getOrientation() == 0) {
            if (this.cmpColumnLabels == null) {
                this.cmpColumnLabels = new Composite[tableColumnModelArray.length];
            }
            if (this.bmpBgnd == null) {
                this.bmpBgnd = this.resMan.newBitmap(this.screenId, this.rendererConfig.getMENU_FRAME_WIDTH(), this.rendererConfig.getLINE_HEIGHT(), false);
                graphics2D.bindTarget(this.bmpBgnd);
                graphics2D.clear(this.rendererConfig.getCOLOR_WHITE());
                graphics2D.releaseTarget();
            }
            for (int i = 0; i < tableColumnModelArray.length; ++i) {
                int n3 = tableColumnModelArray[i].getWidth();
                if (this.rendererConfig instanceof RendererConfigBasic) {
                    n3 /= 2;
                }
                if (this.cmpColumnLabels[i] == null) {
                    this.cmpColumnLabels[i] = this.resMan.newComposite(this.screenId, n3, this.rendererConfig.getLINE_HEIGHT());
                }
                if (this.isSelected()) {
                    this.bmpBgnd.setModulateColor(this.rendererConfig.getCOLOR_WHITE());
                } else {
                    this.bmpBgnd.setModulateColor(this.rendererConfig.getCOLOR_LIGHT_GREEN());
                }
                this.cmpColumnLabels[i].setPosition(n2, this.y);
                this.bmpBgnd.setPosition(0, 0);
                Font font = this.rendererConfig.getFont();
                if (this.teColumnLabels[i] == null) {
                    this.teColumnLabels[i] = this.resMan.newTextElement(this.screenId, font, tableColumnModelArray[i].getLabel(), false);
                    this.teColumnLabels[i].setColor(this.rendererConfig.getCOLOR_BLACK());
                    this.teColumnLabels[i].setPosition(0, n);
                }
                this.cmpColumnLabels[i].addDrawable((Drawable)this.bmpBgnd, 1);
                this.cmpColumnLabels[i].addDrawable((Drawable)this.teColumnLabels[i], 0);
                composite.addDrawable((Drawable)this.cmpColumnLabels[i], 0);
                n2 += n3 + this.rendererConfig.getTABLE_COL_SPACE();
            }
        }
    }

    public void cleanup(HMITerminalImpl hMITerminalImpl) {
        super.cleanup(hMITerminalImpl);
    }
}

