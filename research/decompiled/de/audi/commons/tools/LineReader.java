/*
 * Decompiled with CFR 0.152.
 */
package de.audi.commons.tools;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.LineNumberReader;
import java.io.UnsupportedEncodingException;

public class LineReader {
    private File file;
    private FileInputStream fileInputStream;
    private InputStreamReader inputStreamReader;
    private LineNumberReader reader;
    private boolean prepared;

    public LineReader() {
        this.prepared = false;
    }

    public LineReader(File file) throws FileNotFoundException, UnsupportedEncodingException {
        this.prepareReader(file);
    }

    public LineReader(String string) throws FileNotFoundException, UnsupportedEncodingException {
        this.setFile(string);
    }

    public void setFile(String string) throws FileNotFoundException, UnsupportedEncodingException {
        this.file = new File(string);
        this.prepareReader(this.file);
    }

    public void setFile(File file) throws FileNotFoundException, UnsupportedEncodingException {
        this.file = file;
        this.prepareReader(file);
    }

    private void prepareReader(File file) throws FileNotFoundException, UnsupportedEncodingException {
        this.fileInputStream = new FileInputStream(file);
        this.inputStreamReader = new InputStreamReader((InputStream)this.fileInputStream, "CP1252");
        this.reader = new LineNumberReader(this.inputStreamReader);
        this.prepared = true;
    }

    public String readln() throws IOException {
        String string = null;
        if (this.prepared) {
            string = this.reader.readLine();
        }
        return string;
    }

    public int getLastReadLine() {
        int n = 0;
        if (this.prepared) {
            n = this.reader.getLineNumber() - 1;
        }
        return n;
    }

    public boolean ready() throws IOException {
        boolean bl = false;
        if (this.prepared) {
            bl = this.reader.ready();
        }
        return bl;
    }

    public String getFileName() {
        String string = null;
        if (this.prepared) {
            string = this.file.getName();
        }
        return string;
    }

    public void mark() throws IOException {
        this.reader.mark(255);
    }

    public void reset() throws IOException {
        this.reader.reset();
    }

    public void close() throws IOException {
        this.reader.close();
        this.inputStreamReader.close();
        this.fileInputStream.close();
        this.prepared = false;
    }
}

