/*
 * Decompiled with CFR 0.152.
 */
package de.audi.parser;

import de.audi.commons.tools.TokenReader;
import de.audi.parser.EngineeringFileFilter;
import de.audi.parser.ParseException;
import de.audi.parser.ScreenParser;
import de.audi.tghu.development.manager.LogMan;
import de.audi.tghu.development.renderer.ScreenRenderer;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.UnsupportedEncodingException;

public class ESDFileParser
extends ScreenParser {
    private static final String PATH_PROPERTY = "de.audi.tghu.engineering.base_dir";
    private static String engdefsPath = "/mnt/flash/efs1/engdefs";
    private static ESDFileParser parserInstance;

    public void init(File file) throws ParseException, InterruptedException {
        engdefsPath = file.getAbsolutePath();
        this.init();
    }

    public void init(ScreenRenderer screenRenderer) {
        super.init();
        LogMan.log(10, "ESDFileParser.init(): Parser started");
        try {
            File[] fileArray = this.getEngineeringFiles();
            this.parseFiles(fileArray);
            this.linkScreens();
        }
        catch (ParseException parseException) {
            this.parserLog(parseException.getMessage());
        }
        LogMan.log(10, "ESDFileParser.init(): enter main screen");
        screenRenderer.enterScreen(SCREENID_MAIN);
    }

    private File[] getEngineeringFiles() throws ParseException {
        EngineeringFileFilter engineeringFileFilter = new EngineeringFileFilter();
        String string = System.getProperty(PATH_PROPERTY, engdefsPath);
        File[] fileArray = new File(string).listFiles(engineeringFileFilter);
        if (fileArray == null) {
            throw new ParseException("No files found in directory " + string);
        }
        return fileArray;
    }

    private void parseFiles(File[] fileArray) throws ParseException {
        for (int i = 0; i < fileArray.length; ++i) {
            File file = fileArray[i];
            try {
                this.setupTokenReader(file);
                while (reader.ready()) {
                    this.parseScreens();
                }
                continue;
            }
            catch (IOException iOException) {
                LogMan.log("Could not read line!");
                iOException.printStackTrace();
                break;
            }
        }
        LogMan.log(4, "Parser finished");
    }

    private void setupTokenReader(File file) throws FileNotFoundException, UnsupportedEncodingException, ParseException {
        if (reader == null) {
            reader = new TokenReader(file);
        } else {
            reader.setFile(file);
        }
    }

    public static synchronized ESDFileParser getInstance() {
        if (parserInstance == null) {
            parserInstance = new ESDFileParser();
        }
        return parserInstance;
    }
}

