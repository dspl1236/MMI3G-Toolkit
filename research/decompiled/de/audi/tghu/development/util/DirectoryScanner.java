/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.util;

import de.audi.tghu.development.util.FileUtils;
import de.audi.tghu.development.util.IErrorTypeDelegate;
import de.audi.tghu.development.util.SelectorUtils;
import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Enumeration;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Hashtable;
import java.util.Map;
import java.util.Set;
import java.util.Vector;

public class DirectoryScanner {
    protected static final String[] DEFAULTEXCLUDES = new String[]{"**/*~", "**/#*#", "**/.#*", "**/%*%", "**/._*", "**/CVS", "**/CVS/**", "**/.cvsignore", "**/SCCS", "**/SCCS/**", "**/vssver.scc", "**/.svn", "**/.svn/**", "**/.DS_Store"};
    private FileUtils FILE_UTILS;
    private static final boolean[] CS_SCAN_ONLY = new boolean[]{true};
    private static final boolean[] CS_THEN_NON_CS = new boolean[]{true, false};
    private static Vector defaultExcludes = new Vector();
    protected File basedir;
    protected String[] includes;
    protected String[] excludes;
    protected Vector filesIncluded;
    protected Vector filesNotIncluded;
    protected Vector filesExcluded;
    protected Vector dirsIncluded;
    protected Vector dirsNotIncluded;
    protected Vector dirsExcluded;
    protected Vector filesDeselected;
    protected Vector dirsDeselected;
    protected boolean haveSlowResults = false;
    protected boolean isCaseSensitive = true;
    private boolean followSymlinks = true;
    protected boolean everythingIncluded = true;
    private Map fileListMap = new HashMap();
    private Set scannedDirs = new HashSet();
    private Set includeNonPatterns = new HashSet();
    private Set excludeNonPatterns = new HashSet();
    private String[] includePatterns;
    private String[] excludePatterns;
    private boolean areNonPatternSetsReady = false;
    private boolean scanning = false;
    private Object scanLock = new Object();
    private boolean slowScanning = false;
    private Object slowScanLock = new Object();
    private IllegalStateException illegal = null;
    private IErrorTypeDelegate errorDelegator = null;

    public DirectoryScanner() {
        this.FILE_UTILS = FileUtils.getFileUtils();
    }

    public DirectoryScanner(IErrorTypeDelegate iErrorTypeDelegate) {
        this.FILE_UTILS = FileUtils.newFileUtils(iErrorTypeDelegate);
        this.errorDelegator = iErrorTypeDelegate;
    }

    protected static boolean matchPatternStart(String string, String string2) {
        return SelectorUtils.matchPatternStart(string, string2);
    }

    protected static boolean matchPatternStart(String string, String string2, boolean bl) {
        return SelectorUtils.matchPatternStart(string, string2, bl);
    }

    protected static boolean matchPath(String string, String string2) {
        return SelectorUtils.matchPath(string, string2);
    }

    protected static boolean matchPath(String string, String string2, boolean bl) {
        return SelectorUtils.matchPath(string, string2, bl);
    }

    public static boolean match(String string, String string2) {
        return SelectorUtils.match(string, string2);
    }

    protected static boolean match(String string, String string2, boolean bl) {
        return SelectorUtils.match(string, string2, bl);
    }

    public static String[] getDefaultExcludes() {
        return defaultExcludes.toArray(new String[defaultExcludes.size()]);
    }

    public static boolean addDefaultExclude(String string) {
        if (defaultExcludes.indexOf(string) == -1) {
            defaultExcludes.add(string);
            return true;
        }
        return false;
    }

    public static boolean removeDefaultExclude(String string) {
        return defaultExcludes.remove(string);
    }

    public static void resetDefaultExcludes() {
        defaultExcludes = new Vector();
        for (int i = 0; i < DEFAULTEXCLUDES.length; ++i) {
            defaultExcludes.add(DEFAULTEXCLUDES[i]);
        }
    }

    public void setBasedir(String string) {
        this.setBasedir(new File(string.replace('/', File.separatorChar).replace('\\', File.separatorChar)));
    }

    public synchronized void setBasedir(File file) {
        this.basedir = file;
    }

    public synchronized File getBasedir() {
        return this.basedir;
    }

    public synchronized boolean isCaseSensitive() {
        return this.isCaseSensitive;
    }

    public synchronized void setCaseSensitive(boolean bl) {
        this.isCaseSensitive = bl;
    }

