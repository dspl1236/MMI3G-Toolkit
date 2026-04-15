/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.jobs;

import de.audi.tghu.development.jobs.Job;
import de.audi.tghu.development.jobs.JobRunner;
import java.util.EventObject;

public class JobEvent
extends EventObject {
    private static final long serialVersionUID = 1L;
    private Job job;
    private String message;
    private int priority = 3;
    private Throwable exception;

    public JobEvent(Job job) {
        super(job);
        this.job = job;
    }

    public JobEvent(JobRunner jobRunner) {
        super(jobRunner);
        this.job = null;
    }

    public Job getJob() {
        return this.job;
    }

    public void setMessage(String string, int n) {
        this.message = string;
        this.priority = n;
    }

    public void setException(Throwable throwable) {
        this.exception = throwable;
    }

    public String getMessage() {
        return this.message;
    }

    public int getPriority() {
        return this.priority;
    }

    public Throwable getException() {
        return this.exception;
    }
}

