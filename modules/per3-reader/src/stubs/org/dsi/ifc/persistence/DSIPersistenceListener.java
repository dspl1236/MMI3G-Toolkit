package org.dsi.ifc.persistence;

import org.dsi.ifc.base.DSIListener;

/**
 * Stub of org.dsi.ifc.persistence.DSIPersistenceListener.
 *
 * Callback signatures extracted from FakePersistence.java:
 *   this.listener.readInt(ns, addr, value, errcode)     // errcode 0 = OK
 *   this.listener.readString(ns, addr, value, errcode)
 *   this.listener.writeInt(ns, addr, errcode)
 *   this.listener.writeString(ns, addr, errcode)
 *
 * Note the unusual naming: the listener's methods have the SAME names as
 * DSIPersistence's read* / write* methods. The difference is the arg list —
 * listener callbacks include the result/errcode, DSIPersistence requests do not.
 *
 * Error codes observed in FakePersistence:
 *    0  OK
 *    1  no namespace found
 *    2  no data found at address
 *    5  unexpected type
 * (other codes likely exist in the real implementation — these are what
 * the fake uses).
 *
 * A listener must register itself as an OSGi service of this interface type.
 * DSIPersistence implementations track listeners via their own ServiceTracker
 * on DSIPersistenceListener.
 */
public interface DSIPersistenceListener extends DSIListener {

    // Read result callbacks
    void readInt(int namespace, long address, int value, int errorCode);
    void readString(int namespace, long address, String value, int errorCode);
    void readArray(int namespace, long address, int[] value, int errorCode);
    void readBuffer(int namespace, long address, byte[] value, int errorCode);

    // Write ack callbacks
    void writeInt(int namespace, long address, int errorCode);
    void writeString(int namespace, long address, int errorCode);
    void writeArray(int namespace, long address, int errorCode);
    void writeBuffer(int namespace, long address, int errorCode);
}
