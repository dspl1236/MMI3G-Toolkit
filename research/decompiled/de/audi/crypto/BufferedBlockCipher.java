/*
 * Decompiled with CFR 0.152.
 */
package de.audi.crypto;

import de.audi.crypto.BlockCipher;
import de.audi.crypto.CipherParameters;
import de.audi.crypto.CryptoException;

public class BufferedBlockCipher {
    protected byte[] buf;
    protected int bufOff;
    protected boolean forEncryption;
    protected BlockCipher cipher;
    protected boolean partialBlockOkay;

    protected BufferedBlockCipher() {
    }

    public BufferedBlockCipher(BlockCipher blockCipher) {
        this.cipher = blockCipher;
        this.buf = new byte[blockCipher.getBlockSize()];
        this.bufOff = 0;
        String string = blockCipher.getAlgorithmName();
        int n = string.indexOf(47) + 1;
        this.partialBlockOkay = n > 0 && (string.startsWith("CFB", n) || string.startsWith("OFB", n));
    }

    public BlockCipher getUnderlyingCipher() {
        return this.cipher;
    }

    public void init(boolean bl, CipherParameters cipherParameters) throws IllegalArgumentException {
        this.forEncryption = bl;
        this.reset();
        this.cipher.init(bl, cipherParameters);
    }

    public int getBlockSize() {
        return this.cipher.getBlockSize();
    }

    public int getUpdateOutputSize(int n) {
        int n2 = n + this.bufOff;
        int n3 = n2 % this.buf.length;
        return n2 - n3;
    }

    public int getOutputSize(int n) {
        int n2 = n + this.bufOff;
        int n3 = n2 % this.buf.length;
        if (n3 == 0) {
            return n2;
        }
        return n2 - n3 + this.buf.length;
    }

    public int processByte(byte by, byte[] byArray, int n) throws IllegalStateException {
        int n2 = 0;
        this.buf[this.bufOff++] = by;
        if (this.bufOff == this.buf.length) {
            n2 = this.cipher.processBlock(this.buf, 0, byArray, n);
            this.bufOff = 0;
        }
        return n2;
    }

    public int processBytes(byte[] byArray, int n, int n2, byte[] byArray2, int n3) throws IllegalStateException {
        if (n2 < 0) {
            throw new IllegalArgumentException("Can't have a negative input length!");
        }
        int n4 = this.getBlockSize();
        int n5 = this.getUpdateOutputSize(n2);
        if (n5 > 0 && n3 + n5 > byArray2.length) {
            throw new RuntimeException("output buffer too short");
        }
        int n6 = 0;
        int n7 = this.buf.length - this.bufOff;
        if (n2 > n7) {
            System.arraycopy(byArray, n, this.buf, this.bufOff, n7);
            n6 += this.cipher.processBlock(this.buf, 0, byArray2, n3);
            this.bufOff = 0;
            n2 -= n7;
            n += n7;
            while (n2 > this.buf.length) {
                n6 += this.cipher.processBlock(byArray, n, byArray2, n3 + n6);
                n2 -= n4;
                n += n4;
            }
        }
        System.arraycopy(byArray, n, this.buf, this.bufOff, n2);
        this.bufOff += n2;
        if (this.bufOff == this.buf.length) {
            n6 += this.cipher.processBlock(this.buf, 0, byArray2, n3 + n6);
            this.bufOff = 0;
        }
        return n6;
    }

    public int doFinal(byte[] byArray, int n) throws IllegalStateException, CryptoException {
        int n2 = 0;
        if (n + this.bufOff > byArray.length) {
            throw new RuntimeException("output buffer too short for doFinal()");
        }
        if (this.bufOff != 0 && this.partialBlockOkay) {
            this.cipher.processBlock(this.buf, 0, this.buf, 0);
            n2 = this.bufOff;
            this.bufOff = 0;
            System.arraycopy(this.buf, 0, byArray, n, n2);
        } else if (this.bufOff != 0) {
            throw new RuntimeException("data not block size aligned");
        }
        this.reset();
        return n2;
    }

    public void reset() {
        for (int i = 0; i < this.buf.length; ++i) {
            this.buf[i] = 0;
        }
        this.bufOff = 0;
        this.cipher.reset();
    }
}

