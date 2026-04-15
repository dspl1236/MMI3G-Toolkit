/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.jobs;

import de.audi.tghu.development.jobs.JobListener;
import java.io.PrintStream;

public interface IJobLogger
extends JobListener {
    public static final String LINE_SEP = System.getProperty("line.separator");

    public void setMessageOutputLevel(int var1);

    public void setOutputPrintStream(PrintStream var1);

    public void setEmacsMode(boolean var1);

    public void setErrorPrintStream(PrintStream var1);
}

