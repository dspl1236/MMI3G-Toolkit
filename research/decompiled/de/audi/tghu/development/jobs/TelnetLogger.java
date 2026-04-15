/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.jobs;

import de.audi.tghu.development.jobs.DefaultLogger;
import java.io.IOException;
import java.io.PrintStream;
import java.net.ServerSocket;
import java.net.Socket;
import java.util.Enumeration;
import java.util.Vector;

public class TelnetLogger
extends DefaultLogger {
    static final String TELNET_LINE_SEP = "\r\n";
    private SocketHandler sh;
    private int port = 10147;

    public int getPort() {
        return this.port;
    }

    public void setPort(int n) {
        this.port = n;
    }

    public void activateOptions() {
        try {
            this.sh = new SocketHandler(this.port);
            this.sh.start();
        }
        catch (Exception exception) {
            this.error("[JobTelnetLogger] Can not activate logger", exception);
        }
    }

    public void close() {
        if (this.sh != null) {
            this.sh.shutdown();
        }
    }

    protected void printMessage(String string, PrintStream printStream, int n) {
        if (this.sh != null) {
            this.sh.send(string);
        }
    }

    public void setOutputPrintStream(PrintStream printStream) {
    }

    public void setErrorPrintStream(PrintStream printStream) {
    }

    protected String getOutputLineSep() {
        return TELNET_LINE_SEP;
    }

    private void error(String string) {
        System.err.println(string);
    }

    private void error(String string, Throwable throwable) {
        System.err.println(string);
        if (throwable != null) {
            System.err.println(TelnetLogger.getStackTrace(throwable));
        }
    }

    protected class SocketHandler
    extends Thread {
        private boolean done = false;
        private Vector streams = new Vector();
        private Vector connections = new Vector();
        private ServerSocket serverSocket;
        private int MAX_CONNECTIONS = 5;
        private int MAX_RETRY = 5;

        public void shutdown() {
            Enumeration enumeration = this.connections.elements();
            while (enumeration.hasMoreElements()) {
                try {
                    ((Socket)enumeration.nextElement()).close();
                }
                catch (Exception exception) {}
            }
            try {
                this.serverSocket.close();
            }
            catch (Exception exception) {
                // empty catch block
            }
            this.done = true;
        }

        public void send(String string) {
            Enumeration enumeration = this.connections.elements();
            Enumeration enumeration2 = this.streams.elements();
            while (enumeration2.hasMoreElements()) {
                Socket socket = (Socket)enumeration.nextElement();
                PrintStream printStream = (PrintStream)enumeration2.nextElement();
                printStream.print(string);
                printStream.print(TelnetLogger.TELNET_LINE_SEP);
                if (!printStream.checkError()) continue;
                this.connections.remove(socket);
                this.streams.remove(printStream);
            }
        }

        public void run() {
            int n = 0;
            while (!this.done) {
                try {
                    Socket socket = this.serverSocket.accept();
                    PrintStream printStream = new PrintStream(socket.getOutputStream(), true);
                    if (this.connections.size() < this.MAX_CONNECTIONS) {
                        this.connections.addElement(socket);
                        this.streams.addElement(printStream);
                        printStream.print("Job Telnet Logger v1.0 (" + this.connections.size() + " active connections)\r\n\r\n");
                        continue;
                    }
                    printStream.print("Too many connections.\r\n");
                    socket.close();
                }
                catch (Exception exception) {
                    TelnetLogger.this.error("[JobTelnetLogger] Encountered error while in SocketHandler loop.", exception);
                    if (++n > this.MAX_RETRY) {
                        this.shutdown();
                        TelnetLogger.this.error("[JobTelnetLogger] Logger stopped! (encountered error on socket)");
                        continue;
                    }
                    try {
                        SocketHandler.sleep(5000L);
                    }
                    catch (Exception exception2) {}
                }
            }
        }

        public SocketHandler(int n) throws IOException {
            this.serverSocket = new ServerSocket(n);
        }
    }
}