    public synchronized boolean isFollowSymlinks() {
        return this.followSymlinks;
    }

    public synchronized void setFollowSymlinks(boolean bl) {
        this.followSymlinks = bl;
    }

    public synchronized void setIncludes(String[] stringArray) {
        if (stringArray == null) {
            this.includes = null;
        } else {
            this.includes = new String[stringArray.length];
            for (int i = 0; i < stringArray.length; ++i) {
                this.includes[i] = DirectoryScanner.normalizePattern(stringArray[i]);
            }
        }
    }

    public synchronized void setExcludes(String[] stringArray) {
        if (stringArray == null) {
            this.excludes = null;
        } else {
            this.excludes = new String[stringArray.length];
            for (int i = 0; i < stringArray.length; ++i) {
                this.excludes[i] = DirectoryScanner.normalizePattern(stringArray[i]);
            }
        }
    }

    public synchronized void addExcludes(String[] stringArray) {
        if (stringArray != null && stringArray.length > 0) {
            if (this.excludes != null && this.excludes.length > 0) {
                String[] stringArray2 = new String[stringArray.length + this.excludes.length];
                System.arraycopy(this.excludes, 0, stringArray2, 0, this.excludes.length);
                for (int i = 0; i < stringArray.length; ++i) {
                    stringArray2[this.excludes.length + i] = DirectoryScanner.normalizePattern(stringArray[i]);
                }
                this.excludes = stringArray2;
            } else {
                this.setExcludes(stringArray);
            }
        }
    }

    private static String normalizePattern(String string) {
        String string2 = string.replace('/', File.separatorChar).replace('\\', File.separatorChar);
        if (string2.endsWith(File.separator)) {
            string2 = string2 + "**";
        }
        return string2;
    }

    public synchronized boolean isEverythingIncluded() {
        return this.everythingIncluded;
    }

    /*
     * WARNING - Removed try catching itself - possible behaviour change.
     */
    public void scan() throws IllegalStateException {
        Object object;
        Object object2 = this.scanLock;
        synchronized (object2) {
            if (this.scanning) {
                while (this.scanning) {
                    try {
                        this.scanLock.wait();
                    }
                    catch (InterruptedException interruptedException) {}
                }
                if (this.illegal != null) {
                    throw this.illegal;
                }
                return;
            }
            this.scanning = true;
        }
        try {
            object2 = this;
            synchronized (object2) {
                String[] stringArray;
                boolean bl;
                this.illegal = null;
                this.clearResults();
                boolean bl2 = bl = this.includes == null;
                if (bl) {
                    String[] stringArray2 = new String[1];
                    stringArray = stringArray2;
                    stringArray2[0] = "**";
                } else {
                    stringArray = this.includes;
                }
                this.includes = stringArray;
                boolean bl3 = this.excludes == null;
                String[] stringArray3 = this.excludes = bl3 ? new String[]{} : this.excludes;
                if (this.basedir == null) {
                    this.illegal = new IllegalStateException("No basedir set");
                } else {
                    if (!this.basedir.exists()) {
                        this.illegal = new IllegalStateException("basedir " + this.basedir + " does not exist");
                    }
                    if (!this.basedir.isDirectory()) {
                        this.illegal = new IllegalStateException("basedir " + this.basedir + " is not a directory");
                    }
                }
                if (this.illegal != null) {
                    throw this.illegal;
                }
                if (this.isIncluded("")) {
                    if (!this.isExcluded("")) {
                        if (this.isSelected("", this.basedir)) {
                            this.dirsIncluded.addElement("");
                        } else {
                            this.dirsDeselected.addElement("");
                        }
                    } else {
                        this.dirsExcluded.addElement("");
                    }
                } else {
                    this.dirsNotIncluded.addElement("");
                }
                this.checkIncludePatterns();
                this.clearCaches();
                this.includes = bl ? null : this.includes;
                this.excludes = bl3 ? null : this.excludes;
            }
            Object var6_7 = null;
            object = this.scanLock;
        }
        catch (Throwable throwable) {
            Object var6_8 = null;
            Object object3 = this.scanLock;
            synchronized (object3) {
                this.scanning = false;
                this.scanLock.notifyAll();
            }
            throw throwable;
        }
        synchronized (object) {
            this.scanning = false;
            this.scanLock.notifyAll();
        }
    }

