/*
 * Decompiled with CFR 0.152.
 */
package de.audi.crypto;

import de.audi.crypto.CipherParameters;

public interface StreamCipher {
    public void init(boolean var1, CipherParameters var2) throws IllegalArgumentException;

    public String getAlgorithmName();

    public byte returnByte(byte var1);

    public void processBytes(byte[] var1, int var2, int var3, byte[] var4, int var5);

    public void reset();
}

