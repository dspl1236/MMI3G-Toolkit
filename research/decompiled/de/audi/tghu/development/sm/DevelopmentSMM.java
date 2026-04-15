/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  de.audi.atip.statemachine.ActionProxy
 *  de.audi.atip.statemachine.EventMediator
 *  de.audi.atip.statemachine.ap.DevelopmentActionProxy
 *  de.audi.tghu.statemachine.AbstractAppSMM
 */
package de.audi.tghu.development.sm;

import de.audi.atip.statemachine.ActionProxy;
import de.audi.atip.statemachine.EventMediator;
import de.audi.atip.statemachine.ap.DevelopmentActionProxy;
import de.audi.tghu.statemachine.AbstractAppSMM;
import java.util.NoSuchElementException;

public class DevelopmentSMM
extends AbstractAppSMM {
    public static final int MODULE_ID = 16;
    public static final String SMM_NAME = "DevelopmentSMM";
    private DevelopmentActionProxy ap0;

    public DevelopmentSMM(int n, String string) {
        super(n, string, 16, SMM_NAME);
    }

    public ActionProxy addActionProxy(int n, ActionProxy actionProxy) {
        if (actionProxy instanceof DevelopmentActionProxy) {
            this.ap0 = (DevelopmentActionProxy)actionProxy;
            this.logChannel.log(10000000, "DevelopmentActionProxy Action Proxy added");
            return this.ap0;
        }
        return null;
    }

    public void removeActionProxy(int n, ActionProxy actionProxy) {
        if (actionProxy instanceof DevelopmentActionProxy) {
            this.ap0 = null;
            this.logChannel.log(10000000, "DevelopmentActionProxy Action Proxy removed");
            return;
        }
    }

    protected void init() {
        this.topLevelStateID = 160001;
        this.extStateIDList = new int[]{160001};
        this.extStateLabelList = new String[]{"DevelopmentTLS"};
        this.incSlotList = new int[0];
        this.incSlotStateIDList = new int[0];
        this.stateSuperstateList = new int[]{-1, -10, 160001};
        this.stateDHSList = new int[]{-1, -1, 160001};
        this.stateFlagList = new int[]{0, 7, 0};
        this.stateTriggerEventList = new int[3][];
        this.stateOutTransList = new int[3][];
        this.stateTriggerEventList[1] = new int[]{1};
        this.stateOutTransList[1] = new int[]{160001};
        this.stateMediatorList = new int[3][];
        this.mediatorList = new EventMediator[1];
        this.transFlagList = new int[]{0, 0};
        this.transTrgtStateList = new int[2][];
        this.transTrgtStateList[1] = new int[]{160002};
        this.transTrgtFlagList = new int[2][];
        this.transTrgtFlagList[1] = new int[]{0};
    }

    public void execEnterAction(int n) {
        switch (n) {
            case 160001: {
                try {
                    this.ap0.hmiActivated(this.terminalID);
                }
                catch (NullPointerException nullPointerException) {
                    if (this.ap0 == null) {
                        this.logChannel.log(100000, "Action Proxy 'DevelopmentActionProxy' missing", (Throwable)nullPointerException);
                    }
                    throw nullPointerException;
                }
                return;
            }
        }
    }

    public void execExitAction(int n) {
        switch (n) {
            case 160001: {
                try {
                    this.ap0.hmiDeactivated(this.terminalID);
                }
                catch (NullPointerException nullPointerException) {
                    if (this.ap0 == null) {
                        this.logChannel.log(100000, "Action Proxy 'DevelopmentActionProxy' missing", (Throwable)nullPointerException);
                    }
                    throw nullPointerException;
                }
                return;
            }
        }
    }

    public void execTransitionAction(int n, int n2) {
        switch (n) {
            default: 
        }
    }

    public boolean checkGuard(int n, int n2) {
        try {
            switch (n) {
                default: 
            }
            return false;
        }
        catch (NullPointerException nullPointerException) {
            if (this.hmiService == null) {
                this.logChannel.log(10000, "Model Broker not registered");
                return false;
            }
            throw nullPointerException;
        }
        catch (NoSuchElementException noSuchElementException) {
            this.logChannel.log(10000, "unable to retrieve all required models to check guard of transition %1.%2", (long)n, (long)n2, (Throwable)noSuchElementException);
            return false;
        }
    }
}

