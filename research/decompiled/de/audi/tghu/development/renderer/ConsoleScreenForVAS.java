/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  org.dsi.ifc.base.DSIFatalException
 *  org.dsi.ifc.base.DSINonFatalException
 */
package de.audi.tghu.development.renderer;

import de.audi.tghu.development.model.LabelModel;
import de.audi.tghu.development.model.ScreenModel;
import de.audi.tghu.development.renderer.ConsoleBuffer;
import de.audi.tghu.development.renderer.ScreenInfo;
import de.audi.tghu.development.renderer.ScreenRenderer;
import java.util.Observable;
import java.util.Observer;
import org.dsi.ifc.base.DSIFatalException;
import org.dsi.ifc.base.DSINonFatalException;

public class ConsoleScreenForVAS
implements Observer {
    private final int BUFFERSIZE = 96;
    private ScreenRenderer screenRenderer = null;
    private ScreenModel consoleScreen = null;
    private LabelModel[] lines = null;
    private static ConsoleScreenForVAS console = null;

    public static ConsoleScreenForVAS getInstance(ScreenRenderer screenRenderer) {
        if (console == null) {
            console = new ConsoleScreenForVAS(screenRenderer);
        }
        return console;
    }

    private ConsoleScreenForVAS(ScreenRenderer screenRenderer) {
        this.screenRenderer = screenRenderer;
    }

    /*
     * WARNING - Removed try catching itself - possible behaviour change.
     */
    public void initialize() throws DSINonFatalException, DSIFatalException {
        int n;
        this.consoleScreen = new ScreenModel(4242);
        this.consoleScreen.setScreenName("VASConsole");
        int n2 = n = this.screenRenderer.screenStack.size() == 0 ? 0 : ((ScreenInfo)this.screenRenderer.screenStack.peek()).screenId;
        if (n == this.consoleScreen.getScreenId()) {
            return;
        }
        if (this.screenRenderer.currentScreen != null) {
            this.screenRenderer.currentScreen.model.leave();
            this.screenRenderer.currentScreen = (ScreenInfo)this.screenRenderer.screenStack.pop();
            this.screenRenderer.screenStack.push(this.screenRenderer.currentScreen);
        }
        Object object = this.screenRenderer.screenInfoMutex;
        synchronized (object) {
            this.screenRenderer.currentScreen = new ScreenInfo(this.consoleScreen);
        }
        this.lines = new LabelModel[96];
        for (int i = 0; i < 96; ++i) {
            this.lines[i] = new LabelModel();
            this.lines[i].setLabel("");
            this.consoleScreen.addElement(this.lines[i]);
        }
    }

    public ScreenModel getScreenModel() {
        return this.consoleScreen;
    }

    public void update(Observable observable, Object object) {
        if (observable instanceof ConsoleBuffer && object instanceof String[]) {
            String[] stringArray = (String[])object;
            for (int i = 0; i < stringArray.length; ++i) {
                this.lines[i].setLabel(stringArray[i]);
            }
        }
    }
}

