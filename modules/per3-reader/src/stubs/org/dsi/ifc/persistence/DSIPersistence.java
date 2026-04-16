package org.dsi.ifc.persistence;

import org.dsi.ifc.base.DSIBase;
import org.dsi.ifc.base.DSIListener;
import org.dsi.ifc.base.DSIFatalException;
import org.dsi.ifc.base.DSINonFatalException;

/**
 * Stub of org.dsi.ifc.persistence.DSIPersistence for offline compilation.
 *
 * Real signatures extracted from decompiled
 * de/audi/tghu/sim/persistence/FakePersistence.java which
 * "implements DSIPersistence".
 *
 * Key design note: all read* methods are FIRE-AND-FORGET — they don't return
 * the value. Results are delivered asynchronously to a DSIPersistenceListener
 * that the caller must register separately (via OSGi service registration,
 * not a direct setListener() call — FakePersistence tracks the listener
 * via its own internal ServiceTracker).
 *
 * The real dsi.jar on the MMI /lsd/ provides the backing implementation.
 */
public interface DSIPersistence extends DSIBase {

    // --- Read API (async — results via DSIPersistenceListener) -----------

    void readInt(int namespace, long address) throws DSINonFatalException, DSIFatalException;
    void readInt(int namespace, long address, boolean nonBlocking) throws DSINonFatalException, DSIFatalException;

    void readString(int namespace, long address) throws DSINonFatalException, DSIFatalException;
    void readString(int namespace, long address, boolean nonBlocking) throws DSINonFatalException, DSIFatalException;

    void readArray(int namespace, long address) throws DSINonFatalException, DSIFatalException;
    void readArray(int namespace, long address, boolean nonBlocking) throws DSINonFatalException, DSIFatalException;

    void readBuffer(int namespace, long address) throws DSINonFatalException, DSIFatalException;
    void readBuffer(int namespace, long address, boolean nonBlocking) throws DSINonFatalException, DSIFatalException;

    // Set reads — for bulk address enumeration
    void readIntSet(int namespace, long address, int count) throws DSINonFatalException, DSIFatalException;
    void readStringSet(int namespace, long address, int count) throws DSINonFatalException, DSIFatalException;
    void readIntArraySet(int namespace, long address, int count) throws DSINonFatalException, DSIFatalException;
    void readObjectSet(int namespace, long address, int count) throws DSINonFatalException, DSIFatalException;

    // --- Write API --------------------------------------------------------

    void writeInt(int namespace, long address, int value) throws DSINonFatalException, DSIFatalException;
    void writeString(int namespace, long address, String value) throws DSINonFatalException, DSIFatalException;
    void writeArray(int namespace, long address, int[] value) throws DSINonFatalException, DSIFatalException;
    void writeBuffer(int namespace, long address, byte[] value) throws DSINonFatalException, DSIFatalException;

    // --- Notification / subscription -------------------------------------

    void addNotification(int namespace, long[] addresses) throws DSINonFatalException, DSIFatalException;
    void clearNotification(DSIListener listener) throws DSIFatalException, DSINonFatalException;
    void clearNotification(short ns, DSIListener listener) throws DSIFatalException, DSINonFatalException;
    void clearNotification(short[] nsArray, DSIListener listener) throws DSIFatalException, DSINonFatalException;

    // --- Session / engineering -------------------------------------------

    void enterEngineeringSession(int sessionId) throws DSINonFatalException, DSIFatalException;
    void exitEngineeringSession(int sessionId) throws DSINonFatalException, DSIFatalException;
    void enterGreenEngineeringMenu() throws DSINonFatalException, DSIFatalException;
    void leaveGreenEngineeringMenu() throws DSINonFatalException, DSIFatalException;
    void flushSQLDatabase() throws DSINonFatalException, DSIFatalException;
    void flushSQLDatabase(boolean sync) throws DSINonFatalException, DSIFatalException;
    void getVisibleSystemLanguages() throws DSINonFatalException, DSIFatalException;

    // --- Identification ---------------------------------------------------

    String getName();
    String getServiceAdapterVersion();
}
