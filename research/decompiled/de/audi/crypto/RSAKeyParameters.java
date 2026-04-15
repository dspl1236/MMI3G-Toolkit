/*
 * Decompiled with CFR 0.152.
 */
package de.audi.crypto;

import java.math.BigInteger;

public class RSAKeyParameters {
    private boolean isPrivate;
    private BigInteger modulus;
    private BigInteger exponent;

    public RSAKeyParameters(boolean bl, BigInteger bigInteger, BigInteger bigInteger2) {
        this.isPrivate = bl;
        this.modulus = bigInteger;
        this.exponent = bigInteger2;
    }

    public BigInteger getModulus() {
        return this.modulus;
    }

    public BigInteger getExponent() {
        return this.exponent;
    }

    public boolean isPrivate() {
        return this.isPrivate;
    }
}

