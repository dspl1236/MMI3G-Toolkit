package org.osgi.framework;

import java.util.Dictionary;

/**
 * Stub of org.osgi.framework.BundleContext for offline compilation.
 * Real implementation supplied at runtime by the OSGi framework.
 */
public interface BundleContext {
    Object getService(ServiceReference reference);
    boolean ungetService(ServiceReference reference);
    ServiceRegistration registerService(String[] clazzes, Object service, Dictionary properties);
    ServiceRegistration registerService(String clazz, Object service, Dictionary properties);
    ServiceReference getServiceReference(String clazz);
    ServiceReference[] getServiceReferences(String clazz, String filter) throws InvalidSyntaxException;
    ServiceReference[] getAllServiceReferences(String clazz, String filter) throws InvalidSyntaxException;
}
