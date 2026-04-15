/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.model;

import de.audi.tghu.development.manager.LogMan;
import de.audi.tghu.development.model.DecoderConsumer;
import java.io.ByteArrayInputStream;
import java.io.DataInputStream;
import java.io.IOException;

public class TLVDecoder {
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
    private static final int STATE_TYPE = 1;
    private static final int STATE_LENGTH = 2;
    private static final int STATE_VALUE = 3;
    private ByteArrayInputStream bais;
    private DataInputStream dis;
    private DecoderConsumer consumer;
    private byte[] data;
    private int state;
    private int dt;
    private int len;

    public TLVDecoder(byte[] byArray, DecoderConsumer decoderConsumer) {
        this.consumer = decoderConsumer;
        this.data = new byte[byArray.length];
        System.arraycopy(byArray, 0, this.data, 0, byArray.length);
        this.bais = new ByteArrayInputStream(byArray);
        this.dis = new DataInputStream(this.bais);
    }

    protected byte _unpack_sbyte() {
        byte by = 0;
        try {
            by = this.dis.readByte();
        }
        catch (IOException iOException) {
            this.state = -1;
        }
        return by;
    }

    protected short _unpack_sshort() {
        short s = 0;
        try {
            s = this.dis.readShort();
        }
        catch (IOException iOException) {
            this.state = -1;
        }
        return s;
    }

    protected int _unpack_sint() {
        int n = 0;
        try {
            n = this.dis.readInt();
        }
        catch (IOException iOException) {
            this.state = -1;
        }
        return n;
    }

    protected short _unpack_ubyte() {
        short s = 0;
        try {
            s = (short)this.dis.readUnsignedByte();
        }
        catch (IOException iOException) {
            this.state = -1;
        }
        return s;
    }

    protected int _unpack_ushort() {
        int n = 0;
        try {
            n = this.dis.readUnsignedShort();
        }
        catch (IOException iOException) {
            this.state = -1;
        }
        return n;
    }

    protected long _unpack_uint() {
        long l = 0L;
        try {
            int n = this.dis.readUnsignedShort();
            int n2 = this.dis.readUnsignedShort();
            l = ((n & 0xFFFF) << 16) + n2;
        }
        catch (IOException iOException) {
            this.state = -1;
        }
        return l;
    }

    protected String _unpack_string() {
        String string = null;
        try {
            byte[] byArray = new byte[this.len];
            this.dis.readFully(byArray, 0, this.len);
            string = new String(byArray, "UTF8");
        }
        catch (IOException iOException) {
            this.state = -1;
        }
        return string;
    }

    protected int decodeType() {
        this.dt = this._unpack_sint();
        if (this.dt == 0) {
            return 0;
        }
        if (this.dt >= 1 && this.dt <= 8) {
            return 2;
        }
        this.dt = 0;
        return -1;
    }

    protected int decodeLength() {
        this.len = this._unpack_sint();
        if (this.len < 0) {
            this.len = 0;
            return -1;
        }
        return 3;
    }

    protected int decodeValue() {
        switch (this.dt) {
            case 1: {
                this.consumer.consumeElement(this.dt, new Byte(this._unpack_sbyte()));
                break;
            }
            case 2: {
                this.consumer.consumeElement(this.dt, new Short(this._unpack_sshort()));
                break;
            }
            case 3: {
                this.consumer.consumeElement(this.dt, new Integer(this._unpack_sint()));
                break;
            }
            case 5: {
                this.consumer.consumeElement(this.dt, new Short(this._unpack_ubyte()));
                break;
            }
            case 6: {
                this.consumer.consumeElement(this.dt, new Integer(this._unpack_ushort()));
                break;
            }
            case 7: {
                this.consumer.consumeElement(this.dt, new Long(this._unpack_uint()));
                break;
            }
            case 8: {
                this.consumer.consumeElement(this.dt, this._unpack_string());
                break;
            }
            default: {
                return -1;
            }
        }
        return 1;
    }

    public void decode() {
        this.state = 1;
        block5: while (this.state != 0 && this.state != -1) {
            switch (this.state) {
                case 1: {
                    this.state = this.decodeType();
                    continue block5;
                }
                case 2: {
                    this.state = this.decodeLength();
                    continue block5;
                }
                case 3: {
                    this.state = this.decodeValue();
                    continue block5;
                }
            }
            LogMan.log("TLVDecoder.decode(): invalid state " + this.state);
        }
    }
}

