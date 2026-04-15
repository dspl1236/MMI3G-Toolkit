/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.jobs;

import de.audi.tghu.development.jobs.IJobLogger;
import de.audi.tghu.development.jobs.JobConfigurationException;
import de.audi.tghu.development.jobs.JobEvent;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.PrintStream;
import java.io.PrintWriter;
import java.io.StringReader;
import java.io.StringWriter;
import java.io.Writer;
import java.text.ChoiceFormat;
import java.text.MessageFormat;

public class DefaultLogger
implements IJobLogger {
    public static final int LEFT_COLUMN_SIZE = 12;
    protected PrintStream out;
    protected PrintStream err;
    protected int msgOutputLevel = 2;
    private long startTime = System.currentTimeMillis();
    protected boolean emacsMode = false;
    private static final MessageFormat MINUTE_SECONDS = new MessageFormat("{0}{1}");
    private static final double[] LIMITS = new double[]{0.0, 1.0, 2.0};
    private static final String[] MINUTES_PART = new String[]{"", "1 minute ", "{0,number} minutes "};
    private static final String[] SECONDS_PART = new String[]{"0 seconds", "1 second", "{1,number} seconds"};
    private static final ChoiceFormat MINUTES_FORMAT = new ChoiceFormat(LIMITS, MINUTES_PART);
    private static final ChoiceFormat SECONDS_FORMAT = new ChoiceFormat(LIMITS, SECONDS_PART);

    public void setMessageOutputLevel(int n) {
        this.msgOutputLevel = n;
    }

    public void setOutputPrintStream(PrintStream printStream) {
        this.out = new PrintStream(printStream, true);
    }

    public void setErrorPrintStream(PrintStream printStream) {
        this.err = new PrintStream(printStream, true);
    }

    public void setEmacsMode(boolean bl) {
        this.emacsMode = bl;
    }

    public void jobStarted(JobEvent jobEvent) {
        this.startTime = System.currentTimeMillis();
    }

    public void jobFinished(JobEvent jobEvent) {
        String string;
        Throwable throwable = jobEvent.getException();
        StringBuffer stringBuffer = new StringBuffer();
        if (throwable == null) {
            stringBuffer.append(this.getOutputLineSep());
            stringBuffer.append("JOB SUCCESSFUL");
        } else {
            stringBuffer.append(this.getOutputLineSep());
            stringBuffer.append("JOB FAILED");
            stringBuffer.append(this.getOutputLineSep());
            if (3 <= this.msgOutputLevel || !(throwable instanceof JobConfigurationException)) {
                string = DefaultLogger.getStackTrace(throwable);
                BufferedReader bufferedReader = new BufferedReader(new StringReader(string));
                try {
                    String string2;
                    while ((string2 = bufferedReader.readLine()) != null) {
                        stringBuffer.append(string2);
                        stringBuffer.append(this.getOutputLineSep());
                    }
                }
                catch (IOException iOException) {
                    stringBuffer.append(jobEvent.getMessage());
                }
            } else if (throwable instanceof JobConfigurationException) {
                stringBuffer.append(throwable.toString()).append(this.getOutputLineSep());
            } else {
                stringBuffer.append(throwable.getMessage()).append(this.getOutputLineSep());
            }
        }
        stringBuffer.append(this.getOutputLineSep());
        stringBuffer.append("Total time: ");
        stringBuffer.append(DefaultLogger.formatTime(System.currentTimeMillis() - this.startTime));
        string = stringBuffer.toString();
        if (throwable == null) {
            this.printMessage(string, this.out, 3);
        } else {
            this.printMessage(string, this.err, 0);
        }
        this.log(string);
    }

    public void messageLogged(JobEvent jobEvent) {
        int n = jobEvent.getPriority();
        if (n <= this.msgOutputLevel) {
            String string;
            StringBuffer stringBuffer = new StringBuffer();
            if (jobEvent.getJob() != null && !this.emacsMode) {
                string = jobEvent.getJob().getJobName();
                String string2 = "[" + string + "] ";
                int n2 = 12 - string2.length();
                StringBuffer stringBuffer2 = new StringBuffer();
                for (int i = 0; i < n2; ++i) {
                    stringBuffer2.append(" ");
                }
                stringBuffer2.append(string2);
                string2 = stringBuffer2.toString();
                try {
                    BufferedReader bufferedReader = new BufferedReader(new StringReader(jobEvent.getMessage()));
                    String string3 = bufferedReader.readLine();
                    boolean bl = true;
                    while (string3 != null) {
                        if (!bl) {
                            stringBuffer.append(this.getOutputLineSep());
                        }
                        bl = false;
                        stringBuffer.append(string2).append(string3);
                        string3 = bufferedReader.readLine();
                    }
                }
                catch (IOException iOException) {
                    stringBuffer.append(string2).append(jobEvent.getMessage());
                }
            } else {
                stringBuffer.append(jobEvent.getMessage());
            }
            string = stringBuffer.toString();
            if (n != 0) {
                this.printMessage(string, this.out, n);
            } else {
                this.printMessage(string, this.err, n);
            }
            this.log(string);
        }
    }

    protected static String formatTime(long l) {
        return DefaultLogger.formatElapsedTime(l);
    }

    protected void printMessage(String string, PrintStream printStream, int n) {
        if (printStream != null) {
            printStream.println(string);
        }
    }

    protected void log(String string) {
    }

    public static String formatElapsedTime(long l) {
        long l2 = l / 1000L;
        long l3 = l2 / 60L;
        Object[] objectArray = new Object[]{new Long(l3), new Long(l2 % 60L)};
        return MINUTE_SECONDS.format(objectArray);
    }

    public static String getStackTrace(Throwable throwable) {
        StringWriter stringWriter = new StringWriter();
        PrintWriter printWriter = new PrintWriter((Writer)stringWriter, true);
        throwable.printStackTrace(printWriter);
        printWriter.flush();
        printWriter.close();
        return stringWriter.toString();
    }

    protected String getOutputLineSep() {
        return IJobLogger.LINE_SEP;
    }

    static {
        MINUTE_SECONDS.setFormat(0, MINUTES_FORMAT);
        MINUTE_SECONDS.setFormat(1, SECONDS_FORMAT);
    }
}

