/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  org.dsi.ifc.base.DSIFatalException
 *  org.dsi.ifc.base.DSIListener
 *  org.dsi.ifc.base.DSINonFatalException
 *  org.dsi.ifc.persistence.DSIPersistence
 *  org.dsi.ifc.persistence.DSIPersistenceListener
 *  org.osgi.framework.BundleContext
 *  org.osgi.framework.ServiceReference
 *  org.osgi.util.tracker.ServiceTracker
 *  org.osgi.util.tracker.ServiceTrackerCustomizer
 */
package de.audi.tghu.sim.persistence;

import de.audi.tghu.development.manager.LogMan;
import de.audi.tghu.development.model.TLVEncoder;
import java.util.Hashtable;
import java.util.Random;
import org.dsi.ifc.base.DSIFatalException;
import org.dsi.ifc.base.DSIListener;
import org.dsi.ifc.base.DSINonFatalException;
import org.dsi.ifc.persistence.DSIPersistence;
import org.dsi.ifc.persistence.DSIPersistenceListener;
import org.osgi.framework.BundleContext;
import org.osgi.framework.ServiceReference;
import org.osgi.util.tracker.ServiceTracker;
import org.osgi.util.tracker.ServiceTrackerCustomizer;

public class FakePersistence
implements DSIPersistence {
    private DSIPersistenceListener listener = null;
    private static final Hashtable htSpaces = new Hashtable();
    private static final Hashtable htValues = new Hashtable();
    private ServiceTracker tracker;
    private BundleContext context;
    static int x = 0;
    static /* synthetic */ Class class$org$dsi$ifc$persistence$DSIPersistenceListener;
    static /* synthetic */ Class class$org$dsi$ifc$persistence$DSIPersistence;

    public void initialize(BundleContext bundleContext) {
        this.context = bundleContext;
        this.tracker = new ServiceTracker(bundleContext, (class$org$dsi$ifc$persistence$DSIPersistenceListener == null ? (class$org$dsi$ifc$persistence$DSIPersistenceListener = FakePersistence.class$("org.dsi.ifc.persistence.DSIPersistenceListener")) : class$org$dsi$ifc$persistence$DSIPersistenceListener).getName(), new ServiceTrackerCustomizer(){

            public Object addingService(ServiceReference serviceReference) {
                LogMan.log(6, "FakePersistence.initialize(): listener found");
                FakePersistence.this.listener = (DSIPersistenceListener)FakePersistence.this.context.getService(serviceReference);
                return FakePersistence.this.listener;
            }

            public void modifiedService(ServiceReference serviceReference, Object object) {
                FakePersistence.this.listener = (DSIPersistenceListener)object;
            }

            public void removedService(ServiceReference serviceReference, Object object) {
                LogMan.log(6, "FakePersistence.initialize(): listener removed");
                if (object == FakePersistence.this.listener) {
                    FakePersistence.this.listener = null;
                }
            }
        });
        this.tracker.open();
    }

    public void writeInt(int n, long l, int n2) throws DSINonFatalException, DSIFatalException {
        Hashtable hashtable = (Hashtable)htSpaces.get(new Integer(n));
        if (hashtable != null) {
            if (l == 30000L) {
                this.listener.writeInt(n, l, 0);
            } else if (l == 21000L) {
                x = n2;
                this.listener.writeInt(n, l, 0);
            } else {
                LogMan.log(6, "FakePersistence.writeInt(): store int ns=" + n + ", key=" + l + " value=" + n2);
                hashtable.put(new Long(l), new Integer(n2));
                this.listener.writeInt(n, l, 0);
            }
        }
    }

    public void writeString(int n, long l, String string) throws DSINonFatalException, DSIFatalException {
        Hashtable hashtable = (Hashtable)htSpaces.get(new Integer(n));
        if (hashtable != null) {
            if (l == 30000L) {
                this.listener.writeString(n, l, 0);
            } else {
                LogMan.log(6, "FakePersistence.writeString(): store string ns=" + n + ", key=" + l + " value=" + string);
                hashtable.put(new Long(l), string);
                this.listener.writeString(n, l, 0);
            }
        }
    }

    public void writeArray(int n, long l, int[] nArray) throws DSINonFatalException, DSIFatalException {
        System.err.println("FakePersistence.writeArray(): not implemented");
    }

    public void writeBuffer(int n, long l, byte[] byArray) throws DSINonFatalException, DSIFatalException {
        System.err.println("FakePersistence.writeBuffer(): not implemented");
    }

    public void writeIntSet(int n, long l, int n2, int[] nArray) throws DSINonFatalException, DSIFatalException {
        Hashtable hashtable = (Hashtable)htSpaces.get(new Integer(n));
        if (hashtable != null) {
            for (int i = 0; i < n2; ++i) {
                hashtable.put(new Long(l + (long)i), new Integer(nArray[i]));
            }
        }
    }

    public void writeStringSet(int n, long l, int n2, String[] stringArray) throws DSINonFatalException, DSIFatalException {
        Hashtable hashtable = (Hashtable)htSpaces.get(new Integer(n));
        if (hashtable != null) {
            for (int i = 0; i < n2; ++i) {
                hashtable.put(new Long(l + (long)i), new String(stringArray[i]));
            }
        }
    }

    public void writIntArraySet(int n, long l, int n2, int[] nArray) throws DSINonFatalException, DSIFatalException {
        System.err.println("FakePersistence.writeIntArraySet(): not implemented");
    }

    public void writeObjectSet(int n, long l, int n2, byte[] byArray) throws DSINonFatalException, DSIFatalException {
        System.err.println("FakePersistence.writeObjectSet(): not implemented");
    }

    public void readInt(int n, long l) throws DSINonFatalException, DSIFatalException {
        Hashtable hashtable = (Hashtable)htSpaces.get(new Integer(n));
        if (hashtable != null) {
            Object v;
            if (l == 21000L) {
                htValues.put(new Long(21000L), new Integer(x));
                x = (x + 1) % 20;
                htValues.put(new Long(22001L), new Integer(50 - x));
            }
            if ((v = hashtable.get(new Long(l))) == null) {
                LogMan.log(6, "FakePersistence.readInt(): no data found, namespace = " + n + ", key = " + l);
                this.listener.readInt(n, l, -1, 2);
                return;
            }
            if (v instanceof Integer) {
                Integer n2 = (Integer)v;
                LogMan.log(6, "FakePersistence.readInt(): value=" + n2 + " listener=" + this.listener);
                if (this.listener != null) {
                    this.listener.readInt(n, l, n2.intValue(), 0);
                }
            } else if (v instanceof Boolean) {
                boolean bl = (Boolean)v;
                int n3 = bl ? 1 : 0;
                LogMan.log(6, "FakePersistence.readInt(): value=" + n3 + " listener=" + this.listener);
                if (this.listener != null) {
                    this.listener.readInt(n, l, n3, 0);
                }
            } else {
                LogMan.log(6, "FakePersistence.readInt(): unexpected type " + v.getClass().getName() + ", namespace = " + n + ", key = " + l);
                this.listener.readInt(n, l, -1, 5);
            }
        } else {
            LogMan.log(6, "FakePersistence.readInt(): no namespace found, namespace = " + n);
            this.listener.readInt(n, l, -1, 1);
        }
    }

    public void readString(int n, long l) throws DSINonFatalException, DSIFatalException {
        Hashtable hashtable = (Hashtable)htSpaces.get(new Integer(n));
        if (hashtable != null) {
            Object v = hashtable.get(new Long(l));
            if (v == null) {
                LogMan.log(6, "FakePersistence.readString(): no data found, namespace = " + n + ", key = " + l);
                this.listener.readString(n, l, null, 2);
                return;
            }
            if (v instanceof String) {
                String string = (String)v;
                LogMan.log(6, "FakePersistence.readString(): value=" + string + " listener=" + this.listener);
                if (this.listener != null) {
                    this.listener.readString(n, l, string, 0);
                }
            } else {
                LogMan.log(6, "FakePersistence.readString(): unexpected type " + v.getClass().getName() + ", namespace = " + n + ", key = " + l);
                this.listener.readString(n, l, null, 5);
            }
        } else {
            LogMan.log(6, "FakePersistence.readString(): no namespace found, namespace = " + n);
            this.listener.readString(n, l, null, 1);
        }
    }

    public void readArray(int n, long l) throws DSINonFatalException, DSIFatalException {
        Hashtable hashtable = (Hashtable)htSpaces.get(new Integer(n));
        if (hashtable != null) {
            Object v = hashtable.get(new Long(l));
            if (v == null) {
                LogMan.log(6, "FakePersistence.readArray(): no data found, namespace = " + n + ", key = " + l);
                this.listener.readArray(n, l, null, 2);
                return;
            }
            if (v instanceof int[]) {
                int[] nArray = (int[])v;
                LogMan.log(6, "FakePersistence.readArray(): arraylen=" + nArray.length + " listener=" + this.listener);
                if (this.listener != null) {
                    this.listener.readArray(n, l, nArray, 0);
                }
            } else {
                LogMan.log(6, "FakePersistence.readArray(): unexpected type " + v.getClass().getName() + ", namespace = " + n + ", key = " + l);
                this.listener.readArray(n, l, null, 5);
            }
        } else {
            LogMan.log(6, "FakePersistence.readArray(): no namespace found, namespace = " + n);
            this.listener.readArray(n, l, null, 1);
        }
    }

    public void readBuffer(int n, long l) throws DSINonFatalException, DSIFatalException {
        if (n == 234524) {
            if (l == 25001L) {
                TLVEncoder tLVEncoder = new TLVEncoder();
                tLVEncoder.encodeString("Bayern 3");
                tLVEncoder.encodeSInt(976);
                tLVEncoder.encodeString("Antenne");
                tLVEncoder.encodeSInt(1002);
                tLVEncoder.encodeString("Galaxy");
                tLVEncoder.encodeSInt(1079);
                tLVEncoder.terminate();
                byte[] byArray = tLVEncoder.getResult();
                tLVEncoder = null;
                this.listener.readBuffer(n, l, byArray, 0);
            } else if (l == 25002L) {
                TLVEncoder tLVEncoder = new TLVEncoder();
                tLVEncoder.encodeSByte((byte)1);
                tLVEncoder.encodeSByte((byte)1);
                tLVEncoder.encodeSByte((byte)0);
                tLVEncoder.encodeSByte((byte)1);
                tLVEncoder.encodeSByte((byte)0);
                tLVEncoder.encodeSByte((byte)1);
                tLVEncoder.encodeSByte((byte)0);
                tLVEncoder.encodeSByte((byte)0);
                tLVEncoder.encodeSByte((byte)1);
                tLVEncoder.encodeSByte((byte)0);
                tLVEncoder.encodeSByte((byte)1);
                tLVEncoder.encodeSByte((byte)0);
                tLVEncoder.encodeSByte((byte)1);
                tLVEncoder.encodeSByte((byte)0);
                tLVEncoder.encodeSByte((byte)0);
                tLVEncoder.encodeSByte((byte)1);
                tLVEncoder.encodeSByte((byte)0);
                tLVEncoder.encodeSByte((byte)1);
                tLVEncoder.encodeSByte((byte)1);
                tLVEncoder.encodeSByte((byte)0);
                tLVEncoder.encodeSByte((byte)1);
                tLVEncoder.terminate();
                byte[] byArray = tLVEncoder.getResult();
                tLVEncoder = null;
                this.listener.readBuffer(n, l, byArray, 0);
            } else {
                LogMan.log(6, "FakePersistence.readBuffer(): no data found, namespace = " + n + ", key = " + l);
                this.listener.readBuffer(n, l, null, 2);
            }
        } else {
            LogMan.log(6, "FakePersistence.readBuffer(): invalid namespace = " + n);
            this.listener.readBuffer(n, l, null, 1);
        }
    }

    public void readIntSet(int n, long l, int n2) throws DSINonFatalException, DSIFatalException {
        LogMan.log(6, "FakePersistence.readIntSet(): not implemented");
    }

    public void readStringSet(int n, long l, int n2) throws DSINonFatalException, DSIFatalException {
        LogMan.log(6, "FakePersistence.readStringSet(): not implemented");
    }

    public void readIntArraySet(int n, long l, int n2) throws DSINonFatalException, DSIFatalException {
        LogMan.log(6, "FakePersistence.readIntArraySet(): not implemented");
    }

    public void readObjectSet(int n, long l, int n2) throws DSINonFatalException, DSIFatalException {
        LogMan.log(6, "FakePersistence.readObjectSet(): not implemented");
    }

    public String getServiceAdapterVersion() {
        return "1.0";
    }

    public void setNotification(short[] sArray, DSIListener dSIListener) throws DSIFatalException, DSINonFatalException {
        LogMan.log(6, "FakePersistence.setNotification(): not implemented");
    }

    public void setNotification(short s, DSIListener dSIListener) throws DSIFatalException, DSINonFatalException {
        LogMan.log(6, "FakePersistence.setNotification(): not implemented");
    }

    public void setNotification(DSIListener dSIListener) throws DSIFatalException, DSINonFatalException {
        LogMan.log(6, "FakePersistence.setNotification(): not implemented");
    }

    public void clearNotification(short[] sArray, DSIListener dSIListener) throws DSIFatalException, DSINonFatalException {
        LogMan.log(6, "FakePersistence.clearNotification(): not implemented");
    }

    public void clearNotification(short s, DSIListener dSIListener) throws DSIFatalException, DSINonFatalException {
        LogMan.log(6, "FakePersistence.clearNotification(): not implemented");
    }

    public void clearNotification(DSIListener dSIListener) throws DSIFatalException, DSINonFatalException {
        LogMan.log(6, "FakePersistence.clearNotification(): not implemented");
    }

    public String getName() {
        return (class$org$dsi$ifc$persistence$DSIPersistence == null ? (class$org$dsi$ifc$persistence$DSIPersistence = FakePersistence.class$("org.dsi.ifc.persistence.DSIPersistence")) : class$org$dsi$ifc$persistence$DSIPersistence).getName();
    }

    public void addNotification(int n, long[] lArray) throws DSINonFatalException, DSIFatalException {
    }

    public void removeNotification(int n, long[] lArray) throws DSINonFatalException, DSIFatalException {
    }

    public void enterGreenEngineeringMenu() throws DSINonFatalException, DSIFatalException {
    }

    public void leaveGreenEngineeringMenu() throws DSINonFatalException, DSIFatalException {
    }

    public void enterEngineeringSession(int n) throws DSINonFatalException, DSIFatalException {
    }

    public void exitEngineeringSession(int n) throws DSINonFatalException, DSIFatalException {
    }

    public void flushSQLDatabase() throws DSINonFatalException, DSIFatalException {
    }

    public void getVisibleSystemLanguages() throws DSINonFatalException, DSIFatalException {
    }

    public void setSQLDatabaseMedium(int n) throws DSINonFatalException, DSIFatalException {
    }

    public void flushSQLDatabase(boolean bl) throws DSINonFatalException, DSIFatalException {
    }

    public void readArray(int n, long l, boolean bl) throws DSINonFatalException, DSIFatalException {
    }

    public void readBuffer(int n, long l, boolean bl) throws DSINonFatalException, DSIFatalException {
    }

    public void readInt(int n, long l, boolean bl) throws DSINonFatalException, DSIFatalException {
    }

    public void readString(int n, long l, boolean bl) throws DSINonFatalException, DSIFatalException {
    }

    public void writeArray(int n, long l, int[] nArray, boolean bl) throws DSINonFatalException, DSIFatalException {
    }

    public void writeBuffer(int n, long l, byte[] byArray, boolean bl) throws DSINonFatalException, DSIFatalException {
    }

    public void writeInt(int n, long l, int n2, boolean bl) throws DSINonFatalException, DSIFatalException {
    }

    public void writeString(int n, long l, String string, boolean bl) throws DSINonFatalException, DSIFatalException {
    }

    static /* synthetic */ Class class$(String string) {
        try {
            return Class.forName(string);
        }
        catch (ClassNotFoundException classNotFoundException) {
            throw new NoClassDefFoundError(classNotFoundException.getMessage());
        }
    }

    static {
        htValues.put(new Long(10000L), "japan");
        htValues.put(new Long(10001L), new Integer(99));
        htValues.put(new Long(21000L), new Integer(53));
        htValues.put(new Long(21001L), new Integer(0));
        htValues.put(new Long(21002L), new Integer(20));
        htValues.put(new Long(22000L), "German");
        htValues.put(new Long(22001L), new Integer(220));
        htValues.put(new Long(22002L), new Integer(14));
        htValues.put(new Long(22003L), "MMIHighNavMedia");
        htValues.put(new Long(24000L), new Boolean(true));
        htValues.put(new Long(25000L), new Integer(7));
        htValues.put(new Long(25001L), new Integer(0));
        htValues.put(new Long(25002L), new Integer(20));
        htValues.put(new Long(20016L), new Integer(20));
        htValues.put(new Long(20017L), new Integer(0));
        htValues.put(new Long(20018L), new Integer(31));
        htValues.put(new Long(20019L), new Integer(3));
        htValues.put(new Long(20020L), new Integer(-6));
        htValues.put(new Long(20021L), new Integer(6));
        htValues.put(new Long(20022L), new Integer(5));
        htValues.put(new Long(20023L), new Integer(-6));
        htValues.put(new Long(20024L), new Integer(6));
        htValues.put(new Long(20151L), new Integer(47));
        htValues.put(new Long(26000L), "H3_HI_EU_E6.1");
        htValues.put(new Long(27000L), new int[]{1, 0, 0, 1, 1, 0, 1, 0, 1, 1, 1, 0, 0});
        htValues.put(new Long(27001L), new int[]{3, 4, 5, 6});
        htSpaces.put(new Integer(234524), htValues);
    }

    class ChangeFaker
    implements Runnable {
        Random r = new Random();

        ChangeFaker() {
        }

        public void run() {
            try {
                while (true) {
                    htValues.put(new Long(22001L), new Integer(this.r.nextInt() & 0xFF));
                    Thread.sleep(2000L);
                }
            }
            catch (InterruptedException interruptedException) {
                interruptedException.printStackTrace();
                return;
            }
        }
    }
}

