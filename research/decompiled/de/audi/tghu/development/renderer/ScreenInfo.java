/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.renderer;

import de.audi.tghu.development.model.ScreenModel;

public class ScreenInfo {
    public int screenId;
    public String screenName;
    public int currentRow;
    public int windowStart;
    public int cursorPos;
    public ScreenModel model;

    public ScreenInfo(ScreenModel screenModel) {
        this.screenId = screenModel.getScreenId();
        this.model = screenModel;
        this.screenName = screenModel.getScreenName();
        this.currentRow = 0;
        this.windowStart = 0;
        this.cursorPos = 0;
    }

    public boolean equals(Object object) {
        if (this == null && object == null) {
            return true;
        }
        if (object == null) {
            return false;
        }
        if (!(object instanceof ScreenInfo)) {
            return false;
        }
        return this.screenId == ((ScreenInfo)object).screenId;
    }
}

