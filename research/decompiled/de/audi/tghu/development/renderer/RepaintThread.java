/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.renderer;

import de.audi.tghu.development.manager.LogMan;
import de.audi.tghu.development.renderer.ScreenRenderer;
import java.util.Hashtable;
import java.util.Map;

public final class RepaintThread
extends Thread {
    private static Map repaintThreads = new Hashtable();
    private volatile boolean running = true;
    private Integer terminalID;
    private ScreenRenderer renderer;

    private RepaintThread(ScreenRenderer screenRenderer) {
        this.renderer = screenRenderer;
    }

    public static RepaintThread getInstance(int n, ScreenRenderer screenRenderer) {
        RepaintThread repaintThread;
        Object v = repaintThreads.get(new Integer(n));
        if (v == null) {
            repaintThread = new RepaintThread(screenRenderer);
            repaintThread.terminalID = new Integer(n);
            repaintThreads.put(repaintThread.terminalID, repaintThread);
        } else {
            repaintThread = (RepaintThread)v;
        }
        return repaintThread;
    }

    public void run() {
        LogMan.log(10, "RepaintThread.run(): thread started.");
        do {
            this.renderer.sendRepaintEvent(-1);
            try {
                Thread.sleep(1000L);
            }
            catch (InterruptedException interruptedException) {
                Thread.interrupted();
                interruptedException.printStackTrace();
            }
        } while (this.running);
        LogMan.log(10, "RepaintThread.run(): thread stopped.");
    }

    public void killRepaintThread() {
        this.running = false;
        repaintThreads.remove(this.terminalID);
    }
}

