/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  de.audi.atip.hmi.event.KeyEvent
 *  de.audi.atip.hmi.event.WheelButtonEvent
 *  de.audi.tghu.hmi.view.HMITerminalImpl
 *  de.audi.tghu.hmi.view.HWGManager
 *  de.audi.tghu.hmi.view.InitializationContext
 *  de.audi.tghu.hmi.view.RedrawContext
 *  de.audi.tghu.hmi.view.adapter.AbstractWidgetAdapter
 *  fi.hybrid.a2dg.Graphics2D
 *  fi.hybrid.a2dg.Paint
 *  fi.hybrid.a2dg.Path
 *  fi.hybrid.a2dg.SolidPaint
 *  fi.hybrid.hwg.Bitmap
 *  fi.hybrid.hwg.Composite
 *  fi.hybrid.hwg.Drawable
 *  fi.hybrid.hwg.Graphics
 *  fi.hybrid.hwg.TextElement
 *  org.dsi.ifc.base.DSIFatalException
 *  org.dsi.ifc.base.DSINonFatalException
 */
package de.audi.tghu.development.renderer;

import de.audi.atip.hmi.event.KeyEvent;
import de.audi.atip.hmi.event.WheelButtonEvent;
import de.audi.parser.ESDFileParser;
import de.audi.tghu.development.EngineeringException;
import de.audi.tghu.development.app.DevelopmentApp;
import de.audi.tghu.development.app.Logger;
import de.audi.tghu.development.config.AbstractRendererConfig;
import de.audi.tghu.development.config.RendererConfigFactory;
import de.audi.tghu.development.eis.EngineeringInfoService;
import de.audi.tghu.development.manager.LogMan;
import de.audi.tghu.development.manager.ResMan;
import de.audi.tghu.development.model.JobModel;
import de.audi.tghu.development.model.LabelModel;
import de.audi.tghu.development.model.ReturnModel;
import de.audi.tghu.development.model.RunnerModel;
import de.audi.tghu.development.model.ScreenElementModel;
import de.audi.tghu.development.model.ScreenModel;
import de.audi.tghu.development.renderer.ConsoleBuffer;
import de.audi.tghu.development.renderer.ConsoleScreen;
import de.audi.tghu.development.renderer.ConsoleScreenForVAS;
import de.audi.tghu.development.renderer.JobScreen;
import de.audi.tghu.development.renderer.LinkListener;
import de.audi.tghu.development.renderer.MenuElements;
import de.audi.tghu.development.renderer.RepaintThread;
import de.audi.tghu.development.renderer.ScreenInfo;
import de.audi.tghu.development.renderer.ScriptOutputReader;
import de.audi.tghu.development.renderer.SlideShowScreen;
import de.audi.tghu.development.renderer.StartUpScreen;
import de.audi.tghu.development.widget.CursorWidget;
import de.audi.tghu.development.widget.LabelWidget;
import de.audi.tghu.development.widget.PathWidget;
import de.audi.tghu.development.widget.Widget;
import de.audi.tghu.hmi.view.HMITerminalImpl;
import de.audi.tghu.hmi.view.HWGManager;
import de.audi.tghu.hmi.view.InitializationContext;
import de.audi.tghu.hmi.view.RedrawContext;
import de.audi.tghu.hmi.view.adapter.AbstractWidgetAdapter;
import fi.hybrid.a2dg.Graphics2D;
import fi.hybrid.a2dg.Paint;
import fi.hybrid.a2dg.Path;
import fi.hybrid.a2dg.SolidPaint;
import fi.hybrid.hwg.Bitmap;
import fi.hybrid.hwg.Composite;
import fi.hybrid.hwg.Drawable;
import fi.hybrid.hwg.Graphics;
import fi.hybrid.hwg.TextElement;
import java.io.File;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.io.Writer;
import java.util.ArrayList;
import java.util.Hashtable;
import java.util.Map;
import java.util.Observable;
import java.util.Stack;
import java.util.StringTokenizer;
import org.dsi.ifc.base.DSIFatalException;
import org.dsi.ifc.base.DSINonFatalException;

