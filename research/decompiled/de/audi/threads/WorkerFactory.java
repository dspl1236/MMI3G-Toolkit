/*
 * Decompiled with CFR 0.152.
 */
package de.audi.threads;

import de.audi.threads.WorkIFC;
import de.audi.threads.Worker;
import de.audi.threads.WorkerWatchDog;

public class WorkerFactory {
    public static Worker startWorker(WorkIFC workIFC) {
        Worker worker = new Worker(workIFC, null);
        worker.start();
        return worker;
    }

    public static Worker startWorker(WorkIFC workIFC, int n) {
        Worker worker = new Worker(workIFC, null);
        worker.setPriority(n);
        worker.start();
        return worker;
    }

    public static Worker startWorker(WorkIFC workIFC, WorkerWatchDog workerWatchDog) {
        Worker worker = new Worker(workIFC, workerWatchDog);
        worker.start();
        return worker;
    }

    public static Worker startWorker(WorkIFC workIFC, int n, WorkerWatchDog workerWatchDog) {
        Worker worker = new Worker(workIFC, workerWatchDog);
        worker.setPriority(n);
        worker.start();
        return worker;
    }
}

