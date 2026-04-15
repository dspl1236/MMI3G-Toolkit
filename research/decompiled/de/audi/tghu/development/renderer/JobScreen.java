/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  org.dsi.ifc.base.DSIFatalException
 *  org.dsi.ifc.base.DSINonFatalException
 */
package de.audi.tghu.development.renderer;

import de.audi.tghu.development.EngineeringException;
import de.audi.tghu.development.jobs.JobRunner;
import de.audi.tghu.development.model.JobModel;
import de.audi.tghu.development.model.RunnerModel;
import de.audi.tghu.development.model.ScreenModel;
import de.audi.tghu.development.renderer.ScreenInfo;
import de.audi.tghu.development.renderer.ScreenRenderer;
import org.dsi.ifc.base.DSIFatalException;
import org.dsi.ifc.base.DSINonFatalException;

public class JobScreen {
    private ScreenRenderer screenRenderer = null;
    private ScreenModel jobScreen = null;
    private static JobRunner JOB_RUNNER = new JobRunner(JobRunner.getDefaultJobLogger(true));
    private static JobScreen jobs = null;

    public static JobScreen getInstance(ScreenRenderer screenRenderer) {
        if (jobs == null) {
            jobs = new JobScreen(screenRenderer);
        }
        return jobs;
    }

    private JobScreen(ScreenRenderer screenRenderer) {
        this.screenRenderer = screenRenderer;
    }

    public static JobRunner getJobRunner() {
        return JOB_RUNNER;
    }

    /*
     * WARNING - Removed try catching itself - possible behaviour change.
     */
    public void initialize(JobModel jobModel, RunnerModel[] runnerModelArray) throws DSINonFatalException, DSIFatalException {
        int n;
        this.jobScreen = new JobScreenModel(jobModel, 4711);
        this.jobScreen.setScreenName("Jobs");
        int n2 = n = this.screenRenderer.screenStack.size() == 0 ? 0 : ((ScreenInfo)this.screenRenderer.screenStack.peek()).screenId;
        if (n == this.jobScreen.getScreenId()) {
            return;
        }
        if (this.screenRenderer.currentScreen != null) {
            this.screenRenderer.currentScreen.model.leave();
            this.screenRenderer.screenStack.push(this.screenRenderer.currentScreen);
        }
        Object object = this.screenRenderer.screenInfoMutex;
        synchronized (object) {
            this.screenRenderer.currentScreen = new ScreenInfo(this.jobScreen);
        }
        for (int i = 0; i < runnerModelArray.length; ++i) {
            this.jobScreen.addElement(runnerModelArray[i]);
        }
    }

    public ScreenModel getScreenModel() {
        return this.jobScreen;
    }

    class JobScreenModel
    extends ScreenModel {
        private JobModel model;

        public JobScreenModel(JobModel jobModel, int n) {
            super(n);
            this.model = jobModel;
        }

        public void enter() throws EngineeringException, DSINonFatalException, DSIFatalException {
            JobScreen.getJobRunner().addJobListener(this.model);
            super.enter();
        }

        public void leave() throws DSINonFatalException, DSIFatalException {
            JobScreen.getJobRunner().removeJobListener(this.model);
            super.leave();
        }
    }
}

