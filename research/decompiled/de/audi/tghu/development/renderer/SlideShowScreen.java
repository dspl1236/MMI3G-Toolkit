/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  de.audi.atip.hmi.event.KeyEvent
 *  de.audi.atip.hmi.event.WheelButtonEvent
 *  fi.hybrid.hwg.Bitmap
 *  fi.hybrid.hwg.Composite
 *  fi.hybrid.hwg.Drawable
 *  fi.hybrid.hwg.Graphics
 *  org.dsi.ifc.base.DSIFatalException
 *  org.dsi.ifc.base.DSINonFatalException
 */
package de.audi.tghu.development.renderer;

import de.audi.atip.hmi.event.KeyEvent;
import de.audi.atip.hmi.event.WheelButtonEvent;
import de.audi.tghu.development.EngineeringException;
import de.audi.tghu.development.manager.LogMan;
import de.audi.tghu.development.model.ScreenModel;
import de.audi.tghu.development.renderer.ScreenInfo;
import de.audi.tghu.development.renderer.ScreenRenderer;
import de.audi.tghu.development.util.DirectoryScanner;
import fi.hybrid.hwg.Bitmap;
import fi.hybrid.hwg.Composite;
import fi.hybrid.hwg.Drawable;
import fi.hybrid.hwg.Graphics;
import java.io.File;
import java.io.IOException;
import org.dsi.ifc.base.DSIFatalException;
import org.dsi.ifc.base.DSINonFatalException;

public class SlideShowScreen {
    private Composite fullScreen;
    private Graphics hwg;
    private ScreenRenderer screenRenderer;
    private ScreenModel screenModel;
    private static SlideShowScreen slideShowScreen = null;
    private static final String SRC_PATH = "sdcard*/slideshow/*.png";
    private static final String SRC_BACK = "_background.png";
    private static File backgroundImageFile = null;
    private int fCurrentIdx = 0;
    private String[] fImages = null;
    int numberOfImages;
    private Bitmap hgBitmap = null;
    private Bitmap bgBitmap = null;

    public static SlideShowScreen getInstance(ScreenRenderer screenRenderer) {
        if (slideShowScreen == null) {
            slideShowScreen = new SlideShowScreen(screenRenderer);
        }
        return slideShowScreen;
    }

    private SlideShowScreen(ScreenRenderer screenRenderer) {
        this.screenRenderer = screenRenderer;
        this.hwg = screenRenderer.resMan.getHWG();
    }

    /*
     * WARNING - Removed try catching itself - possible behaviour change.
     */
    public void initialize() throws DSINonFatalException, DSIFatalException {
        int n;
        this.screenModel = new SlideShowScreenModel(8999);
        this.fullScreen = this.screenRenderer.getFullScreen();
        this.screenModel.setScreenName("SlideShow");
        if (this.hgBitmap != null || this.hgBitmap != null) {
            LogMan.log("SlideShowScreen: hgBitmap and/or bgBitmap not null on entry!");
            this.hgBitmap = null;
            this.bgBitmap = null;
        }
        int n2 = n = this.screenRenderer.screenStack.size() == 0 ? 0 : ((ScreenInfo)this.screenRenderer.screenStack.peek()).screenId;
        if (n == this.screenModel.getScreenId()) {
            return;
        }
        if (this.screenRenderer.currentScreen != null) {
            this.screenRenderer.currentScreen.model.leave();
            this.screenRenderer.screenStack.push(this.screenRenderer.currentScreen);
        }
        Object object = this.screenRenderer.screenInfoMutex;
        synchronized (object) {
            this.screenRenderer.currentScreen = new ScreenInfo(this.screenModel);
        }
    }

    public ScreenModel getScreenModel() {
        return this.screenModel;
    }

    public void keyPressed(KeyEvent keyEvent) {
        LogMan.log("KeyEvent in SlideShowScreen: " + keyEvent.getKeyCode());
        switch (keyEvent.getKeyCode()) {
            case 9: 
            case 10: {
                LogMan.log("showPreviousImage()");
                this.showPreviousImage();
                break;
            }
            case 11: 
            case 12: {
                LogMan.log("showNextImage()");
                this.showNextImage();
            }
        }
    }

    public void keyTurned(WheelButtonEvent wheelButtonEvent) {
        String string = wheelButtonEvent.getDirection() == 0 ? "right" : "left";
        LogMan.log("KeyTurned in SlideShowScreen: " + wheelButtonEvent.getClickCount() + " times " + string);
        if (wheelButtonEvent.getDirection() == 0) {
            this.showNextImage();
        } else {
            this.showPreviousImage();
        }
    }

    /*
     * WARNING - Removed try catching itself - possible behaviour change.
     */
    private void showImage(int n) throws IOException {
        SlideShowScreen slideShowScreen = this;
        synchronized (slideShowScreen) {
            if (backgroundImageFile != null) {
                LogMan.log("found background image: " + backgroundImageFile.getAbsolutePath());
                if (backgroundImageFile.exists() && backgroundImageFile.canRead()) {
                    this.bgBitmap = this.createBitmap(backgroundImageFile.getAbsolutePath(), this.bgBitmap, 1);
                } else {
                    LogMan.log("cannot load background image: " + backgroundImageFile.getAbsolutePath());
                }
            }
            if (this.fImages == null || n < 0 || n >= this.fImages.length) {
                return;
            }
            File file = new File(this.fImages[n]);
            if (file.exists() && file.canRead()) {
                LogMan.log("draw slide show image: " + file.getAbsolutePath());
                this.hgBitmap = this.createBitmap(file.getAbsolutePath(), this.hgBitmap, 0);
            } else {
                LogMan.log("cannot draw slide show image: " + file.getAbsolutePath());
            }
        }
    }

