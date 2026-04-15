/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  de.audi.tghu.hmi.view.HWGManager
 *  fi.hybrid.a2dg.Graphics2D
 *  fi.hybrid.a2dg.Path
 *  fi.hybrid.a2dg.SolidPaint
 *  fi.hybrid.hwg.Bitmap
 *  fi.hybrid.hwg.Composite
 *  fi.hybrid.hwg.Drawable
 *  fi.hybrid.hwg.TextElement
 */
package de.audi.tghu.development.renderer;

import de.audi.tghu.development.config.AbstractRendererConfig;
import de.audi.tghu.development.manager.ResMan;
import de.audi.tghu.development.renderer.ScreenRenderer;
import de.audi.tghu.development.widget.PathWidget;
import de.audi.tghu.hmi.view.HWGManager;
import fi.hybrid.a2dg.Graphics2D;
import fi.hybrid.a2dg.Path;
import fi.hybrid.a2dg.SolidPaint;
import fi.hybrid.hwg.Bitmap;
import fi.hybrid.hwg.Composite;
import fi.hybrid.hwg.Drawable;
import fi.hybrid.hwg.TextElement;

public class MenuElements {
    private static Path pageUp;
    private static Path pageDown;
    private static Bitmap texture;
    private static Composite fullScreen;

    public static Path createMenuFrame(ResMan resMan, AbstractRendererConfig abstractRendererConfig) {
        Path path = resMan.newPath(0, 10, 10, true);
        path.appendRoundedRectangle((float)abstractRendererConfig.getMENU_FRAME_LEFT(), (float)abstractRendererConfig.getMENU_FRAME_TOP(), (float)abstractRendererConfig.getMENU_FRAME_WIDTH(), (float)abstractRendererConfig.getMENU_FRAME_HEIGHT(), 10.0f, 10.0f);
        path.appendLine((float)abstractRendererConfig.getMENU_FRAME_LEFT(), (float)abstractRendererConfig.getMENU_FRAME_TITLE(), (float)(abstractRendererConfig.getMENU_FRAME_LEFT() + abstractRendererConfig.getMENU_FRAME_WIDTH()), (float)abstractRendererConfig.getMENU_FRAME_TITLE());
        return path;
    }

    private static Path createPageUpIcon(ResMan resMan, AbstractRendererConfig abstractRendererConfig) {
        pageUp = resMan.newPath(0, 6, 6, true);
        pageUp.appendPolygon(new float[]{0.0f, abstractRendererConfig.getSCROLL_ARROW_HEIGHT(), abstractRendererConfig.getSCROLL_ARROW_WIDTH() / 2, 0.0f, abstractRendererConfig.getSCROLL_ARROW_WIDTH(), abstractRendererConfig.getSCROLL_ARROW_HEIGHT()}, true);
        return pageUp;
    }

    private static Path createPageDownIcon(ResMan resMan, AbstractRendererConfig abstractRendererConfig) {
        pageDown = resMan.newPath(0, 6, 6, true);
        pageDown.appendPolygon(new float[]{0.0f, 0.0f, abstractRendererConfig.getSCROLL_ARROW_WIDTH() / 2, abstractRendererConfig.getSCROLL_ARROW_HEIGHT(), abstractRendererConfig.getSCROLL_ARROW_WIDTH(), 0.0f}, true);
        return pageDown;
    }

    public static PathWidget[] createPageArrows(ResMan resMan, AbstractRendererConfig abstractRendererConfig, ScreenRenderer screenRenderer) {
        pageUp = MenuElements.createPageUpIcon(resMan, abstractRendererConfig);
        pageDown = MenuElements.createPageDownIcon(resMan, abstractRendererConfig);
        SolidPaint solidPaint = abstractRendererConfig.getPntLightGreen();
        PathWidget[] pathWidgetArray = new PathWidget[]{new PathWidget(pageUp, solidPaint, solidPaint, 1, screenRenderer), new PathWidget(pageDown, solidPaint, solidPaint, 1, screenRenderer)};
        pathWidgetArray[0].setPos(abstractRendererConfig.getSCROLL_ARROW_X(), abstractRendererConfig.getSCROLL_ARROW_UP_Y());
        pathWidgetArray[1].setPos(abstractRendererConfig.getSCROLL_ARROW_X(), abstractRendererConfig.getSCROLL_ARROW_DOWN_Y());
        return pathWidgetArray;
    }

    public static Composite createFullScreen(ResMan resMan, AbstractRendererConfig abstractRendererConfig) {
        HWGManager hWGManager = resMan.getHWGManager();
        Graphics2D graphics2D = resMan.getG2D();
        int n = abstractRendererConfig.getLAYERDEF_MENU_WIDTH();
        int n2 = abstractRendererConfig.getLAYERDEF_MENU_HEIGHT();
        int n3 = abstractRendererConfig.getLAYERDEF_MENU_LEFT();
        int n4 = abstractRendererConfig.getLAYERDEF_MENU_TOP();
        fullScreen = hWGManager.getComposite(n, n2);
        texture = hWGManager.getTexture(1, n, n2);
        graphics2D.bindTarget(texture);
        graphics2D.clear(abstractRendererConfig.getCOLOR_BLACK());
        graphics2D.releaseTarget();
        texture.setPosition(0, 0);
        fullScreen.addDrawable((Drawable)texture, 1);
        fullScreen.setPosition(n3, n4);
        fullScreen.setOpacity(0.0f);
        hWGManager.addDrawable((Drawable)fullScreen, 0);
        return fullScreen;
    }

    private static void cleanupFullScreen(ResMan resMan) {
        if (fullScreen != null && texture != null) {
            fullScreen.removeDrawable((Drawable)texture);
            resMan.getHWG().destroyDrawable((Drawable)texture);
            texture = null;
        }
    }

    public static void cleanup(ResMan resMan) {
        MenuElements.cleanupFullScreen(resMan);
    }

    public static TextElement createMenuTitle(ResMan resMan, AbstractRendererConfig abstractRendererConfig, int n, String string) {
        TextElement textElement = resMan.newTextElement(n, abstractRendererConfig.getFont(), string, true);
        textElement.setColor(abstractRendererConfig.getCOLOR_LIGHT_GREEN());
        textElement.setPosition(0, 23);
        return textElement;
    }
}

