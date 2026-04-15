/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  de.audi.atip.base.Framework
 *  de.audi.tghu.statemachine.AbstractSMM
 *  de.audi.tghu.statemachine.AbstractSMMActivator
 */
package de.audi.tghu.development.sm;

import de.audi.atip.base.Framework;
import de.audi.tghu.development.sm.DevelopmentSMM;
import de.audi.tghu.statemachine.AbstractSMM;
import de.audi.tghu.statemachine.AbstractSMMActivator;

public class SMActivator
extends AbstractSMMActivator {
    public void init() {
        this.smmList = new AbstractSMM[6];
        if (Framework.isFrontMainUnit()) {
            this.smmList[0] = new DevelopmentSMM(0, "main");
            if (Framework.isDualView()) {
                this.smmList[2] = new DevelopmentSMM(2, "front passenger");
            }
        } else {
            this.smmList[3] = new DevelopmentSMM(3, "rear seat 1");
            this.smmList[4] = new DevelopmentSMM(4, "rear seat 2");
        }
        this.reqActionProxies = new int[]{16};
    }
}

