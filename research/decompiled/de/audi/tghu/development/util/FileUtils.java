/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.util;

import de.audi.tghu.development.util.IErrorTypeDelegate;
import java.io.BufferedInputStream;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.Reader;
import java.io.Writer;
import java.net.MalformedURLException;
import java.net.URL;
import java.text.DecimalFormat;
import java.text.StringCharacterIterator;
import java.util.Random;
import java.util.Stack;
import java.util.StringTokenizer;
import java.util.Vector;

public class FileUtils {
    private static final FileUtils PRIMARY_INSTANCE = new FileUtils(null);
    private static final String PATH_SEP = System.getProperty("path.separator");
    private static boolean onDos = PATH_SEP.equals(";");
    private static Random rand = new Random(System.currentTimeMillis() + Runtime.getRuntime().freeMemory());
    private static final int BUF_SIZE = 8192;
    private static boolean[] isSpecial = new boolean[256];
    private static char[] escapedChar1 = new char[256];
    private static char[] escapedChar2 = new char[256];
    private IErrorTypeDelegate errorDelegator;

    public static FileUtils newFileUtils(IErrorTypeDelegate iErrorTypeDelegate) {
        return new FileUtils(iErrorTypeDelegate);
    }

    public static FileUtils getFileUtils() {
        return PRIMARY_INSTANCE;
    }

    protected FileUtils(IErrorTypeDelegate iErrorTypeDelegate) {
        this.errorDelegator = iErrorTypeDelegate;
    }

    public URL getFileURL(File file) throws MalformedURLException {
        return new URL(this.toURI(file.getAbsolutePath()));
    }

    public void setFileLastModified(File file, long l) {
        file.setLastModified(l < 0L ? System.currentTimeMillis() : l);
    }

    public File resolveFile(File file, String string) {
        if (FileUtils.isAbsolutePath(string = string.replace('/', File.separatorChar).replace('\\', File.separatorChar))) {
            return this.normalize(string);
        }
        if (file == null) {
            return new File(string);
        }
        File file2 = new File(file.getAbsolutePath());
        StringTokenizer stringTokenizer = new StringTokenizer(string, File.separator);
        while (stringTokenizer.hasMoreTokens()) {
            String string2 = stringTokenizer.nextToken();
            if (string2.equals("..")) {
                if ((file2 = file2.getParentFile()) != null) continue;
                String string3 = "The file or path you specified (" + string + ") is invalid relative to " + file.getPath();
                throw this.createUserRuntimeException(string3);
            }
            if (string2.equals(".")) continue;
            file2 = new File(file2, string2);
        }
        return new File(file2.getAbsolutePath());
    }

    public static boolean isAbsolutePath(String string) {
        if (string.startsWith(File.separator)) {
            return true;
        }
        return onDos && string.length() >= 2 && Character.isLetter(string.charAt(0)) && string.charAt(1) == ':';
    }

