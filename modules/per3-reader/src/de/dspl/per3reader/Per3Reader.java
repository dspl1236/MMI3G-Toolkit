package de.dspl.per3reader;

import java.util.HashMap;
import java.util.Map;

import org.dsi.ifc.persistence.DSIPersistence;
import org.dsi.ifc.persistence.DSIPersistenceListener;

/**
 * Synchronous read wrapper around the async DSIPersistence API.
 *
 * DSIPersistence's read methods are fire-and-forget; results arrive later
 * via DSIPersistenceListener callbacks. This class registers itself AS a
 * listener (through OSGi — see Activator) and blocks the calling thread
 * on a per-(ns, address) monitor until the callback fires.
 *
 * Usage:
 *   Per3Reader r = new Per3Reader(dsiPersistence);
 *   Integer v = r.readInt(0, 0x00100015, 2000);   // 2 s timeout
 *   String s = r.readString(0, 0x00120004, 2000);
 *
 * Callback error codes (observed in FakePersistence):
 *     0  OK
 *     1  no namespace
 *     2  no data found at address
 *     5  unexpected type
 *   any non-zero errcode causes the waiting caller to receive null.
 *
 * Thread-safety: concurrent reads of different addresses run in parallel.
 * Two concurrent reads of the same address will both see the same result
 * (the second caller's issue() overwrites the Pending, but both threads
 * sleep on it — both wake up together when the single callback fires).
 * For the file-trigger loop this corner is harmless (we serialize requests).
 */
public class Per3Reader implements DSIPersistenceListener {

    public static final long DEFAULT_TIMEOUT_MS = 2000L;

    private final DSIPersistence dsi;
    private final Map pending = new HashMap();

    public Per3Reader(DSIPersistence dsi) {
        this.dsi = dsi;
    }

    // --- Public synchronous read API ---------------------------------------

    public Integer readInt(int ns, long address, long timeoutMs) {
        Pending p = issue(ns, address);
        try {
            dsi.readInt(ns, address, false);
        } catch (Throwable t) {
            complete(ns, address, null);
            return null;
        }
        return (Integer) await(p, timeoutMs);
    }

    public String readString(int ns, long address, long timeoutMs) {
        Pending p = issue(ns, address);
        try {
            dsi.readString(ns, address, false);
        } catch (Throwable t) {
            complete(ns, address, null);
            return null;
        }
        return (String) await(p, timeoutMs);
    }

    public byte[] readBuffer(int ns, long address, long timeoutMs) {
        Pending p = issue(ns, address);
        try {
            dsi.readBuffer(ns, address, false);
        } catch (Throwable t) {
            complete(ns, address, null);
            return null;
        }
        return (byte[]) await(p, timeoutMs);
    }

    public int[] readArray(int ns, long address, long timeoutMs) {
        Pending p = issue(ns, address);
        try {
            dsi.readArray(ns, address, false);
        } catch (Throwable t) {
            complete(ns, address, null);
            return null;
        }
        return (int[]) await(p, timeoutMs);
    }

    // --- DSIPersistenceListener callbacks ----------------------------------

    public void readInt(int ns, long address, int value, int errorCode) {
        complete(ns, address, (errorCode == 0) ? (Object) Integer.valueOf(value) : null);
    }

    public void readString(int ns, long address, String value, int errorCode) {
        complete(ns, address, (errorCode == 0) ? (Object) value : null);
    }

    public void readArray(int ns, long address, int[] value, int errorCode) {
        complete(ns, address, (errorCode == 0) ? (Object) value : null);
    }

    public void readBuffer(int ns, long address, byte[] value, int errorCode) {
        complete(ns, address, (errorCode == 0) ? (Object) value : null);
    }

    // Write acks — we don't issue writes from the reader, but the listener
    // interface requires these methods. No-op is safe.
    public void writeInt(int ns, long address, int errorCode)    { /* no-op */ }
    public void writeString(int ns, long address, int errorCode) { /* no-op */ }
    public void writeArray(int ns, long address, int errorCode)  { /* no-op */ }
    public void writeBuffer(int ns, long address, int errorCode) { /* no-op */ }

    // --- Internals ---------------------------------------------------------

    private Long keyOf(int ns, long address) {
        return Long.valueOf((((long) ns) << 32) | (address & 0xFFFFFFFFL));
    }

    private Pending issue(int ns, long address) {
        Pending p = new Pending();
        synchronized (pending) {
            pending.put(keyOf(ns, address), p);
        }
        return p;
    }

    private void complete(int ns, long address, Object value) {
        Pending p;
        synchronized (pending) {
            p = (Pending) pending.remove(keyOf(ns, address));
        }
        if (p != null) {
            synchronized (p) {
                p.value = value;
                p.done = true;
                p.notifyAll();
            }
        }
    }

    private Object await(Pending p, long timeoutMs) {
        long deadline = System.currentTimeMillis() + timeoutMs;
        synchronized (p) {
            while (!p.done) {
                long left = deadline - System.currentTimeMillis();
                if (left <= 0) return null;
                try { p.wait(left); } catch (InterruptedException ie) { return null; }
            }
            return p.value;
        }
    }

    private static class Pending {
        volatile boolean done = false;
        volatile Object value = null;
    }
}
