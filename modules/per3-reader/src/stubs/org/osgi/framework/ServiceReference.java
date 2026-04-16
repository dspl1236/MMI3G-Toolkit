package org.osgi.framework;

public interface ServiceReference {
    Object getProperty(String key);
    String[] getPropertyKeys();
}