    public File normalize(String string) {
        int n;
        CharSequence charSequence;
        Object object;
        Object object2;
        String string2 = string;
        string = string.replace('/', File.separatorChar).replace('\\', File.separatorChar);
        int n2 = string.indexOf(":");
        if (!FileUtils.isAbsolutePath(string)) {
            String string3 = string + " is not an absolute path";
            throw this.createUserRuntimeException(string3);
        }
        boolean bl = false;
        String string4 = null;
        if (onDos && string.length() >= 2 && Character.isLetter(string.charAt(0)) && string.charAt(1) == ':') {
            bl = true;
            object2 = string.replace('/', '\\').toCharArray();
            object = new StringBuffer();
            for (int i = 0; i < n2; ++i) {
                ((StringBuffer)object).append(Character.toUpperCase((char)object2[i]));
            }
            ((StringBuffer)object).append(':');
            if (n2 + 1 < string.length()) {
                ((StringBuffer)object).append(File.separatorChar);
            }
            string4 = ((StringBuffer)object).toString();
            charSequence = new StringBuffer();
            for (n = n2 + 1; n < ((Object)object2).length; ++n) {
                if (object2[n] == 92 && (object2[n] != 92 || object2[n - 1] == 92)) continue;
                ((StringBuffer)charSequence).append((char)object2[n]);
            }
            string = ((StringBuffer)charSequence).toString().replace('\\', File.separatorChar);
        } else if (string.length() == 1) {
            string4 = File.separator;
            string = "";
        } else if (string.charAt(1) == File.separatorChar) {
            string4 = File.separator + File.separator;
            string = string.substring(2);
        } else {
            string4 = File.separator;
            string = string.substring(1);
        }
        object2 = new Stack<String>();
        ((Stack)object2).push(string4);
        object = new StringTokenizer(string, File.separator);
        while (((StringTokenizer)object).hasMoreTokens()) {
            charSequence = ((StringTokenizer)object).nextToken();
            if (".".equals(charSequence)) continue;
            if ("..".equals(charSequence)) {
                if (((Vector)object2).size() < 2) {
                    throw this.createUserRuntimeException("Cannot resolve path " + string2);
                }
                ((Stack)object2).pop();
                continue;
            }
            ((Stack)object2).push(charSequence);
        }
        charSequence = new StringBuffer();
        for (n = 0; n < ((Vector)object2).size(); ++n) {
            if (n > 1) {
                ((StringBuffer)charSequence).append(File.separatorChar);
            }
            ((StringBuffer)charSequence).append(((Vector)object2).elementAt(n));
        }
        string = ((StringBuffer)charSequence).toString();
        if (bl) {
            string = string.replace('/', '\\');
        }
        return new File(string);
    }

    public String toVMSPath(File file) {
        String string = this.normalize(file.getAbsolutePath()).getPath();
        String string2 = file.getName();
        boolean bl = string.charAt(0) == File.separatorChar;
        boolean bl2 = file.isDirectory() && !string2.regionMatches(true, string2.length() - 4, ".DIR", 0, 4);
        String string3 = null;
        StringBuffer stringBuffer = null;
        String string4 = null;
        int n = 0;
        if (bl) {
            n = string.indexOf(File.separatorChar, 1);
            if (n == -1) {
                return string.substring(1) + ":[000000]";
            }
            string3 = string.substring(1, n++);
        }
        if (bl2) {
            stringBuffer = new StringBuffer(string.substring(n).replace(File.separatorChar, '.'));
        } else {
            int n2 = string.lastIndexOf(File.separatorChar, string.length());
            if (n2 == -1 || n2 < n) {
                string4 = string.substring(n);
            } else {
                stringBuffer = new StringBuffer(string.substring(n, n2).replace(File.separatorChar, '.'));
                n = n2 + 1;
                if (string.length() > n) {
                    string4 = string.substring(n);
                }
            }
        }
        if (!bl && stringBuffer != null) {
            stringBuffer.insert(0, '.');
        }
        String string5 = (string3 != null ? string3 + ":" : "") + (stringBuffer != null ? "[" + stringBuffer + "]" : "") + (string4 != null ? string4 : "");
        return string5;
    }

    /*
     * WARNING - Removed try catching itself - possible behaviour change.
     */
    public File createTempFile(String string, String string2, File file) {
        File file2 = null;
        String string3 = file == null ? System.getProperty("java.io.tmpdir") : file.getPath();
        DecimalFormat decimalFormat = new DecimalFormat("#####");
        Random random = rand;
        synchronized (random) {
            while ((file2 = new File(string3, string + decimalFormat.format(Math.abs(rand.nextInt())) + string2)).exists()) {
            }
        }
        return file2;
    }

    public boolean contentEquals(File file, File file2) throws IOException {
        return this.contentEquals(file, file2, false);
    }

    public boolean contentEquals(File file, File file2, boolean bl) throws IOException {
        if (file.exists() != file2.exists()) {
            return false;
        }
        if (!file.exists()) {
            return true;
        }
        if (file.isDirectory() || file2.isDirectory()) {
            return false;
        }
        if (this.fileNameEquals(file, file2)) {
            return true;
        }
        return bl ? this.textEquals(file, file2) : this.binaryEquals(file, file2);
    }

