/*
 * Decompiled with CFR 0.152.
 */
package de.audi.crypto;

import de.audi.crypto.RSAEngine;
import de.audi.crypto.RSAKeyParameters;
import java.security.SecureRandom;

public class PKCS1Encoding {
    private static final int HEADER_LENGTH = 10;
    private SecureRandom random;
    private RSAEngine engine;
    private boolean forEncryption;
    private boolean forPrivateKey;
    private boolean useStrictLength;

    public PKCS1Encoding(RSAEngine rSAEngine) {
        this.engine = rSAEngine;
        this.useStrictLength = this.useStrict();
    }

    private boolean useStrict() {
        return true;
    }

    public RSAEngine getUnderlyingCipher() {
        return this.engine;
    }

    public void init(boolean bl, RSAKeyParameters rSAKeyParameters) {
        this.random = new SecureRandom();
        this.engine.init(bl, rSAKeyParameters);
        this.forPrivateKey = rSAKeyParameters.isPrivate();
        this.forEncryption = bl;
    }

    public int getInputBlockSize() {
        int n = this.engine.getInputBlockSize();
        if (this.forEncryption) {
            return n - 10;
        }
        return n;
    }

    public int getOutputBlockSize() {
        int n = this.engine.getOutputBlockSize();
        if (this.forEncryption) {
            return n;
        }
        return n - 10;
    }

    public byte[] processBlock(byte[] byArray, int n, int n2) {
        if (this.forEncryption) {
            return this.encodeBlock(byArray, n, n2);
        }
        return this.decodeBlock(byArray, n, n2);
    }

    private byte[] encodeBlock(byte[] byArray, int n, int n2) {
        byte[] byArray2 = new byte[this.engine.getInputBlockSize()];
        if (this.forPrivateKey) {
            byArray2[0] = 1;
            for (int i = 1; i != byArray2.length - n2 - 1; ++i) {
                byArray2[i] = -1;
            }
        } else {
            this.random.nextBytes(byArray2);
            byArray2[0] = 2;
            for (int i = 1; i != byArray2.length - n2 - 1; ++i) {
                while (byArray2[i] == 0) {
                    byArray2[i] = (byte)this.random.nextInt();
                }
            }
        }
        byArray2[byArray2.length - n2 - 1] = 0;
        System.arraycopy(byArray, n, byArray2, byArray2.length - n2, n2);
        return this.engine.processBlock(byArray2, 0, byArray2.length);
    }

    private byte[] decodeBlock(byte[] byArray, int n, int n2) {
        byte by;
        int n3;
        byte[] byArray2 = this.engine.processBlock(byArray, n, n2);
        if (byArray2.length < this.getOutputBlockSize()) {
            throw new RuntimeException("block truncated");
        }
        byte by2 = byArray2[0];
        if (by2 != 1 && by2 != 2) {
            throw new RuntimeException("unknown block type");
        }
        if (this.useStrictLength && byArray2.length != this.engine.getOutputBlockSize()) {
            throw new RuntimeException("block incorrect size");
        }
        for (n3 = 1; n3 != byArray2.length && (by = byArray2[n3]) != 0; ++n3) {
            if (by2 != 1 || by == -1) continue;
            throw new RuntimeException("block padding incorrect");
        }
        if (++n3 >= byArray2.length || n3 < 10) {
            throw new RuntimeException("no data in block");
        }
        byte[] byArray3 = new byte[byArray2.length - n3];
        System.arraycopy(byArray2, n3, byArray3, 0, byArray3.length);
        return byArray3;
    }
}

