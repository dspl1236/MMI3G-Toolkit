/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.model;

import java.io.ByteArrayOutputStream;
import java.io.DataOutputStream;
import java.io.IOException;

public class TLVEncoder {
    public static final int DT_TERM = 0;
    public static final int DT_SBYTE = 1;
    public static final int DT_SSHORT = 2;
    public static final int DT_SINT = 3;
    public static final int DT_UBYTE = 5;
    public static final int DT_USHORT = 6;
    public static final int DT_UINT = 7;
    public static final int DT_STRING = 8;
    private static final int STATE_ERROR = -1;
    private static final int STATE_EOM = 0;
    private static final int BUFSIZE = 2048;
    private ByteArrayOutputStream baos = new ByteArrayOutputStream(2048);
    private DataOutputStream dos = new DataOutputStream(this.baos);
    private int state;

    public void encodeSByte(byte by) {
        try {
            this.dos.writeInt(1);
            this.dos.writeInt(1);
            this.dos.writeByte(by);
        }
        catch (IOException iOException) {
            this.state = -1;
        }
    }

    public void encodeSShort(short s) {
        try {
            this.dos.writeInt(2);
            this.dos.writeInt(2);
            this.dos.writeShort(s);
        }
        catch (IOException iOException) {
            this.state = -1;
        }
    }

    public void encodeSInt(int n) {
        try {
            this.dos.writeInt(3);
            this.dos.writeInt(4);
            this.dos.writeInt(n);
        }
        catch (IOException iOException) {
            this.state = -1;
        }
    }

    public void encodeUByte(short s) {
        try {
            this.dos.writeInt(5);
            this.dos.writeInt(1);
            this.dos.writeByte(s & 0xFF);
        }
        catch (IOException iOException) {
            this.state = -1;
        }
    }

    public void encodeUShort(int n) {
        try {
            this.dos.writeInt(6);
            this.dos.writeInt(2);
            this.dos.writeShort(n & 0xFFFF);
        }
        catch (IOException iOException) {
            this.state = -1;
        }
    }

    public void encodeUInt(long l) {
        try {
            this.dos.writeInt(7);
            this.dos.writeInt(4);
            this.dos.writeInt((int)(l & 0xFFFFFFFFFFFFFFFFL));
        }
        catch (IOException iOException) {
            this.state = -1;
        }
    }

    public void encodeString(String string) {
        try {
            byte[] byArray = string.getBytes("UTF8");
            this.dos.writeInt(8);
            this.dos.writeInt(byArray.length);
            this.dos.write(byArray);
        }
        catch (IOException iOException) {
            this.state = -1;
        }
    }

    public void terminate() {
        try {
            this.dos.writeInt(0);
            this.state = 0;
        }
        catch (IOException iOException) {
            this.state = -1;
        }
    }

    public byte[] getResult() {
        if (this.state != 0) {
            return null;
        }
        return this.baos.toByteArray();
    }
}

