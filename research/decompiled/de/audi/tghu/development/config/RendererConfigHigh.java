/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  de.audi.tghu.hmi.view.FontLoader
 *  fi.hybrid.a2dg.Path
 *  fi.hybrid.hwg.Font
 */
package de.audi.tghu.development.config;

import de.audi.tghu.development.config.AbstractRendererConfig;
import de.audi.tghu.development.manager.ResMan;
import de.audi.tghu.hmi.view.FontLoader;
import fi.hybrid.a2dg.Path;
import fi.hybrid.hwg.Font;

public final class RendererConfigHigh
extends AbstractRendererConfig {
    private static RendererConfigHigh rendererConfig = null;
    private Path pShape = new Path(5, 5);
    private Path pFrame;
    private Path pCheck;
    private float[] cursorPoly;
    public final int LAYERDEF_MENU_LEFT = 0;
    public final int LAYERDEF_MENU_TOP = 0;
    public final int LAYERDEF_MENU_WIDTH = 800;
    public final int LAYERDEF_MENU_HEIGHT = 480;
    public final int LAYERDEF_TITLE_LEFT = 20;
    public final int LAYERDEF_TITLE_TOP = 15;
    public final int LAYERDEF_TITLE_WIDTH = 760;
    public final int LAYERDEF_TITLE_HEIGHT = 30;
    public final int LAYERDEF_BORDER_LEFT = 20;
    public final int LAYERDEF_BORDER_TOP = 60;
    public final int LAYERDEF_BORDER_WIDTH = 25;
    public final int LAYERDEF_BORDER_HEIGHT = 400;
    public final int LAYERDEF_CONTENT_LEFT = 60;
    public final int LAYERDEF_CONTENT_TOP = 80;
    public final int LAYERDEF_CONTENT_WIDTH = 720;
    public final int LAYERDEF_CONTENT_HEIGHT = 360;
    public final int LAYERDEF_POPUP_LEFT = 150;
    public final int LAYERDEF_POPUP_TOP = 140;
    public final int LAYERDEF_POPUP_WIDTH = 500;
    public final int LAYERDEF_POPUP_HEIGHT = 200;
    public final int LAYERDEF_SPELLER_LEFT = 150;
    public final int LAYERDEF_SPELLER_TOP = 140;
    public final int LAYERDEF_SPELLER_WIDTH = 500;
    public final int LAYERDEF_SPELLER_HEIGHT = 200;
    public final int MENU_FRAME_LEFT = 10;
    public final int MENU_FRAME_TOP = 10;
    public final int MENU_FRAME_WIDTH = 780;
    public final int MENU_FRAME_HEIGHT = 460;
    public final int MENU_FRAME_TITLE = 50;
    public final int POPUP_FRAME_LEFT = 10;
    public final int POPUP_FRAME_TOP = 10;
    public final int POPUP_FRAME_WIDTH = 480;
    public final int POPUP_FRAME_HEIGHT = 180;
    public final int POPUP_FRAME_TITLE = 50;
    public final int CURSOR_X = 2;
    public final int CURSOR_TOP = 25;
    public final int CURSOR_WIDTH = 20;
    public final int CURSOR_HEIGHT = 20;
    public final int SCROLL_ARROW_X = 0;
    public final int SCROLL_ARROW_UP_Y = 0;
    public final int SCROLL_ARROW_DOWN_Y = 390;
    public final int SCROLL_ARROW_WIDTH = 20;
    public final int SCROLL_ARROW_HEIGHT = 10;
    public final int LINE_HEIGHT = 30;
    public final int ROWS_PER_SCREEN = 12;
    public final int FONT_SIZE = 20;
    public final int SLIDER_LEFT = 350;
    public final int SLIDER_BAR_WIDTH = 200;
    public final int SLIDER_BAR_HEIGHT = 4;
    public final int SLIDER_HANDLE_HEIGHT = 20;
    public final int SLIDER_HANDLE_WIDTH = 10;
    public final int SLIDER_VALUE_LEFT = 570;
    public final int LINK_LEFT = 350;
    public final int CHOICE_LEFT = 350;
    public final int KEYVALUE_LEFT = 350;
    public final int TABLE_LEFT = 50;
    public final int TABLE_VERT_LEFT = 350;
    public final int TABLE_COL_SPACE = 5;
    public final int SPELLER_INPUT_LEFT = 15;
    public final int SPELLER_INPUT_WIDTH = 470;
    public final int SPELLER_INPUT_TOP = 120;
    public final int SPELLER_INPUT_HEIGHT = 25;
    public final int BUTTON_BOX_WADDER = 5;
    public final int BUTTON_BOX_HSUB = 2;
    public final int BUTTON_BOX_WSTROKE = 2;
    public final int BUTTON_BOX_ROUNDING = 8;

    public static RendererConfigHigh getInstance(int n) {
        if (rendererConfig == null) {
            rendererConfig = new RendererConfigHigh();
            RendererConfigHigh.rendererConfig.terminalID = n;
        }
        return rendererConfig;
    }

    private RendererConfigHigh() {
        this.pShape.appendLine(1.0f, 1.0f, 20.0f, 10.0f);
        this.pShape.appendLine(20.0f, 10.0f, 1.0f, 20.0f);
        this.pShape.appendLine(1.0f, 20.0f, 1.0f, 1.0f);
        this.cursorPoly = new float[]{0.0f, 0.0f, 18.0f, 8.0f, 0.0f, 16.0f, 5.0f, 8.0f};
        this.pFrame = new Path(5, 5);
        this.pFrame.appendRectangle(0.0f, 0.0f, 20.0f, 20.0f);
        this.pCheck = new Path(5, 5);
        this.pCheck.appendRectangle(3.0f, 3.0f, 14.0f, 14.0f);
    }

    public Font getFont() {
        Font font = ResMan.getInstance(this.terminalID).getTerminal().getFontLoader().getATIPFont(FontLoader.STANDARD_FONT_PLAIN, 0, rendererConfig.getFONT_SIZE()).getFont();
        return font;
    }

    public int getBUTTON_BOX_HSUB() {
        return 2;
    }

    public int getBUTTON_BOX_ROUNDING() {
        return 8;
    }

    public int getBUTTON_BOX_WADDER() {
        return 5;
    }

    public int getBUTTON_BOX_WSTROKE() {
        return 2;
    }

    public int getCHOICE_LEFT() {
        return 350;
    }

    public int getCURSOR_HEIGHT() {
        return 20;
    }

    public int getCURSOR_TOP() {
        return 25;
    }

    public int getCURSOR_WIDTH() {
        return 20;
    }

    public int getCURSOR_X() {
        return 2;
    }

    public int getFONT_SIZE() {
        return 20;
    }

    public int getKEYVALUE_LEFT() {
        return 350;
    }

    public int getLAYERDEF_BORDER_HEIGHT() {
        return 400;
    }

    public int getLAYERDEF_BORDER_LEFT() {
        return 20;
    }

    public int getLAYERDEF_BORDER_TOP() {
        return 60;
    }

    public int getLAYERDEF_BORDER_WIDTH() {
        return 25;
    }

    public int getLAYERDEF_CONTENT_HEIGHT() {
        return 360;
    }

    public int getLAYERDEF_CONTENT_LEFT() {
        return 60;
    }

    public int getLAYERDEF_CONTENT_TOP() {
        return 80;
    }

    public int getLAYERDEF_CONTENT_WIDTH() {
        return 720;
    }

    public int getLAYERDEF_MENU_HEIGHT() {
        return 480;
    }

    public int getLAYERDEF_MENU_LEFT() {
        return 0;
    }

    public int getLAYERDEF_MENU_TOP() {
        return 0;
    }

    public int getLAYERDEF_MENU_WIDTH() {
        return 800;
    }

    public int getLAYERDEF_POPUP_HEIGHT() {
        return 200;
    }

    public int getLAYERDEF_POPUP_LEFT() {
        return 150;
    }

    public int getLAYERDEF_POPUP_TOP() {
        return 140;
    }

    public int getLAYERDEF_POPUP_WIDTH() {
        return 500;
    }

    public int getLAYERDEF_SPELLER_HEIGHT() {
        return 200;
    }

    public int getLAYERDEF_SPELLER_LEFT() {
        return 150;
    }

    public int getLAYERDEF_SPELLER_TOP() {
        return 140;
    }

    public int getLAYERDEF_SPELLER_WIDTH() {
        return 500;
    }

    public int getLAYERDEF_TITLE_HEIGHT() {
        return 30;
    }

    public int getLAYERDEF_TITLE_LEFT() {
        return 20;
    }

    public int getLAYERDEF_TITLE_TOP() {
        return 15;
    }

    public int getLAYERDEF_TITLE_WIDTH() {
        return 760;
    }

    public int getLINE_HEIGHT() {
        return 30;
    }

    public int getLINK_LEFT() {
        return 350;
    }

    public int getMENU_FRAME_HEIGHT() {
        return 460;
    }

    public int getMENU_FRAME_LEFT() {
        return 10;
    }

    public int getMENU_FRAME_TITLE() {
        return 50;
    }

    public int getMENU_FRAME_TOP() {
        return 10;
    }

    public int getMENU_FRAME_WIDTH() {
        return 780;
    }

    public int getPOPUP_FRAME_HEIGHT() {
        return 180;
    }

    public int getPOPUP_FRAME_LEFT() {
        return 10;
    }

    public int getPOPUP_FRAME_TITLE() {
        return 50;
    }

    public int getPOPUP_FRAME_TOP() {
        return 10;
    }

    public int getPOPUP_FRAME_WIDTH() {
        return 480;
    }

    public RendererConfigHigh getRendererConfig() {
        return rendererConfig;
    }

    public int getROWS_PER_SCREEN() {
        return 12;
    }

    public int getSCROLL_ARROW_DOWN_Y() {
        return 390;
    }

    public int getSCROLL_ARROW_HEIGHT() {
        return 10;
    }

    public int getSCROLL_ARROW_UP_Y() {
        return 0;
    }

    public int getSCROLL_ARROW_WIDTH() {
        return 20;
    }

    public int getSCROLL_ARROW_X() {
        return 0;
    }

    public int getSLIDER_BAR_HEIGHT() {
        return 4;
    }

    public int getSLIDER_BAR_WIDTH() {
        return 200;
    }

    public int getSLIDER_HANDLE_HEIGHT() {
        return 20;
    }

    public int getSLIDER_HANDLE_WIDTH() {
        return 10;
    }

    public int getSLIDER_LEFT() {
        return 350;
    }

    public int getSLIDER_VALUE_LEFT() {
        return 570;
    }

    public int getSPELLER_INPUT_HEIGHT() {
        return 25;
    }

    public int getSPELLER_INPUT_LEFT() {
        return 15;
    }

    public int getSPELLER_INPUT_TOP() {
        return 120;
    }

    public int getSPELLER_INPUT_WIDTH() {
        return 470;
    }

    public int getTABLE_COL_SPACE() {
        return 5;
    }

    public int getTABLE_LEFT() {
        return 50;
    }

    public int getTABLE_VERT_LEFT() {
        return 350;
    }

    public Path getPShape() {
        return this.pShape;
    }

    public Path getLinkSymbol() {
        return this.pShape;
    }

    public float[] getCursorPoly() {
        return this.cursorPoly;
    }

    public Path getPFrame() {
        return this.pFrame;
    }

    public Path getPCheck() {
        return this.pCheck;
    }
}

