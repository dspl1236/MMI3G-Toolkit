/*
 * Decompiled with CFR 0.152.
 */
package de.audi.parser;

import java.io.File;
import java.io.FilenameFilter;

class EngineeringFileFilter
implements FilenameFilter {
    EngineeringFileFilter() {
    }

    public boolean accept(File file, String string) {
        return string.endsWith(".esd");
    }
}

