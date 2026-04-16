package de.dspl.per3reader.test;

import java.util.HashMap;
import java.util.Map;

import org.dsi.ifc.base.DSIFatalException;
import org.dsi.ifc.base.DSINonFatalException;
import org.dsi.ifc.base.DSIListener;
import org.dsi.ifc.persistence.DSIPersistence;
import org.dsi.ifc.persistence.DSIPersistenceListener;

/**
 * Minimal in-memory implementation of DSIPersistence for offline testing.
 *
 * Populated via put() in test setup, delivers reads synchronously through
 * the registered DSIPersistenceListener (same callback semantics as the
 * real DSI implementation and FakePersistence, but without the OSGi
 * ServiceTracker indirection).
 *
 * Error codes match FakePersistence:
 *    0  OK
 *    1  no namespace
 *    2  no data at address
 *    5  unexpected type
 */
public class MockDSIPersistence implements DSIPersistence {

    private final Map<Long, Object> values = new HashMap<Long, Object>();
    private DSIPersistenceListener listener;

    public void setListener(DSIPersistenceListener l) {
        this.listener = l;
    }

    // Convenience populators ------------------------------------------------

    public MockDSIPersistence putInt(int ns, long addr, int v) {
        values.put(Long.valueOf(k(ns, addr)), Integer.valueOf(v));
        return this;
    }

    public MockDSIPersistence putString(int ns, long addr, String v) {
        values.put(Long.valueOf(k(ns, addr)), v);
        return this;
    }

    public MockDSIPersistence putBuffer(int ns, long addr, byte[] v) {
        values.put(Long.valueOf(k(ns, addr)), v);
        return this;
    }

    public MockDSIPersistence putArray(int ns, long addr, int[] v) {
        values.put(Long.valueOf(k(ns, addr)), v);
        return this;
    }

    private long k(int ns, long addr) {
        return (((long) ns) << 32) | (addr & 0xFFFFFFFFL);
    }

    // DSIPersistence surface ------------------------------------------------

    public void readInt(int ns, long addr) { readInt(ns, addr, false); }

    public void readInt(int ns, long addr, boolean nb) {
        if (listener == null) return;
        Object v = values.get(Long.valueOf(k(ns, addr)));
        if (v == null) { listener.readInt(ns, addr, -1, 2); return; }
        if (v instanceof Integer) { listener.readInt(ns, addr, ((Integer) v).intValue(), 0); return; }
        listener.readInt(ns, addr, -1, 5);
    }

    public void readString(int ns, long addr) { readString(ns, addr, false); }

    public void readString(int ns, long addr, boolean nb) {
        if (listener == null) return;
        Object v = values.get(Long.valueOf(k(ns, addr)));
        if (v == null) { listener.readString(ns, addr, null, 2); return; }
        if (v instanceof String) { listener.readString(ns, addr, (String) v, 0); return; }
        listener.readString(ns, addr, null, 5);
    }

    public void readBuffer(int ns, long addr) { readBuffer(ns, addr, false); }

    public void readBuffer(int ns, long addr, boolean nb) {
        if (listener == null) return;
        Object v = values.get(Long.valueOf(k(ns, addr)));
        if (v == null) { listener.readBuffer(ns, addr, null, 2); return; }
        if (v instanceof byte[]) { listener.readBuffer(ns, addr, (byte[]) v, 0); return; }
        listener.readBuffer(ns, addr, null, 5);
    }

    public void readArray(int ns, long addr) { readArray(ns, addr, false); }

    public void readArray(int ns, long addr, boolean nb) {
        if (listener == null) return;
        Object v = values.get(Long.valueOf(k(ns, addr)));
        if (v == null) { listener.readArray(ns, addr, null, 2); return; }
        if (v instanceof int[]) { listener.readArray(ns, addr, (int[]) v, 0); return; }
        listener.readArray(ns, addr, null, 5);
    }

    // --- Unused in our tests but required by interface --------------------

    public void readIntSet(int ns, long addr, int n) { }
    public void readStringSet(int ns, long addr, int n) { }
    public void readIntArraySet(int ns, long addr, int n) { }
    public void readObjectSet(int ns, long addr, int n) { }

    public void writeInt(int ns, long addr, int v) { }
    public void writeInt(int ns, long addr, int v, boolean nb) { }
    public void writeString(int ns, long addr, String v) { }
    public void writeString(int ns, long addr, String v, boolean nb) { }
    public void writeArray(int ns, long addr, int[] v) { }
    public void writeArray(int ns, long addr, int[] v, boolean nb) { }
    public void writeBuffer(int ns, long addr, byte[] v) { }
    public void writeBuffer(int ns, long addr, byte[] v, boolean nb) { }

    public void writeIntSet(int ns, long addr, int n, int[] v) { }
    public void writeStringSet(int ns, long addr, int n, String[] v) { }
    public void writIntArraySet(int ns, long addr, int n, int[] v) { }
    public void writeObjectSet(int ns, long addr, int n, byte[] v) { }

    public void addNotification(int ns, long[] addrs) { }
    public void removeNotification(int ns, long[] addrs) { }

    public void setNotification(DSIListener l) { }
    public void setNotification(short ns, DSIListener l) { }
    public void setNotification(short[] ns, DSIListener l) { }

    public void clearNotification(DSIListener l) { }
    public void clearNotification(short ns, DSIListener l) { }
    public void clearNotification(short[] ns, DSIListener l) { }

    public void enterEngineeringSession(int s) { }
    public void exitEngineeringSession(int s) { }
    public void enterGreenEngineeringMenu() { }
    public void leaveGreenEngineeringMenu() { }
    public void flushSQLDatabase() { }
    public void flushSQLDatabase(boolean s) { }
    public void setSQLDatabaseMedium(int m) { }
    public void getVisibleSystemLanguages() { }

    public String getName() { return "MockDSIPersistence"; }
    public String getServiceAdapterVersion() { return "mock-0.2"; }
}
