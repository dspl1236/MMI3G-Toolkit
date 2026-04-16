package org.osgi.framework;

public interface ServiceRegistration {
    ServiceReference getReference();
    void unregister();
}
