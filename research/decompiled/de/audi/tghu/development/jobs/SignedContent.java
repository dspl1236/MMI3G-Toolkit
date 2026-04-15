/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.jobs;

import de.audi.crypto.KeyParameter;
import de.audi.crypto.RC4Engine;
import de.audi.tghu.development.jobs.DigestedInputStream;
import de.audi.tghu.development.jobs.JobRunner;
import de.audi.tghu.development.jobs.ScrambledInputStream;
import de.audi.tghu.development.jobs.SignerInfo;
import java.io.IOException;
import java.io.InputStream;
import java.util.HashMap;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;

public class SignedContent {
    static final SignerInfo[] EMPTY_SIGNERINFO = new SignerInfo[0];
    volatile ZipFile content;
    private final HashMap contentMDResults;
    private final SignerInfo[] signerInfos;
    private final byte[] scramblerKey;

    public SignedContent(SignerInfo[] signerInfoArray, HashMap hashMap, byte[] byArray) {
        this.signerInfos = signerInfoArray == null ? EMPTY_SIGNERINFO : signerInfoArray;
        this.contentMDResults = hashMap;
        byte[] byArray2 = new byte[4];
        if (byArray != null) {
            for (int i = 0; i < byArray.length || i < 4; ++i) {
                byArray2[i] = byArray[i];
            }
        }
        this.scramblerKey = byArray2;
    }

    public SignerInfo[] getSignerInfos() {
        return this.signerInfos;
    }

    public boolean isSigned() {
        return this.signerInfos.length > 0;
    }

    void setContent(ZipFile zipFile) {
        this.content = zipFile;
    }

    ZipFile getContent() {
        return this.content;
    }

    HashMap getContentMDResults() {
        return this.contentMDResults;
    }

    InputStream getDigestInputStream(JobRunner jobRunner, InputStream inputStream, String string, long l) throws IOException {
        if (this.contentMDResults == null) {
            return inputStream;
        }
        Object[] objectArray = (Object[])this.contentMDResults.get(string);
        if (objectArray == null) {
            return null;
        }
        return new DigestedInputStream(jobRunner, inputStream, string, this.content, (SignerInfo[])objectArray[0], (byte[][])objectArray[1], l);
    }

    InputStream getEntryInputStream(JobRunner jobRunner, ZipEntry zipEntry, String string) throws IOException {
        InputStream inputStream = this.content.getInputStream(zipEntry);
        RC4Engine rC4Engine = new RC4Engine();
        int n = string.hashCode();
        byte[] byArray = new byte[]{(byte)(n >>> 24 & 0xFF), (byte)(n >>> 16 & 0xFF), (byte)(n >>> 8 & 0xFF), (byte)(n >>> 0 & 0xFF)};
        byArray[0] = (byte)(byArray[0] ^ this.scramblerKey[0]);
        byArray[1] = (byte)(byArray[1] ^ this.scramblerKey[2]);
        byArray[2] = (byte)(byArray[2] ^ this.scramblerKey[1]);
        byArray[3] = (byte)(byArray[3] ^ this.scramblerKey[3]);
        rC4Engine.init(false, new KeyParameter(byArray));
        ScrambledInputStream scrambledInputStream = new ScrambledInputStream(rC4Engine, inputStream);
        return this.getDigestInputStream(jobRunner, scrambledInputStream, string, zipEntry.getSize());
    }
}

