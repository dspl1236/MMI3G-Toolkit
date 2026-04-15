/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.util;

import java.io.File;
import java.util.StringTokenizer;
import java.util.Vector;

public final class SelectorUtils {
    private static SelectorUtils instance = new SelectorUtils();

    private SelectorUtils() {
    }

    public static SelectorUtils getInstance() {
        return instance;
    }

    public static boolean matchPatternStart(String string, String string2) {
        return SelectorUtils.matchPatternStart(string, string2, true);
    }

    public static boolean matchPatternStart(String string, String string2, boolean bl) {
        String string3;
        int n;
        if (string2.startsWith(File.separator) != string.startsWith(File.separator)) {
            return false;
        }
        String[] stringArray = SelectorUtils.tokenizePathAsArray(string);
        String[] stringArray2 = SelectorUtils.tokenizePathAsArray(string2);
        int n2 = 0;
        int n3 = stringArray.length - 1;
        int n4 = stringArray2.length - 1;
        for (n = 0; n2 <= n3 && n <= n4 && !(string3 = stringArray[n2]).equals("**"); ++n2, ++n) {
            if (SelectorUtils.match(string3, stringArray2[n], bl)) continue;
            return false;
        }
        if (n > n4) {
            return true;
        }
        return n2 <= n3;
    }

    public static boolean matchPath(String string, String string2) {
        return SelectorUtils.matchPath(string, string2, true);
    }

    public static boolean matchPath(String string, String string2, boolean bl) {
        String string3;
        int n;
        if (string2.startsWith(File.separator) != string.startsWith(File.separator)) {
            return false;
        }
        String[] stringArray = SelectorUtils.tokenizePathAsArray(string);
        String[] stringArray2 = SelectorUtils.tokenizePathAsArray(string2);
        int n2 = 0;
        int n3 = stringArray.length - 1;
        int n4 = stringArray2.length - 1;
        for (n = 0; n2 <= n3 && n <= n4 && !(string3 = stringArray[n2]).equals("**"); ++n2, ++n) {
            if (SelectorUtils.match(string3, stringArray2[n], bl)) continue;
            stringArray = null;
            stringArray2 = null;
            return false;
        }
        if (n > n4) {
            for (int i = n2; i <= n3; ++i) {
                if (stringArray[i].equals("**")) continue;
                stringArray = null;
                stringArray2 = null;
                return false;
            }
            return true;
        }
        if (n2 > n3) {
            stringArray = null;
            stringArray2 = null;
            return false;
        }
        while (n2 <= n3 && n <= n4 && !(string3 = stringArray[n3]).equals("**")) {
            if (!SelectorUtils.match(string3, stringArray2[n4], bl)) {
                stringArray = null;
                stringArray2 = null;
                return false;
            }
            --n3;
            --n4;
        }
        if (n > n4) {
            for (int i = n2; i <= n3; ++i) {
                if (stringArray[i].equals("**")) continue;
                stringArray = null;
                stringArray2 = null;
                return false;
            }
            return true;
        }
        while (n2 != n3 && n <= n4) {
            int n5;
            int n6 = -1;
            for (n5 = n2 + 1; n5 <= n3; ++n5) {
                if (!stringArray[n5].equals("**")) continue;
                n6 = n5;
                break;
            }
            if (n6 == n2 + 1) {
                ++n2;
                continue;
            }
            n5 = n6 - n2 - 1;
            int n7 = n4 - n + 1;
            int n8 = -1;
            block6: for (int i = 0; i <= n7 - n5; ++i) {
                for (int j = 0; j < n5; ++j) {
                    String string4 = stringArray[n2 + j + 1];
                    String string5 = stringArray2[n + i + j];
                    if (!SelectorUtils.match(string4, string5, bl)) continue block6;
                }
                n8 = n + i;
                break;
            }
            if (n8 == -1) {
                stringArray = null;
                stringArray2 = null;
                return false;
            }
            n2 = n6;
            n = n8 + n5;
        }
        for (int i = n2; i <= n3; ++i) {
            if (stringArray[i].equals("**")) continue;
            stringArray = null;
            stringArray2 = null;
            return false;
        }
        return true;
    }

    public static boolean match(String string, String string2) {
        return SelectorUtils.match(string, string2, true);
    }

