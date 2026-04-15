/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.jobs;

import de.audi.crypto.StreamCipher;
import java.io.FilterInputStream;
import java.io.IOException;
import java.io.InputStream;

public class ScrambledInputStream
extends FilterInputStream {
    private StreamCipher sc;

    protected ScrambledInputStream(StreamCipher streamCipher, InputStream inputStream) {
        super(inputStream);
        this.sc = streamCipher;
    }

    public int read() throws IOException {
        int n = this.in.read();
        if (n == -1) {
            return -1;
        }
        return this.sc.returnByte((byte)n) & 0xFF;
    }

    public int read(byte[] byArray, int n, int n2) throws IOException {
        int n3 = this._read(this.in, byArray, n, n2);
        if (n3 == -1) {
            return -1;
        }
        this.sc.processBytes(byArray, n, n3, byArray, n);
        return n3;
    }

    private int _read(InputStream inputStream, byte[] byArray, int n, int n2) throws IOException {
        int n3;
        if (n2 <= 0) {
            return 0;
        }
        int n4 = inputStream.read();
        if (n4 == -1) {
            return -1;
        }
        if (byArray != null) {
            byArray[n] = (byte)n4;
        }
        for (n3 = 1; n3 < n2 && (n4 = inputStream.read()) != -1; ++n3) {
            if (byArray == null) continue;
            byArray[n + n3] = (byte)n4;
        }
        return n3;
    }

    public boolean markSupported() {
        return false;
    }

    public synchronized void reset() throws IOException {
        throw new IOException("mark/reset not supported");
    }

    public synchronized void mark(int n) {
    }
}

