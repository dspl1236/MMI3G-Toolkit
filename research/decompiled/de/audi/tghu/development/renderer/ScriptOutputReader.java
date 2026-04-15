/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.renderer;

import de.audi.tghu.development.manager.LogMan;
import de.audi.tghu.development.renderer.ConsoleBuffer;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.Observer;

public class ScriptOutputReader
extends Thread {
    private File file = null;
    private ConsoleBuffer consoleBuffer = null;
    private static boolean scriptRunning = false;
    private static ScriptOutputReader scriptOutputReader = null;

    public static ScriptOutputReader getInstance() {
        return scriptOutputReader;
    }

    public static ScriptOutputReader getInstance(File file, int n) {
        if (scriptOutputReader == null) {
            scriptOutputReader = new ScriptOutputReader(file, n);
        }
        return scriptOutputReader;
    }

    public boolean isScriptRunning() {
        return scriptRunning;
    }

    private ScriptOutputReader(File file, int n) {
        this.file = file;
        this.consoleBuffer = new ConsoleBuffer(n);
    }

    public void registerObserver(Observer observer) {
        this.consoleBuffer.addObserver(observer);
    }

    public void unregisterObserver(Observer observer) {
        this.consoleBuffer.deleteObserver(observer);
    }

    public void run() {
        try {
            String string;
            scriptRunning = true;
            try {
                Thread.sleep(2000L);
            }
            catch (InterruptedException interruptedException) {
                interruptedException.printStackTrace();
            }
            LogMan.log("2 secs waited ... (for fifo creation)");
            InputStreamReader inputStreamReader = new InputStreamReader(new FileInputStream(this.file));
            BufferedReader bufferedReader = new BufferedReader(inputStreamReader);
            while ((string = bufferedReader.readLine()) != null) {
                this.consoleBuffer.addLine(string);
                this.consoleBuffer.notifyObservers(this.consoleBuffer.removeLine());
                try {
                    ScriptOutputReader.sleep(20L);
                }
                catch (InterruptedException interruptedException) {
                    interruptedException.printStackTrace();
                }
            }
            bufferedReader.close();
            inputStreamReader.close();
            scriptOutputReader = null;
            scriptRunning = false;
        }
        catch (IOException iOException) {
            iOException.printStackTrace();
        }
    }
}

