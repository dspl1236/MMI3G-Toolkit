/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.jobs;

import de.audi.tghu.development.jobs.JobRunner;
import de.audi.tghu.development.jobs.SignatureBlockProcessor;
import de.audi.tghu.development.jobs.SignerInfo;
import java.io.FilterInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.security.MessageDigest;
import java.text.MessageFormat;
import java.util.zip.ZipFile;

class DigestedInputStream
extends FilterInputStream {
    private final MessageDigest[] digests;
    private final byte[][] result;
    private final String entry;
    private final ZipFile zipFile;
    private long remaining;

    DigestedInputStream(JobRunner jobRunner, InputStream inputStream, String string, ZipFile zipFile, SignerInfo[] signerInfoArray, byte[][] byArray, long l) throws IOException {
        super(inputStream);
        this.entry = string;
        this.zipFile = zipFile;
        this.remaining = l;
        this.digests = new MessageDigest[signerInfoArray.length];
        for (int i = 0; i < signerInfoArray.length; ++i) {
            this.digests[i] = SignatureBlockProcessor.getMessageDigest(jobRunner, signerInfoArray[i].getMessageDigestAlgorithm());
        }
        this.result = byArray;
    }

    public synchronized void mark(int n) {
    }

    public boolean markSupported() {
        return false;
    }

    public int read() throws IOException {
        if (this.remaining <= 0L) {
            return -1;
        }
        int n = super.read();
        if (n != -1) {
            for (int i = 0; i < this.digests.length; ++i) {
                this.digests[i].update((byte)n);
            }
            --this.remaining;
        } else {
            this.remaining = 0L;
        }
        if (this.remaining == 0L) {
            this.verifyDigests();
        }
        return n;
    }

    private void verifyDigests() throws IOException {
        for (int i = 0; i < this.digests.length; ++i) {
            byte[] byArray = this.digests[i].digest();
            if (MessageDigest.isEqual(this.result[i], byArray)) continue;
            throw new IOException(MessageFormat.format("The file \"{0}\" in the jar \"{1}\" has been tampered!", this.entry, this.zipFile.getName()));
        }
    }

    public int read(byte[] byArray, int n, int n2) throws IOException {
        if (this.remaining <= 0L) {
            return -1;
        }
        int n3 = super.read(byArray, n, n2);
        if (n3 != -1) {
            for (int i = 0; i < this.digests.length; ++i) {
                this.digests[i].update(byArray, n, n3);
            }
            this.remaining -= (long)n3;
        } else {
            this.remaining = 0L;
        }
        if (this.remaining <= 0L) {
            this.verifyDigests();
        }
        return n3;
    }

    public synchronized void reset() throws IOException {
        throw new IOException("Reset not supported");
    }

    public long skip(long l) throws IOException {
        byte[] byArray = new byte[4096];
        long l2 = 0L;
        while (l - l2 > 0L) {
            int n = l - l2 > (long)byArray.length ? byArray.length : (int)(l - l2);
            if ((n = this.read(byArray, 0, n)) == -1) break;
            l2 += (long)n;
            l -= (long)n;
        }
        return l2;
    }
}

