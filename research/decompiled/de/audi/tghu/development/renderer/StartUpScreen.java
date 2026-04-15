/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  fi.hybrid.hwg.Drawable
 *  fi.hybrid.hwg.Font
 *  fi.hybrid.hwg.TextElement
 *  org.dsi.ifc.base.DSIFatalException
 *  org.dsi.ifc.base.DSINonFatalException
 */
package de.audi.tghu.development.renderer;

import de.audi.tghu.development.EngineeringException;
import de.audi.tghu.development.manager.LogMan;
import de.audi.tghu.development.model.ScreenModel;
import de.audi.tghu.development.renderer.ScreenInfo;
import de.audi.tghu.development.renderer.ScreenRenderer;
import fi.hybrid.hwg.Drawable;
import fi.hybrid.hwg.Font;
import fi.hybrid.hwg.TextElement;
import org.dsi.ifc.base.DSIFatalException;
import org.dsi.ifc.base.DSINonFatalException;

public class StartUpScreen {
    public static final int screenId = 42987;
    private ScreenRenderer screenRenderer = null;
    private ScreenModel screenModel = null;
    private TextElement text = null;

    public StartUpScreen(ScreenRenderer screenRenderer) {
        this.screenRenderer = screenRenderer;
        this.screenModel = new StartUpScreenModel(42987);
        this.screenModel.setScreenName("StartUpScreen");
    }

    public void initialize() {
        this.screenRenderer.currentScreen = new ScreenInfo(this.screenModel);
    }

    public ScreenModel getScreenModel() {
        return this.screenModel;
    }

    class StartUpScreenModel
    extends ScreenModel {
        public StartUpScreenModel(int n) {
            super(n);
        }

        public void enter() throws EngineeringException, DSINonFatalException, DSIFatalException {
            super.enter();
            LogMan.log("Enter StartUpScreen");
            try {
                Font font = ((StartUpScreen)StartUpScreen.this).screenRenderer.rendererConfig.getFont();
                StartUpScreen.this.text = ((StartUpScreen)StartUpScreen.this).screenRenderer.resMan.newTextElement(42987, font, "Green Menu loading...", false);
                StartUpScreen.this.text.setColor(((StartUpScreen)StartUpScreen.this).screenRenderer.rendererConfig.getCOLOR_LIGHT_GREEN());
                StartUpScreen.this.text.setPosition(40, 40);
                StartUpScreen.this.screenRenderer.getFullScreen().addDrawable((Drawable)StartUpScreen.this.text, 1);
                StartUpScreen.this.screenRenderer.enterFullScreen(true);
            }
            catch (Throwable throwable) {
                StartUpScreen.this.screenRenderer.enterErrorScreen("Enter StartUpScreen faild!", throwable);
            }
        }

        public void leave() throws DSINonFatalException, DSIFatalException {
            StartUpScreen.this.screenRenderer.getFullScreen().removeDrawable((Drawable)StartUpScreen.this.text);
            StartUpScreen.this.text = null;
            StartUpScreen.this.screenRenderer.enterFullScreen(false);
            LogMan.log("Leave StartUpScreen");
            super.leave();
        }
    }
}