    private void checkIncludePatterns() {
        Hashtable<String, String> hashtable = new Hashtable<String, String>();
        for (int i = 0; i < this.includes.length; ++i) {
            hashtable.put(SelectorUtils.rtrimWildcardTokens(this.includes[i]), this.includes[i]);
        }
        if (hashtable.containsKey("")) {
            this.scandir(this.basedir, "", true);
        } else {
            Enumeration enumeration = hashtable.keys();
            File file = null;
            try {
                file = this.basedir.getCanonicalFile();
            }
            catch (IOException iOException) {
                throw this.createUserRuntimeException(iOException);
            }
            while (enumeration.hasMoreElements()) {
                File file2;
                String string = (String)enumeration.nextElement();
                String string2 = (String)hashtable.get(string);
                File file3 = new File(this.basedir, string);
                if (file3.exists()) {
                    try {
                        file2 = file3.getCanonicalFile();
                        String string3 = this.FILE_UTILS.removeLeadingPath(file, file2);
                        if (!string3.equals(string) && (file3 = this.findFile(this.basedir, string, true)) != null) {
                            string = this.FILE_UTILS.removeLeadingPath(this.basedir, file3);
                        }
                    }
                    catch (IOException iOException) {
                        throw this.createUserRuntimeException(iOException);
                    }
                }
                if (!(file3 != null && file3.exists() || this.isCaseSensitive() || (file2 = this.findFile(this.basedir, string, false)) == null || !file2.exists())) {
                    string = this.FILE_UTILS.removeLeadingPath(this.basedir, file2);
                    file3 = file2;
                }
                if (file3 == null || !file3.exists() || !this.followSymlinks && this.isSymlink(this.basedir, string)) continue;
                if (file3.isDirectory()) {
                    if (this.isIncluded(string) && string.length() > 0) {
                        this.accountForIncludedDir(string, file3, true);
                        continue;
                    }
                    if (string.length() > 0 && string.charAt(string.length() - 1) != File.separatorChar) {
                        string = string + File.separatorChar;
                    }
                    this.scandir(file3, string, true);
                    continue;
                }
                boolean bl = this.isCaseSensitive() ? string2.equals(string) : string2.equalsIgnoreCase(string);
                if (!bl) continue;
                this.accountForIncludedFile(string, file3);
            }
        }
    }

    protected synchronized void clearResults() {
        this.filesIncluded = new Vector();
        this.filesNotIncluded = new Vector();
        this.filesExcluded = new Vector();
        this.filesDeselected = new Vector();
        this.dirsIncluded = new Vector();
        this.dirsNotIncluded = new Vector();
        this.dirsExcluded = new Vector();
        this.dirsDeselected = new Vector();
        this.everythingIncluded = this.basedir != null;
        this.scannedDirs.clear();
    }

    /*
     * WARNING - Removed try catching itself - possible behaviour change.
     */
    protected void slowScan() {
        Object object;
        Object object2 = this.slowScanLock;
        synchronized (object2) {
            if (this.haveSlowResults) {
                return;
            }
            if (this.slowScanning) {
                while (this.slowScanning) {
                    try {
                        this.slowScanLock.wait();
                    }
                    catch (InterruptedException interruptedException) {}
                }
                return;
            }
            this.slowScanning = true;
        }
        try {
            object2 = this;
            synchronized (object2) {
                int n;
                String[] stringArray;
                boolean bl;
                boolean bl2 = bl = this.includes == null;
                if (bl) {
                    String[] stringArray2 = new String[1];
                    stringArray = stringArray2;
                    stringArray2[0] = "**";
                } else {
                    stringArray = this.includes;
                }
                this.includes = stringArray;
                boolean bl3 = this.excludes == null;
                this.excludes = bl3 ? new String[]{} : this.excludes;
                Object[] objectArray = new String[this.dirsExcluded.size()];
                this.dirsExcluded.copyInto(objectArray);
                Object[] objectArray2 = new String[this.dirsNotIncluded.size()];
                this.dirsNotIncluded.copyInto(objectArray2);
                for (n = 0; n < objectArray.length; ++n) {
                    if (this.couldHoldIncluded((String)objectArray[n])) continue;
                    this.scandir(new File(this.basedir, (String)objectArray[n]), (String)objectArray[n] + File.separator, false);
                }
                for (n = 0; n < objectArray2.length; ++n) {
                    if (this.couldHoldIncluded((String)objectArray2[n])) continue;
                    this.scandir(new File(this.basedir, (String)objectArray2[n]), (String)objectArray2[n] + File.separator, false);
                }
                this.clearCaches();
                this.includes = bl ? null : this.includes;
                this.excludes = bl3 ? null : this.excludes;
            }
            Object var9_10 = null;
            object = this.slowScanLock;
        }
        catch (Throwable throwable) {
            Object var9_11 = null;
            Object object3 = this.slowScanLock;
            synchronized (object3) {
                this.haveSlowResults = true;
                this.slowScanning = false;
                this.slowScanLock.notifyAll();
            }
            throw throwable;
        }
        synchronized (object) {
            this.haveSlowResults = true;
            this.slowScanning = false;
            this.slowScanLock.notifyAll();
        }
    }

