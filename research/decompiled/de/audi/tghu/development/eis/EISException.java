/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.eis;

import de.audi.tghu.development.EngineeringException;

public class EISException
extends EngineeringException {
    protected int ds;
    protected int ns;
    protected long key;

    public EISException(int n, int n2, long l, String string) {
        super(string);
        this.ds = n;
        this.ns = n2;
        this.key = l;
    }
}

