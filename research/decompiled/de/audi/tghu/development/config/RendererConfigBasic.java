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

public final class RendererConfigBasic
extends AbstractRendererConfig {
    private static RendererConfigBasic rendererConfig = null;
    private Path pShape = new Path(5, 5);
    private Path pFrame;
    private Path pCheck;
    private float[] cursorPoly;
    public final int LAYERDEF_MENU_LEFT = 0;
    public final int LAYERDEF_MENU_TOP = 0;
    public final int LAYERDEF_MENU_WIDTH = 400;
    public final int LAYERDEF_MENU_HEIGHT = 240;
    public final int LAYERDEF_TITLE_LEFT = 10;
    public final int LAYERDEF_TITLE_TOP = -5;
    public final int LAYERDEF_TITLE_WIDTH = 380;
    public final int LAYERDEF_TITLE_HEIGHT = 30;
    public final int LAYERDEF_BORDER_LEFT = 10;
    public final int LAYERDEF_BORDER_TOP = 30;
    public final int LAYERDEF_BORDER_WIDTH = 12;
    public final int LAYERDEF_BORDER_HEIGHT = 200;
    public final int LAYERDEF_CONTENT_LEFT = 30;
    public final int LAYERDEF_CONTENT_TOP = 40;
    public final int LAYERDEF_CONTENT_WIDTH = 360;
    public final int LAYERDEF_CONTENT_HEIGHT = 180;
    public final int LAYERDEF_POPUP_LEFT = 75;
    public final int LAYERDEF_POPUP_TOP = 70;
    public final int LAYERDEF_POPUP_WIDTH = 250;
    public final int LAYERDEF_POPUP_HEIGHT = 100;
    public final int LAYERDEF_SPELLER_LEFT = 75;
    public final int LAYERDEF_SPELLER_TOP = 70;
    public final int LAYERDEF_SPELLER_WIDTH = 250;
    public final int LAYERDEF_SPELLER_HEIGHT = 100;
    public final int MENU_FRAME_LEFT = 5;
    public final int MENU_FRAME_TOP = 5;
    public final int MENU_FRAME_WIDTH = 390;
    public final int MENU_FRAME_HEIGHT = 230;
    public final int MENU_FRAME_TITLE = 25;
    public final int POPUP_FRAME_LEFT = 5;
    public final int POPUP_FRAME_TOP = 5;
    public final int POPUP_FRAME_WIDTH = 240;
    public final int POPUP_FRAME_HEIGHT = 90;
    public final int POPUP_FRAME_TITLE = 25;
    public final int CURSOR_X = 1;
    public final int CURSOR_TOP = 12;
    public final int CURSOR_WIDTH = 10;
    public final int CURSOR_HEIGHT = 10;
    public final int SCROLL_ARROW_X = 0;
    public final int SCROLL_ARROW_UP_Y = 0;
    public final int SCROLL_ARROW_DOWN_Y = 195;
    public final int SCROLL_ARROW_WIDTH = 10;
    public final int SCROLL_ARROW_HEIGHT = 5;
    public final int LINE_HEIGHT = 15;
    public final int ROWS_PER_SCREEN = 12;
    public final int FONT_SIZE = 10;
    public final int SLIDER_LEFT = 175;
    public final int SLIDER_BAR_WIDTH = 100;
    public final int SLIDER_BAR_HEIGHT = 2;
    public final int SLIDER_HANDLE_HEIGHT = 10;
    public final int SLIDER_HANDLE_WIDTH = 5;
    public final int SLIDER_VALUE_LEFT = 285;
    public final int LINK_LEFT = 175;
    public final int CHOICE_LEFT = 175;
    public final int KEYVALUE_LEFT = 175;
    public final int TABLE_LEFT = 25;
    public final int TABLE_VERT_LEFT = 175;
    public final int TABLE_COL_SPACE = 2;
    public final int SPELLER_INPUT_LEFT = 7;
    public final int SPELLER_INPUT_WIDTH = 235;
    public final int SPELLER_INPUT_TOP = 60;
    public final int SPELLER_INPUT_HEIGHT = 12;
    public final int BUTTON_BOX_WADDER = 2;
    public final int BUTTON_BOX_HSUB = 1;
    public final int BUTTON_BOX_WSTROKE = 1;
    public final int BUTTON_BOX_ROUNDING = 4;

    public static RendererConfigBasic getInstance(int n) {
        if (rendererConfig == null) {
            rendererConfig = new RendererConfigBasic();
            RendererConfigBasic.rendererConfig.terminalID = n;
        }
        return rendererConfig;
    }

    private RendererConfigBasic() {
        this.pShape.appendLine(1.0f, 1.0f, 10.0f, 5.0f);
        this.pShape.appendLine(10.0f, 5.0f, 1.0f, 10.0f);
        this.pShape.appendLine(1.0f, 10.0f, 1.0f, 1.0f);
        this.cursorPoly = new float[]{0.0f, 0.0f, 9.0f, 4.0f, 0.0f, 8.0f, 2.0f, 4.0f};
        this.pFrame = new Path(5, 5);
        this.pFrame.appendRectangle(0.0f, 0.0f, 10.0f, 10.0f);
        this.pCheck = new Path(5, 5);
        this.pCheck.appendRectangle(2.0f, 2.0f, 6.0f, 6.0f);
    }

    public Font getFont() {
        Font font = ResMan.getInstance(this.terminalID).getTerminal().getFontLoader().getATIPFont(FontLoader.STANDARD_FONT_PLAIN, 0, rendererConfig.getFONT_SIZE()).getFont();
        return font;
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

    public int getBUTTON_BOX_HSUB() {
        return 1;
    }

    public int getBUTTON_BOX_ROUNDING() {
        return 4;
    }

    public int getBUTTON_BOX_WADDER() {
        return 2;
    }

    public int getBUTTON_BOX_WSTROKE() {
        return 1;
    }

    public int getCHOICE_LEFT() {
        return 175;
    }

    public int getCURSOR_HEIGHT() {
        return 10;
    }

    public int getCURSOR_TOP() {
        return 12;
    }

    public int getCURSOR_WIDTH() {
        return 10;
    }

    public int getCURSOR_X() {
        return 1;
    }

    public int getFONT_SIZE() {
        return 10;
    }

    public int getKEYVALUE_LEFT() {
        return 175;
    }

    public int getLAYERDEF_BORDER_HEIGHT() {
        return 200;
    }

    public int getLAYERDEF_BORDER_LEFT() {
        return 10;
    }

    public int getLAYERDEF_BORDER_TOP() {
        return 30;
    }

    public int getLAYERDEF_BORDER_WIDTH() {
        return 12;
    }

    public int getLAYERDEF_CONTENT_HEIGHT() {
        return 180;
    }

    public int getLAYERDEF_CONTENT_LEFT() {
        return 30;
    }

    public int getLAYERDEF_CONTENT_TOP() {
        return 40;
    }

    public int getLAYERDEF_CONTENT_WIDTH() {
        return 360;
    }

    public int getLAYERDEF_MENU_HEIGHT() {
        return 240;
    }

    public int getLAYERDEF_MENU_LEFT() {
        return 0;
    }

    public int getLAYERDEF_MENU_TOP() {
        return 0;
    }

    public int getLAYERDEF_MENU_WIDTH() {
        return 400;
    }

    public int getLAYERDEF_POPUP_HEIGHT() {
        return 100;
    }

    public int getLAYERDEF_POPUP_LEFT() {
        return 75;
    }

    public int getLAYERDEF_POPUP_TOP() {
        return 70;
    }

    public int getLAYERDEF_POPUP_WIDTH() {
        return 250;
    }

    public int getLAYERDEF_SPELLER_HEIGHT() {
        return 100;
    }

    public int getLAYERDEF_SPELLER_LEFT() {
        return 75;
    }

    public int getLAYERDEF_SPELLER_TOP() {
        return 70;
    }

    public int getLAYERDEF_SPELLER_WIDTH() {
        return 250;
    }

    public int getLAYERDEF_TITLE_HEIGHT() {
        return 30;
    }

    public int getLAYERDEF_TITLE_LEFT() {
        return 10;
    }

    public int getLAYERDEF_TITLE_TOP() {
        return -5;
    }

    public int getLAYERDEF_TITLE_WIDTH() {
        return 380;
    }

    public int getLINE_HEIGHT() {
        return 15;
    }

    public int getLINK_LEFT() {
        return 175;
    }

    public int getMENU_FRAME_HEIGHT() {
        return 230;
    }

    public int getMENU_FRAME_LEFT() {
        return 5;
    }

    public int getMENU_FRAME_TITLE() {
        return 25;
    }

    public int getMENU_FRAME_TOP() {
        return 5;
    }

    public int getMENU_FRAME_WIDTH() {
        return 390;
    }

    public int getPOPUP_FRAME_HEIGHT() {
        return 90;
    }

    public int getPOPUP_FRAME_LEFT() {
        return 5;
    }

    public int getPOPUP_FRAME_TITLE() {
        return 25;
    }

    public int getPOPUP_FRAME_TOP() {
        return 5;
    }

    public int getPOPUP_FRAME_WIDTH() {
        return 240;
    }

    public int getROWS_PER_SCREEN() {
        return 12;
    }

    public int getSCROLL_ARROW_DOWN_Y() {
        return 195;
    }

    public int getSCROLL_ARROW_HEIGHT() {
        return 5;
    }

    public int getSCROLL_ARROW_UP_Y() {
        return 0;
    }

    public int getSCROLL_ARROW_WIDTH() {
        return 10;
    }

    public int getSCROLL_ARROW_X() {
        return 0;
    }

    public int getSLIDER_BAR_HEIGHT() {
        return 2;
    }

    public int getSLIDER_BAR_WIDTH() {
        return 100;
    }

    public int getSLIDER_HANDLE_HEIGHT() {
        return 10;
    }

    public int getSLIDER_HANDLE_WIDTH() {
        return 5;
    }

    public int getSLIDER_LEFT() {
        return 175;
    }

    public int getSLIDER_VALUE_LEFT() {
        return 285;
    }

    public int getSPELLER_INPUT_HEIGHT() {
        return 12;
    }

    public int getSPELLER_INPUT_LEFT() {
        return 7;
    }

    public int getSPELLER_INPUT_TOP() {
        return 60;
    }

    public int getSPELLER_INPUT_WIDTH() {
        return 235;
    }

    public int getTABLE_COL_SPACE() {
        return 2;
    }

    public int getTABLE_LEFT() {
        return 25;
    }

    public int getTABLE_VERT_LEFT() {
        return 175;
    }

    public Path getPShape() {
        return this.pShape;
    }
}

