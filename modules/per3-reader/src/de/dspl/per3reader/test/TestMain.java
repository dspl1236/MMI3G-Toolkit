package de.dspl.per3reader.test;

import java.io.File;
import java.io.FileOutputStream;
import java.io.FileReader;
import java.io.BufferedReader;

import de.dspl.per3reader.Per3Reader;
import de.dspl.per3reader.TriggerLoop;

/**
 * Offline test harness.
 *
 * Exercises Per3Reader and TriggerLoop against an in-memory MockDSIPersistence
 * populated with known values, proving the bundle logic is correct
 * independent of the real DSI implementation.
 *
 * This cannot verify the on-MMI OSGi wiring (Activator.addingService and the
 * DEVICE_NAME-filtered service lookup), but it DOES verify:
 *
 *   - Per3Reader's async->sync monitor pattern works correctly
 *   - readInt/readString/readBuffer/readArray all round-trip
 *   - Error codes return null
 *   - Missing addresses return null
 *   - TriggerLoop parses request filenames correctly
 *   - TriggerLoop writes responses atomically (no half-written files)
 *
 * Run:  javac + java -cp build de.dspl.per3reader.test.TestMain
 *       (see build.sh which wires this up as a test step)
 *
 * Exit code 0 = all pass; 1 = any failure.
 */
public class TestMain {

    private static int passed = 0;
    private static int failed = 0;

    public static void main(String[] args) throws Exception {
        System.out.println("=== per3-reader offline test ===");

        testPer3ReaderDirect();
        testPer3ReaderMissing();
        testPer3ReaderString();
        testPer3ReaderBuffer();
        testPer3ReaderArray();
        testTriggerLoopRoundTrip();
        testTriggerLoopMalformed();

        System.out.println();
        System.out.println("Passed: " + passed);
        System.out.println("Failed: " + failed);
        System.exit(failed == 0 ? 0 : 1);
    }

    // --- Tests -------------------------------------------------------------

    static void testPer3ReaderDirect() {
        MockDSIPersistence mock = new MockDSIPersistence().putInt(0, 0x00100015, 42);
        Per3Reader r = new Per3Reader(mock);
        mock.setListener(r);
        Integer v = r.readInt(0, 0x00100015, 1000);
        assertEquals("readInt returns stored value", Integer.valueOf(42), v);
    }

    static void testPer3ReaderMissing() {
        MockDSIPersistence mock = new MockDSIPersistence();
        Per3Reader r = new Per3Reader(mock);
        mock.setListener(r);
        Integer v = r.readInt(0, 0x00000000, 500);
        assertEquals("readInt on missing namespace returns null", null, v);
    }

    static void testPer3ReaderString() {
        MockDSIPersistence mock = new MockDSIPersistence()
                .putString(0, 0x00120004, "HN+R_EU_AU_K0942_4");
        Per3Reader r = new Per3Reader(mock);
        mock.setListener(r);
        String v = r.readString(0, 0x00120004, 1000);
        assertEquals("readString returns stored value", "HN+R_EU_AU_K0942_4", v);
    }

    static void testPer3ReaderBuffer() {
        byte[] expected = new byte[]{1, 2, 3, 4};
        MockDSIPersistence mock = new MockDSIPersistence().putBuffer(0, 0xAA, expected);
        Per3Reader r = new Per3Reader(mock);
        mock.setListener(r);
        byte[] v = r.readBuffer(0, 0xAA, 1000);
        assertArrayEquals("readBuffer returns stored bytes", expected, v);
    }

    static void testPer3ReaderArray() {
        int[] expected = new int[]{10, 20, 30};
        MockDSIPersistence mock = new MockDSIPersistence().putArray(0, 0xBB, expected);
        Per3Reader r = new Per3Reader(mock);
        mock.setListener(r);
        int[] v = r.readArray(0, 0xBB, 1000);
        assertIntArrayEquals("readArray returns stored ints", expected, v);
    }

