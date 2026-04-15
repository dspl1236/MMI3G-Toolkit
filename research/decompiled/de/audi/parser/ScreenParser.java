/*
 * Decompiled with CFR 0.152.
 */
package de.audi.parser;

import de.audi.parser.GenericParser;
import de.audi.parser.LinkInfo;
import de.audi.parser.ParseException;
import de.audi.parser.element.ElementParserIFC;
import de.audi.tghu.development.manager.LogMan;
import de.audi.tghu.development.model.LinkModel;
import de.audi.tghu.development.model.ScreenElementModel;
import de.audi.tghu.development.model.ScreenModel;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Hashtable;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

public class ScreenParser
extends GenericParser {
    public static int SCREENID_MAIN;
    private static Map screens;
    private static Map screenNames;
    private static Map screenLinkings;
    private static ScreenModel currentScreen;
    private static int runningScreenId;
    private static int parsedElements;
    private static int parsedScreens;

    protected void init() {
        runningScreenId = 0;
        screens = new Hashtable(100);
        screenLinkings = new Hashtable(100);
        screenNames = new Hashtable(100);
        parsedElements = 0;
        parsedScreens = 0;
    }

    protected void parseScreens() throws IOException {
        String[] stringArray = reader.readTokens();
        if (stringArray.length > 0) {
            try {
                this.parseScreenOrElement(stringArray);
            }
            catch (ParseException parseException) {
                this.parserLog(parseException.getMessage(), parseException.getTokenIndex());
            }
        }
    }

    private void parseScreenOrElement(String[] stringArray) throws ParseException {
        ScreenElementModel screenElementModel = null;
        if (stringArray[0].equals("screen")) {
            this.parseScreen(stringArray);
        } else {
            screenElementModel = this.parseElement(stringArray);
        }
        if (screenElementModel != null) {
            currentScreen.addElement(screenElementModel);
        }
    }

    private void parseScreen(String[] stringArray) {
        if (stringArray.length == 3) {
            String string = stringArray[1].toLowerCase();
            String string2 = stringArray[2].toLowerCase();
            try {
                if ("main".equals(string)) {
                    SCREENID_MAIN = runningScreenId;
                } else {
                    this.prepareLink(string, string2, runningScreenId);
                }
                currentScreen = new ScreenModel(runningScreenId);
                currentScreen.setScreenName(string);
                screens.put(new Integer(runningScreenId), currentScreen);
                screenNames.put(string, new Integer(runningScreenId));
                ++runningScreenId;
                ++parsedScreens;
            }
            catch (NumberFormatException numberFormatException) {
                this.parserLog("screen id not a number");
            }
        } else {
            this.parserLog("wrong number of arguments for SCREEN");
        }
    }

    private ScreenElementModel parseElement(String[] stringArray) throws ParseException {
        String string = "de.audi.parser.element." + stringArray[0].substring(0, 1).toUpperCase() + stringArray[0].substring(1).toLowerCase() + "Parser";
        ScreenElementModel screenElementModel = null;
        try {
            ElementParserIFC elementParserIFC = this.loadElementParser(string);
            screenElementModel = elementParserIFC.parseElement(stringArray, reader);
        }
        catch (Throwable throwable) {
            System.out.println(string);
        }
        ++parsedElements;
        return screenElementModel;
    }

    private ElementParserIFC loadElementParser(String string) {
        ElementParserIFC elementParserIFC = null;
        try {
            Class<?> clazz = Class.forName(string);
            elementParserIFC = (ElementParserIFC)clazz.newInstance();
        }
        catch (ClassNotFoundException classNotFoundException) {
            this.parserLog("Element " + string + " not defined! (" + reader.getFileName() + ")");
        }
        catch (InstantiationException instantiationException) {
            this.parserLog("Element " + string + " cannot be instanciated!");
        }
        catch (IllegalAccessException illegalAccessException) {
            this.parserLog("Element " + string + " cannot be accessed!");
        }
        return elementParserIFC;
    }

    private void prepareLink(String string, String string2, int n) {
        List list = this.getLinkList(string2);
        list.add(new LinkInfo(string, n));
        screenLinkings.put(string2, list);
    }

    private List getLinkList(String string) {
        ArrayList arrayList = (ArrayList)screenLinkings.get(string);
        if (arrayList == null) {
            arrayList = new ArrayList();
        }
        return arrayList;
    }

    protected void linkScreens() {
        Iterator iterator = screenLinkings.keySet().iterator();
        while (iterator.hasNext()) {
            String string = (String)iterator.next();
            List list = (List)screenLinkings.get(string);
            for (int i = 0; i < list.size(); ++i) {
                Integer n = (Integer)screenNames.get(string);
                if (n == null) continue;
                LinkInfo linkInfo = (LinkInfo)list.get(i);
                LinkModel linkModel = new LinkModel();
                linkModel.setLabel(linkInfo.getLinkName());
                linkModel.setScreenId(linkInfo.getLinkId());
                ScreenModel screenModel = (ScreenModel)screens.get(new Integer(n));
                if (screenModel == null) continue;
                screenModel.addElement(linkModel);
            }
        }
        LogMan.log(4, "linkScreens() finished");
    }

    public ScreenModel getScreen(int n) {
        LogMan.log(4, "screenTable.get(" + n + ")");
        ScreenModel screenModel = null;
        if (screens != null) {
            screenModel = (ScreenModel)screens.get(new Integer(n));
        }
        if (screenModel == null) {
            screenModel = new ScreenModel(-1);
            screenModel.setScreenName("Screen " + n + " not found!");
        }
        return screenModel;
    }

    public ScreenModel getScreen(String string) {
        int n = (Integer)screenNames.get(string);
        return this.getScreen(n);
    }

    public List getScreens(String string, List list) {
        if (string != null) {
            list.add(this.getScreen(string));
            List list2 = (List)screenLinkings.get(string);
            if (list2 != null) {
                for (int i = 0; i < list2.size(); ++i) {
                    LinkInfo linkInfo = (LinkInfo)list2.get(i);
                    this.getScreens(linkInfo.getLinkName(), list);
                }
            }
        }
        return list;
    }
}

