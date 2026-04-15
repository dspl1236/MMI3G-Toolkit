/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  org.dsi.ifc.base.DSIFatalException
 *  org.dsi.ifc.base.DSINonFatalException
 */
package de.audi.tghu.development.eis;

import de.audi.tghu.development.eis.EISException;
import de.audi.tghu.development.eis.EngineeringInfoService;
import de.audi.tghu.development.manager.LogMan;
import de.audi.tghu.development.model.DecoderConsumer;
import de.audi.tghu.development.model.ScreenElementModel;
import de.audi.tghu.development.model.TLVDecoder;
import de.audi.tghu.development.model.TLVEncoder;
import java.io.File;
import java.io.IOException;
import org.dsi.ifc.base.DSIFatalException;
import org.dsi.ifc.base.DSINonFatalException;

public class SystemAccessor
implements DecoderConsumer {
    private EngineeringInfoService.CallbackHandler callbackHandler;
    private static final int NAMESPACE_SYSTEM = 1;
    private static final int SYSTEM_FREEMEMORY = 1;
    private static final int SYSTEM_TOTALMEMORY = 2;
    private static final int SYSTEM_GC = 3;
    private static final int SYSTEM_SHELLEXEC = 256;
    private static final long SYSTEM_DECODERTEST = 512L;

    public SystemAccessor(EngineeringInfoService.CallbackHandler callbackHandler) {
        this.callbackHandler = callbackHandler;
    }

    private void getFreeMemory() {
        int n = (int)Runtime.getRuntime().freeMemory();
        this.callbackHandler.updateInt(1, 1, 1L, n);
    }

    private void getTotalMemory() {
        int n = (int)Runtime.getRuntime().totalMemory();
        this.callbackHandler.updateInt(1, 1, 2L, n);
    }

    private void runGC() {
        Runtime.getRuntime().gc();
    }

    private int execScript(String string) {
        final String[] stringArray = new String[]{string};
        boolean bl = false;
        if (System.getProperty("os.name").indexOf("QNX") != -1) {
            bl = true;
        }
        LogMan.log("exec script " + string);
        final int[] nArray = new int[1];
        if (bl) {
            Object object;
            try {
                LogMan.log("delete old fifo");
                object = Runtime.getRuntime().exec("rm script.fifo", null, new File("/scripts"));
                ((Process)object).waitFor();
            }
            catch (IOException iOException) {
                iOException.printStackTrace();
            }
            catch (InterruptedException interruptedException) {
                interruptedException.printStackTrace();
            }
            try {
                LogMan.log("create new fifo");
                object = Runtime.getRuntime().exec("mkfifo script.fifo", null, new File("/scripts"));
                ((Process)object).waitFor();
            }
            catch (IOException iOException) {
                iOException.printStackTrace();
            }
            catch (InterruptedException interruptedException) {
                interruptedException.printStackTrace();
            }
            object = new Thread(){

                public void run() {
                    try {
                        File file = new File(stringArray[0]);
                        if (file.exists()) {
                            String[] stringArray2 = new String[]{"/bin/ksh", "-c", stringArray[0] + " >/scripts/script.fifo"};
                            Process process = Runtime.getRuntime().exec(stringArray2);
                            nArray[0] = process.waitFor();
                            SystemAccessor.this.callbackHandler.updateInt(1, 1, 256L, 1);
                        } else {
                            String[] stringArray3 = new String[]{"/bin/ksh", "-c", "echo \"Script not found!\" >/scripts/script.fifo"};
                            Runtime.getRuntime().exec(stringArray3);
                        }
                    }
                    catch (IOException iOException) {
                        iOException.printStackTrace();
                    }
                    catch (InterruptedException interruptedException) {
                        interruptedException.printStackTrace();
                    }
                }
            };
            ((Thread)object).start();
        } else {
            Thread thread = new Thread(){

                public void run() {
                    try {
                        String[] stringArray2 = new String[]{"cmd", "/c", stringArray[0] + " >C:/output.txt"};
                        Process process = Runtime.getRuntime().exec(stringArray2);
                        nArray[0] = process.waitFor();
                        SystemAccessor.this.callbackHandler.updateInt(1, 1, 256L, 1);
                    }
                    catch (IOException iOException) {
                        iOException.printStackTrace();
                    }
                    catch (InterruptedException interruptedException) {
                        interruptedException.printStackTrace();
                    }
                }
            };
            thread.start();
        }
        return nArray[0];
    }

    private void pollInt(int n, long l) {
        if (n != 1) {
            LogMan.log(2, "SystemAccessor.pollInt(): unsupported namespace, error handling needed!");
            this.callbackHandler.handleError(1, n, l, "SystemAccessor.pollInt(): invalid namespace specified.");
            return;
        }
        if (l == 1L) {
            this.getFreeMemory();
        } else if (l == 2L) {
            this.getTotalMemory();
        } else {
            LogMan.log(2, "SystemAccessor.pollInt(): undefined integer ns=" + n + ", key=" + l);
            this.callbackHandler.handleError(1, n, l, "SystemAccessor.pollInt(): undefined integer ns=" + n + ", key=" + l);
        }
    }

    private void pollString(int n, long l) {
        if (n != 1) {
            LogMan.log(2, "SystemAccessor.pollString(): unsupported namespace, error handling needed!");
            this.callbackHandler.handleError(1, n, l, "SystemAccessor.pollString(): invalid namespace specified.");
            return;
        }
        LogMan.log(2, "SystemAccessor.pollString(): undefined string ns=" + n + ", key=" + l);
        this.callbackHandler.handleError(1, n, l, "SystemAccessor.pollString(): undefined string ns=" + n + ", key=" + l);
    }

    public void pollModel(ScreenElementModel screenElementModel) throws EISException {
        int n = screenElementModel.getDataType();
        int n2 = screenElementModel.getNamespace();
        long[] lArray = screenElementModel.getKeys();
        block4: for (int i = 0; i < lArray.length; ++i) {
            switch (n) {
                case 0: {
                    this.pollInt(n2, lArray[i]);
                    continue block4;
                }
                case 3: {
                    this.pollString(n2, lArray[i]);
                    continue block4;
                }
                default: {
                    LogMan.log(2, "SystemAccessor.pollModel(): invalid data type " + n + " for item ns=" + n2 + ", key=" + lArray[i]);
                    throw new EISException(1, n2, lArray[i], "SystemAccessor.pollModel(): invalid data type " + n);
                }
            }
        }
    }

    public void storeInt(int n, long l, int n2) throws DSINonFatalException, DSIFatalException {
        if (n != 1) {
            LogMan.log(2, "SystemAccessor.storeInt(): unsupported namespace");
            this.callbackHandler.handleError(1, n, l, "SystemAccessor.storeInt(): invalid namespace specified.");
            return;
        }
    }

    public void storeString(int n, long l, String string) throws DSINonFatalException, DSIFatalException {
        int n2;
        if (n != 1) {
            LogMan.log(2, "SystemAccessor.storeString(): unsupported namespace");
            this.callbackHandler.handleError(1, n, l, "SystemAccessor.storeString(): invalid namespace specified.");
            return;
        }
        if (l == 3L) {
            this.runGC();
        } else if (l == 256L && (n2 = this.execScript(string)) != 0) {
            LogMan.log(2, "SystemAccessor.shellExec() returned with error code " + n2);
            this.callbackHandler.handleError(1, n, l, "SystemAccessor.shellExec() returned with error code " + n2);
        }
        if (l == 512L) {
            final SystemAccessor systemAccessor = this;
            new Thread(){

                /*
                 * Unable to fully structure code
                 */
                public void run() {
                    var1_1 = new byte[50][];
                    for (var2_2 = 0; var2_2 < 50; ++var2_2) {
                        var3_4 = new TLVEncoder();
                        for (var4_5 = 0; var4_5 < 20; ++var4_5) {
                            var3_4.encodeString(var4_5 + "11" + var4_5);
                        }
                        var1_1[var2_2] = var3_4.getResult();
                        var3_4.terminate();
                    }
                    while (true) lbl-1000:
                    // 4 sources

                    {
                        for (var2_2 = 0; var2_2 < 50; ++var2_2) {
                            var3_4 = new TLVDecoder(var1_1[var2_2], systemAccessor);
                            var3_4.decode();
                        }
                        try {
                            Thread.sleep(1000L);
                            ** continue;
                        }
                        catch (InterruptedException var2_3) {
                            var2_3.printStackTrace();
                            continue;
                        }
                        break;
                    }
                }
            }.start();
        } else {
            LogMan.log(2, "SystemAccessor.storeString(): undefined string ns=" + n + ", key=" + l);
            this.callbackHandler.handleError(1, n, l, "SystemAccessor.storeString(): undefined string ns=" + n + ", key=" + l);
        }
    }

    public void consumeElement(int n, Object object) {
    }
}

