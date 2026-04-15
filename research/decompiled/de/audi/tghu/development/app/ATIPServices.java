/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  de.audi.atip.base.Framework
 *  de.audi.atip.storage.StorageManager
 */
package de.audi.tghu.development.app;

import de.audi.atip.base.Framework;
import de.audi.atip.storage.StorageManager;

public final class ATIPServices {
    private static StorageManager storageMgr;

    public static void init(StorageManager storageManager) {
        storageMgr = storageManager;
    }

    public static void init() {
        storageMgr = Framework.getStorageManager();
    }

    public static void deinit() {
        storageMgr = null;
    }

    public static StorageManager getStorageManager() {
        return storageMgr;
    }
}

