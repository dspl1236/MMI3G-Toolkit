package org.dsi.ifc.persistence;

import org.dsi.ifc.base.DSIListener;

/**
 * Stub of org.dsi.ifc.persistence.DSIPersistenceListener for offline compilation.
 *
 * GROUND-TRUTH SIGNATURES extracted from de.audi.tghu.development.eis.PersistenceListener
 * (which "implements DSIPersistenceListener") via javap -p on the real
 * AppDevelopment.jar carved from HN+R_EU_AU_K0942_4 MU9411 variant 61
 * efs-system.efs. This is not inferred from FakePersistence callback
 * invocations — this is the actual interface any concrete DSIPersistenceListener
 * must satisfy.
 *
 * If our Per3Reader pretends to implement this interface without all 18
 * methods below, the bundle will fail to load on-device with
 * AbstractMethodError. Earlier versions of this stub had only 8 methods
 * and were MISSING 10 (asyncException, readIntSet, readStringSet,
 * updateDTCErrorMemoryStatus, writeIntSet, writeStringSet,
 * flushSQLDatabase, getVisibleSystemLanguages,
 * updateActiveSQLDatabaseMedium, updateGlobalPersistenceAvailabilityStatus).
 *
 * Error code convention (from FakePersistence bytecode):
 *     0  OK
 *     1  no namespace
 *     2  no data at address
 *     5  unexpected type
 */
public interface DSIPersistenceListener extends DSIListener {

    // --- Read result callbacks (the ones Per3Reader actually cares about) ---

    void readInt(int namespace, long address, int value, int errorCode);
    void readString(int namespace, long address, String value, int errorCode);
    void readArray(int namespace, long address, int[] value, int errorCode);
    void readBuffer(int namespace, long address, byte[] value, int errorCode);

    // --- Write ack callbacks --------------------------------------------------

    void writeInt(int namespace, long address, int errorCode);
    void writeString(int namespace, long address, int errorCode);
    void writeArray(int namespace, long address, int errorCode);
    void writeBuffer(int namespace, long address, int errorCode);

    // --- Set-style bulk callbacks (DSI supports bulk reads) ------------------

    void readIntSet(int namespace, long address, int[] values, int errorCode);
    void readStringSet(int namespace, long address, String[] values, int errorCode);
    void writeIntSet(int namespace, long address, int errorCode);
    void writeStringSet(int namespace, long address, int errorCode);

    // --- Error + system-state callbacks --------------------------------------

    /** Delivered when the DSI daemon hits an async fault during a pending op. */
    void asyncException(int namespace, String message, int errorCode);

    /** Status change for the DTC error memory — used by diagnostic screens. */
    void updateDTCErrorMemoryStatus(int status, int errorCode);

    /** Response to enterEngineeringSession / flush calls. */
    void flushSQLDatabase(int errorCode);

    /** Response to getVisibleSystemLanguages — delivers language code string. */
    void getVisibleSystemLanguages(String languages);

    /** Status change when DSI switches between SQL storage media. */
    void updateActiveSQLDatabaseMedium(int medium, int errorCode);

    /** Global persistence service availability — tracks daemon uptime. */
    void updateGlobalPersistenceAvailabilityStatus(int status, int errorCode);
}
