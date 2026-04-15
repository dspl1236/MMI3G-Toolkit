/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.eis;

import de.audi.tghu.development.eis.EISListener;
import de.audi.tghu.development.util.HashtableOfLong;

public class Namespace {
    private int namespaceId;
    private HashtableOfLong map;

    public Namespace(int n) {
        this.namespaceId = n;
        this.map = new HashtableOfLong();
    }

    public int getId() {
        return this.namespaceId;
    }

    public EISListener getEISListener(long l) {
        return (EISListener)this.map.get(l);
    }

    public boolean containsEISListener(long l) {
        return this.map.containsKey(l);
    }

    public EISListener removeEISListener(long l) {
        return (EISListener)this.map.remove(l);
    }

    public EISListener putEISListener(long l, EISListener eISListener) {
        return (EISListener)this.map.put(l, eISListener);
    }

    public String toString() {
        return "Namespace id=" + this.namespaceId + " keys=" + this.arrayToString(this.map.keys());
    }

    private String arrayToString(long[] lArray) {
        StringBuffer stringBuffer = new StringBuffer();
        stringBuffer.append("[");
        for (int i = 0; i < lArray.length; ++i) {
            if (i > 0) {
                stringBuffer.append(";");
            }
            stringBuffer.append(lArray[i]);
        }
        stringBuffer.append("]");
        return stringBuffer.toString();
    }
}

