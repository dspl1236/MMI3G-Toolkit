/*
 * Decompiled with CFR 0.152.
 */
package de.audi.crypto;

import de.audi.crypto.CipherParameters;

public interface BlockCipher {
    public void init(boolean var1, CipherParameters var2) throws IllegalArgumentException;

    public String getAlgorithmName();

    public int getBlockSize();

    public int processBlock(byte[] var1, int var2, byte[] var3, int var4) throws IllegalStateException;

    public void reset();
}

