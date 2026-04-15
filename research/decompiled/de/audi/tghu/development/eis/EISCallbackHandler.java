/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.eis;

interface EISCallbackHandler {
    public void updateInt(int var1, int var2, long var3, int var5);

    public void updateString(int var1, int var2, long var3, String var5);

    public void updateObject(int var1, int var2, long var3, byte[] var5);

    public void updateIntArray(int var1, int var2, long var3, int[] var5);

    public void handleError(int var1, int var2, long var3, String var5);
}

