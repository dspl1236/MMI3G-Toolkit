package org.osgi.util.tracker;

import org.osgi.framework.BundleContext;
import org.osgi.framework.ServiceReference;

public class ServiceTracker {
    public ServiceTracker(BundleContext ctx, String clazz, ServiceTrackerCustomizer customizer) { }
    public void open() { }
    public void close() { }
    public Object getService() { return null; }
    public Object getService(ServiceReference ref) { return null; }
    public ServiceReference[] getServiceReferences() { return null; }
}
