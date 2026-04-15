/*
 * Decompiled with CFR 0.152.
 */
package de.audi.commons.tools;

import java.io.BufferedWriter;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.io.OutputStreamWriter;
import java.io.UnsupportedEncodingException;

public class LineWriter {
    private transient File file;
    private transient FileOutputStream fileOutputStream;
    private transient OutputStreamWriter streamWriter;
    private transient BufferedWriter writer;
    private transient int lineCounter;

    public LineWriter(File file) throws FileNotFoundException, UnsupportedEncodingException {
        this.prepareStreams(file, false);
    }

    public LineWriter(File file, boolean bl) throws FileNotFoundException, UnsupportedEncodingException {
        this.prepareStreams(file, bl);
    }

    public LineWriter(String string, boolean bl) throws FileNotFoundException, UnsupportedEncodingException {
        this.file = new File(string);
        this.prepareStreams(this.file, bl);
    }

    public LineWriter(String string) throws FileNotFoundException, UnsupportedEncodingException {
        this.file = new File(string);
        this.prepareStreams(this.file, false);
    }

    private void prepareStreams(File file, boolean bl) throws FileNotFoundException, UnsupportedEncodingException {
        this.fileOutputStream = new FileOutputStream(file.getPath(), bl);
        this.streamWriter = new OutputStreamWriter((OutputStream)this.fileOutputStream, "CP1252");
        this.writer = new BufferedWriter(this.streamWriter);
        this.lineCounter = 0;
    }

    public void writeln() throws IOException {
        this.writeln("");
    }

    public void writeln(String string) throws IOException {
        this.writer.write(string);
        this.writer.newLine();
        ++this.lineCounter;
    }

    public int getLinesWritten() {
        return this.lineCounter;
    }

    public void close() throws IOException {
        this.writer.close();
        this.streamWriter.close();
        this.fileOutputStream.close();
    }
}