    protected void scandir(File file, String string, boolean bl) {
        Object object;
        if (file == null) {
            throw this.createUserRuntimeException("dir must not be null.");
        }
        if (!file.exists()) {
            throw this.createUserRuntimeException(file + " doesn't exists.");
        }
        if (!file.isDirectory()) {
            throw this.createUserRuntimeException(file + " is not a directory.");
        }
        if (bl && this.hasBeenScanned(string)) {
            return;
        }
        Object[] objectArray = file.list();
        if (objectArray == null) {
            throw this.createUserRuntimeException("IO error scanning directory " + file.getAbsolutePath());
        }
        if (!this.followSymlinks) {
            Vector<Object> vector = new Vector<Object>();
            for (int i = 0; i < objectArray.length; ++i) {
                Object object2;
                try {
                    if (this.FILE_UTILS.isSymbolicLink(file, objectArray[i])) {
                        object = string + (String)objectArray[i];
                        object2 = new File(file, (String)objectArray[i]);
                        (((File)object2).isDirectory() ? this.dirsExcluded : this.filesExcluded).addElement(object);
                        continue;
                    }
                    vector.addElement(objectArray[i]);
                    continue;
                }
                catch (IOException iOException) {
                    object2 = "IOException caught while checking for links, couldn't get canonical path!";
                    System.err.println((String)object2);
                    vector.addElement(objectArray[i]);
                }
            }
            objectArray = new String[vector.size()];
            vector.copyInto(objectArray);
        }
        for (int i = 0; i < objectArray.length; ++i) {
            String string2 = string + objectArray[i];
            object = new File(file, (String)objectArray[i]);
            if (((File)object).isDirectory()) {
                if (this.isIncluded(string2)) {
                    this.accountForIncludedDir(string2, (File)object, bl);
                } else {
                    this.everythingIncluded = false;
                    this.dirsNotIncluded.addElement(string2);
                    if (bl && this.couldHoldIncluded(string2)) {
                        this.scandir((File)object, string2 + File.separator, bl);
                    }
                }
                if (bl) continue;
                this.scandir((File)object, string2 + File.separator, bl);
                continue;
            }
            if (!((File)object).isFile()) continue;
            if (this.isIncluded(string2)) {
                this.accountForIncludedFile(string2, (File)object);
                continue;
            }
            this.everythingIncluded = false;
            this.filesNotIncluded.addElement(string2);
        }
    }

    private void accountForIncludedFile(String string, File file) {
        if (this.filesIncluded.contains(string) || this.filesExcluded.contains(string) || this.filesDeselected.contains(string)) {
            return;
        }
        boolean bl = false;
        if (this.isExcluded(string)) {
            this.filesExcluded.addElement(string);
        } else if (this.isSelected(string, file)) {
            bl = true;
            this.filesIncluded.addElement(string);
        } else {
            this.filesDeselected.addElement(string);
        }
        this.everythingIncluded &= bl;
    }

    private void accountForIncludedDir(String string, File file, boolean bl) {
        if (this.dirsIncluded.contains(string) || this.dirsExcluded.contains(string) || this.dirsDeselected.contains(string)) {
            return;
        }
        boolean bl2 = false;
        if (this.isExcluded(string)) {
            this.dirsExcluded.addElement(string);
        } else if (this.isSelected(string, file)) {
            bl2 = true;
            this.dirsIncluded.addElement(string);
        } else {
            this.dirsDeselected.addElement(string);
        }
        this.everythingIncluded &= bl2;
        if (bl && this.couldHoldIncluded(string) && !this.contentsExcluded(string)) {
            this.scandir(file, string + File.separator, bl);
        }
    }

