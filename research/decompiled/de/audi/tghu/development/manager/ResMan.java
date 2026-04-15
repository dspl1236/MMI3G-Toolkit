/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  de.audi.tghu.fwhmi.HMITerminalRegistry
 *  de.audi.tghu.hmi.view.HMITerminalImpl
 *  de.audi.tghu.hmi.view.HWGManager
 *  fi.hybrid.a2dg.Disposable
 *  fi.hybrid.a2dg.Graphics2D
 *  fi.hybrid.a2dg.Path
 *  fi.hybrid.a2dg.SolidPaint
 *  fi.hybrid.hwg.Bitmap
 *  fi.hybrid.hwg.Composite
 *  fi.hybrid.hwg.Drawable
 *  fi.hybrid.hwg.Font
 *  fi.hybrid.hwg.Graphics
 *  fi.hybrid.hwg.TextElement
 */
package de.audi.tghu.development.manager;

import de.audi.tghu.development.manager.LogMan;
import de.audi.tghu.fwhmi.HMITerminalRegistry;
import de.audi.tghu.hmi.view.HMITerminalImpl;
import de.audi.tghu.hmi.view.HWGManager;
import fi.hybrid.a2dg.Disposable;
import fi.hybrid.a2dg.Graphics2D;
import fi.hybrid.a2dg.Path;
import fi.hybrid.a2dg.SolidPaint;
import fi.hybrid.hwg.Bitmap;
import fi.hybrid.hwg.Composite;
import fi.hybrid.hwg.Drawable;
import fi.hybrid.hwg.Font;
import fi.hybrid.hwg.Graphics;
import fi.hybrid.hwg.TextElement;
import java.util.ArrayList;
import java.util.Hashtable;
import java.util.Iterator;
import java.util.Map;

public class ResMan {
    private static Map resourceManagers = new Hashtable();
    private int screenId = -999;
    private ArrayList composites = new ArrayList();
    private ArrayList temporaryHWG = new ArrayList();
    private ArrayList temporaryA2DG = new ArrayList();
    private ArrayList longLifeHWG = new ArrayList();
    private ArrayList longLifeA2DG = new ArrayList();
    private HWGManager hwgManager;
    private HMITerminalImpl terminal;
    private Graphics hwg;
    private Graphics2D g2d;
    private boolean isRunning = false;

    public static ResMan getInstance(int n) {
        ResMan resMan;
        Object v = resourceManagers.get(new Integer(n));
        if (v == null) {
            resMan = new ResMan();
            resMan.initialize(n);
            resourceManagers.put(new Integer(n), resMan);
        } else {
            resMan = (ResMan)v;
        }
        return resMan;
    }

    private ResMan() {
    }

    public int getSizeHWG() {
        return this.temporaryHWG.size() + this.longLifeHWG.size();
    }

    public int getSizeA2DG() {
        return this.temporaryA2DG.size() + this.longLifeA2DG.size();
    }

    public int getSizeComposites() {
        return this.composites.size();
    }

    private void initialize(int n) {
        this.terminal = (HMITerminalImpl)HMITerminalRegistry.getTerminal((int)n);
        this.hwgManager = this.terminal.getHWGManager();
        this.hwg = this.hwgManager.getGraphicsHWG();
        this.g2d = Graphics2D.getInstance();
    }

    public Graphics getHWG() {
        return this.hwg;
    }

    public HWGManager getHWGManager() {
        return this.hwgManager;
    }

    public Graphics2D getG2D() {
        return this.g2d;
    }

    public HMITerminalImpl getTerminal() {
        return this.terminal;
    }

    private void gc(int n) {
        if (this.screenId != n) {
            LogMan.log(0, "gc call with screenId = " + n + " (old screenId = " + this.screenId + ")");
            this.cleanUp();
            this.screenId = n;
        }
    }

    private void addHWG(Drawable drawable, boolean bl) {
        if (!bl) {
            LogMan.log(0, "create   -> temporary native resource  (HWG): " + drawable.getClass() + " -> " + drawable + " for screen " + this.screenId);
            this.temporaryHWG.add(drawable);
        } else {
            LogMan.log(0, "create   -> long life native resource  (HWG): " + drawable.getClass() + " -> " + drawable + " for screen " + this.screenId);
            this.longLifeHWG.add(drawable);
        }
    }

    private void addA2DG(Disposable disposable, boolean bl) {
        if (!bl) {
            LogMan.log(0, "create   -> temporary native resource (A2DG): " + disposable.getClass() + " -> " + disposable + " for screen " + this.screenId);
            this.temporaryA2DG.add(disposable);
        } else {
            LogMan.log(0, "create   -> long life native resource (A2DG): " + disposable.getClass() + " -> " + disposable + " for screen " + this.screenId);
            this.longLifeA2DG.add(disposable);
        }
    }

