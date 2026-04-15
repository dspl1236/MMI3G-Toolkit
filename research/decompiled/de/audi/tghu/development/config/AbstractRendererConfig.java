/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  fi.hybrid.a2dg.Path
 *  fi.hybrid.a2dg.SolidPaint
 *  fi.hybrid.hwg.Font
 */
package de.audi.tghu.development.config;

import fi.hybrid.a2dg.Path;
import fi.hybrid.a2dg.SolidPaint;
import fi.hybrid.hwg.Font;

public abstract class AbstractRendererConfig {
    protected int terminalID;
    public final int COLOR_TRANSPARENT = 0;
    public final int COLOR_BLACK = -16777216;
    public final int COLOR_WHITE = -1;
    public final int COLOR_LIGHT_GREEN = -16711936;
    public final int COLOR_DARK_GREEN = -16748800;
    public final int COLOR_LIGHT_GRAY = -4144960;
    public final int COLOR_MID_GRAY = -8355712;
    public final int COLOR_DARK_GRAY = -14671840;
    public final SolidPaint pntBlack = new SolidPaint(-16777216);
    public final SolidPaint pntWhite = new SolidPaint(-1);
    public final SolidPaint pntLightGreen = new SolidPaint(-16711936);
    public final SolidPaint pntDarkGreen = new SolidPaint(-16748800);
    public final SolidPaint pntLightGray = new SolidPaint(-4144960);
    public final SolidPaint pntMidGray = new SolidPaint(-8355712);
    public final SolidPaint pntDarkGray = new SolidPaint(-14671840);

    public abstract Font getFont();

    public abstract float[] getCursorPoly();

    public abstract Path getPFrame();

    public abstract Path getPCheck();

    public abstract int getBUTTON_BOX_HSUB();

    public abstract int getBUTTON_BOX_ROUNDING();

    public abstract int getBUTTON_BOX_WADDER();

    public abstract int getBUTTON_BOX_WSTROKE();

    public abstract int getCHOICE_LEFT();

    public abstract int getCURSOR_HEIGHT();

    public abstract int getCURSOR_TOP();

    public abstract int getCURSOR_WIDTH();

    public abstract int getCURSOR_X();

    public abstract int getFONT_SIZE();

    public abstract int getKEYVALUE_LEFT();

    public abstract int getLAYERDEF_BORDER_HEIGHT();

    public abstract int getLAYERDEF_BORDER_LEFT();

    public abstract int getLAYERDEF_BORDER_TOP();

    public abstract int getLAYERDEF_BORDER_WIDTH();

    public abstract int getLAYERDEF_CONTENT_HEIGHT();

    public abstract int getLAYERDEF_CONTENT_LEFT();

    public abstract int getLAYERDEF_CONTENT_TOP();

    public abstract int getLAYERDEF_CONTENT_WIDTH();

    public abstract int getLAYERDEF_MENU_HEIGHT();

    public abstract int getLAYERDEF_MENU_LEFT();

    public abstract int getLAYERDEF_MENU_TOP();

    public abstract int getLAYERDEF_MENU_WIDTH();

    public abstract int getLAYERDEF_POPUP_HEIGHT();

    public abstract int getLAYERDEF_POPUP_LEFT();

    public abstract int getLAYERDEF_POPUP_TOP();

    public abstract int getLAYERDEF_POPUP_WIDTH();

    public abstract int getLAYERDEF_SPELLER_HEIGHT();

    public abstract int getLAYERDEF_SPELLER_LEFT();

    public abstract int getLAYERDEF_SPELLER_TOP();

    public abstract int getLAYERDEF_SPELLER_WIDTH();

    public abstract int getLAYERDEF_TITLE_HEIGHT();

    public abstract int getLAYERDEF_TITLE_LEFT();

    public abstract int getLAYERDEF_TITLE_TOP();

    public abstract int getLAYERDEF_TITLE_WIDTH();

    public abstract int getLINE_HEIGHT();

    public abstract int getLINK_LEFT();

    public abstract int getMENU_FRAME_HEIGHT();

    public abstract int getMENU_FRAME_LEFT();

    public abstract int getMENU_FRAME_TITLE();

    public abstract int getMENU_FRAME_TOP();

    public abstract int getMENU_FRAME_WIDTH();

    public abstract int getPOPUP_FRAME_HEIGHT();

    public abstract int getPOPUP_FRAME_LEFT();

    public abstract int getPOPUP_FRAME_TITLE();

    public abstract int getPOPUP_FRAME_TOP();

    public abstract int getPOPUP_FRAME_WIDTH();

    public abstract int getROWS_PER_SCREEN();

    public abstract int getSCROLL_ARROW_DOWN_Y();

    public abstract int getSCROLL_ARROW_HEIGHT();

    public abstract int getSCROLL_ARROW_UP_Y();

    public abstract int getSCROLL_ARROW_WIDTH();

    public abstract int getSCROLL_ARROW_X();

    public abstract int getSLIDER_BAR_HEIGHT();

    public abstract int getSLIDER_BAR_WIDTH();

    public abstract int getSLIDER_HANDLE_HEIGHT();

    public abstract int getSLIDER_HANDLE_WIDTH();

    public abstract int getSLIDER_LEFT();

    public abstract int getSLIDER_VALUE_LEFT();

    public abstract int getSPELLER_INPUT_HEIGHT();

    public abstract int getSPELLER_INPUT_LEFT();

    public abstract int getSPELLER_INPUT_TOP();

    public abstract int getSPELLER_INPUT_WIDTH();

    public abstract int getTABLE_COL_SPACE();

    public abstract int getTABLE_LEFT();

    public abstract int getTABLE_VERT_LEFT();

    public abstract Path getLinkSymbol();

    public int getCOLOR_DARK_GRAY() {
        return -14671840;
    }

    public int getCOLOR_DARK_GREEN() {
        return -16748800;
    }

    public int getCOLOR_LIGHT_GRAY() {
        return -4144960;
    }

    public int getCOLOR_LIGHT_GREEN() {
        return -16711936;
    }

    public int getCOLOR_MID_GRAY() {
        return -8355712;
    }

    public int getCOLOR_TRANSPARENT() {
        return 0;
    }

    public int getCOLOR_WHITE() {
        return -1;
    }

    public int getCOLOR_BLACK() {
        return -16777216;
    }

    public SolidPaint getPntBlack() {
        return this.pntBlack;
    }

    public SolidPaint getPntDarkGray() {
        return this.pntDarkGray;
    }

    public SolidPaint getPntDarkGreen() {
        return this.pntDarkGreen;
    }

    public SolidPaint getPntLightGray() {
        return this.pntLightGray;
    }

    public SolidPaint getPntLightGreen() {
        return this.pntLightGreen;
    }

    public SolidPaint getPntMidGray() {
        return this.pntMidGray;
    }

    public SolidPaint getPntWhite() {
        return this.pntWhite;
    }
}