    protected boolean isIncluded(String string) {
        this.ensureNonPatternSetsReady();
        if (this.isCaseSensitive() ? this.includeNonPatterns.contains(string) : this.includeNonPatterns.contains(string.toUpperCase())) {
            return true;
        }
        for (int i = 0; i < this.includePatterns.length; ++i) {
            if (!DirectoryScanner.matchPath(this.includePatterns[i], string, this.isCaseSensitive())) continue;
            return true;
        }
        return false;
    }

    protected boolean couldHoldIncluded(String string) {
        for (int i = 0; i < this.includes.length; ++i) {
            if (!DirectoryScanner.matchPatternStart(this.includes[i], string, this.isCaseSensitive()) || !this.isMorePowerfulThanExcludes(string, this.includes[i]) || !this.isDeeper(this.includes[i], string)) continue;
            return true;
        }
        return false;
    }

    private boolean isDeeper(String string, String string2) {
        Vector vector = SelectorUtils.tokenizePath(string);
        Vector vector2 = SelectorUtils.tokenizePath(string2);
        return vector.contains("**") || vector.size() > vector2.size();
    }

    private boolean isMorePowerfulThanExcludes(String string, String string2) {
        String string3 = string + File.separator + "**";
        for (int i = 0; i < this.excludes.length; ++i) {
            if (!this.excludes[i].equals(string3)) continue;
            return false;
        }
        return true;
    }

    private boolean contentsExcluded(String string) {
        string = string.endsWith(File.separator) ? string : string + File.separator;
        for (int i = 0; i < this.excludes.length; ++i) {
            String string2 = this.excludes[i];
            if (!string2.endsWith("**") || !SelectorUtils.matchPath(string2.substring(0, string2.length() - 2), string, this.isCaseSensitive())) continue;
            return true;
        }
        return false;
    }

    protected boolean isExcluded(String string) {
        this.ensureNonPatternSetsReady();
        if (this.isCaseSensitive() ? this.excludeNonPatterns.contains(string) : this.excludeNonPatterns.contains(string.toUpperCase())) {
            return true;
        }
        for (int i = 0; i < this.excludePatterns.length; ++i) {
            if (!DirectoryScanner.matchPath(this.excludePatterns[i], string, this.isCaseSensitive())) continue;
            return true;
        }
        return false;
    }

    protected boolean isSelected(String string, File file) {
        return true;
    }

    public synchronized String[] getIncludedFiles() {
        if (this.filesIncluded == null) {
            throw new IllegalStateException();
        }
        Object[] objectArray = new String[this.filesIncluded.size()];
        this.filesIncluded.copyInto(objectArray);
        Arrays.sort(objectArray);
        return objectArray;
    }

    public synchronized int getIncludedFilesCount() {
        if (this.filesIncluded == null) {
            throw new IllegalStateException();
        }
        return this.filesIncluded.size();
    }

    public synchronized String[] getNotIncludedFiles() {
        this.slowScan();
        Object[] objectArray = new String[this.filesNotIncluded.size()];
        this.filesNotIncluded.copyInto(objectArray);
        return objectArray;
    }

    public synchronized String[] getExcludedFiles() {
        this.slowScan();
        Object[] objectArray = new String[this.filesExcluded.size()];
        this.filesExcluded.copyInto(objectArray);
        return objectArray;
    }

    public synchronized String[] getDeselectedFiles() {
        this.slowScan();
        Object[] objectArray = new String[this.filesDeselected.size()];
        this.filesDeselected.copyInto(objectArray);
        return objectArray;
    }

    public synchronized String[] getIncludedDirectories() {
        if (this.dirsIncluded == null) {
            throw new IllegalStateException();
        }
        Object[] objectArray = new String[this.dirsIncluded.size()];
        this.dirsIncluded.copyInto(objectArray);
        Arrays.sort(objectArray);
        return objectArray;
    }

    public synchronized int getIncludedDirsCount() {
        if (this.dirsIncluded == null) {
            throw new IllegalStateException();
        }
        return this.dirsIncluded.size();
    }

    public synchronized String[] getNotIncludedDirectories() {
        this.slowScan();
        Object[] objectArray = new String[this.dirsNotIncluded.size()];
        this.dirsNotIncluded.copyInto(objectArray);
        return objectArray;
    }

    public synchronized String[] getExcludedDirectories() {
        this.slowScan();
        Object[] objectArray = new String[this.dirsExcluded.size()];
        this.dirsExcluded.copyInto(objectArray);
        return objectArray;
    }

    public synchronized String[] getDeselectedDirectories() {
        this.slowScan();
        Object[] objectArray = new String[this.dirsDeselected.size()];
        this.dirsDeselected.copyInto(objectArray);
        return objectArray;
    }

