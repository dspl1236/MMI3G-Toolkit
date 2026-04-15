/*
 * Decompiled with CFR 0.152.
 */
package de.audi.commons.tools;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.UnsupportedEncodingException;

public interface TokenReaderIFC {
    public void setFile(File var1) throws FileNotFoundException, UnsupportedEncodingException;

    public boolean ready() throws IOException;

    public String[] readTokens() throws IOException;

    public String getFileName();

    public void mark() throws IOException;

    public void reset() throws IOException;

    public int getCurrentLine();

    public String getToken(int var1);

    public void setReReadLastLine();
}

