/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  de.audi.atip.base.Framework
 *  de.audi.atip.log.LogChannel
 */
package de.audi.tghu.development.app;

import de.audi.atip.base.Framework;
import de.audi.atip.log.LogChannel;

public class Logger {
    private static final String LOG_CH_MEDIA = "App.Development.Main";
    private static final String LOG_CH_HMI = "App.Development.HMI";
    private static final String LOG_CH_SM = "App.Development.SM";
    private static final String LOG_CH_DSI = "App.Development.DSI";
    public static final int DSI_SERVICE_ERROR = 10000000;
    public static final int DSI_SERVICE_MISSING = 100000;
    private static Logger _instance;
    public LogChannel dsi;
    public LogChannel hmi;
    public LogChannel main;
    public LogChannel sm;

    public Logger() {
        this.initLogChannels();
    }

    public static synchronized Logger getInstance() {
        if (_instance == null) {
            _instance = new Logger();
        }
        return _instance;
    }

    private void initLogChannels() {
        this.main = Framework.getLogChannel((String)LOG_CH_MEDIA);
        this.hmi = Framework.getLogChannel((String)LOG_CH_HMI);
        this.sm = Framework.getLogChannel((String)LOG_CH_SM);
        this.dsi = Framework.getLogChannel((String)LOG_CH_DSI);
    }
}

