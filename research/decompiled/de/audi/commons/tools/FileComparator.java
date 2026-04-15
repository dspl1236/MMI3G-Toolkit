/*
 * Decompiled with CFR 0.152.
 */
package de.audi.commons.tools;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;

public class FileComparator {
    private transient FileInputStream fis1;
    private transient FileInputStream fis2;

    public FileComparator(File file, File file2) {
        try {
            this.fis1 = new FileInputStream(file);
            this.fis2 = new FileInputStream(file2);
        }
        catch (FileNotFoundException fileNotFoundException) {
            fileNotFoundException.printStackTrace();
        }
    }

    public boolean equals() {
        boolean bl = false;
        try {
            byte[] byArray = new byte[8192];
            byte[] byArray2 = new byte[8192];
            while (this.fis1.available() > 0 && this.fis2.available() > 0) {
                int n;
                int n2 = this.fis1.read(byArray);
                if (n2 != (n = this.fis2.read(byArray2))) continue;
                boolean bl2 = false;
                for (int i = 0; i < n2; ++i) {
                    if (byArray[i] == byArray2[i]) continue;
                    bl2 = true;
                    break;
                }
                if (bl2) continue;
                bl = true;
            }
        }
        catch (IOException iOException) {
            iOException.printStackTrace();
        }
        return bl;
    }
}