    /*
     * WARNING - Removed try catching itself - possible behaviour change.
     */
    private Bitmap createBitmap(String string, Bitmap bitmap, int n) throws IOException {
        this.destroyBitmap(bitmap);
        SlideShowScreen slideShowScreen = this;
        synchronized (slideShowScreen) {
            bitmap = this.hwg.createBitmap(1, string, false);
            LogMan.log("SlideShow.createBitmap(" + System.identityHashCode(bitmap) + ") and add drawable in z-level " + n);
            bitmap.setPosition(0, 0);
            this.screenRenderer.getFullScreen().addDrawable((Drawable)bitmap, n);
            return bitmap;
        }
    }

    public void destroyBitmaps() {
        LogMan.log("SlideShow.destroyBitmaps();");
        this.destroyBitmap(this.bgBitmap);
        this.destroyBitmap(this.hgBitmap);
    }

    /*
     * WARNING - Removed try catching itself - possible behaviour change.
     */
    public void destroyBitmap(Bitmap bitmap) {
        SlideShowScreen slideShowScreen = this;
        synchronized (slideShowScreen) {
            if (bitmap != null) {
                LogMan.log("SlideShow.destroyBitmap(" + System.identityHashCode(bitmap) + ") -> remove from drawable and destroy");
                this.fullScreen.removeDrawable((Drawable)bitmap);
                this.hwg.destroyDrawable((Drawable)bitmap);
                bitmap = null;
            }
        }
    }

    private void scanSDCard() throws IOException {
        this.fImages = null;
        String[] stringArray = this.getSliedshowImages(SRC_PATH);
        if (stringArray == null) {
            this.screenRenderer.enterErrorScreen("abort - no SDCard found", null);
            return;
        }
        this.fImages = stringArray;
        this.numberOfImages = this.fImages.length;
        this.fCurrentIdx = 0;
    }

    private String[] getSliedshowImages(String string) {
        Object object;
        DirectoryScanner directoryScanner = new DirectoryScanner();
        directoryScanner.setBasedir("/mnt");
        directoryScanner.setCaseSensitive(true);
        directoryScanner.setIncludes(new String[]{string});
        directoryScanner.setExcludes(new String[]{"**/_background.png"});
        directoryScanner.scan();
        String[] stringArray = directoryScanner.getIncludedFiles();
        String[] stringArray2 = new String[stringArray.length];
        for (int i = 0; i < stringArray.length; ++i) {
            object = stringArray[i];
            File file = new File(directoryScanner.getBasedir(), (String)object);
            stringArray2[i] = file.getAbsolutePath();
        }
        backgroundImageFile = null;
        if (stringArray.length > 0) {
            String string2 = stringArray2[0].substring(0, stringArray2[0].lastIndexOf(47) + 1);
            object = new File(string2 + SRC_BACK);
            if (((File)object).exists() && ((File)object).canRead()) {
                LogMan.log("Background image found: " + string2);
                backgroundImageFile = object;
            } else {
                LogMan.log("no background image found: " + string2);
            }
            return stringArray2;
        }
        return null;
    }

    /*
     * WARNING - Removed try catching itself - possible behaviour change.
     */
    private void showNextImage() {
        SlideShowScreen slideShowScreen = this;
        synchronized (slideShowScreen) {
            ++this.fCurrentIdx;
            this.fCurrentIdx %= this.numberOfImages;
            try {
                this.showImage(this.fCurrentIdx);
            }
            catch (IOException iOException) {
                this.screenRenderer.enterErrorScreen("cannot load image for showNextImage() -> index = " + this.fCurrentIdx, iOException);
            }
        }
    }

    /*
     * WARNING - Removed try catching itself - possible behaviour change.
     */
    private void showPreviousImage() {
        SlideShowScreen slideShowScreen = this;
        synchronized (slideShowScreen) {
            --this.fCurrentIdx;
            if (this.fCurrentIdx < 0) {
                this.fCurrentIdx = this.numberOfImages - 1;
            }
            try {
                this.showImage(this.fCurrentIdx);
            }
            catch (IOException iOException) {
                this.screenRenderer.enterErrorScreen("cannot load image for showPreviousImage", iOException);
            }
        }
    }

    class SlideShowScreenModel
    extends ScreenModel {
        public SlideShowScreenModel(int n) {
            super(n);
        }

        public void enter() throws EngineeringException, DSINonFatalException, DSIFatalException {
            super.enter();
            LogMan.log("Enter SlideShowScreen");
            try {
                SlideShowScreen.this.fCurrentIdx = 0;
                SlideShowScreen.this.scanSDCard();
                SlideShowScreen.this.showImage(SlideShowScreen.this.fCurrentIdx);
                SlideShowScreen.this.screenRenderer.enterFullScreen(true);
            }
            catch (Throwable throwable) {
                SlideShowScreen.this.screenRenderer.enterErrorScreen("Enter SlideShow faild!", throwable);
            }
        }

        public void leave() throws DSINonFatalException, DSIFatalException {
            SlideShowScreen.this.destroyBitmap(SlideShowScreen.this.bgBitmap);
            SlideShowScreen.this.destroyBitmap(SlideShowScreen.this.hgBitmap);
            SlideShowScreen.this.screenRenderer.enterFullScreen(false);
            LogMan.log("Leave SlideShowScreen");
            super.leave();
        }
    }
}