public class ScreenRenderer
extends AbstractWidgetAdapter {
    public static final String VERSION = "1.0t";
    private static Map screenRenderers = new Hashtable();
    public ResMan resMan;
    public AbstractRendererConfig rendererConfig;
    public Stack screenStack = new Stack();
    public ScreenInfo currentScreen;
    public Object screenInfoMutex = new Object();
    public static final int DRAW_ALL_COMPOSITES = -1;
    private static final int SCREENID_ERROR = -1;
    private static final int LAYER_DEPTH = 10;
    private static final int MENU_LAYER = 0;
    private static final int TITLE_LAYER = 1;
    private static final int BORDER_LAYER = 2;
    private static final int ROW_LAYER_START = 4;
    private static final int FULL_SCREEN_LAYER = 16;
    private static final int NUM_LAYERS = 17;
    private static final int ARROW_UP = 0;
    private static final int ARROW_DOWN = 1;
    private Widget[] widgets;
    private CursorWidget cursor;
    private PathWidget[] arrows;
    private Path pathFrame;
    private Bitmap bmpMenu;
    private TextElement teTitle;
    private int[] rowLayerIdTable;
    private int numRows;
    private LinkListener scriptListener = new LinkListener(){

        public void linkClicked(int n) {
            if (ScreenRenderer.this.scriptOutputReader == null || !ScreenRenderer.this.scriptOutputReader.isAlive()) {
                ScreenRenderer.this.enterConsoleScreen(true);
            } else {
                ScreenRenderer.this.enterConsoleScreen(false);
            }
        }
    };
    private LinkListener linkListener = new LinkListener(){

        public void linkClicked(int n) {
            ScreenRenderer.this.enterScreen(n);
        }
    };
    ScriptOutputReader scriptOutputReader;
    private ConsoleScreen consoleScreen;
    private ConsoleScreenForVAS consoleScreenForVAS;
    private JobScreen jobScreen;
    private SlideShowScreen slideShowScreen;
    private DevelopmentApp devApp;
    private RepaintThread repaintThread;
    private ArrayList listWidgets;
    private int layerId;

    protected ScreenRenderer(int n) {
        this.composites = new Composite[17];
        this.compositeDirty = new boolean[17];
        LogMan.log("new ScreenRenderer() called");
    }

    private RepaintThread createRepaintThread(int n) {
        RepaintThread repaintThread = RepaintThread.getInstance(n, this);
        if (repaintThread != null) {
            LogMan.log(10, "Repaint thread created.");
            if (!repaintThread.isAlive()) {
                try {
                    repaintThread.start();
                    LogMan.log(10, "Repaint thread started.");
                }
                catch (IllegalThreadStateException illegalThreadStateException) {
                    LogMan.log(10, "Repaint thread could not be started!");
                }
            } else {
                LogMan.log(10, "Thread already started!");
            }
        } else {
            LogMan.log(10, "Repaint thread could not be created!");
        }
        return repaintThread;
    }

    private void checkRepaintThread(int n) {
        if (this.repaintThread == null) {
            this.repaintThread = this.createRepaintThread(n);
        } else if (!this.repaintThread.isAlive()) {
            LogMan.log("RepaintThread not alive - create new one.");
            this.repaintThread = this.createRepaintThread(n);
        } else {
            LogMan.log("RepaintThread is still alive - do nothing.");
        }
    }

    public static synchronized ScreenRenderer getInstance(int n, String string) {
        ScreenRenderer screenRenderer = null;
        try {
            LogMan.log(1, "ScreenRenderer.getInstance(" + n + ") from " + string);
            Object v = screenRenderers.get(new Integer(n));
            if (v == null) {
                LogMan.log(1, "ScreenRenderer.getInstance(" + n + "): create new instance");
                screenRenderer = new ScreenRenderer(n);
                screenRenderer.resMan = ResMan.getInstance(n);
                screenRenderer.rendererConfig = RendererConfigFactory.getRendererConfig(screenRenderer.getTerminal());
                screenRenderers.put(new Integer(n), screenRenderer);
            } else {
                LogMan.log(1, "ScreenRenderer.getInstance(" + n + "): use existing instance");
                screenRenderer = (ScreenRenderer)((Object)v);
            }
            screenRenderer.checkRepaintThread(n);
            LogMan.log(1, "ScreenRenderer.getInstance(" + n + ") from " + string + " finished");
        }
        catch (Exception exception) {
            LogMan.log("getInstance()", exception);
        }
        return screenRenderer;
    }

    public void setDevApp(DevelopmentApp developmentApp) {
        LogMan.log(7, "ScreenRenderer.setDevApp()");
        this.devApp = developmentApp;
    }

    public void sendRepaintEvent(int n) {
        LogMan.log(7, "ScreenRenderer.sendRepaintEvent()");
        this.invalidateLayer(n);
        if (this.devApp != null) {
            this.devApp.sendRepaintEvent();
        } else {
            LogMan.log(7, "ScreenRenderer.sendRepaintEvent(): no DevApp set");
        }
    }

    public void initialize() {
        this.setBounds(0, 0, this.rendererConfig.getLAYERDEF_MENU_WIDTH(), this.rendererConfig.getLAYERDEF_MENU_HEIGHT());
        this.layerId = 2;
        ScreenModel screenModel = new ScreenModel(9988);
        this.currentScreen = new ScreenInfo(screenModel);
        this.rowLayerIdTable = new int[this.rendererConfig.getROWS_PER_SCREEN()];
        this.numRows = 0;
        this.screenStack.clear();
        if (this.cursor == null) {
            this.cursor = new CursorWidget(this);
        }
        if (this.pathFrame == null) {
            this.pathFrame = MenuElements.createMenuFrame(this.resMan, this.rendererConfig);
        }
        if (this.arrows == null) {
            this.arrows = MenuElements.createPageArrows(this.resMan, this.rendererConfig, this);
        }
        if (this.composites[16] == null) {
            this.composites[16] = MenuElements.createFullScreen(this.resMan, this.rendererConfig);
        }
        LogMan.log(5, "ScreenRenderer.initialize(): renderer initialized");
    }

    private void cleanUpResources() {
        if (this.scriptOutputReader != null) {
            this.scriptOutputReader.unregisterObserver(this.consoleScreen);
        }
        if (this.widgets != null) {
            for (int i = 0; i < this.widgets.length; ++i) {
                if (this.widgets[i] == null) continue;
                LogMan.log(5, "Cleanup Widget -> " + this.widgets[i].getClass().getName());
                this.widgets[i].cleanup(this.resMan.getTerminal());
                this.widgets[i] = null;
            }
        } else {
            LogMan.log(5, "There are NO widgets in the list ...");
        }
    }

    private void changeScreen(ScreenModel screenModel) {
        int n;
        this.cleanUpResources();
        LogMan.log(5, "--- change screen ---");
        int n2 = screenModel.getNumElements();
        this.listWidgets = new ArrayList(n2);
        this.layerId = 4;
        if (!this.currentScreen.screenName.equalsIgnoreCase("main")) {
            ReturnModel returnModel = new ReturnModel("...");
            this.listWidgets.add(((ScreenElementModel)returnModel).getWidget(this));
            ++this.layerId;
        }
        for (n = 0; n < n2; ++n) {
            ScreenElementModel screenElementModel = screenModel.getElement(n);
            Widget widget = screenElementModel.getWidget(this);
            if (widget != null) {
                this.listWidgets.add(widget);
            }
            ++this.layerId;
        }
        this.numRows = this.listWidgets.size();
        this.widgets = this.listWidgets.toArray(new Widget[this.numRows]);
        if (this.currentScreen != null) {
            if (this.cursor != null) {
                this.cursor.setPosition(this.currentScreen.cursorPos);
            } else {
                LogMan.log("ScreenRenderer.changeScreen(): cursor not initialized (=null).");
            }
            this.highlightRow(this.currentScreen.currentRow);
            for (n = 0; n < this.rendererConfig.getROWS_PER_SCREEN(); ++n) {
                int n3 = this.currentScreen.windowStart + n;
                if (n3 > this.numRows - 1) {
                    n3 = -1;
                }
                this.rowLayerIdTable[n] = n3;
                this.setCompositeDirty(4 + n);
            }
            this.updateScrollArrows();
        } else {
            LogMan.log("ScreenRenderer.changeScreen(): currentScreen not initialized (=null).");
        }
        this.setCompositeDirty(1);
        this.setCompositeDirty(2);
    }

    /*
     * WARNING - Removed try catching itself - possible behaviour change.
     */
    public void enterConsoleScreen(boolean bl) {
        try {
            this.consoleScreen = ConsoleScreen.getInstance(this);
            this.consoleScreen.initialize();
            Object object = this.screenInfoMutex;
            synchronized (object) {
                this.changeScreen(this.consoleScreen.getScreenModel());
            }
            object = null;
            object = System.getProperty("os.name").indexOf("QNX") != -1 ? new File("/scripts/script.fifo") : new File("C:/output.txt");
            if (this.scriptOutputReader == null || !this.scriptOutputReader.isAlive()) {
                this.scriptOutputReader = ScriptOutputReader.getInstance((File)object, this.consoleScreen.getBufferSize());
                this.scriptOutputReader.registerObserver(this.consoleScreen);
                this.scriptOutputReader.start();
            } else {
                this.scriptOutputReader.registerObserver(this.consoleScreen);
            }
        }
        catch (Exception exception) {
            this.enterErrorScreen("ScreenRenderer().enterConsoleScreen()", exception);
        }
    }

    /*
     * WARNING - Removed try catching itself - possible behaviour change.
     */
    public ConsoleBuffer enterTesterTaskScreen() throws DSINonFatalException, DSIFatalException {
        this.consoleScreenForVAS = ConsoleScreenForVAS.getInstance(this);
        this.consoleScreenForVAS.initialize();
        Object object = this.screenInfoMutex;
        synchronized (object) {
            ScreenModel screenModel = this.consoleScreenForVAS.getScreenModel();
            try {
                screenModel.enter();
            }
            catch (EngineeringException engineeringException) {
                this.enterErrorScreen("on enterScreen", engineeringException);
            }
            this.changeScreen(screenModel);
        }
        object = new ConsoleBuffer(40);
        ((Observable)object).addObserver(this.consoleScreenForVAS);
        return object;
    }

    /*
     * WARNING - Removed try catching itself - possible behaviour change.
     */
    public void enterJobScreen(JobModel jobModel, RunnerModel[] runnerModelArray) throws DSINonFatalException, DSIFatalException {
        this.jobScreen = JobScreen.getInstance(this);
        this.jobScreen.initialize(jobModel, runnerModelArray);
        Object object = this.screenInfoMutex;
        synchronized (object) {
            ScreenModel screenModel = this.jobScreen.getScreenModel();
            try {
                screenModel.enter();
            }
            catch (EngineeringException engineeringException) {
                this.enterErrorScreen("on enterScreen", engineeringException);
            }
            this.changeScreen(this.jobScreen.getScreenModel());
        }
    }

    /*
     * WARNING - Removed try catching itself - possible behaviour change.
     */
    public void enterStartUpScreen() {
        StartUpScreen startUpScreen = new StartUpScreen(this);
        startUpScreen.initialize();
        Object object = this.screenInfoMutex;
        synchronized (object) {
            ScreenModel screenModel = startUpScreen.getScreenModel();
            try {
                screenModel.enter();
            }
            catch (Exception exception) {
                this.enterErrorScreen("Error on ScreenRenderer.enterStartUpScreen()", exception);
            }
            this.changeScreen(screenModel);
        }
        this.sendRepaintEvent(-1);
        LogMan.log("ScreenRenderer.enterStartUpScreen()");
    }

    /*
     * WARNING - Removed try catching itself - possible behaviour change.
     */
    public void enterSlideShowScreen() {
        try {
            this.slideShowScreen = SlideShowScreen.getInstance(this);
            this.slideShowScreen.initialize();
            Object object = this.screenInfoMutex;
            synchronized (object) {
                ScreenModel screenModel = this.slideShowScreen.getScreenModel();
                try {
                    screenModel.enter();
                }
                catch (EngineeringException engineeringException) {
                    this.enterErrorScreen("on enterScreen", engineeringException);
                }
                this.changeScreen(screenModel);
            }
        }
        catch (Exception exception) {
            this.enterErrorScreen("Error on ScreenRenderer.enterSlideShowScreen()", exception);
        }
    }

    /*
     * WARNING - Removed try catching itself - possible behaviour change.
     */
    public void enterErrorScreen(String string, Throwable throwable) {
        int n;
        Object object;
        Object object2;
        String string2 = null;
        if (throwable != null) {
            throwable.printStackTrace();
            object2 = new StringWriter();
            object = new PrintWriter((Writer)object2);
            throwable.printStackTrace((PrintWriter)object);
            ((PrintWriter)object).close();
            string2 = ((StringWriter)object2).toString();
        }
        object2 = new ScreenModel(-1);
        ((ScreenModel)object2).setScreenName("Error in ScreenRenderer");
        object = new LabelModel();
        if (string != null) {
            ((ScreenElementModel)object).setLabel(string);
        } else {
            ((ScreenElementModel)object).setLabel("no message available");
        }
        ((ScreenModel)object2).addElement((ScreenElementModel)object);
        if (string2 != null) {
            StringTokenizer stringTokenizer = new StringTokenizer(string2, "\n");
            for (int i = 0; stringTokenizer.hasMoreTokens() && i < 11; ++i) {
                LabelModel labelModel = new LabelModel();
                String string3 = stringTokenizer.nextToken().trim();
                labelModel.setLabel(string3);
                ((ScreenModel)object2).addElement(labelModel);
            }
        }
        int n2 = n = this.screenStack.size() == 0 ? 0 : ((ScreenInfo)this.screenStack.peek()).screenId;
        if (n == ((ScreenModel)object2).getScreenId()) {
            return;
        }
        if (this.currentScreen != null) {
            try {
                this.currentScreen.model.leave();
            }
            catch (Exception exception) {
                LogMan.log("cannot show error screen", exception);
                LogMan.log("error to be shown: " + string, throwable);
            }
            this.screenStack.push(this.currentScreen);
        }
        Object object3 = this.screenInfoMutex;
        synchronized (object3) {
            try {
                ((ScreenModel)object2).enter();
            }
            catch (Exception exception) {
                LogMan.log("cannot show error screen", exception);
                LogMan.log("error to be shown: " + string, throwable);
            }
            this.currentScreen = new ScreenInfo((ScreenModel)object2);
            this.changeScreen((ScreenModel)object2);
        }
    }

    /*
     * WARNING - Removed try catching itself - possible behaviour change.
     */
    public void enterScreen(int n) {
        block9: {
            try {
                ScreenModel screenModel = ESDFileParser.getInstance().getScreen(n);
                if (screenModel == null) break block9;
                if (this.currentScreen != null) {
                    this.currentScreen.model.leave();
                    if (this.currentScreen.screenId != 42987) {
                        this.screenStack.push(this.currentScreen);
                    }
                }
                Object object = this.screenInfoMutex;
                synchronized (object) {
                    try {
                        screenModel.enter();
                        this.currentScreen = new ScreenInfo(screenModel);
                        this.changeScreen(screenModel);
                    }
                    catch (EngineeringException engineeringException) {
                        this.enterErrorScreen("on enterScreen", engineeringException);
                    }
                }
            }
            catch (Exception exception) {
                this.enterErrorScreen("Error on ScreenRenderer.enterScreen()", exception);
            }
        }
    }

    /*
     * WARNING - Removed try catching itself - possible behaviour change.
     */
    public void leaveScreen() throws DSINonFatalException, DSIFatalException {
        block8: {
            try {
                if (this.screenStack.isEmpty()) {
                    return;
                }
                ScreenInfo screenInfo = (ScreenInfo)this.screenStack.pop();
                ScreenModel screenModel = ESDFileParser.getInstance().getScreen(screenInfo.screenId);
                if (screenModel == null) break block8;
                Object object = this.screenInfoMutex;
                synchronized (object) {
                    this.currentScreen.model.leave();
                    this.currentScreen = screenInfo;
                    try {
                        screenModel.enter();
                        this.changeScreen(screenModel);
                    }
                    catch (EngineeringException engineeringException) {
                        this.enterErrorScreen("on leaveScreen", engineeringException);
                    }
                }
            }
            catch (Exception exception) {
                this.enterErrorScreen("Error on ScreenRenderer().leaveScreen()", exception);
            }
        }
    }

    protected String getScreenPath() {
        String string = "";
        Object[] objectArray = this.screenStack.toArray();
        for (int i = 1; i < objectArray.length; ++i) {
            string = string + ((ScreenInfo)objectArray[i]).screenName + "/";
        }
        string = string + this.currentScreen.screenName;
        return string;
    }

    private void highlightRow(int n) {
        int n2;
        if (this.widgets.length == 0 || n >= this.widgets.length) {
            return;
        }
        for (n2 = 0; n2 < n; ++n2) {
            this.widgets[n2].setSelected(false);
        }
        this.widgets[n].setSelected(true);
        for (n2 = n + 1; n2 < this.widgets.length; ++n2) {
            this.widgets[n2].setSelected(false);
        }
    }

    public void moveCursor(int n) {
        int n2;
        int n3 = this.currentScreen.currentRow;
        int n4 = this.currentScreen.windowStart;
        this.currentScreen.currentRow += n;
        int n5 = this.currentScreen.currentRow >= 0 ? (this.currentScreen.currentRow < this.numRows ? this.currentScreen.currentRow : this.numRows - 1) : (this.currentScreen.currentRow = 0);
        if (this.currentScreen.currentRow == n3) {
            return;
        }
        int n6 = this.currentScreen.currentRow / this.rendererConfig.getROWS_PER_SCREEN() * this.rendererConfig.getROWS_PER_SCREEN();
        if (n6 != this.currentScreen.windowStart) {
            for (n2 = 0; n2 < this.rendererConfig.getROWS_PER_SCREEN(); ++n2) {
                int n7 = n6 + n2;
                if (n7 > this.numRows - 1) {
                    n7 = -1;
                }
                this.rowLayerIdTable[n2] = n7;
                this.setCompositeDirty(4 + n2);
            }
        }
        n2 = this.currentScreen.currentRow - n6;
        this.currentScreen.windowStart = n6;
        this.currentScreen.cursorPos = n2;
        this.cursor.setPosition(this.currentScreen.cursorPos);
        this.highlightRow(this.currentScreen.currentRow);
        this.setCompositeDirty(4 + n3 - n4);
        this.setCompositeDirty(4 + this.currentScreen.currentRow - this.currentScreen.windowStart);
        this.setCompositeDirty(2);
        this.updateScrollArrows();
    }

    private void updateScrollArrows() {
        this.arrows[0].setVisible(this.currentScreen.windowStart > 0);
        this.arrows[1].setVisible(this.currentScreen.windowStart + this.rendererConfig.getROWS_PER_SCREEN() < this.numRows);
    }

    protected void renderMenu(HWGManager hWGManager, Graphics graphics, Graphics2D graphics2D) {
        if (this.bmpMenu == null) {
            if (this.rendererConfig == null) {
                LogMan.log("Error on ScreenRenderer.renderMenu() -> no rendererConfig set");
            }
            if (this.resMan != null) {
                ScreenModel screenModel;
                if (this.currentScreen == null) {
                    screenModel = ESDFileParser.getInstance().getScreen(ESDFileParser.SCREENID_MAIN);
                    if (screenModel == null) {
                        this.enterErrorScreen("Error on ScreenRenderer.renderMenu() -> no main screen found", null);
                    }
                    this.currentScreen = new ScreenInfo(screenModel);
                }
                this.bmpMenu = this.resMan.newBitmap(this.currentScreen.screenId, this.rendererConfig.getLAYERDEF_MENU_WIDTH(), this.rendererConfig.getLAYERDEF_MENU_HEIGHT(), true);
                screenModel = this.rendererConfig.getPntLightGreen();
                SolidPaint solidPaint = this.rendererConfig.getPntDarkGray();
                graphics2D.bindTarget(this.bmpMenu);
                graphics2D.clear(this.rendererConfig.getCOLOR_TRANSPARENT());
                graphics2D.getTransform().setIdentity();
                graphics2D.setStroke((Paint)screenModel);
                graphics2D.setFill((Paint)solidPaint);
                graphics2D.setStrokeWidth(2.0f);
                graphics2D.fillAndStrokePath(this.pathFrame);
                graphics2D.releaseTarget();
            } else {
                LogMan.log("Resource Manager not available!");
            }
            this.composites[0].clearDrawables();
            this.composites[0].addDrawable((Drawable)this.bmpMenu, 10);
        }
    }

    protected void renderTitle(HWGManager hWGManager, Graphics graphics, Graphics2D graphics2D) {
        String string = "EM";
        String string2 = this.getScreenPath();
        if (string2.length() > 0) {
            string = "<" + string + " " + VERSION + ">  /" + string2;
        }
        if (this.teTitle == null) {
            this.teTitle = MenuElements.createMenuTitle(this.resMan, this.rendererConfig, this.currentScreen.screenId, string);
            this.composites[1].clearDrawables();
            this.composites[1].addDrawable((Drawable)this.teTitle, 9);
        } else {
            this.teTitle.setString(string);
        }
    }

    private void startParser() {
        final ScreenRenderer screenRenderer = this;
        final ESDFileParser eSDFileParser = ESDFileParser.getInstance();
        Thread thread = new Thread(new Runnable(){

            public void run() {
                try {
                    LogMan.log(10, "DevelopmentApp.hmiActivated(): Parser thread started!");
                    eSDFileParser.init(screenRenderer);
                }
                catch (Exception exception) {
                    exception.printStackTrace();
                }
            }
        });
        thread.setPriority(5);
        LogMan.log(10, "DevelopmentApp.hmiActivated(): Parser thread created!");
        thread.start();
    }

    public void connected(InitializationContext initializationContext) {
        super.connected(initializationContext);
        this.initialize();
        LogMan.log("ScreenRenderer.connected(): enter startup screen");
        this.startParser();
        this.enterStartUpScreen();
    }

    public void disconnecting() {
        LogMan.log("ScreenRenderer.disconnecting(): leave Green Engineering Menu");
        SlideShowScreen.getInstance(this).destroyBitmaps();
        if (this.widgets != null) {
            for (int i = 0; i < this.widgets.length; ++i) {
                if (this.widgets[i] == null) continue;
                this.widgets[i].cleanup(this.resMan.getTerminal());
                this.widgets[i] = null;
            }
        } else {
            LogMan.log(5, "There are NO widgets in the list ... (on disconnecting)");
        }
        try {
            MenuElements.cleanup(this.resMan);
            this.freeComposites();
            this.resMan.finalCleanUp();
            this.arrows = null;
            this.cursor = null;
            this.pathFrame = null;
            this.bmpMenu = null;
            this.teTitle = null;
        }
        catch (Exception exception) {
            exception.printStackTrace();
        }
        EngineeringInfoService.getInstance().clearAllListeners();
        this.repaintThread.killRepaintThread();
    }

    protected void createFatalError(RedrawContext redrawContext, Throwable throwable) {
        throwable.printStackTrace();
        Logger.getInstance().hmi.log(1000, throwable.toString());
        try {
            Graphics graphics = this.resMan.getHWG();
            Graphics2D graphics2D = this.resMan.getG2D();
            graphics.clear(this.rendererConfig.getCOLOR_DARK_GRAY());
            Composite composite = graphics.createComposite(this.rendererConfig.getLAYERDEF_MENU_WIDTH(), this.rendererConfig.getLAYERDEF_MENU_HEIGHT());
            String string = "Fatal error in renderer: " + throwable.toString();
            String string2 = throwable.getMessage();
            int n = this.rendererConfig.getLAYERDEF_CONTENT_LEFT();
            int n2 = this.rendererConfig.getLAYERDEF_CONTENT_TOP();
            LabelWidget labelWidget = new LabelWidget(null, this);
            labelWidget.setLabel(string);
            labelWidget.setPos(n, n2);
            labelWidget.render(graphics, graphics2D, composite);
            n2 += this.rendererConfig.getLINE_HEIGHT();
            if (string2 != null) {
                StringTokenizer stringTokenizer = new StringTokenizer(string2, "\n");
                while (stringTokenizer.hasMoreTokens()) {
                    labelWidget = new LabelWidget(null, this);
                    labelWidget.setLabel(stringTokenizer.nextToken());
                    labelWidget.setPos(n, n2);
                    labelWidget.render(graphics, graphics2D, composite);
                    n2 += this.rendererConfig.getLINE_HEIGHT();
                }
            } else {
                labelWidget = new LabelWidget(null, this);
                labelWidget.setLabel("no message");
                labelWidget.setPos(n, n2);
                labelWidget.render(graphics, graphics2D, composite);
            }
            HWGManager.getInstance((HMITerminalImpl)this.resMan.getTerminal()).addDrawable((Drawable)composite, 0);
        }
        catch (Throwable throwable2) {
            LogMan.log("Failed to create fatal error screen!");
        }
    }

    public void enterFullScreen(boolean bl) {
        if (bl) {
            this.composites[16].setOpacity(1.0f);
        } else {
            this.composites[16].setOpacity(0.0f);
        }
    }

    public Composite getFullScreen() {
        return this.composites[16];
    }

    /*
     * WARNING - Removed try catching itself - possible behaviour change.
     */
    public void render(RedrawContext redrawContext) {
        LogMan.log(7, "ScreenRenderer.render()");
        Graphics graphics = this.resMan.getHWG();
        HWGManager hWGManager = this.resMan.getHWGManager();
        Graphics2D graphics2D = this.resMan.getG2D();
        try {
            if (this.composites[0] == null) {
                this.composites[0] = hWGManager.getComposite(this.rendererConfig.getLAYERDEF_MENU_WIDTH(), this.rendererConfig.getLAYERDEF_MENU_HEIGHT());
                this.composites[0].setPosition(this.rendererConfig.getLAYERDEF_MENU_LEFT(), this.rendererConfig.getLAYERDEF_MENU_TOP());
                hWGManager.addDrawable((Drawable)this.composites[0], 10);
                this.setCompositeDirty(0);
            }
            if (this.composites[1] == null) {
                this.composites[1] = hWGManager.getComposite(this.rendererConfig.getLAYERDEF_TITLE_WIDTH(), this.rendererConfig.getLAYERDEF_TITLE_HEIGHT());
                this.composites[1].setPosition(this.rendererConfig.getLAYERDEF_TITLE_LEFT(), this.rendererConfig.getLAYERDEF_TITLE_TOP());
                hWGManager.addDrawable((Drawable)this.composites[1], 10);
                this.setCompositeDirty(1);
            }
            if (this.composites[2] == null) {
                this.composites[2] = hWGManager.getComposite(this.rendererConfig.getLAYERDEF_BORDER_WIDTH(), this.rendererConfig.getLAYERDEF_BORDER_HEIGHT());
                this.composites[2].setPosition(this.rendererConfig.getLAYERDEF_BORDER_LEFT(), this.rendererConfig.getLAYERDEF_BORDER_TOP());
                hWGManager.addDrawable((Drawable)this.composites[2], 10);
                this.setCompositeDirty(2);
            }
            if (this.composites[16] == null) {
                this.composites[16] = this.getFullScreen();
            }
            Object object = this.screenInfoMutex;
            synchronized (object) {
                if (this.compositeDirty[0]) {
                    this.renderMenu(hWGManager, graphics, graphics2D);
                }
                if (this.compositeDirty[1]) {
                    this.renderTitle(hWGManager, graphics, graphics2D);
                }
                if (this.compositeDirty[2]) {
                    this.composites[2].clearDrawables();
                    this.cursor.render(graphics, graphics2D, this.composites[2]);
                    this.arrows[0].render(graphics, graphics2D, this.composites[2]);
                    this.arrows[1].render(graphics, graphics2D, this.composites[2]);
                }
                int n = 0;
                int n2 = this.rendererConfig.getROWS_PER_SCREEN();
                for (int i = 0; i < n2; ++i) {
                    int n3 = 4 + i;
                    int n4 = this.rowLayerIdTable[i];
                    if (this.composites[n3] == null) {
                        int n5 = this.rendererConfig.getLAYERDEF_CONTENT_WIDTH();
                        int n6 = this.rendererConfig.getLINE_HEIGHT();
                        int n7 = this.rendererConfig.getLAYERDEF_CONTENT_LEFT();
                        int n8 = this.rendererConfig.getLAYERDEF_CONTENT_TOP() + n;
                        this.composites[n3] = hWGManager.getComposite(n5, n6);
                        this.composites[n3].setPosition(n7, n8);
                        this.resMan.getHWGManager().addDrawable((Drawable)this.composites[n3], 9);
                    }
                    if (this.compositeDirty[n3]) {
                        this.composites[n3].clearDrawables();
                        if (n4 != -1) {
                            Widget widget = this.widgets[n4];
                            widget.setPos(0, 0);
                            widget.render(graphics, graphics2D, this.composites[n3]);
                        }
                    }
                    n += this.rendererConfig.getLINE_HEIGHT();
                }
            }
        }
        catch (Throwable throwable) {
            this.createFatalError(redrawContext, throwable);
        }
    }

    public void keyPressed(KeyEvent keyEvent) {
        LogMan.log("KeyEvent in ScreenRenderer: " + keyEvent.getKeyCode());
        LogMan.log("CurrentScreen: " + this.currentScreen.screenId);
        boolean bl = false;
        try {
            Object object;
            if (this.currentScreen.model.getScreenId() == 8999 && keyEvent.getKeyCode() != 15) {
                object = SlideShowScreen.getInstance(this);
                ((SlideShowScreen)object).keyPressed(keyEvent);
                bl = true;
            }
            if (this.widgets != null && this.currentScreen.currentRow < this.widgets.length && ((Widget)(object = this.widgets[this.currentScreen.currentRow])).processKey(keyEvent.getKeyCode())) {
                this.setCompositeDirty(4 + this.currentScreen.currentRow - this.currentScreen.windowStart);
                bl = true;
            }
            if (!bl) {
                switch (keyEvent.getKeyCode()) {
                    case 15: {
                        this.setCompositeDirty(2);
                        this.leaveScreen();
                    }
                }
                bl = true;
            }
        }
        catch (Throwable throwable) {
            this.enterErrorScreen("on keyEvent", throwable);
            return;
        }
        if (bl) {
            keyEvent.consume();
        }
    }

    public void keyReleased(KeyEvent keyEvent) {
    }

    public void keyTurned(WheelButtonEvent wheelButtonEvent) {
        Widget widget;
        if (this.currentScreen.model.getScreenId() == 8999 && wheelButtonEvent.getKeyCode() != 15) {
            SlideShowScreen slideShowScreen = SlideShowScreen.getInstance(this);
            slideShowScreen.keyTurned(wheelButtonEvent);
            return;
        }
        int n = wheelButtonEvent.getDirection();
        int n2 = wheelButtonEvent.getClickCount();
        if (n == 1) {
            n2 = -n2;
        }
        boolean bl = false;
        if (this.widgets != null && this.currentScreen.currentRow <= this.widgets.length && (widget = this.widgets[this.currentScreen.currentRow]).processEncoder(wheelButtonEvent.getKeyCode(), n2)) {
            this.setCompositeDirty(4 + this.currentScreen.currentRow - this.currentScreen.windowStart);
            bl = true;
        }
        if (!bl) {
            switch (wheelButtonEvent.getKeyCode()) {
                case 17: {
                    this.moveCursor(-n2);
                    bl = true;
                }
            }
        }
        if (bl) {
            wheelButtonEvent.consume();
        }
    }

    public void invalidateLayer(int n) {
        if (n == -1) {
            this.setCompositesDirty(true);
        } else {
            this.setCompositeDirty(n);
        }
    }

    public HMITerminalImpl getTerminal() {
        return this.resMan.getTerminal();
    }

    public LinkListener getScriptListener() {
        return this.scriptListener;
    }

    public LinkListener getLinkListener() {
        return this.linkListener;
    }

    public ArrayList getWidgetList() {
        return this.listWidgets;
    }

    public int getLayerId() {
        return this.layerId;
    }

    public void setLayerId(int n) {
        this.layerId = n;
    }

    public int getCurrentScreenId() {
        return this.currentScreen.screenId;
    }
}

