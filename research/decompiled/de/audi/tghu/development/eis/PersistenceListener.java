/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  org.dsi.ifc.persistence.DSIPersistenceListener
 */
package de.audi.tghu.development.eis;

import de.audi.tghu.development.app.Logger;
import de.audi.tghu.development.eis.EISCallbackHandler;
import de.audi.tghu.development.manager.LogMan;
import org.dsi.ifc.persistence.DSIPersistenceListener;

public class PersistenceListener
implements DSIPersistenceListener {
    protected EISCallbackHandler callbackHandler;
    protected EISCallbackHandler exportCallbackHandler;

    public PersistenceListener(EISCallbackHandler eISCallbackHandler, EISCallbackHandler eISCallbackHandler2) throws Exception {
        if (eISCallbackHandler == null || eISCallbackHandler2 == null) {
            throw new Exception("EISCallbackHandler cannot be null!");
        }
        this.callbackHandler = eISCallbackHandler;
        this.exportCallbackHandler = eISCallbackHandler2;
    }

    public void readInt(int n, long l, int n2, int n3) {
        LogMan.log(2, "PersistenceListener.readInt(): retrieved int (" + n + "," + l + "): " + n2);
        if (n3 == 0) {
            this.callbackHandler.updateInt(0, n, l, n2);
            this.exportCallbackHandler.updateInt(0, n, l, n2);
        } else {
            LogMan.log(2, "PersistenceListener.Error() ->" + n3 + " (" + n + "," + l + "): ");
        }
    }

    public void readBuffer(int n, long l, byte[] byArray, int n2) {
        LogMan.log(2, "PersistenceListener.readBuffer(): retrieved object (" + n + "," + l + ").");
        if (n2 == 0) {
            if (n == 0) {
                this.callbackHandler.updateString(0, n, l, byArray.toString());
                this.exportCallbackHandler.updateString(0, n, l, byArray.toString());
            } else {
                this.callbackHandler.updateObject(0, n, l, byArray);
                this.exportCallbackHandler.updateObject(0, n, l, byArray);
            }
        } else {
            LogMan.log(2, "PersistenceListener.Error() ->" + n2 + " (" + n + "," + l + "): ");
        }
    }

    public void readString(int n, long l, String string, int n2) {
        LogMan.log(2, "PersistenceListener.readString(): retrieved string (" + n + "," + l + "): " + string);
        if (n2 == 0) {
            if (n == 0) {
                this.callbackHandler.updateString(0, n, l, string.toString());
                this.exportCallbackHandler.updateString(0, n, l, string.toString());
            } else {
                this.callbackHandler.updateString(0, n, l, string);
                this.exportCallbackHandler.updateString(0, n, l, string);
            }
        } else {
            LogMan.log(2, "PersistenceListener.Error() ->" + n2 + " (" + n + "," + l + "): ");
        }
    }

    public void readArray(int n, long l, int[] nArray, int n2) {
        LogMan.log(2, "PersistenceListener.readArray(): retrieved int-array (" + n + "," + l + ").");
        if (n2 == 0) {
            this.callbackHandler.updateIntArray(0, n, l, nArray);
            this.exportCallbackHandler.updateIntArray(0, n, l, nArray);
        }
    }

    public void writeInt(int n, long l, int n2) {
        LogMan.log(2, "PersistenceListener.writeInt(): store result (" + n + "," + l + "): " + n2);
        if (n2 != 0) {
            this.callbackHandler.handleError(0, n, l, "Error writing into persistence, code = " + n2);
            this.exportCallbackHandler.handleError(0, n, l, "Error writing into persistence, code = " + n2);
        } else {
            LogMan.log(2, "PersistenceListener.Error() ->" + n2 + " (" + n + "," + l + "): ");
        }
    }

    public void writeBuffer(int n, long l, int n2) {
        LogMan.log(2, "PersistenceListener.writeBuffer(): store result (" + n + "," + l + "): " + n2);
        if (n2 != 0) {
            this.callbackHandler.handleError(0, n, l, "Error writing into persistence, code = " + n2);
            this.exportCallbackHandler.handleError(0, n, l, "Error writing into persistence, code = " + n2);
        } else {
            LogMan.log(2, "PersistenceListener.Error() ->" + n2 + " (" + n + "," + l + "): ");
        }
    }

    public void writeString(int n, long l, int n2) {
        LogMan.log(2, "PersistenceListener.writeString(): store result (" + n + "," + l + "): " + n2);
        if (n2 != 0) {
            this.callbackHandler.handleError(0, n, l, "Error writing into persistence, code = " + n2);
            this.exportCallbackHandler.handleError(0, n, l, "Error writing into persistence, code = " + n2);
        } else {
            LogMan.log(2, "PersistenceListener.Error() ->" + n2 + " (" + n + "," + l + "): ");
        }
    }

    public void writeArray(int n, long l, int n2) {
        LogMan.log(2, "PersistenceListener.writeArray(): store result (" + n + "," + l + "): " + n2);
        if (n2 != 0) {
            this.callbackHandler.handleError(0, n, l, "Error writing into persistence, code = " + n2);
            this.exportCallbackHandler.handleError(0, n, l, "Error writing into persistence, code = " + n2);
        } else {
            LogMan.log(2, "PersistenceListener.Error() ->" + n2 + " (" + n + "," + l + "): ");
        }
    }

    public void asyncException(int n, String string, int n2) {
        LogMan.log(2, "PersistenceListener.asyncException(): error code " + n + ", msg: " + string + ", request: " + n2);
        Logger.getInstance().dsi.log(100000, "PersistenceListener.asyncException(): error code " + n + ", msg: " + string + ", request: " + n2);
    }

    public void readIntSet(int n, long l, int[] nArray, int n2) {
    }

    public void readStringSet(int n, long l, String[] stringArray, int n2) {
    }

    public void updateDTCErrorMemoryStatus(int n, int n2) {
    }

    public void writeIntSet(int n, long l, int n2) {
    }

    public void writeStringSet(int n, long l, int n2) {
    }

    public void flushSQLDatabase(int n) {
    }

    public void getVisibleSystemLanguages(String string) {
    }

    public void updateActiveSQLDatabaseMedium(int n, int n2) {
    }

    public void updateGlobalPersistenceAvailabilityStatus(int n, int n2) {
    }
}