    public synchronized void addDefaultExcludes() {
        int n = this.excludes == null ? 0 : this.excludes.length;
        String[] stringArray = new String[n + defaultExcludes.size()];
        if (n > 0) {
            System.arraycopy(this.excludes, 0, stringArray, 0, n);
        }
        String[] stringArray2 = DirectoryScanner.getDefaultExcludes();
        for (int i = 0; i < stringArray2.length; ++i) {
            stringArray[i + n] = stringArray2[i].replace('/', File.separatorChar).replace('\\', File.separatorChar);
        }
        this.excludes = stringArray;
    }

    private String[] list(File file) {
        String[] stringArray = (String[])this.fileListMap.get(file);
        if (stringArray == null && (stringArray = file.list()) != null) {
            this.fileListMap.put(file, stringArray);
        }
        return stringArray;
    }

    private File findFile(File file, String string, boolean bl) {
        return this.findFile(file, SelectorUtils.tokenizePath(string), bl);
    }

    private File findFile(File file, Vector vector, boolean bl) {
        if (vector.size() == 0) {
            return file;
        }
        if (!file.isDirectory()) {
            return null;
        }
        String[] stringArray = this.list(file);
        if (stringArray == null) {
            throw this.createUserRuntimeException("IO error scanning directory " + file.getAbsolutePath());
        }
        String string = (String)vector.remove(0);
        boolean[] blArray = bl ? CS_SCAN_ONLY : CS_THEN_NON_CS;
        for (int i = 0; i < blArray.length; ++i) {
            for (int j = 0; j < stringArray.length; ++j) {
                if (!(blArray[i] ? stringArray[j].equals(string) : stringArray[j].equalsIgnoreCase(string))) continue;
                return this.findFile(new File(file, stringArray[j]), vector, bl);
            }
        }
        return null;
    }

    private boolean isSymlink(File file, String string) {
        return this.isSymlink(file, SelectorUtils.tokenizePath(string));
    }

    private boolean isSymlink(File file, Vector vector) {
        if (vector.size() > 0) {
            String string = (String)vector.remove(0);
            try {
                return this.FILE_UTILS.isSymbolicLink(file, string) || this.isSymlink(new File(file, string), vector);
            }
            catch (IOException iOException) {
                String string2 = "IOException caught while checking for links, couldn't get canonical path!";
                System.err.println(string2);
            }
        }
        return false;
    }

    private boolean hasBeenScanned(String string) {
        return !this.scannedDirs.add(string);
    }

    Set getScannedDirs() {
        return this.scannedDirs;
    }

    private synchronized void clearCaches() {
        this.fileListMap.clear();
        this.includeNonPatterns.clear();
        this.excludeNonPatterns.clear();
        this.includePatterns = null;
        this.excludePatterns = null;
        this.areNonPatternSetsReady = false;
    }

    private synchronized void ensureNonPatternSetsReady() {
        if (!this.areNonPatternSetsReady) {
            this.includePatterns = this.fillNonPatternSet(this.includeNonPatterns, this.includes);
            this.excludePatterns = this.fillNonPatternSet(this.excludeNonPatterns, this.excludes);
            this.areNonPatternSetsReady = true;
        }
    }

    private String[] fillNonPatternSet(Set set, String[] stringArray) {
        ArrayList<String> arrayList = new ArrayList<String>(stringArray.length);
        for (int i = 0; i < stringArray.length; ++i) {
            if (!SelectorUtils.hasWildcards(stringArray[i])) {
                set.add(this.isCaseSensitive() ? stringArray[i] : stringArray[i].toUpperCase());
                continue;
            }
            arrayList.add(stringArray[i]);
        }
        return set.size() == 0 ? stringArray : arrayList.toArray(new String[arrayList.size()]);
    }

    protected RuntimeException createUserRuntimeException(String string) {
        if (this.errorDelegator != null) {
            return this.errorDelegator.createRuntimeException(string);
        }
        return new IllegalStateException(string);
    }

    protected RuntimeException createUserRuntimeException(Throwable throwable) {
        if (this.errorDelegator != null) {
            return this.errorDelegator.createRuntimeException(throwable);
        }
        if (throwable == null) {
            return new IllegalStateException();
        }
        return new IllegalStateException(throwable.getMessage());
    }

    static {
        DirectoryScanner.resetDefaultExcludes();
    }
}

