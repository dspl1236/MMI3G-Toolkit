/*
 * Decompiled with CFR 0.152.
 */
package de.audi.crypto;

import de.audi.crypto.BlockCipher;
import de.audi.crypto.BlockCipherPadding;
import de.audi.crypto.BufferedBlockCipher;
import de.audi.crypto.CipherParameters;
import de.audi.crypto.CryptoException;
import de.audi.crypto.PKCS7Padding;

public class PaddedBufferedBlockCipher
extends BufferedBlockCipher {
    BlockCipherPadding padding;

    public PaddedBufferedBlockCipher(BlockCipher blockCipher, BlockCipherPadding blockCipherPadding) {
        this.cipher = blockCipher;
        this.padding = blockCipherPadding;
        this.buf = new byte[blockCipher.getBlockSize()];
        this.bufOff = 0;
    }

    public PaddedBufferedBlockCipher(BlockCipher blockCipher) {
        this(blockCipher, new PKCS7Padding());
    }

    public void init(boolean bl, CipherParameters cipherParameters) throws IllegalArgumentException {
        this.forEncryption = bl;
        this.reset();
        this.padding.init(null);
        this.cipher.init(bl, cipherParameters);
    }

    public int getOutputSize(int n) {
        int n2 = n + this.bufOff;
        int n3 = n2 % this.buf.length;
        if (n3 == 0) {
            if (this.forEncryption) {
                return n2 + this.buf.length;
            }
            return n2;
        }
        return n2 - n3 + this.buf.length;
    }

    public int getUpdateOutputSize(int n) {
        int n2 = n + this.bufOff;
        int n3 = n2 % this.buf.length;
        if (n3 == 0) {
            return n2 - this.buf.length;
        }
        return n2 - n3;
    }

    public int processByte(byte by, byte[] byArray, int n) throws IllegalStateException {
        int n2 = 0;
        if (this.bufOff == this.buf.length) {
            n2 = this.cipher.processBlock(this.buf, 0, byArray, n);
            this.bufOff = 0;
        }
        this.buf[this.bufOff++] = by;
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
        return n6;
    }

    /*
     * WARNING - Removed try catching itself - possible behaviour change.
     */
    public int doFinal(byte[] byArray, int n) throws IllegalStateException, CryptoException {
        int n2 = this.cipher.getBlockSize();
        int n3 = 0;
        if (this.forEncryption) {
            if (this.bufOff == n2) {
                if (n + 2 * n2 > byArray.length) {
                    this.reset();
                    throw new RuntimeException("output buffer too short");
                }
                n3 = this.cipher.processBlock(this.buf, 0, byArray, n);
                this.bufOff = 0;
            }
            this.padding.addPadding(this.buf, this.bufOff);
            n3 += this.cipher.processBlock(this.buf, 0, byArray, n + n3);
            this.reset();
        } else {
            if (this.bufOff != n2) {
                this.reset();
                throw new RuntimeException("last block incomplete in decryption");
            }
            n3 = this.cipher.processBlock(this.buf, 0, this.buf, 0);
            this.bufOff = 0;
            try {
                System.arraycopy(this.buf, 0, byArray, n, n3 -= this.padding.padCount(this.buf));
            }
            finally {
                this.reset();
            }
        }
        return n3;
    }
}