    public static boolean match(String string, String string2, boolean bl) {
        char c;
        int n;
        char[] cArray = string.toCharArray();
        char[] cArray2 = string2.toCharArray();
        int n2 = 0;
        int n3 = cArray.length - 1;
        int n4 = 0;
        int n5 = cArray2.length - 1;
        boolean bl2 = false;
        for (n = 0; n < cArray.length; ++n) {
            if (cArray[n] != '*') continue;
            bl2 = true;
            break;
        }
        if (!bl2) {
            if (n3 != n5) {
                return false;
            }
            for (n = 0; n <= n3; ++n) {
                char c2 = cArray[n];
                if (c2 == '?') continue;
                if (bl && c2 != cArray2[n]) {
                    return false;
                }
                if (bl || Character.toUpperCase(c2) == Character.toUpperCase(cArray2[n])) continue;
                return false;
            }
            return true;
        }
        if (n3 == 0) {
            return true;
        }
        while ((c = cArray[n2]) != '*' && n4 <= n5) {
            if (c != '?') {
                if (bl && c != cArray2[n4]) {
                    return false;
                }
                if (!bl && Character.toUpperCase(c) != Character.toUpperCase(cArray2[n4])) {
                    return false;
                }
            }
            ++n2;
            ++n4;
        }
        if (n4 > n5) {
            for (n = n2; n <= n3; ++n) {
                if (cArray[n] == '*') continue;
                return false;
            }
            return true;
        }
        while ((c = cArray[n3]) != '*' && n4 <= n5) {
            if (c != '?') {
                if (bl && c != cArray2[n5]) {
                    return false;
                }
                if (!bl && Character.toUpperCase(c) != Character.toUpperCase(cArray2[n5])) {
                    return false;
                }
            }
            --n3;
            --n5;
        }
        if (n4 > n5) {
            for (n = n2; n <= n3; ++n) {
                if (cArray[n] == '*') continue;
                return false;
            }
            return true;
        }
        while (n2 != n3 && n4 <= n5) {
            int n6;
            n = -1;
            for (n6 = n2 + 1; n6 <= n3; ++n6) {
                if (cArray[n6] != '*') continue;
                n = n6;
                break;
            }
            if (n == n2 + 1) {
                ++n2;
                continue;
            }
            n6 = n - n2 - 1;
            int n7 = n5 - n4 + 1;
            int n8 = -1;
            block8: for (int i = 0; i <= n7 - n6; ++i) {
                for (int j = 0; j < n6; ++j) {
                    c = cArray[n2 + j + 1];
                    if (c != '?' && (bl && c != cArray2[n4 + i + j] || !bl && Character.toUpperCase(c) != Character.toUpperCase(cArray2[n4 + i + j]))) continue block8;
                }
                n8 = n4 + i;
                break;
            }
            if (n8 == -1) {
                return false;
            }
            n2 = n;
            n4 = n8 + n6;
        }
        for (n = n2; n <= n3; ++n) {
            if (cArray[n] == '*') continue;
            return false;
        }
        return true;
    }

    public static Vector tokenizePath(String string) {
        return SelectorUtils.tokenizePath(string, File.separator);
    }

    public static Vector tokenizePath(String string, String string2) {
        Vector<String> vector = new Vector<String>();
        StringTokenizer stringTokenizer = new StringTokenizer(string, string2);
        while (stringTokenizer.hasMoreTokens()) {
            vector.addElement(stringTokenizer.nextToken());
        }
        return vector;
    }

    private static String[] tokenizePathAsArray(String string) {
        char c = File.separatorChar;
        int n = 0;
        int n2 = string.length();
        int n3 = 0;
        for (int i = 0; i < n2; ++i) {
            if (string.charAt(i) != c) continue;
            if (i != n) {
                ++n3;
            }
            n = i + 1;
        }
        if (n2 != n) {
            ++n3;
        }
        String[] stringArray = new String[n3];
        n3 = 0;
        n = 0;
        for (int i = 0; i < n2; ++i) {
            if (string.charAt(i) != c) continue;
            if (i != n) {
                String string2 = string.substring(n, i);
                stringArray[n3++] = string2;
            }
            n = i + 1;
        }
        if (n2 != n) {
            String string3;
            stringArray[n3] = string3 = string.substring(n);
        }
        return stringArray;
    }

    public static boolean isOutOfDate(File file, File file2, int n) {
        if (!file.exists()) {
            return false;
        }
        if (!file2.exists()) {
            return true;
        }
        return file.lastModified() - (long)n > file2.lastModified();
    }

    public static String removeWhitespace(String string) {
        StringBuffer stringBuffer = new StringBuffer();
        if (string != null) {
            StringTokenizer stringTokenizer = new StringTokenizer(string);
            while (stringTokenizer.hasMoreTokens()) {
                stringBuffer.append(stringTokenizer.nextToken());
            }
        }
        return stringBuffer.toString();
    }

    public static boolean hasWildcards(String string) {
        return string.indexOf(42) != -1 || string.indexOf(63) != -1;
    }

    public static String rtrimWildcardTokens(String string) {
        Vector vector = SelectorUtils.tokenizePath(string, File.separator);
        StringBuffer stringBuffer = new StringBuffer();
        for (int i = 0; i < vector.size() && !SelectorUtils.hasWildcards((String)vector.elementAt(i)); ++i) {
            if (i > 0) {
                stringBuffer.append(File.separator);
            }
            stringBuffer.append((String)vector.elementAt(i));
        }
        return stringBuffer.toString();
    }
}