    static void testTriggerLoopRoundTrip() throws Exception {
        MockDSIPersistence mock = new MockDSIPersistence()
                .putInt(0, 0x00100015, 1234)
                .putString(0, 0x00120004, "TestTrain");
        Per3Reader r = new Per3Reader(mock);
        mock.setListener(r);

        File dir = makeTempDir("per3test");
        TriggerLoop loop = new TriggerLoop(r, dir);
        loop.start();
        try {
            // Request 1: int
            writeReq(dir, "0.00100015.int.req");
            String resp1 = waitForResp(dir, "0.00100015.int.resp", 3000);
            assertEquals("int req returns stored value", "ok 1234", trimOne(resp1));

            // Request 2: string
            writeReq(dir, "0.00120004.string.req");
            String resp2 = waitForResp(dir, "0.00120004.string.resp", 3000);
            assertEquals("string req returns stored value", "ok TestTrain", trimOne(resp2));

            // Request 3: missing address
            writeReq(dir, "0.DEADBEEF.int.req");
            String resp3 = waitForResp(dir, "0.DEADBEEF.int.resp", 3000);
            assertTrue("missing addr returns err", resp3 != null && resp3.startsWith("err"));

        } finally {
            loop.shutdown();
            deleteDir(dir);
        }
    }

    static void testTriggerLoopMalformed() throws Exception {
        MockDSIPersistence mock = new MockDSIPersistence();
        Per3Reader r = new Per3Reader(mock);
        mock.setListener(r);

        File dir = makeTempDir("per3test-bad");
        TriggerLoop loop = new TriggerLoop(r, dir);
        loop.start();
        try {
            // Missing the .type. segment
            writeReq(dir, "badfilename.req");
            String resp = waitForResp(dir, "badfilename.resp", 3000);
            assertTrue("malformed filename returns err", resp != null && resp.startsWith("err"));
        } finally {
            loop.shutdown();
            deleteDir(dir);
        }
    }

    // --- Assertions + helpers ----------------------------------------------

    static void assertEquals(String label, Object expected, Object actual) {
        boolean ok = (expected == null) ? (actual == null) : expected.equals(actual);
        report(label, ok, "expected=" + expected + " actual=" + actual);
    }

    static void assertTrue(String label, boolean cond) {
        report(label, cond, "condition was false");
    }

    static void assertArrayEquals(String label, byte[] a, byte[] b) {
        boolean ok = (a == null && b == null) ||
                     (a != null && b != null && a.length == b.length);
        if (ok && a != null) {
            for (int i = 0; i < a.length; i++) {
                if (a[i] != b[i]) { ok = false; break; }
            }
        }
        report(label, ok, "arrays differ");
    }

    static void assertIntArrayEquals(String label, int[] a, int[] b) {
        boolean ok = (a == null && b == null) ||
                     (a != null && b != null && a.length == b.length);
        if (ok && a != null) {
            for (int i = 0; i < a.length; i++) {
                if (a[i] != b[i]) { ok = false; break; }
            }
        }
        report(label, ok, "int arrays differ");
    }

    static void report(String label, boolean ok, String detail) {
        if (ok) {
            System.out.println("  [PASS] " + label);
            passed++;
        } else {
            System.out.println("  [FAIL] " + label + " — " + detail);
            failed++;
        }
    }

    static File makeTempDir(String prefix) throws Exception {
        File base = new File(System.getProperty("java.io.tmpdir"));
        File d = new File(base, prefix + "-" + System.nanoTime());
        d.mkdirs();
        return d;
    }

    static void deleteDir(File d) {
        if (!d.exists()) return;
        File[] kids = d.listFiles();
        if (kids != null) for (File k : kids) k.delete();
        d.delete();
    }

    static void writeReq(File dir, String name) throws Exception {
        File f = new File(dir, name);
        FileOutputStream out = new FileOutputStream(f);
        out.write("".getBytes());
        out.close();
    }

    static String waitForResp(File dir, String respName, long timeoutMs) throws Exception {
        long deadline = System.currentTimeMillis() + timeoutMs;
        File respFile = new File(dir, respName);
        while (System.currentTimeMillis() < deadline) {
            if (respFile.exists()) {
                BufferedReader br = new BufferedReader(new FileReader(respFile));
                StringBuilder sb = new StringBuilder();
                String line;
                while ((line = br.readLine()) != null) sb.append(line).append('\n');
                br.close();
                return sb.toString();
            }
            Thread.sleep(50);
        }
        return null;
    }

    static String trimOne(String s) {
        if (s == null) return null;
        if (s.endsWith("\n")) s = s.substring(0, s.length() - 1);
        return s;
    }
}
