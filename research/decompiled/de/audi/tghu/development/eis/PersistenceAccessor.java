/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  org.dsi.ifc.base.DSIFatalException
 *  org.dsi.ifc.base.DSINonFatalException
 *  org.dsi.ifc.persistence.DSIPersistence
 */
package de.audi.tghu.development.eis;

import de.audi.tghu.development.manager.LogMan;
import de.audi.tghu.development.model.ScreenElementModel;
import org.dsi.ifc.base.DSIFatalException;
import org.dsi.ifc.base.DSINonFatalException;
import org.dsi.ifc.persistence.DSIPersistence;

public class PersistenceAccessor {
    protected static final boolean USEHBPERSISTENCE = true;
    protected static final int DUMMYNAMESPACE = 234524;
    protected DSIPersistence persistence;
    protected DSIPersistence fakePersistence;

    public void setFakePersistence(DSIPersistence dSIPersistence) {
        this.fakePersistence = dSIPersistence;
    }

    public void setPersistence(DSIPersistence dSIPersistence) {
        this.persistence = dSIPersistence;
    }

    public DSIPersistence getPersistence() {
        return this.persistence;
    }

    public DSIPersistence getFakePersistence() {
        return this.fakePersistence;
    }

    protected void _poll_fp(int n, int n2, long[] lArray) throws DSINonFatalException, DSIFatalException {
        block6: for (int i = 0; i < lArray.length; ++i) {
            switch (n) {
                case 0: {
                    this.fakePersistence.readInt(n2, lArray[i], false);
                    continue block6;
                }
                case 3: {
                    this.fakePersistence.readString(n2, lArray[i], false);
                    continue block6;
                }
                case 4: {
                    this.fakePersistence.readBuffer(n2, lArray[i], false);
                    continue block6;
                }
                case 5: {
                    this.fakePersistence.readArray(n2, lArray[i], false);
                    continue block6;
                }
                default: {
                    LogMan.log("PersistenceAccessor.pollModel(): invalid data type " + n + " for item ns=" + n2 + ", key=" + lArray[i]);
                }
            }
        }
    }

    public void _poll_hb(int n, int n2, long[] lArray) throws DSINonFatalException, DSIFatalException {
        if (this.persistence == null) {
            return;
        }
        block6: for (int i = 0; i < lArray.length; ++i) {
            switch (n) {
                case 0: {
                    LogMan.log(2, "PersistenceAccessor.pollModel(): polling H/B per for key " + lArray[i] + " per=" + this.persistence);
                    this.persistence.readInt(n2, lArray[i], false);
                    continue block6;
                }
                case 3: {
                    LogMan.log(2, "PersistenceAccessor.pollModel(): polling H/B per for key " + lArray[i] + " per=" + this.persistence);
                    if (n2 == 0) {
                        this.persistence.readBuffer(n2, lArray[i], false);
                        continue block6;
                    }
                    this.persistence.readString(n2, lArray[i], false);
                    continue block6;
                }
                case 4: {
                    LogMan.log(2, "PersistenceAccessor.pollModel(): polling H/B per for key " + lArray[i] + " per=" + this.persistence);
                    this.persistence.readBuffer(n2, lArray[i], false);
                    continue block6;
                }
                case 5: {
                    LogMan.log(2, "PersistenceAccessor.pollModel(): polling H/B per for key " + lArray[i] + " per=" + this.persistence);
                    this.persistence.readArray(n2, lArray[i], false);
                    continue block6;
                }
                default: {
                    LogMan.log(2, "PersistenceAccessor.pollModel(): invalid data type " + n + " for item ns=" + n2 + ", key=" + lArray[i]);
                }
            }
        }
    }

    public void pollModel(ScreenElementModel screenElementModel) throws DSINonFatalException, DSIFatalException {
        int n = screenElementModel.getDataType();
        int n2 = screenElementModel.getNamespace();
        long[] lArray = screenElementModel.getKeys();
        if (n2 == 234524) {
            this._poll_fp(n, n2, lArray);
        } else {
            this._poll_hb(n, n2, lArray);
        }
    }

    public void storeInt(int n, long l, int n2) throws DSINonFatalException, DSIFatalException {
        LogMan.log(11, "GEM->storeInt(" + n + ", " + l + ", " + n2 + ")");
        if (n == 234524) {
            this.fakePersistence.writeInt(n, l, n2, false);
        } else {
            this.persistence.writeInt(n, l, n2, false);
        }
    }

    public void storeString(int n, long l, String string) throws DSINonFatalException, DSIFatalException {
        LogMan.log(11, "GEM->storeString(" + n + ", " + l + ", " + string + ")");
        if (n == 234524) {
            this.fakePersistence.writeString(n, l, string, false);
        } else if (n == 0) {
            this.persistence.writeBuffer(n, l, string.getBytes(), false);
        } else {
            this.persistence.writeString(n, l, string, false);
        }
    }

    public void readString(int n, long l) throws DSINonFatalException, DSIFatalException {
        this.persistence.readString(n, l, false);
    }

    public void readInt(int n, long l) throws DSINonFatalException, DSIFatalException {
        this.persistence.readInt(n, l, false);
    }
}

