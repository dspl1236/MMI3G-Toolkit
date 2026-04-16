package org.dsi.ifc.admin;

/**
 * Stub of org.dsi.ifc.admin.JDSIAdmin.
 *
 * From AppActivator.java line 76:
 *   dsiAdmin.startService("org.dsi.ifc.persistence.DSIPersistence", 0)
 *
 * Used to kick-start a DSI service that's registered but not yet live.
 */
public interface JDSIAdmin {
    void startService(String serviceName, int flags) throws Exception;
    void stopService(String serviceName, int flags) throws Exception;
}
