/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.util;

public final class HashtableOfLong {
    public long[] keyTable;
    public Object[] valueTable;
    public int elementSize = 0;
    int threshold;

    public HashtableOfLong() {
        this(13);
    }

    public HashtableOfLong(int n) {
        this.threshold = n;
        int n2 = (int)((float)n * 1.75f);
        if (this.threshold == n2) {
            ++n2;
        }
        this.keyTable = new long[n2];
        this.valueTable = new Object[n2];
    }

    public boolean containsKey(long l) {
        long l2;
        int n = (int)(l >>> 32) % this.valueTable.length;
        while ((l2 = this.keyTable[n]) != 0L) {
            if (l2 == l) {
                return true;
            }
            n = (n + 1) % this.keyTable.length;
        }
        return false;
    }

    public Object remove(long l) {
        long l2;
        int n = (int)(l >>> 32) % this.valueTable.length;
        while ((l2 = this.keyTable[n]) != 0L) {
            if (l2 == l) {
                this.keyTable[n] = 0L;
                Object object = this.valueTable[n];
                this.valueTable[n] = null;
                return object;
            }
            n = (n + 1) % this.keyTable.length;
        }
        return null;
    }

    public Object get(long l) {
        long l2;
        int n = (int)(l >>> 32) % this.valueTable.length;
        while ((l2 = this.keyTable[n]) != 0L) {
            if (l2 == l) {
                return this.valueTable[n];
            }
            n = (n + 1) % this.keyTable.length;
        }
        return null;
    }

    public Object put(long l, Object object) {
        long l2;
        int n = (int)(l >>> 32) % this.valueTable.length;
        while ((l2 = this.keyTable[n]) != 0L) {
            if (l2 == l) {
                this.valueTable[n] = object;
                return this.valueTable[n];
            }
            n = (n + 1) % this.keyTable.length;
        }
        this.keyTable[n] = l;
        this.valueTable[n] = object;
        if (++this.elementSize > this.threshold) {
            this.rehash();
        }
        return object;
    }

    private void rehash() {
        HashtableOfLong hashtableOfLong = new HashtableOfLong(this.elementSize * 2);
        int n = this.keyTable.length;
        while (--n >= 0) {
            long l = this.keyTable[n];
            if (l == 0L) continue;
            hashtableOfLong.put(l, this.valueTable[n]);
        }
        this.keyTable = hashtableOfLong.keyTable;
        this.valueTable = hashtableOfLong.valueTable;
        this.threshold = hashtableOfLong.threshold;
    }

    public int size() {
        return this.elementSize;
    }

    public String toString() {
        String string = "";
        int n = this.valueTable.length;
        for (int i = 0; i < n; ++i) {
            Object object = this.valueTable[i];
            if (object == null) continue;
            string = string + this.keyTable[i] + " -> " + object.toString() + "\n";
        }
        return string;
    }

    public long[] keys() {
        long[] lArray = new long[this.elementSize];
        int n = 0;
        for (int i = 0; i < this.keyTable.length; ++i) {
            long l = this.keyTable[i];
            if (l == 0L) continue;
            lArray[n] = l;
            ++n;
        }
        return lArray;
    }
}

