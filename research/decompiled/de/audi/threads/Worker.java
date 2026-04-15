/*
 * Decompiled with CFR 0.152.
 */
package de.audi.threads;

import de.audi.threads.WorkIFC;
import de.audi.threads.WorkerWatchDog;

class Worker
extends Thread {
    private WorkIFC work;
    private WorkerWatchDog workerWatchDog;

    Worker(WorkIFC workIFC, WorkerWatchDog workerWatchDog) {
        this.work = workIFC;
        this.workerWatchDog = workerWatchDog;
    }

    public void run() {
        super.run();
        while (!this.workDone()) {
            this.doWork();
        }
        if (this.workerWatchDog != null) {
            this.workerWatchDog.workerFinished();
        }
    }

    public void doWork() {
        this.work.doWork();
    }

    public boolean workDone() {
        return this.work.workDone();
    }
}