    public TextElement newTextElement(int n, Font font, String string, boolean bl) {
        if (!bl) {
            this.gc(n);
        }
        TextElement textElement = this.hwg.createTextElement(font, string, 0);
        this.addHWG((Drawable)textElement, bl);
        return textElement;
    }

    public SolidPaint newSolidPaint(int n, int n2, boolean bl) {
        if (!bl) {
            this.gc(n);
        }
        SolidPaint solidPaint = new SolidPaint(n2);
        this.addA2DG((Disposable)solidPaint, bl);
        return solidPaint;
    }

    public Bitmap newBitmap(int n, int n2, int n3, boolean bl) {
        if (!bl) {
            this.gc(n);
        }
        Bitmap bitmap = this.hwg.createBitmap(1, n2, n3);
        this.addHWG((Drawable)bitmap, bl);
        return bitmap;
    }

    public Path newPath(int n, int n2, int n3, boolean bl) {
        if (!bl) {
            this.gc(n);
        }
        Path path = new Path(n2, n3);
        this.addA2DG((Disposable)path, bl);
        return path;
    }

    public Composite newComposite(int n, int n2, int n3) {
        this.gc(n);
        Composite composite = this.hwg.createComposite(n2, n3);
        LogMan.log(0, "create   -> long life native resource  (HWG): " + composite.getClass() + " -> " + composite + " for screen " + n);
        this.composites.add(composite);
        return composite;
    }

    private void cleanUp() {
        if (!this.isRunning) {
            Composite composite;
            Iterator iterator;
            this.isRunning = true;
            LogMan.log(0, "");
            LogMan.log(0, "CleanUp starts!");
            LogMan.log(0, "composites     : " + this.composites.size());
            LogMan.log(0, "temporaryHWG   : " + this.temporaryHWG.size());
            LogMan.log(0, "temporaryA2DG  : " + this.temporaryA2DG.size());
            if (this.composites != null) {
                iterator = this.composites.iterator();
                while (iterator.hasNext()) {
                    composite = (Composite)iterator.next();
                    LogMan.log(0, "destroy  -> temporary native resource  (HWG): " + composite.getClass() + " -> " + composite + " from screen " + this.screenId);
                    composite.clearDrawables();
                    this.hwg.destroyDrawable((Drawable)composite);
                }
                this.composites.clear();
            }
            if (this.temporaryHWG != null) {
                iterator = this.temporaryHWG.iterator();
                while (iterator.hasNext()) {
                    composite = (Drawable)iterator.next();
                    LogMan.log(0, "destroy  -> temporary native resource  (HWG): " + composite.getClass() + " -> " + composite + " from screen " + this.screenId);
                    this.hwg.destroyDrawable((Drawable)composite);
                }
                this.temporaryHWG.clear();
            }
            if (this.temporaryA2DG != null) {
                iterator = this.temporaryA2DG.iterator();
                while (iterator.hasNext()) {
                    composite = (Disposable)iterator.next();
                    LogMan.log(0, "dispose  -> temporary native resource (A2DG): " + composite.getClass() + " -> " + composite + " from screen " + this.screenId);
                    composite.dispose();
                }
                this.temporaryA2DG.clear();
            }
            LogMan.log(0, "");
            this.isRunning = false;
        }
    }

    public void finalCleanUp() {
        Drawable drawable;
        Iterator iterator;
        this.cleanUp();
        LogMan.log(0, "");
        LogMan.log(0, "finalCleanUp starts!");
        LogMan.log(0, "longLifeHWG   : " + this.longLifeHWG.size());
        LogMan.log(0, "longLifeA2DG  : " + this.longLifeA2DG.size());
        if (this.longLifeHWG != null) {
            iterator = this.longLifeHWG.iterator();
            while (iterator.hasNext()) {
                drawable = (Drawable)iterator.next();
                LogMan.log(0, "destroy  -> long life native resource  (HWG): " + drawable.getClass() + " -> " + drawable + " from screen " + this.screenId);
                this.hwg.destroyDrawable(drawable);
            }
            this.longLifeHWG.clear();
        }
        if (this.longLifeA2DG != null) {
            iterator = this.longLifeA2DG.iterator();
            while (iterator.hasNext()) {
                drawable = (Disposable)iterator.next();
                LogMan.log(0, "dispose  -> long life native resource (A2DG): " + drawable.getClass() + " -> " + drawable + " from screen " + this.screenId);
                drawable.dispose();
            }
            this.longLifeA2DG.clear();
        }
    }
}