    /*
     * WARNING - Removed try catching itself - possible behaviour change.
     * Enabled aggressive block sorting
     * Enabled unnecessary exception pruning
     * Enabled aggressive exception aggregation
     */
    private boolean binaryEquals(File file, File file2) throws IOException {
        boolean bl;
        BufferedInputStream bufferedInputStream;
        BufferedInputStream bufferedInputStream2;
        block7: {
            block8: {
                boolean bl2;
                if (file.length() != file2.length()) {
                    return false;
                }
                bufferedInputStream2 = null;
                bufferedInputStream = null;
                try {
                    bufferedInputStream2 = new BufferedInputStream(new FileInputStream(file));
                    bufferedInputStream = new BufferedInputStream(new FileInputStream(file2));
                    int n = ((InputStream)bufferedInputStream2).read();
                    while (n != -1) {
                        if (n != ((InputStream)bufferedInputStream).read()) {
                            bl = false;
                            break block7;
                        }
                        n = ((InputStream)bufferedInputStream2).read();
                    }
                    if (((InputStream)bufferedInputStream).read() == -1) break block8;
                    bl2 = false;
                }
                catch (Throwable throwable) {
                    FileUtils.close(bufferedInputStream2);
                    FileUtils.close(bufferedInputStream);
                    throw throwable;
                }
                FileUtils.close(bufferedInputStream2);
                FileUtils.close(bufferedInputStream);
                return bl2;
            }
            boolean bl3 = true;
            FileUtils.close(bufferedInputStream2);
            FileUtils.close(bufferedInputStream);
            return bl3;
        }
        FileUtils.close(bufferedInputStream2);
        FileUtils.close(bufferedInputStream);
        return bl;
    }

    /*
     * WARNING - Removed try catching itself - possible behaviour change.
     * Enabled aggressive block sorting
     * Enabled unnecessary exception pruning
     * Enabled aggressive exception aggregation
     */
    private boolean textEquals(File file, File file2) throws IOException {
        boolean bl;
        BufferedReader bufferedReader;
        BufferedReader bufferedReader2;
        block6: {
            block7: {
                boolean bl2;
                bufferedReader2 = null;
                bufferedReader = null;
                try {
                    bufferedReader2 = new BufferedReader(new FileReader(file));
                    bufferedReader = new BufferedReader(new FileReader(file2));
                    String string = bufferedReader2.readLine();
                    while (string != null) {
                        if (!string.equals(bufferedReader.readLine())) {
                            bl = false;
                            break block6;
                        }
                        string = bufferedReader2.readLine();
                    }
                    if (bufferedReader.readLine() == null) break block7;
                    bl2 = false;
                }
                catch (Throwable throwable) {
                    FileUtils.close(bufferedReader2);
                    FileUtils.close(bufferedReader);
                    throw throwable;
                }
                FileUtils.close(bufferedReader2);
                FileUtils.close(bufferedReader);
                return bl2;
            }
            boolean bl3 = true;
            FileUtils.close(bufferedReader2);
            FileUtils.close(bufferedReader);
            return bl3;
        }
        FileUtils.close(bufferedReader2);
        FileUtils.close(bufferedReader);
        return bl;
    }

    public File getParentFile(File file) {
        return file == null ? null : file.getParentFile();
    }

    public static final String readFully(Reader reader) throws IOException {
        return FileUtils.readFully(reader, 8192);
    }

    public static final String readFully(Reader reader, int n) throws IOException {
        if (n <= 0) {
            throw new IllegalArgumentException("Buffer size must be greater than 0");
        }
        char[] cArray = new char[n];
        int n2 = 0;
        StringBuffer stringBuffer = null;
        while (n2 != -1) {
            n2 = reader.read(cArray);
            if (n2 <= 0) continue;
            stringBuffer = stringBuffer == null ? new StringBuffer() : stringBuffer;
            stringBuffer.append(new String(cArray, 0, n2));
        }
        return stringBuffer == null ? null : stringBuffer.toString();
    }

    public boolean createNewFile(File file) throws IOException {
        return file.createNewFile();
    }

