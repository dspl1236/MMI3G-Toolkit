/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.manager;

import de.audi.commons.tools.LineWriter;
import de.audi.tghu.development.manager.LogListener;
import de.audi.tghu.development.renderer.JobScreen;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.io.Writer;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;

public class LogMan {
    public static boolean logging = true;
    public static final int resDebugLevel = 0;
    public static final int devAppDebugLevel = 1;
    public static final int eisDebugLevel = 2;
    public static final int modelDebugLevel = 3;
    public static final int parserDebugLevel = 4;
    public static final int renderDebugLevel = 5;
    public static final int simulationDebugLevel = 6;
    public static final int repaintDebugLevel = 7;
    public static final int exportDebugLevel = 8;
    public static final int keylistenerDebugLevel = 9;
    public static final int threadDebugLevel = 10;
    public static final int persistenceAccessDebugLevel = 11;
    public static final boolean[] logLevelState = new boolean[]{false, false, false, false, false, false, false, false, false, false, false, true};
    public static List listenerList = new ArrayList(10);
    public static final int CONSOLE_LOGGER_MODE = 0;
    public static final int FILE_LOGGER_MODE = 1;
    public static final int JOB_LOGGER_MODE = 2;
    private static int logMode = 0;
    private static long startUpTime = System.currentTimeMillis();

    private static void logMsg(String string) {
        if (logging) {
            if (string == null) {
                new Throwable().printStackTrace();
                return;
            }
            switch (logMode) {
                case 0: {
                    System.out.println(string);
                    LogMan.informListeners(string);
                    break;
                }
                case 2: {
                    JobScreen.getJobRunner().log(string);
                    break;
                }
                case 1: {
                    try {
                        LineWriter lineWriter = new LineWriter("/lsd/geLog.txt", true);
                        lineWriter.writeln(string);
                        lineWriter.close();
                    }
                    catch (Exception exception) {
                        exception.printStackTrace();
                    }
                    break;
                }
                default: {
                    System.out.println("unkown logger mode -> logger switched to console mode");
                    logMode = 0;
                    LogMan.log(string);
                }
            }
        }
    }

    public static void setLogLevel(int n, boolean bl) {
        LogMan.logLevelState[n] = bl;
    }

    public static void setLogMode(int n) {
        logMode = n;
    }

    public static void addListener(LogListener logListener) {
        listenerList.add(logListener);
    }

    public static String getStackTrace(Throwable throwable) {
        StringWriter stringWriter = new StringWriter();
        PrintWriter printWriter = new PrintWriter((Writer)stringWriter, true);
        throwable.printStackTrace(printWriter);
        printWriter.flush();
        printWriter.close();
        return stringWriter.toString();
    }

    public static void log(int n, String string) {
        if (logLevelState[n]) {
            LogMan.log(string);
        }
    }

    public static void log(String string) {
        long l = System.currentTimeMillis();
        LogMan.logMsg(l - startUpTime + ": " + string);
    }

    public static void log(String string, Throwable throwable) {
        String string2 = string + ":\n" + LogMan.getStackTrace(throwable);
        LogMan.log(string2);
    }

    private static void informListeners(String string) {
        if (listenerList.size() > 0) {
            Iterator iterator = listenerList.iterator();
            while (iterator.hasNext()) {
                LogListener logListener = (LogListener)iterator.next();
                logListener.update(string + "\n");
            }
        }
    }

    public static void enableLogging() {
        logging = true;
    }
}

