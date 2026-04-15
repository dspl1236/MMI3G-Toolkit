/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  org.dsi.ifc.base.DSIFatalException
 *  org.dsi.ifc.base.DSINonFatalException
 */
package de.audi.tghu.development.model;

import de.audi.tghu.development.EngineeringException;
import de.audi.tghu.development.eis.EngineeringInfoService;
import de.audi.tghu.development.model.ScreenElementModel;
import java.util.ArrayList;
import org.dsi.ifc.base.DSIFatalException;
import org.dsi.ifc.base.DSINonFatalException;

public class ScreenModel {
    private int screenId;
    private String screenName;
    private ArrayList listElements = new ArrayList();

    public ScreenModel(int n) {
        this.screenId = n;
    }

    public void addElement(ScreenElementModel screenElementModel) {
        this.listElements.add(screenElementModel);
    }

    public ScreenElementModel getElement(int n) {
        return (ScreenElementModel)this.listElements.get(n);
    }

    public int getNumElements() {
        return this.listElements.size();
    }

    public int getScreenId() {
        return this.screenId;
    }

    public String getScreenName() {
        return this.screenName;
    }

    public void setScreenName(String string) {
        this.screenName = string;
    }

    public void enter() throws EngineeringException, DSINonFatalException, DSIFatalException {
        int n = this.getNumElements();
        for (int i = 0; i < n; ++i) {
            ScreenElementModel screenElementModel = this.getElement(i);
            EngineeringInfoService.getInstance().addListener(screenElementModel);
        }
    }

    public void leave() throws DSINonFatalException, DSIFatalException {
        int n = this.getNumElements();
        for (int i = 0; i < n; ++i) {
            ScreenElementModel screenElementModel = this.getElement(i);
            EngineeringInfoService.getInstance().removeListener(screenElementModel);
        }
        EngineeringInfoService.getInstance().clearAllTimers();
    }
}

