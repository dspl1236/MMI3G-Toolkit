/*
 * Decompiled with CFR 0.152.
 */
package de.audi.crypto;

import de.audi.crypto.RSAKeyParameters;
import java.math.BigInteger;

public class RSAEngine {
    private RSAKeyParameters key;
    private boolean forEncryption;
    private static String ERR_DataLength = "Input too large for RSA cipher.";
    private static String ERR_NotInit = "RSA engine not initialised.";

    public void init(boolean bl, RSAKeyParameters rSAKeyParameters) {
        this.key = rSAKeyParameters;
        this.forEncryption = bl;
    }

    public int getInputBlockSize() {
        int n = this.key.getModulus().bitLength();
        if (this.forEncryption) {
            return (n + 7) / 8 - 1;
        }
        return (n + 7) / 8;
    }

    public int getOutputBlockSize() {
        int n = this.key.getModulus().bitLength();
        if (this.forEncryption) {
            return (n + 7) / 8;
        }
        return (n + 7) / 8 - 1;
    }

    public byte[] processBlock(byte[] byArray, int n, int n2) {
        if (this.key == null) {
            throw new IllegalStateException(ERR_NotInit);
        }
        return this.convertOutput(this.convertInput(byArray, n, n2).modPow(this.key.getExponent(), this.key.getModulus()));
    }

    private BigInteger convertInput(byte[] byArray, int n, int n2) {
        byte[] byArray2;
        if (n2 > this.getInputBlockSize() + 1) {
            throw new RuntimeException(ERR_DataLength);
        }
        if (n2 == this.getInputBlockSize() + 1 && !this.forEncryption) {
            throw new RuntimeException(ERR_DataLength);
        }
        if (n != 0 || n2 != byArray.length) {
            byArray2 = new byte[n2];
            System.arraycopy(byArray, n, byArray2, 0, n2);
        } else {
            byArray2 = byArray;
        }
        BigInteger bigInteger = new BigInteger(1, byArray2);
        if (bigInteger.compareTo(this.key.getModulus()) >= 0) {
            throw new RuntimeException(ERR_DataLength);
        }
        return bigInteger;
    }

    private byte[] convertOutput(BigInteger bigInteger) {
        byte[] byArray = bigInteger.toByteArray();
        if (this.forEncryption) {
            if (byArray[0] == 0 && byArray.length > this.getOutputBlockSize()) {
                byte[] byArray2 = new byte[byArray.length - 1];
                System.arraycopy(byArray, 1, byArray2, 0, byArray2.length);
                return byArray2;
            }
            if (byArray.length < this.getOutputBlockSize()) {
                byte[] byArray3 = new byte[this.getOutputBlockSize()];
                System.arraycopy(byArray, 0, byArray3, byArray3.length - byArray.length, byArray.length);
                return byArray3;
            }
        } else if (byArray[0] == 0) {
            byte[] byArray4 = new byte[byArray.length - 1];
            System.arraycopy(byArray, 1, byArray4, 0, byArray4.length);
            return byArray4;
        }
        return byArray;
    }
}

