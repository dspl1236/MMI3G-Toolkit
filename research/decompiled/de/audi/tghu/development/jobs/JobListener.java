/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.jobs;

import de.audi.tghu.development.jobs.JobEvent;
import java.util.EventListener;

public interface JobListener
extends EventListener {
    public void jobStarted(JobEvent var1);

    public void jobFinished(JobEvent var1);

    public void messageLogged(JobEvent var1);
}

