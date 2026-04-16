package org.osgi.util.tracker;

import org.osgi.framework.ServiceReference;

public interface ServiceTrackerCustomizer {
    Object addingService(ServiceReference reference);
    void modifiedService(ServiceReference reference, Object service);
    void removedService(ServiceReference reference, Object service);
}
