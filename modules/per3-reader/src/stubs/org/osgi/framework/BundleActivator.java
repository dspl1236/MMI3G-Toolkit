package org.osgi.framework;

/**
 * Stub of org.osgi.framework.BundleActivator for offline compilation.
 * At runtime, the real interface is provided by the MMI's OSGi framework.
 *
 * Signatures derived from decompiled AppActivator.java usage.
 */
public interface BundleActivator {
    public void start(BundleContext context) throws Exception;
    public void stop(BundleContext context) throws Exception;
}
