package org.dsi.ifc.persistence;

import org.dsi.ifc.base.DSIBase;
import org.dsi.ifc.base.DSIListener;
import org.dsi.ifc.base.DSIFatalException;
import org.dsi.ifc.base.DSINonFatalException;

/**
 * Stub of org.dsi.ifc.persistence.DSIPersistence for offline compilation.
 *
 * GROUND-TRUTH SIGNATURES extracted from de.audi.tghu.sim.persistence.FakePersistence
 * (which "implements DSIPersistence") via javap -p on the real
 * AppDevelopment.jar carved from HN+R_EU_AU_K0942_4 MU9411 variant 61.
 *
 * Key design note: all read* methods are FIRE-AND-FORGET — they don't return
 * the value. Results are delivered asynchronously to a DSIPersistenceListener
 * that registers with the DSI implementation's internal ServiceTracker as
 * an OSGi service. FakePersistence.initialize() demonstrates the inverse
 * pattern — it uses a ServiceTracker to find registered listeners.
 *
 * The 4-argument overloads (readInt/readString with trailing boolean) are
 * the non-blocking variants. The 3-arg overloads were the original API;
 * FakePersistence implements BOTH. Our stub reflects that — if we only
 * stubbed one, Per3Reader's compile would work but runtime method resolution
 * might pick the wrong overload.
 *
 * We do NOT implement this interface in Per3Reader — we only consume it.
 * So mismatches here would cause NoSuchMethodError when Per3Reader tries
 * to call a method that doesn't exist on the real interface, not
 * AbstractMethodError at class load.
 */
public interface DSIPersistence extends DSIBase {

    // --- Read API (async — results via DSIPersistenceListener) ---
    // Both 3-arg (legacy) and 4-arg (with nonBlocking flag) overloads exist.

    void readInt(int namespace, long address) throws DSINonFatalException, DSIFatalException;
    void readInt(int namespace, long address, boolean nonBlocking) throws DSINonFatalException, DSIFatalException;

    void readString(int namespace, long address) throws DSINonFatalException, DSIFatalException;
    void readString(int namespace, long address, boolean nonBlocking) throws DSINonFatalException, DSIFatalException;

    void readArray(int namespace, long address) throws DSINonFatalException, DSIFatalException;
    void readArray(int namespace, long address, boolean nonBlocking) throws DSINonFatalException, DSIFatalException;

    void readBuffer(int namespace, long address) throws DSINonFatalException, DSIFatalException;
    void readBuffer(int namespace, long address, boolean nonBlocking) throws DSINonFatalException, DSIFatalException;

    // Set-style bulk reads
    void readIntSet(int namespace, long address, int count) throws DSINonFatalException, DSIFatalException;
    void readStringSet(int namespace, long address, int count) throws DSINonFatalException, DSIFatalException;
    void readIntArraySet(int namespace, long address, int count) throws DSINonFatalException, DSIFatalException;
    void readObjectSet(int namespace, long address, int count) throws DSINonFatalException, DSIFatalException;

    // --- Write API ---
    // 3-arg (legacy) and 4-arg (with nonBlocking flag) overloads.

    void writeInt(int namespace, long address, int value) throws DSINonFatalException, DSIFatalException;
    void writeInt(int namespace, long address, int value, boolean nonBlocking) throws DSINonFatalException, DSIFatalException;

    void writeString(int namespace, long address, String value) throws DSINonFatalException, DSIFatalException;
    void writeString(int namespace, long address, String value, boolean nonBlocking) throws DSINonFatalException, DSIFatalException;

    void writeArray(int namespace, long address, int[] value) throws DSINonFatalException, DSIFatalException;
    void writeArray(int namespace, long address, int[] value, boolean nonBlocking) throws DSINonFatalException, DSIFatalException;

    void writeBuffer(int namespace, long address, byte[] value) throws DSINonFatalException, DSIFatalException;
    void writeBuffer(int namespace, long address, byte[] value, boolean nonBlocking) throws DSINonFatalException, DSIFatalException;

    // Set-style bulk writes (note: writIntArraySet has a typo in the real API — "writ" not "write")
    void writeIntSet(int namespace, long address, int count, int[] values) throws DSINonFatalException, DSIFatalException;
    void writeStringSet(int namespace, long address, int count, String[] values) throws DSINonFatalException, DSIFatalException;
    void writIntArraySet(int namespace, long address, int count, int[] values) throws DSINonFatalException, DSIFatalException;
    void writeObjectSet(int namespace, long address, int count, byte[] values) throws DSINonFatalException, DSIFatalException;

    // --- Notification / subscription ---
    // addNotification + removeNotification for a specific ns + address list,
    // setNotification / clearNotification for listener registration by scope.

    void addNotification(int namespace, long[] addresses) throws DSINonFatalException, DSIFatalException;
    void removeNotification(int namespace, long[] addresses) throws DSINonFatalException, DSIFatalException;

    void setNotification(DSIListener listener) throws DSIFatalException, DSINonFatalException;
    void setNotification(short ns, DSIListener listener) throws DSIFatalException, DSINonFatalException;
    void setNotification(short[] nsArray, DSIListener listener) throws DSIFatalException, DSINonFatalException;

    void clearNotification(DSIListener listener) throws DSIFatalException, DSINonFatalException;
    void clearNotification(short ns, DSIListener listener) throws DSIFatalException, DSINonFatalException;
    void clearNotification(short[] nsArray, DSIListener listener) throws DSIFatalException, DSINonFatalException;

    // --- Session / engineering ---

    void enterEngineeringSession(int sessionId) throws DSINonFatalException, DSIFatalException;
    void exitEngineeringSession(int sessionId) throws DSINonFatalException, DSIFatalException;
    void enterGreenEngineeringMenu() throws DSINonFatalException, DSIFatalException;
    void leaveGreenEngineeringMenu() throws DSINonFatalException, DSIFatalException;
    void flushSQLDatabase() throws DSINonFatalException, DSIFatalException;
    void flushSQLDatabase(boolean sync) throws DSINonFatalException, DSIFatalException;
    void setSQLDatabaseMedium(int medium) throws DSINonFatalException, DSIFatalException;
    void getVisibleSystemLanguages() throws DSINonFatalException, DSIFatalException;

    // --- Identification ---

    String getName();
    String getServiceAdapterVersion();
}
