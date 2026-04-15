/*
 * Decompiled with CFR 0.152.
 */
package de.audi.commons.tools;

public class HexDumpConverter {
    private static char[] hex = new char[]{'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'};

    public static String toHexAsciiString(byte[] byArray) {
        String string = "";
        if (byArray != null && byArray.length > 0) {
            StringBuffer stringBuffer = new StringBuffer(2 * byArray.length);
            for (int i = 0; i < byArray.length; ++i) {
                stringBuffer.append(hex[byArray[i] >>> 4 & 0xF]).append(hex[byArray[i] & 0xF]);
            }
            string = stringBuffer.toString();
        }
        return string;
    }

    public static byte[] toByteArray(String string) {
        byte[] byArray = new byte[string.length() / 2];
        for (int i = 0; i < byArray.length; ++i) {
            String string2 = string.substring(2 * i, 2 * i + 2);
            byArray[i] = (byte)Integer.parseInt(string2, 16);
        }
        return byArray;
    }
}

