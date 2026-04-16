package de.dspl.per3reader;

import java.io.File;
import java.io.FileOutputStream;
import java.io.FileReader;
import java.io.BufferedReader;
import java.io.IOException;

/**
 * Background thread that polls a request directory for read requests and
 * writes responses.
 *
 * Request file format (written by a shell script):
 *   Filename: {namespace}.{addr-hex}.{type}.req
 *     e.g. 0.00100015.int.req           -> namespace 0, addr 0x00100015, type int
 *          0.00120004.string.req        -> namespace 0, addr 0x00120004, type string
 *   Content: (ignored; the filename is the whole request)
 *
 * Response file format (written by us):
 *   Filename: {namespace}.{addr-hex}.{type}.resp
 *   Content: single line:
 *     ok <value>               -- success
 *     err <reason>             -- failure / timeout / bad parse
 *
 * Atomicity: we write to .tmp then rename to .resp so a shell script can
 * safely poll for the final filename without ever seeing a half-written file.
 *
 * Polling loop: 100 ms sleep. Not a tight loop; light on CPU.
 */
public class TriggerLoop extends Thread {

    private static final long POLL_INTERVAL_MS = 100L;
    private static final long READ_TIMEOUT_MS = 2000L;

    private final File requestDir;
    private final Per3Reader reader;
    private volatile boolean running = true;

    public TriggerLoop(Per3Reader reader, File requestDir) {
        super("per3-reader-trigger-loop");
        this.reader = reader;
        this.requestDir = requestDir;
        this.setDaemon(true);
    }

    public void shutdown() {
        running = false;
        this.interrupt();
    }

    public void run() {
        ensureDir();
        while (running) {
            try {
                File[] reqs = listRequests();
                if (reqs != null) {
                    for (int i = 0; i < reqs.length; i++) {
                        handleRequest(reqs[i]);
                    }
                }
                Thread.sleep(POLL_INTERVAL_MS);
            } catch (InterruptedException ie) {
                break;
            } catch (Throwable t) {
                // Swallow — never let one bad request file kill the loop
                log("trigger loop error: " + t.getMessage());
                try { Thread.sleep(POLL_INTERVAL_MS); } catch (InterruptedException ie2) { break; }
            }
        }
    }

    private void ensureDir() {
        if (!requestDir.exists()) {
            requestDir.mkdirs();
        }
    }

    private File[] listRequests() {
        if (!requestDir.isDirectory()) return null;
        String[] names = requestDir.list();
        if (names == null) return null;
        java.util.ArrayList matches = new java.util.ArrayList();
        for (int i = 0; i < names.length; i++) {
            if (names[i].endsWith(".req")) {
                matches.add(new File(requestDir, names[i]));
            }
        }
        File[] out = new File[matches.size()];
        for (int i = 0; i < out.length; i++) out[i] = (File) matches.get(i);
        return out;
    }

    private void handleRequest(File req) {
        String name = req.getName();
        // Strip .req
        String stem = name.substring(0, name.length() - 4);
        // Expect: {ns}.{addr-hex}.{type}
        String[] parts = split(stem, '.');
        File resp = new File(requestDir, stem + ".resp");
        File tmp = new File(requestDir, stem + ".tmp");

        String result;
        if (parts.length != 3) {
            result = "err malformed-filename";
        } else {
            int ns;
            long addr;
            try {
                ns = Integer.parseInt(parts[0]);
                addr = Long.parseLong(parts[1], 16);
            } catch (NumberFormatException nfe) {
                result = "err bad-number " + nfe.getMessage();
                writeResp(resp, tmp, result);
                req.delete();
                return;
            }

            String type = parts[2];
            if ("int".equals(type)) {
                Integer v = reader.readInt(ns, addr, READ_TIMEOUT_MS);
                result = (v == null) ? "err timeout-or-error" : ("ok " + v.intValue());
            } else if ("string".equals(type)) {
                String v = reader.readString(ns, addr, READ_TIMEOUT_MS);
                result = (v == null) ? "err timeout-or-error" : ("ok " + v);
            } else if ("buffer".equals(type)) {
                byte[] v = reader.readBuffer(ns, addr, READ_TIMEOUT_MS);
                result = (v == null) ? "err timeout-or-error" : ("ok " + hex(v));
            } else if ("array".equals(type)) {
                int[] v = reader.readArray(ns, addr, READ_TIMEOUT_MS);
                result = (v == null) ? "err timeout-or-error" : ("ok " + intArrayStr(v));
            } else {
                result = "err unknown-type " + type;
            }
        }

        writeResp(resp, tmp, result);
        req.delete();
    }

    private void writeResp(File resp, File tmp, String payload) {
        FileOutputStream out = null;
        try {
            out = new FileOutputStream(tmp);
            out.write(payload.getBytes("UTF-8"));
            out.write('\n');
            out.close();
            out = null;
            if (resp.exists()) resp.delete();
            tmp.renameTo(resp);
        } catch (IOException ioe) {
            log("writeResp failed: " + ioe.getMessage());
            if (out != null) try { out.close(); } catch (IOException ignore) { }
        }
    }

    // --- Tiny helpers (avoid pulling in large utility classes) --------------

    private static String[] split(String s, char delim) {
        java.util.ArrayList list = new java.util.ArrayList();
        int start = 0;
        for (int i = 0; i < s.length(); i++) {
            if (s.charAt(i) == delim) {
                list.add(s.substring(start, i));
                start = i + 1;
            }
        }
        list.add(s.substring(start));
        String[] out = new String[list.size()];
        for (int i = 0; i < out.length; i++) out[i] = (String) list.get(i);
        return out;
    }

    private static final char[] HEX = "0123456789abcdef".toCharArray();

    private static String hex(byte[] b) {
        StringBuffer sb = new StringBuffer(b.length * 2);
        for (int i = 0; i < b.length; i++) {
            sb.append(HEX[(b[i] >> 4) & 0xF]);
            sb.append(HEX[b[i] & 0xF]);
        }
        return sb.toString();
    }

    private static String intArrayStr(int[] a) {
        StringBuffer sb = new StringBuffer();
        for (int i = 0; i < a.length; i++) {
            if (i > 0) sb.append(',');
            sb.append(a[i]);
        }
        return sb.toString();
    }

    private static void log(String msg) {
        System.err.println("[per3-reader] " + msg);
    }
}
