/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.jobs;

import de.audi.tghu.development.jobs.JobConfigurationException;
import de.audi.tghu.development.jobs.JobRunner;

public abstract class Job {
    public static final int MSG_ERR = 0;
    public static final int MSG_WARN = 1;
    public static final int MSG_INFO = 2;
    public static final int MSG_VERBOSE = 3;
    public static final int MSG_DEBUG = 4;
    private JobRunner runner;
    private String jobName;
    private boolean invalid;

    public void setJobName(String string) {
        this.jobName = string;
    }

    public String getJobName() {
        return this.jobName;
    }

    public void log(String string) {
        this.log(string, 2);
    }

    public void log(String string, int n) {
        this.getRunner().log(this, string, n);
    }

    protected void setRunner(JobRunner jobRunner) {
        this.runner = jobRunner;
    }

    protected JobRunner getRunner() {
        return this.runner;
    }

    public void execute() throws Exception {
    }

    /*
     * WARNING - Removed try catching itself - possible behaviour change.
     */
    final void perform() {
        if (!this.invalid) {
            this.getRunner().fireJobStarted(this);
            Throwable throwable = null;
            try {
                this.execute();
            }
            catch (Exception exception) {
                throwable = exception;
            }
            catch (Error error) {
                throwable = error;
            }
            finally {
                this.getRunner().fireJobFinished(this, throwable);
            }
        } else {
            try {
                this.log("Trying to execute invalidated job, skip execution", 1);
                Object var5_5 = null;
                this.getRunner().fireJobFinished(this, new JobConfigurationException("Invalideted Job: " + this.getJobName()));
            }
            catch (Throwable throwable) {
                Object var5_6 = null;
                this.getRunner().fireJobFinished(this, new JobConfigurationException("Invalideted Job: " + this.getJobName()));
                throw throwable;
            }
        }
    }

    final void markInvalid() {
        this.invalid = true;
    }

    protected final boolean isInvalid() {
        return this.invalid;
    }
}

