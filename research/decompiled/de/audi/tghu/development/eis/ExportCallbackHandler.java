/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.eis;

import de.audi.commons.tools.LineWriter;
import de.audi.tghu.development.eis.EISCallbackHandler;
import de.audi.tghu.development.eis.ExportKey;
import de.audi.tghu.development.eis.ListEntry;
import de.audi.tghu.development.manager.LogMan;
import de.audi.tghu.development.model.DecoderConsumer;
import de.audi.tghu.development.model.TLVDecoder;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.text.DecimalFormat;
import java.util.ArrayList;
import java.util.Iterator;

public class ExportCallbackHandler
implements EISCallbackHandler,
DecoderConsumer {
    private static ExportCallbackHandler handler = null;
    ArrayList properties = new ArrayList();
    private ArrayList exportKeys = null;
    private boolean exportRunning = false;

    public static ExportCallbackHandler getInstance() {
        if (handler == null) {
            handler = new ExportCallbackHandler();
        }
        return handler;
    }

    private ExportCallbackHandler() {
    }

    public int saveExport(String string) {
        int n = 0;
        try {
            Object object;
            int n2 = 0;
            DecimalFormat decimalFormat = new DecimalFormat("000");
            File file = null;
            do {
                object = decimalFormat.format(n2);
                file = new File(string + "." + (String)object);
                ++n2;
            } while (file != null && file.exists());
            object = new LineWriter(file);
            Iterator iterator = this.properties.iterator();
            while (iterator.hasNext()) {
                ListEntry listEntry = (ListEntry)iterator.next();
                Object object2 = listEntry.getKey();
                Object object3 = listEntry.getValue();
                if (object2 == null && object3 != null) {
                    ((LineWriter)object).writeln("  " + object3);
                }
                if (object2 != null && object3 == null) {
                    ((LineWriter)object).writeln(object2 + ":");
                }
                if (object2 == null || object3 == null) continue;
                ((LineWriter)object).writeln(object2 + "=" + object3);
            }
            ((LineWriter)object).close();
            this.properties.clear();
        }
        catch (FileNotFoundException fileNotFoundException) {
            n = -1;
        }
        catch (IOException iOException) {
            n = -2;
        }
        return n;
    }

    /*
     * WARNING - Removed try catching itself - possible behaviour change.
     */
    private ExportKey toBeExported(ExportKey exportKey) {
        if (this.exportKeys != null) {
            LogMan.log(8, " exportRunning = " + this.exportRunning + " / exportKeys = " + this.exportKeys.size());
            if (this.exportRunning) {
                ArrayList arrayList = this.exportKeys;
                synchronized (arrayList) {
                    if (this.exportKeys.size() == 0) {
                        this.exportRunning = false;
                        LogMan.log(8, "toBeExported? no (" + Integer.toHexString(exportKey.getNamespace()) + " / " + Long.toHexString(exportKey.getKey()) + ")");
                        return null;
                    }
                    Iterator iterator = this.exportKeys.iterator();
                    while (iterator.hasNext()) {
                        ExportKey exportKey2 = (ExportKey)iterator.next();
                        if (!exportKey2.equals(exportKey)) continue;
                        this.exportKeys.remove(exportKey2);
                        LogMan.log(8, "toBeExported? yes (" + Integer.toHexString(exportKey.getNamespace()) + " / " + Long.toHexString(exportKey.getKey()) + ")");
                        return exportKey2;
                    }
                }
            }
            LogMan.log(8, "toBeExported? no (" + Integer.toHexString(exportKey.getNamespace()) + " / " + Long.toHexString(exportKey.getKey()) + ")");
        }
        return null;
    }

    public void startExport() {
        this.exportRunning = true;
    }

    public void stopExport() {
        this.exportRunning = false;
    }

    /*
     * WARNING - Removed try catching itself - possible behaviour change.
     */
    public void setExportKeys(ArrayList arrayList) {
        ArrayList arrayList2 = arrayList;
        synchronized (arrayList2) {
            if (this.exportKeys != null) {
                this.exportKeys.addAll(arrayList);
            } else {
                this.exportKeys = arrayList;
            }
            LogMan.log(8, "exportKeys added -> current size = " + arrayList.size());
        }
        this.exportRunning = true;
    }

    public void updateInt(int n, int n2, long l, int n3) {
        ExportKey exportKey = new ExportKey(n2, l);
        if ((exportKey = this.toBeExported(exportKey)) != null) {
            this.properties.add(new ListEntry(exportKey.getLabel(), String.valueOf(n3)));
        }
    }

    public void updateString(int n, int n2, long l, String string) {
        ExportKey exportKey = new ExportKey(n2, l);
        if ((exportKey = this.toBeExported(exportKey)) != null) {
            this.properties.add(new ListEntry(exportKey.getLabel(), string));
        }
    }

    public void updateObject(int n, int n2, long l, byte[] byArray) {
        ExportKey exportKey = new ExportKey(n2, l);
        if ((exportKey = this.toBeExported(exportKey)) != null) {
            this.properties.add(new ListEntry(exportKey.getLabel(), null));
            TLVDecoder tLVDecoder = new TLVDecoder(byArray, this);
            tLVDecoder.decode();
        }
    }

    public void consumeElement(int n, Object object) {
        switch (n) {
            case 3: {
                this.properties.add(new ListEntry(null, String.valueOf(object)));
                break;
            }
            case 8: {
                this.properties.add(new ListEntry(null, (String)object));
            }
        }
    }

    public void updateIntArray(int n, int n2, long l, int[] nArray) {
        ExportKey exportKey = new ExportKey(n2, l);
        if ((exportKey = this.toBeExported(exportKey)) != null) {
            this.properties.add(new ListEntry(exportKey.getLabel(), nArray.toString()));
        }
    }

    public void handleError(int n, int n2, long l, String string) {
    }
}

