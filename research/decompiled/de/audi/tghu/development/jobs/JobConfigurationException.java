/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.jobs;

import java.io.PrintStream;
import java.io.PrintWriter;

public class JobConfigurationException
extends RuntimeException {
    private static final long serialVersionUID = 1L;
    Throwable cause;

    public JobConfigurationException() {
    }

    public JobConfigurationException(String string) {
        super(string);
    }

    public JobConfigurationException(String string, Throwable throwable) {
        super(string);
        this.cause = throwable;
    }

    public JobConfigurationException(Throwable throwable) {
        super(throwable.toString());
        this.cause = throwable;
    }

    public Throwable getException() {
        return this.cause;
    }

    public Throwable getCause() {
        return this.getException();
    }

    public String toString() {
        return this.getMessage();
    }

    public void printStackTrace() {
        this.printStackTrace(System.err);
    }

    /*
     * WARNING - Removed try catching itself - possible behaviour change.
     */
    public void printStackTrace(PrintStream printStream) {
        PrintStream printStream2 = printStream;
        synchronized (printStream2) {
            super.printStackTrace(printStream);
            if (this.cause != null) {
                printStream.println("--- Nested Exception ---");
                this.cause.printStackTrace(printStream);
            }
        }
    }

    /*
     * WARNING - Removed try catching itself - possible behaviour change.
     */
    public void printStackTrace(PrintWriter printWriter) {
        PrintWriter printWriter2 = printWriter;
        synchronized (printWriter2) {
            super.printStackTrace(printWriter);
            if (this.cause != null) {
                printWriter.println("--- Nested Exception ---");
                this.cause.printStackTrace(printWriter);
            }
        }
    }
}