    public boolean createNewFile(File file, boolean bl) throws IOException {
        File file2 = file.getParentFile();
        if (bl && !file2.exists()) {
            file2.mkdirs();
        }
        return file.createNewFile();
    }

    public boolean isSymbolicLink(File file, String string) throws IOException {
        File file2;
        if (file == null) {
            file2 = new File(string);
            file = file2.getParentFile();
            string = file2.getName();
        }
        return !(file2 = new File(file.getCanonicalPath(), string)).getAbsolutePath().equals(file2.getCanonicalPath());
    }

    public String removeLeadingPath(File file, File file2) {
        String string;
        String string2 = this.normalize(file.getAbsolutePath()).getAbsolutePath();
        if (string2.equals(string = this.normalize(file2.getAbsolutePath()).getAbsolutePath())) {
            return "";
        }
        if (!string2.endsWith(File.separator)) {
            string2 = string2 + File.separator;
        }
        return string.startsWith(string2) ? string.substring(string2.length()) : string;
    }

    public String toURI(String string) {
        boolean bl = new File(string).isDirectory();
        StringBuffer stringBuffer = new StringBuffer("file:");
        try {
            string = this.normalize(string).getAbsolutePath();
            stringBuffer.append("//");
            if (!string.startsWith(File.separator)) {
                stringBuffer.append("/");
            }
        }
        catch (RuntimeException runtimeException) {
            // empty catch block
        }
        string = string.replace('\\', '/');
        StringCharacterIterator stringCharacterIterator = new StringCharacterIterator(string);
        char c = stringCharacterIterator.first();
        while (c != '\uffff') {
            if (c < '\u0100' && isSpecial[c]) {
                stringBuffer.append('%');
                stringBuffer.append(escapedChar1[c]);
                stringBuffer.append(escapedChar2[c]);
            } else {
                stringBuffer.append(c);
            }
            c = stringCharacterIterator.next();
        }
        if (bl && !string.endsWith("/")) {
            stringBuffer.append('/');
        }
        return stringBuffer.toString();
    }

    public boolean fileNameEquals(File file, File file2) {
        return this.normalize(file.getAbsolutePath()).equals(this.normalize(file2.getAbsolutePath()));
    }

    public static void close(Writer writer) {
        if (writer != null) {
            try {
                writer.close();
            }
            catch (IOException iOException) {
                // empty catch block
            }
        }
    }

    public static void close(Reader reader) {
        if (reader != null) {
            try {
                reader.close();
            }
            catch (IOException iOException) {
                // empty catch block
            }
        }
    }

    public static void close(OutputStream outputStream) {
        if (outputStream != null) {
            try {
                outputStream.close();
            }
            catch (IOException iOException) {
                // empty catch block
            }
        }
    }

    public static void close(InputStream inputStream) {
        if (inputStream != null) {
            try {
                inputStream.close();
            }
            catch (IOException iOException) {
                // empty catch block
            }
        }
    }

    public static void delete(File file) {
        if (file != null) {
            file.delete();
        }
    }

    protected RuntimeException createUserRuntimeException(String string) {
        if (this.errorDelegator != null) {
            return this.errorDelegator.createRuntimeException(string);
        }
        return new IllegalStateException(string);
    }

    static {
        for (int i = 0; i <= 32; ++i) {
            FileUtils.isSpecial[i] = true;
            FileUtils.escapedChar1[i] = Character.forDigit(i >> 4, 16);
            FileUtils.escapedChar2[i] = Character.forDigit(i & 0xF, 16);
        }
        FileUtils.isSpecial[127] = true;
        FileUtils.escapedChar1[127] = 55;
        FileUtils.escapedChar2[127] = 70;
        char[] cArray = new char[]{'<', '>', '#', '%', '\"', '{', '}', '|', '\\', '^', '~', '[', ']', '`'};
        int n = cArray.length;
        for (int i = 0; i < n; ++i) {
            char c = cArray[i];
            FileUtils.isSpecial[c] = true;
            FileUtils.escapedChar1[c] = Character.forDigit(c >> 4, 16);
            FileUtils.escapedChar2[c] = Character.forDigit(c & 0xF, 16);
        }
    }
}

