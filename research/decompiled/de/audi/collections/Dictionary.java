/*
 * Decompiled with CFR 0.152.
 */
package de.audi.collections;

import de.audi.tghu.development.manager.LogMan;
import java.util.Iterator;
import java.util.Vector;

public class Dictionary {
    private Vector entries = new Vector();

    public void put(int n, Object object) {
        LogMan.log("Dictionary.put -> key = " + n + " value = " + object);
        Entry entry = new Entry(n, object);
        this.entries.add(entry);
    }

    public Object get(int n) {
        Object object = null;
        Iterator iterator = this.entries.iterator();
        while (iterator.hasNext()) {
            Entry entry = (Entry)iterator.next();
            if (n != entry.key) continue;
            object = entry.value;
            LogMan.log("Dictionary.get -> key = " + n + " value = " + object);
            break;
        }
        return object;
    }

    public Object remove(int n) {
        Object object = null;
        Iterator iterator = this.entries.iterator();
        while (iterator.hasNext()) {
            Entry entry = (Entry)iterator.next();
            if (n != entry.key) continue;
            object = entry.value;
            iterator.remove();
            break;
        }
        return object;
    }

    public void clear() {
        this.entries.clear();
    }

    private class Entry {
        private int key;
        private Object value;

        public Entry(int n, Object object) {
            this.key = n;
            this.value = object;
        }
    }
}

