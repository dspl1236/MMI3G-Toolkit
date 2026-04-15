/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.model;

import de.audi.tghu.development.EngineeringException;
import de.audi.tghu.development.jobs.Job;
import de.audi.tghu.development.jobs.JobRunner;
import de.audi.tghu.development.model.ScreenElementModel;
import de.audi.tghu.development.renderer.ScreenRenderer;
import de.audi.tghu.development.widget.RunnerWidget;
import de.audi.tghu.development.widget.Widget;

public class RunnerModel
extends ScreenElementModel {
    private static JobRunner jobRunner;
    private String statusLabel;

    public String getStatus() {
        return this.statusLabel;
    }

    public void setStatus(String string) {
        this.statusLabel = string;
    }

    public RunnerModel(JobRunner jobRunner) {
        super(11, 0);
        RunnerModel.jobRunner = jobRunner;
        this.statusLabel = "status";
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
        Job job = jobRunner.createJob(this.getLabel());
        if (job != null) {
            jobRunner.asyncExec(job);
        }
    }

    public Widget getWidget(ScreenRenderer screenRenderer) {
        return new RunnerWidget(this, screenRenderer);
    }
}

