/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  org.dsi.ifc.base.DSIFatalException
 *  org.dsi.ifc.base.DSINonFatalException
 */
package de.audi.tghu.development.model;

import de.audi.parser.ESDFileParser;
import de.audi.tghu.development.EngineeringException;
import de.audi.tghu.development.eis.EngineeringInfoService;
import de.audi.tghu.development.eis.ExportCallbackHandler;
import de.audi.tghu.development.eis.ExportKey;
import de.audi.tghu.development.eis.PersistenceAccessor;
import de.audi.tghu.development.manager.LogMan;
import de.audi.tghu.development.model.ScreenElementModel;
import de.audi.tghu.development.model.ScreenModel;
import de.audi.tghu.development.renderer.ScreenRenderer;
import de.audi.tghu.development.widget.ExportWidget;
import de.audi.tghu.development.widget.Widget;
import java.util.ArrayList;
import java.util.List;
import org.dsi.ifc.base.DSIFatalException;
import org.dsi.ifc.base.DSINonFatalException;

public class ExportModel
extends ScreenElementModel {
    private String screen;
    private String scope;

    public ExportModel() {
        super(9, 0);
    }

    public boolean areRequiredFieldsSet() {
        return this.label != null && this.screen != null && this.scope != null;
    }

    public void performAction() throws EngineeringException {
        new Thread(new Runnable(){

            public void run() {
                int n;
                LogMan.log("Export started");
                List list = new ArrayList(10);
                list = ESDFileParser.getInstance().getScreens(ExportModel.this.screen, list);
                for (n = 0; n < list.size(); ++n) {
                    ScreenModel screenModel = (ScreenModel)list.get(n);
                    PersistenceAccessor persistenceAccessor = EngineeringInfoService.getInstance().getPersistenceAccessor();
                    for (int i = 0; i < screenModel.getNumElements(); ++i) {
                        ScreenElementModel screenElementModel = screenModel.getElement(i);
                        int n2 = screenElementModel.getNamespace();
                        long[] lArray = screenElementModel.getKeys();
                        ArrayList<ExportKey> arrayList = new ArrayList<ExportKey>(lArray.length);
                        for (int j = 0; j < lArray.length; ++j) {
                            ExportKey exportKey = new ExportKey(screenElementModel.label, screenElementModel.modelType, n2, lArray[j]);
                            arrayList.add(exportKey);
                            LogMan.log(3, "exportKey added -> " + exportKey);
                        }
                        ExportCallbackHandler.getInstance().setExportKeys(arrayList);
                        try {
                            LogMan.log(3, "poll_hb with datatype (ns=" + n2 + "/keys[0]=" + lArray[0] + ") -> wait 50ms");
                            persistenceAccessor._poll_hb(screenElementModel.getDataType(), n2, lArray);
                            Thread.sleep(20L);
                            continue;
                        }
                        catch (DSINonFatalException dSINonFatalException) {
                            dSINonFatalException.printStackTrace();
                            continue;
                        }
                        catch (DSIFatalException dSIFatalException) {
                            dSIFatalException.printStackTrace();
                            continue;
                        }
                        catch (InterruptedException interruptedException) {
                            interruptedException.printStackTrace();
                        }
                    }
                }
                try {
                    Thread.sleep(50L);
                    if (System.getProperty("os.name").indexOf("QNX") != -1) {
                        n = 0;
                        n = ExportCallbackHandler.getInstance().saveExport("/fs/sd0/export");
                        if (n != 0) {
                            ExportCallbackHandler.getInstance().saveExport("/fs/sd1/export");
                        }
                    } else {
                        ExportCallbackHandler.getInstance().saveExport("C:/export.txt");
                    }
                }
                catch (InterruptedException interruptedException) {
                    interruptedException.printStackTrace();
                }
                LogMan.log("Export finished");
                if (ExportModel.this.callbackHandler != null) {
                    ExportModel.this.callbackHandler.workDone();
                    LogMan.log("callbackHandler in ExportModel called");
                }
            }
        }).start();
    }

    public void updateData(int n, long l, Object object) {
    }

    public void setScreen(String string) {
        this.screen = string;
    }

    public void setScope(String string) {
        this.scope = string;
    }

    public String getScope() {
        return this.scope;
    }

    public String getScreen() {
        return this.screen;
    }

    public Widget getWidget(ScreenRenderer screenRenderer) {
        return new ExportWidget(this, screenRenderer);
    }
}

