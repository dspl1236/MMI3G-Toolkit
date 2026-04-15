/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  de.audi.atip.base.Framework
 *  de.audi.atip.hmi.view.AbstractScreenFactory
 *  de.audi.atip.hmi.view.HMIView
 *  de.audi.atip.hmi.view.Screen
 *  de.audi.tghu.fwhmi.HMITerminalRegistry
 *  de.audi.tghu.hmi.view.ATIPFont
 *  de.audi.tghu.hmi.view.AbstractWidget
 *  de.audi.tghu.hmi.view.FontLoader
 *  de.audi.tghu.hmi.view.HMITerminalImpl
 *  de.audi.tghu.hmi.view.LabelWidget
 *  de.audi.tghu.hmi.view.adapter.ScreenWidgetAdapter
 *  fi.hybrid.a2dg.SolidPaint
 */
package de.audi.tghu.development.app;

import de.audi.atip.base.Framework;
import de.audi.atip.hmi.view.AbstractScreenFactory;
import de.audi.atip.hmi.view.HMIView;
import de.audi.atip.hmi.view.Screen;
import de.audi.tghu.development.config.AbstractRendererConfig;
import de.audi.tghu.development.config.RendererConfigFactory;
import de.audi.tghu.development.manager.LogMan;
import de.audi.tghu.development.renderer.ScreenRenderer;
import de.audi.tghu.fwhmi.HMITerminalRegistry;
import de.audi.tghu.hmi.view.ATIPFont;
import de.audi.tghu.hmi.view.AbstractWidget;
import de.audi.tghu.hmi.view.FontLoader;
import de.audi.tghu.hmi.view.HMITerminalImpl;
import de.audi.tghu.hmi.view.LabelWidget;
import de.audi.tghu.hmi.view.adapter.ScreenWidgetAdapter;
import fi.hybrid.a2dg.SolidPaint;
import java.io.InputStream;

public class DevelopmentScreenFactory
extends AbstractScreenFactory {
    private static final SolidPaint paint1 = new SolidPaint(-16777216);
    private static final SolidPaint paint2 = new SolidPaint(-65536);
    private static final SolidPaint paint3 = new SolidPaint(-8355712);
    private static final SolidPaint paint4 = new SolidPaint(-1);
    private static final SolidPaint[][] paintArray1 = new SolidPaint[][]{{paint1, paint2, paint3, paint4}};
    private static final String[] textsDeutsch = new String[0];
    private static final String[] textsEnglisch = new String[0];
    private String[] currentTexts = textsDeutsch;
    private static final String[] images = new String[0];
    private static final int SIZE = 2;
    private static final int MODULE_ID = 16;
    private static DevelopmentScreenFactory screenFactory;

    private DevelopmentScreenFactory() {
        super(16, 2);
    }

    public static DevelopmentScreenFactory getInstance() {
        if (screenFactory == null) {
            screenFactory = new DevelopmentScreenFactory();
        }
        return screenFactory;
    }

    protected Screen createDefaultScreen(int n) {
        ScreenWidgetAdapter screenWidgetAdapter = new ScreenWidgetAdapter(0);
        screenWidgetAdapter.setFonts(new ATIPFont[]{((HMITerminalImpl)HMITerminalRegistry.getTerminal((int)0)).getFontLoader().getATIPFont(FontLoader.STANDARD_FONT_PLAIN, 0, 28)});
        screenWidgetAdapter.setPaints((SolidPaint[][])new SolidPaint[][]{{new SolidPaint(-16777216), new SolidPaint(-7829368)}});
        LabelWidget labelWidget = new LabelWidget(0, 150, 800, 30);
        labelWidget.setAlignment(2, 5);
        labelWidget.setText("There's no screen with id: " + n);
        screenWidgetAdapter.add((AbstractWidget)labelWidget);
        return screenWidgetAdapter;
    }

    public String getText(int n) {
        return this.currentTexts[n - 167000];
    }

    public void setLanguage(int n) {
        if (n == 0) {
            this.currentTexts = textsDeutsch;
            return;
        }
        if (n == 1) {
            this.currentTexts = textsEnglisch;
            return;
        }
    }

    public String getName() {
        return "HMIDevelopment";
    }

    public InputStream getImageInputStream(int n) {
        try {
            return ((Object)((Object)this)).getClass().getClassLoader().getResource("images/" + images[n - 168000]).openStream();
        }
        catch (Exception exception) {
            Framework.getLogChannel((String)"ScreenFactory").log(10000, "Error getting image input stream for image id " + n + ": " + exception.getMessage(), (Throwable)exception);
            return null;
        }
    }

    protected Screen createScreen(int n, int n2) {
        switch (n) {
            case 160001: {
                return this.mainScreen(n2);
            }
        }
        return this.createDefaultScreen(n, n2);
    }

    private Screen mainScreen(int n) {
        LogMan.log("DevelopmentScreenFactory.mainScreen()");
        HMITerminalImpl hMITerminalImpl = (HMITerminalImpl)HMITerminalRegistry.getTerminal((int)n);
        AbstractRendererConfig abstractRendererConfig = RendererConfigFactory.getRendererConfig(hMITerminalImpl);
        FontLoader fontLoader = hMITerminalImpl.getFontLoader();
        ATIPFont aTIPFont = fontLoader.getATIPFont(FontLoader.STANDARD_FONT_PLAIN, 0, abstractRendererConfig.getFONT_SIZE());
        ScreenWidgetAdapter screenWidgetAdapter = new ScreenWidgetAdapter(160001);
        screenWidgetAdapter.setFonts(new ATIPFont[]{aTIPFont});
        screenWidgetAdapter.setPaints(paintArray1);
        ScreenRenderer screenRenderer = ScreenRenderer.getInstance(n, "DevelopmentScreenFactory.mainScreen()");
        screenRenderer.setModelID(161000);
        screenWidgetAdapter.add((AbstractWidget)screenRenderer);
        screenWidgetAdapter.setViews(new int[]{161000}, (HMIView[][])new HMIView[][]{{screenRenderer}});
        return screenWidgetAdapter;
    }

    protected Screen createDefaultScreen(int n, int n2) {
        return this.createDefaultScreen(n);
    }
}

