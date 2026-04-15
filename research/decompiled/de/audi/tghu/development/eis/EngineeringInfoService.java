/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  de.audi.atip.timer.Timer
 *  de.audi.atip.timer.TimerListener
 *  org.dsi.ifc.base.DSIFatalException
 *  org.dsi.ifc.base.DSIListener
 *  org.dsi.ifc.base.DSINonFatalException
 *  org.dsi.ifc.persistence.DSIPersistence
 *  org.dsi.ifc.persistence.DSIPersistenceListener
 */
package de.audi.tghu.development.eis;

import de.audi.atip.timer.Timer;
import de.audi.atip.timer.TimerListener;
import de.audi.tghu.development.EngineeringException;
import de.audi.tghu.development.app.Logger;
import de.audi.tghu.development.eis.EISCallbackHandler;
import de.audi.tghu.development.eis.EISException;
import de.audi.tghu.development.eis.EISListener;
import de.audi.tghu.development.eis.ExportCallbackHandler;
import de.audi.tghu.development.eis.Namespace;
import de.audi.tghu.development.eis.PersistenceAccessor;
import de.audi.tghu.development.eis.PersistenceListener;
import de.audi.tghu.development.eis.SystemAccessor;
import de.audi.tghu.development.manager.LogMan;
import de.audi.tghu.development.model.ScreenElementModel;
import de.audi.tghu.development.util.HashtableOfLong;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Vector;
import org.dsi.ifc.base.DSIFatalException;
import org.dsi.ifc.base.DSIListener;
import org.dsi.ifc.base.DSINonFatalException;
import org.dsi.ifc.persistence.DSIPersistence;
import org.dsi.ifc.persistence.DSIPersistenceListener;

public class EngineeringInfoService {
    private static EngineeringInfoService _instance;
    public static final int DATASOURCE_PERSISTENCE = 0;
    public static final int DATASOURCE_SYSTEM = 1;
    protected List[] m_ListenerTable = new List[3];
    protected HashMap mapTimers = new HashMap();
    protected CallbackHandler callbackHandler = new CallbackHandler();
    protected TimerHandler timerHandler = new TimerHandler();
    protected PersistenceListener persistenceListener = new PersistenceListener(this.callbackHandler, ExportCallbackHandler.getInstance());
    protected PersistenceAccessor persistenceAccessor = new PersistenceAccessor();
    protected SystemAccessor systemAccessor = new SystemAccessor(this.callbackHandler);
    protected HashtableOfLong namespaces;

    protected EngineeringInfoService() throws Exception {
        for (int i = 0; i < 3; ++i) {
            this.m_ListenerTable[i] = new Vector(3);
        }
        Logger.getInstance().main.log(1000000, "EIS constructed.");
        this.namespaces = new HashtableOfLong(16);
    }

    public static synchronized EngineeringInfoService getInstance() {
        if (_instance == null) {
            try {
                _instance = new EngineeringInfoService();
            }
            catch (Exception exception) {
                LogMan.log(exception.getMessage());
                exception.printStackTrace();
            }
        }
        return _instance;
    }

    public void setFakePersistence(DSIPersistence dSIPersistence) {
        this.persistenceAccessor.setFakePersistence(dSIPersistence);
    }

    public void setPersistence(DSIPersistence dSIPersistence) {
        if (dSIPersistence == null && (dSIPersistence = this.persistenceAccessor.getPersistence()) != null) {
            try {
                dSIPersistence.clearNotification((DSIListener)this.persistenceListener);
            }
            catch (Exception exception) {
                LogMan.log("EngineeringInfoService.setPersistence(): " + exception.getMessage());
            }
        }
        this.persistenceAccessor.setPersistence(dSIPersistence);
    }

    public PersistenceAccessor getPersistenceAccessor() {
        return this.persistenceAccessor;
    }

    public DSIPersistenceListener getPersistenceListener() {
        return this.persistenceListener;
    }

    protected void pollModel(ScreenElementModel screenElementModel) throws EngineeringException {
        try {
            switch (screenElementModel.getDataSource()) {
                case 0: {
                    this.persistenceAccessor.pollModel(screenElementModel);
                    break;
                }
                case 1: {
                    this.systemAccessor.pollModel(screenElementModel);
                    break;
                }
                default: {
                    LogMan.log(2, "EngineeringInfoService.pollModel(): not implemented for data source " + screenElementModel.getDataSource());
                    throw new EngineeringException("EngineeringInfoService.pollModel(): not implemented for data source " + screenElementModel.getDataSource());
                }
            }
        }
        catch (DSIFatalException dSIFatalException) {
            throw new EngineeringException(dSIFatalException.getMessage());
        }
        catch (DSINonFatalException dSINonFatalException) {
            throw new EngineeringException(dSINonFatalException.getMessage());
        }
    }

