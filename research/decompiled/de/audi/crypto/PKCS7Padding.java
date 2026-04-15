/*
 * Decompiled with CFR 0.152.
 */
package de.audi.crypto;

import de.audi.crypto.BlockCipherPadding;
import de.audi.crypto.CryptoException;
import java.security.SecureRandom;

public class PKCS7Padding
implements BlockCipherPadding {
    public void init(SecureRandom secureRandom) throws IllegalArgumentException {
    }

    public String getPaddingName() {
        return "PKCS7";
    }

    public int addPadding(byte[] byArray, int n) {
        byte by = (byte)(byArray.length - n);
        while (n < byArray.length) {
            byArray[n] = by;
            ++n;
        }
        return by;
    }

    public int padCount(byte[] byArray) throws CryptoException {
        int n = byArray[byArray.length - 1] & 0xFF;
        if (n > byArray.length || n == 0) {
            throw new CryptoException("pad block corrupted");
        }
        for (int i = 1; i <= n; ++i) {
            if (byArray[byArray.length - i] == n) continue;
            throw new CryptoException("pad block corrupted");
        }
        return n;
    }
}

