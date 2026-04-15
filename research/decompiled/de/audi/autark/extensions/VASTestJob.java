/*
 * Decompiled with CFR 0.152.
 */
package de.audi.autark.extensions;

import de.audi.autark.extensions.VASTask;

public class VASTestJob
extends VASTask {
    public void execute() throws Exception {
        super.execute();
        System.out.println("VASTestJob started");
        char[] cArray = "Hello World!\nHello World!\nThird Line\n".toCharArray();
        this.showTaskOutput(cArray);
    }
}

