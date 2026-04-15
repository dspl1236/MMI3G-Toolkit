/*
 * Decompiled with CFR 0.152.
 */
package de.audi.crypto;

import de.audi.crypto.CryptoException;
import java.security.SecureRandom;

public interface BlockCipherPadding {
    public void init(SecureRandom var1) throws IllegalArgumentException;

    public String getPaddingName();

    public int addPadding(byte[] var1, int var2);

    public int padCount(byte[] var1) throws CryptoException;
}