    public void addListener(ScreenElementModel screenElementModel) throws EngineeringException, DSINonFatalException, DSIFatalException {
        int n = screenElementModel.getDataSource();
        int n2 = screenElementModel.getNamespace();
        long[] lArray = screenElementModel.getKeys();
        boolean bl = false;
        for (int i = 0; i < lArray.length; ++i) {
            if (!this.putListenerIfNotPresent(n, n2, lArray[i], screenElementModel)) {
                LogMan.log(2, "EngineeringInfoService.addListener(): key already contained in listener table " + lArray[i]);
                continue;
            }
            this.pollModel(screenElementModel);
            bl = true;
        }
        if (screenElementModel.getRefreshInterval() > 0 && bl) {
            Timer timer = new Timer((long)screenElementModel.getRefreshInterval(), false, (TimerListener)this.timerHandler);
            LogMan.log(2, "EngineeringInfoService.addListener(): timer installed for model " + screenElementModel.getLabel());
            timer.start();
            this.mapTimers.put(timer, screenElementModel);
        }
    }

    protected EISListener getListener(int n, int n2, long l) {
        Namespace namespace = this.getNamespace(n, n2, false);
        if (namespace != null) {
            return namespace.getEISListener(l);
        }
        return null;
    }

    private boolean putListenerIfNotPresent(int n, int n2, long l, EISListener eISListener) {
        Namespace namespace = this.getNamespace(n, n2, true);
        if (!namespace.containsEISListener(l)) {
            namespace.putEISListener(l, eISListener);
            return true;
        }
        return false;
    }

    private Namespace getNamespace(int n, int n2, boolean bl) {
        Namespace namespace;
        List list = this.m_ListenerTable[n];
        for (int i = 0; i < list.size(); ++i) {
            namespace = (Namespace)list.get(i);
            if (namespace.getId() != n2) continue;
            return namespace;
        }
        if (bl) {
            namespace = new Namespace(n2);
            list.add(namespace);
            return namespace;
        }
        return null;
    }

    public void removeListener(ScreenElementModel screenElementModel) throws DSINonFatalException, DSIFatalException {
        int n = screenElementModel.getDataSource();
        int n2 = screenElementModel.getNamespace();
        long[] lArray = screenElementModel.getKeys();
        for (int i = 0; i < lArray.length; ++i) {
            LogMan.log(2, "EIS.removeListener(): key=" + lArray[i] + ", tablecount: " + this.m_ListenerTable[n].size());
            Namespace namespace = this.getNamespace(n, n2, false);
            if (namespace == null) continue;
            namespace.removeEISListener(lArray[i]);
        }
    }

    public void clearAllListeners() {
        for (int i = 0; i < this.m_ListenerTable.length; ++i) {
            if (this.m_ListenerTable[i] == null) continue;
            this.m_ListenerTable[i].clear();
        }
    }

    public void clearAllTimers() {
        Iterator iterator = this.mapTimers.keySet().iterator();
        while (iterator.hasNext()) {
            Timer timer = (Timer)iterator.next();
            timer.cancel();
            ScreenElementModel screenElementModel = (ScreenElementModel)this.mapTimers.get(timer);
            LogMan.log(2, "EngineeringInfoService.clearAllTimers(): timer removed for model " + screenElementModel.getLabel());
        }
        this.mapTimers.clear();
    }

    public void storeInt(int n, int n2, long l, int n3) throws EISException {
        try {
            switch (n) {
                case 0: {
                    this.persistenceAccessor.storeInt(n2, l, n3);
                    break;
                }
                case 1: {
                    LogMan.log(2, "EngineeringInfoService.storeInt(): data source system not implemented!");
                    throw new EISException(n, n2, l, "EngineeringInfoService.storeInt(): not implemented for system data source.");
                }
                default: {
                    LogMan.log(2, "EngineeringInfoService.storeInt(): unknown data source!");
                    throw new EISException(n, n2, l, "EngineeringInfoService.storeInt(): unknown data source.");
                }
            }
        }
        catch (DSIFatalException dSIFatalException) {
            LogMan.log(2, "EngineeringInfoService.storeInt(): fatal exception: " + dSIFatalException.getMessage());
            throw new EISException(n, n2, l, dSIFatalException.getMessage());
        }
        catch (DSINonFatalException dSINonFatalException) {
            LogMan.log(2, "EngineeringInfoService.storeInt(): non-fatal exception: " + dSINonFatalException.getMessage());
            throw new EISException(n, n2, l, dSINonFatalException.getMessage());
        }
    }

