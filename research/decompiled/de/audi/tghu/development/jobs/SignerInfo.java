/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.jobs;

public class SignerInfo {
    public static final SignerInfo MD5_SIGNER = new SignerInfo("MD5");
    public static final SignerInfo SHA1_SIGNER = new SignerInfo("SHA1");
    private String digAlg;

    public static SignerInfo getSignerInfo(String string) {
        if (string.equals("SHA1")) {
            return SHA1_SIGNER;
        }
        if (string.equals("MD5")) {
            return MD5_SIGNER;
        }
        return null;
    }

    private SignerInfo(String string) {
        this.digAlg = string;
    }

    public String getMessageDigestAlgorithm() {
        return this.digAlg;
    }
}

