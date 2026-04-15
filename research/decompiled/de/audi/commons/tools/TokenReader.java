/*
 * Decompiled with CFR 0.152.
 */
package de.audi.commons.tools;

import de.audi.commons.tools.LineReader;
import de.audi.commons.tools.TokenReaderIFC;
import de.audi.tghu.development.manager.LogMan;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.StreamTokenizer;
import java.io.StringReader;
import java.io.UnsupportedEncodingException;
import java.util.ArrayList;

public class TokenReader
extends LineReader
implements TokenReaderIFC {
    private String[] tokens;
    private boolean reReadLastLine = false;

    public static String[] tokenizeLine(String string) {
        ArrayList<String> arrayList = new ArrayList<String>();
        StreamTokenizer streamTokenizer = new StreamTokenizer(new StringReader(string));
        streamTokenizer.resetSyntax();
        streamTokenizer.quoteChar(34);
        streamTokenizer.slashSlashComments(true);
        streamTokenizer.wordChars(40, 122);
        streamTokenizer.commentChar(35);
        try {
            while (streamTokenizer.nextToken() != -1) {
                if (streamTokenizer.sval == null) continue;
                arrayList.add(streamTokenizer.sval);
            }
        }
        catch (IOException iOException) {
            LogMan.log("Error on tokenizing line: ", iOException);
        }
        return arrayList.toArray(new String[arrayList.size()]);
    }

    public TokenReader() {
    }

    public TokenReader(String string) throws FileNotFoundException, UnsupportedEncodingException {
        super(string);
    }

    public TokenReader(File file) throws FileNotFoundException, UnsupportedEncodingException {
        super(file);
    }

    public String[] readTokens() throws IOException {
        if (!this.reReadLastLine) {
            String string = super.readln();
            this.tokens = TokenReader.tokenizeLine(string);
        } else {
            this.reReadLastLine = false;
        }
        return this.tokens;
    }

    public String getToken(int n) {
        if (this.tokens != null && this.tokens.length >= n) {
            return this.tokens[n];
        }
        return "";
    }

    public void setReReadLastLine() {
        this.reReadLastLine = true;
    }

    public int getCurrentLine() {
        return this.getLastReadLine();
    }
}