    public void storeString(int n, int n2, long l, String string) throws EISException {
        try {
            switch (n) {
                case 0: {
                    this.persistenceAccessor.storeString(n2, l, string);
                    break;
                }
                case 1: {
                    this.systemAccessor.storeString(n2, l, string);
                    break;
                }
                default: {
                    LogMan.log(2, "EngineeringInfoService.storeString(): unknown data source!");
                    throw new EISException(n, n2, l, "EngineeringInfoService.storeString(): unknown data source.");
                }
            }
        }
        catch (DSIFatalException dSIFatalException) {
            LogMan.log(2, "EngineeringInfoService.storeString(): fatal exception: " + dSIFatalException.getMessage());
            throw new EISException(n, n2, l, dSIFatalException.getMessage());
        }
        catch (DSINonFatalException dSINonFatalException) {
            LogMan.log(2, "EngineeringInfoService.storeString(): non-fatal exception: " + dSINonFatalException.getMessage());
            throw new EISException(n, n2, l, dSINonFatalException.getMessage());
        }
    }

    protected class TimerHandler
    implements TimerListener {
        public void fireTimer(Timer timer) {
            ScreenElementModel screenElementModel = (ScreenElementModel)EngineeringInfoService.this.mapTimers.get(timer);
            LogMan.log(2, "EngineeringInfoService@TimerHandler.fireTimer(): timer fired for model " + screenElementModel.getLabel());
            if (screenElementModel == null) {
                return;
            }
            try {
                EngineeringInfoService.this.pollModel(screenElementModel);
            }
            catch (Throwable throwable) {
                // empty catch block
            }
        }

        public void cancelTimer(Timer timer) {
        }

        protected TimerHandler() {
        }
    }

    protected class CallbackHandler
    implements EISCallbackHandler {
        protected CallbackHandler() {
        }

        public void updateInt(int n, int n2, long l, int n3) {
            EISListener eISListener = EngineeringInfoService.this.getListener(n, n2, l);
            LogMan.log(2, "CallbackHandler.updateInt(): src=" + n + ", ns=" + n2 + ", key=" + l + " value=" + n3 + " l=" + eISListener);
            if (eISListener != null) {
                eISListener.updateData(n2, l, new Integer(n3));
            }
        }

        public void updateString(int n, int n2, long l, String string) {
            EISListener eISListener = EngineeringInfoService.this.getListener(n, n2, l);
            LogMan.log(2, "CallbackHandler.updateString(): src=" + n + ", ns=" + n2 + ", key=" + l + " value=" + string + " l=" + eISListener);
            if (eISListener != null) {
                eISListener.updateData(n2, l, string);
            }
        }

        public void updateObject(int n, int n2, long l, byte[] byArray) {
            EISListener eISListener = EngineeringInfoService.this.getListener(n, n2, l);
            LogMan.log(2, "CallbackHandler.updateObject(): src=" + n + ", ns=" + n2 + ", key=" + l + " l=" + eISListener);
            if (eISListener != null) {
                eISListener.updateData(n2, l, byArray);
            }
        }

        public void updateIntArray(int n, int n2, long l, int[] nArray) {
            EISListener eISListener = EngineeringInfoService.this.getListener(n, n2, l);
            LogMan.log(2, "CallbackHandler.updateObject(): src=" + n + ", ns=" + n2 + ", key=" + l + " l=" + eISListener);
            if (eISListener != null) {
                eISListener.updateData(n2, l, nArray);
            }
        }

        public void handleError(int n, int n2, long l, String string) {
        }
    }

    protected class ListenerKey0 {
        private int ns;
        private long key;

        public int hashCode() {
            return (int)this.key;
        }

        public long getKey() {
            return this.key;
        }

        public int getNs() {
            return this.ns;
        }

        public boolean equals(Object object) {
            if (object instanceof ListenerKey0) {
                ListenerKey0 listenerKey0 = (ListenerKey0)object;
                if (this.ns == listenerKey0.ns && this.key == listenerKey0.key) {
                    return true;
                }
            }
            return false;
        }

        public ListenerKey0(int n, long l) {
            this.ns = n;
            this.key = l;
        }
    }
}

