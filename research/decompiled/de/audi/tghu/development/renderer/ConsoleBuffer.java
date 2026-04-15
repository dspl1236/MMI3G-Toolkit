/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.renderer;

import java.util.ArrayList;
import java.util.Observable;

public class ConsoleBuffer
extends Observable {
    String[] lines = null;
    int bufferSize = 0;
    int position = 0;

    public ConsoleBuffer(int n) {
        this.lines = new String[n];
        this.bufferSize = n;
    }

    public void addLine(String string) {
        if (this.position == this.bufferSize - 1) {
            this.moveBuffer();
        }
        this.lines[this.position] = string;
        if (this.position < this.bufferSize - 1) {
            ++this.position;
        }
        this.setChanged();
    }

    public String removeLine() {
        String string = null;
        if (this.position > 0) {
            string = this.lines[0];
            this.moveBuffer();
            --this.position;
        }
        return string;
    }

    public void setBuffer(char[] cArray) {
        this.lines = this.getLines(cArray);
        this.bufferSize = this.lines.length;
        this.setChanged();
        this.notifyObservers(this.lines);
    }

    private String[] getLines(char[] cArray) {
        ArrayList<String> arrayList = new ArrayList<String>(this.bufferSize);
        StringBuffer stringBuffer = new StringBuffer(100);
        for (int i = 0; i < cArray.length; ++i) {
            char c = cArray[i];
            if (c == '\n') {
                arrayList.add(stringBuffer.toString());
                stringBuffer.setLength(0);
                continue;
            }
            stringBuffer.append(c);
        }
        if (stringBuffer.length() > 0) {
            arrayList.add(stringBuffer.toString());
        }
        return arrayList.toArray(new String[arrayList.size()]);
    }

    private void moveBuffer() {
        for (int i = 0; i < this.bufferSize - 1; ++i) {
            this.lines[i] = this.lines[i + 1];
        }
    }
}

