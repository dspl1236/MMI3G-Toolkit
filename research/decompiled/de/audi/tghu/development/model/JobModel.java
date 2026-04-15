/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.model;

import de.audi.tghu.development.EngineeringException;
import de.audi.tghu.development.jobs.JobEvent;
import de.audi.tghu.development.jobs.JobListener;
import de.audi.tghu.development.jobs.JobRunner;
import de.audi.tghu.development.manager.LogMan;
import de.audi.tghu.development.model.RunnerModel;
import de.audi.tghu.development.model.ScreenElementModel;
import de.audi.tghu.development.renderer.JobScreen;
import de.audi.tghu.development.renderer.ScreenRenderer;
import de.audi.tghu.development.widget.JobWidget;
import de.audi.tghu.development.widget.Widget;
import java.util.Enumeration;
import java.util.Hashtable;

public class JobModel
extends ScreenElementModel
implements JobListener {
    private Hashtable jobList = new Hashtable(20);

    public JobModel() {
        super(10, 0);
    }

    public boolean areRequiredFieldsSet() {
        return this.isLabelSet;
    }

    public void updateData(int n, long l, Object object) {
        if (n != this.namespace) {
            return;
        }
        this.widget.dataChanged();
    }

    public void performAction() throws EngineeringException {
        if (!this.isEditable()) {
            return;
        }
        this.jobList.clear();
        JobRunner jobRunner = JobScreen.getJobRunner();
        if (jobRunner != null && jobRunner.scan("/mnt", "sdcard*/jobs/job.mf", "job.mf")) {
            RunnerModel[] runnerModelArray;
            Enumeration enumeration = jobRunner.getJobDefinitions().keys();
            while (enumeration.hasMoreElements()) {
                runnerModelArray = (RunnerModel[])enumeration.nextElement();
                RunnerModel runnerModel = new RunnerModel(jobRunner);
                runnerModel.setLabel((String)runnerModelArray);
                this.jobList.put(runnerModelArray, runnerModel);
            }
            if (this.jobList.size() > 0) {
                runnerModelArray = this.jobList.values().toArray(new RunnerModel[this.jobList.size()]);
                try {
                    this.widget.screenRenderer.enterJobScreen(this, runnerModelArray);
                }
                catch (Exception exception) {
                    exception.printStackTrace();
                }
            } else {
                this.widget.screenRenderer.enterErrorScreen("No jobs found!", null);
            }
        } else {
            LogMan.log("no jobs found");
        }
    }

    private RunnerModel getRunnerByJobName(JobEvent jobEvent) {
        RunnerModel runnerModel = null;
        String string = jobEvent.getJob().getJobName();
        if (string == null) {
            LogMan.log("@getRunnerByJobName -> jobName is null");
        } else {
            runnerModel = (RunnerModel)this.jobList.get(string);
            if (runnerModel == null) {
                LogMan.log("Job not found: " + string);
            }
        }
        return runnerModel;
    }

    public void jobFinished(JobEvent jobEvent) {
        RunnerModel runnerModel = this.getRunnerByJobName(jobEvent);
        if (runnerModel != null) {
            if (jobEvent.getException() == null) {
                runnerModel.setStatus("done");
            } else {
                runnerModel.setStatus("failed");
            }
        }
    }

    public void jobStarted(JobEvent jobEvent) {
        RunnerModel runnerModel;
        if (jobEvent == null) {
            LogMan.log("@jobStarted -> JobEvent is null");
        }
        if ((runnerModel = this.getRunnerByJobName(jobEvent)) != null) {
            runnerModel.setStatus("running");
        }
    }

    public void messageLogged(JobEvent jobEvent) {
    }

    public Widget getWidget(ScreenRenderer screenRenderer) {
        return new JobWidget(this, screenRenderer);
    }
}

