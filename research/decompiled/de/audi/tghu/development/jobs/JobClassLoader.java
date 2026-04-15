/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.jobs;

import de.audi.tghu.development.jobs.JobConfigurationException;
import de.audi.tghu.development.jobs.JobEvent;
import de.audi.tghu.development.jobs.JobListener;
import de.audi.tghu.development.jobs.JobRunner;
import de.audi.tghu.development.jobs.SignatureBlockProcessor;
import de.audi.tghu.development.jobs.SignedContent;
import de.audi.tghu.development.util.FileUtils;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.MalformedURLException;
import java.net.URL;
import java.util.Enumeration;
import java.util.Hashtable;
import java.util.NoSuchElementException;
import java.util.StringTokenizer;
import java.util.Vector;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;

public class JobClassLoader
extends ClassLoader
implements JobListener {
    private boolean ENABLE_SECURE_CLASSLOADER = true;
    private static final FileUtils FILE_UTILS = JobRunner.FILE_UTILS;
    private static final int BUFFER_SIZE = 8192;
    private JobRunner runner;
    private ClassLoader parent;
    private Vector pathComponents = new Vector();
    private boolean parentFirst = true;
    private boolean ignoreBase = false;
    private Hashtable zipFiles = new Hashtable();
    private Vector systemPackages = new Vector();
    private Vector loaderPackages = new Vector();
    static /* synthetic */ Class class$de$audi$tghu$development$jobs$JobClassLoader;

    public JobClassLoader() {
        super(null);
    }

    public JobClassLoader(JobRunner jobRunner, String string) {
        super(null);
        this.setRunner(jobRunner);
        this.setClassPath(string);
    }

    public JobClassLoader(ClassLoader classLoader, JobRunner jobRunner, String string) {
        this(jobRunner, string);
        if (classLoader != null) {
            this.setParent(classLoader);
        }
    }

    public void setRunner(JobRunner jobRunner) {
        this.runner = jobRunner;
        if (jobRunner != null) {
            jobRunner.addJobListener(this);
        }
    }

    public void setClassPath(String string) {
        this.pathComponents.removeAllElements();
        if (string != null) {
            String[] stringArray = JobClassLoader.translatePath(this.runner, string);
            for (int i = 0; i < stringArray.length; ++i) {
                try {
                    this.addPathElement(stringArray[i]);
                    continue;
                }
                catch (JobConfigurationException jobConfigurationException) {
                    // empty catch block
                }
            }
        }
    }

    public void setParent(ClassLoader classLoader) {
        this.parent = classLoader == null ? (class$de$audi$tghu$development$jobs$JobClassLoader == null ? (class$de$audi$tghu$development$jobs$JobClassLoader = JobClassLoader.class$("de.audi.tghu.development.jobs.JobClassLoader")) : class$de$audi$tghu$development$jobs$JobClassLoader).getClassLoader() : classLoader;
    }

    public void addPathElement(String string) throws JobConfigurationException {
        File file = this.runner != null ? this.runner.resolveFile(string) : new File(string);
        try {
            this.addPathFile(file);
        }
        catch (IOException iOException) {
            throw new JobConfigurationException(iOException);
        }
    }

    protected void addPathFile(File file) throws IOException {
        this.pathComponents.addElement(file);
    }

    public String getClasspath() {
        StringBuffer stringBuffer = new StringBuffer();
        boolean bl = true;
        Enumeration enumeration = this.pathComponents.elements();
        while (enumeration.hasMoreElements()) {
            if (!bl) {
                stringBuffer.append(System.getProperty("path.separator"));
            } else {
                bl = false;
            }
            stringBuffer.append(((File)enumeration.nextElement()).getAbsolutePath());
        }
        return stringBuffer.toString();
    }

    public static String[] translatePath(JobRunner jobRunner, String string) {
        Object[] objectArray;
        Vector<String> vector = new Vector<String>();
        if (string == null) {
            return new String[0];
        }
        PathTokenizer pathTokenizer = new PathTokenizer(string);
        StringBuffer stringBuffer = new StringBuffer();
        while (pathTokenizer.hasMoreTokens()) {
            objectArray = pathTokenizer.nextToken();
            try {
                stringBuffer.append(JobClassLoader.resolveFile(jobRunner, (String)objectArray));
            }
            catch (JobConfigurationException jobConfigurationException) {
                jobRunner.log("Dropping path element " + (String)objectArray + " as it is not valid relative to the job", 3);
            }
            for (int i = 0; i < stringBuffer.length(); ++i) {
                JobClassLoader.translateFileSep(stringBuffer, i);
            }
            vector.addElement(stringBuffer.toString());
            stringBuffer = new StringBuffer();
        }
        objectArray = new String[vector.size()];
        vector.copyInto(objectArray);
        return objectArray;
    }

    protected static boolean translateFileSep(StringBuffer stringBuffer, int n) {
        if (stringBuffer.charAt(n) == '/' || stringBuffer.charAt(n) == '\\') {
            stringBuffer.setCharAt(n, File.separatorChar);
            return true;
        }
        return false;
    }

    private static String resolveFile(JobRunner jobRunner, String string) {
        if (jobRunner != null) {
            File file = jobRunner.resolveFile(string);
            return file.getAbsolutePath();
        }
        return string;
    }

    public synchronized void cleanup() {
        Enumeration enumeration = this.zipFiles.elements();
        while (enumeration.hasMoreElements()) {
            Object v = enumeration.nextElement();
            ZipFile zipFile = v instanceof SignedContent ? ((SignedContent)v).getContent() : (ZipFile)v;
            try {
                zipFile.close();
            }
            catch (IOException iOException) {}
        }
        this.zipFiles = new Hashtable();
        if (this.runner != null) {
            this.runner.removeJobListener(this);
        }
        this.runner = null;
    }

    public synchronized void setIsolated(boolean bl) {
        this.ignoreBase = bl;
    }

    protected void log(String string, int n) {
        if (this.runner != null) {
            this.runner.log(string, n);
        }
    }

    public InputStream getResourceAsStream(String string) {
        InputStream inputStream = null;
        if (this.isParentFirst(string)) {
            inputStream = this.loadBaseResource(string);
            if (inputStream != null) {
                this.log("ResourceStream for " + string + " loaded from parent loader", 4);
            } else {
                inputStream = this.loadResource(string);
                if (inputStream != null) {
                    this.log("ResourceStream for " + string + " loaded from job loader", 4);
                }
            }
        } else {
            inputStream = this.loadResource(string);
            if (inputStream != null) {
                this.log("ResourceStream for " + string + " loaded from job loader", 4);
            } else {
                inputStream = this.loadBaseResource(string);
                if (inputStream != null) {
                    this.log("ResourceStream for " + string + " loaded from parent loader", 4);
                }
            }
        }
        if (inputStream == null) {
            this.log("Couldn't load ResourceStream for " + string, 4);
        }
        return inputStream;
    }

    private InputStream loadResource(String string) {
        InputStream inputStream = null;
        Enumeration enumeration = this.pathComponents.elements();
        while (enumeration.hasMoreElements() && inputStream == null) {
            File file = (File)enumeration.nextElement();
            inputStream = this.getResourceStream(file, string);
        }
        return inputStream;
    }

    private InputStream loadBaseResource(String string) {
        if (this.parent == null) {
            return JobClassLoader.getSystemResourceAsStream(string);
        }
        return this.parent.getResourceAsStream(string);
    }

    private InputStream getResourceStream(File file, String string) {
        try {
            if (!file.exists()) {
                return null;
            }
            if (file.isDirectory()) {
                File file2 = new File(file, string);
                if (file2.exists()) {
                    return new FileInputStream(file2);
                }
            } else {
                Object object;
                ZipFile zipFile;
                SignedContent signedContent = null;
                Object v = this.zipFiles.get(file);
                if (v != null) {
                    if (v instanceof SignedContent) {
                        signedContent = (SignedContent)v;
                        zipFile = signedContent.getContent();
                    } else {
                        zipFile = (ZipFile)v;
                    }
                } else {
                    zipFile = new ZipFile(file);
                    if (this.ENABLE_SECURE_CLASSLOADER) {
                        object = new SignatureBlockProcessor(this.runner, zipFile);
                        signedContent = ((SignatureBlockProcessor)object).process();
                        this.zipFiles.put(file, signedContent);
                    } else {
                        this.zipFiles.put(file, zipFile);
                    }
                }
                object = zipFile.getEntry(string);
                if (object != null) {
                    if (signedContent != null && string.endsWith(".class")) {
                        InputStream inputStream = signedContent.getEntryInputStream(this.runner, (ZipEntry)object, string);
                        if (inputStream == null) {
                            throw new SecurityException("Corrupted file: the digest does not exist for the file " + string);
                        }
                        return inputStream;
                    }
                    return zipFile.getInputStream((ZipEntry)object);
                }
            }
        }
        catch (Exception exception) {
            this.log("Ignoring Exception " + exception.getClass().getName() + ": " + exception.getMessage() + " reading resource " + string + " from " + file, 3);
        }
        return null;
    }

    private ZipFile getZipFileCache(File file) throws Exception {
        Object v = this.zipFiles.get(file);
        if (v != null) {
            if (v instanceof SignedContent) {
                return ((SignedContent)v).getContent();
            }
            return (ZipFile)v;
        }
        ZipFile zipFile = new ZipFile(file);
        if (this.ENABLE_SECURE_CLASSLOADER) {
            SignatureBlockProcessor signatureBlockProcessor = new SignatureBlockProcessor(this.runner, zipFile);
            SignedContent signedContent = signatureBlockProcessor.process();
            this.zipFiles.put(file, signedContent);
        } else {
            this.zipFiles.put(file, zipFile);
        }
        return zipFile;
    }

    private boolean isParentFirst(String string) {
        String string2;
        boolean bl = this.parentFirst;
        Enumeration enumeration = this.systemPackages.elements();
        while (enumeration.hasMoreElements()) {
            string2 = (String)enumeration.nextElement();
            if (!string.startsWith(string2)) continue;
            bl = true;
            break;
        }
        enumeration = this.loaderPackages.elements();
        while (enumeration.hasMoreElements()) {
            string2 = (String)enumeration.nextElement();
            if (!string.startsWith(string2)) continue;
            bl = false;
            break;
        }
        return bl;
    }

    public URL getResource(String string) {
        URL uRL = null;
        if (this.isParentFirst(string)) {
            URL uRL2 = uRL = this.parent == null ? super.getResource(string) : this.parent.getResource(string);
        }
        if (uRL != null) {
            this.log("Resource " + string + " loaded from parent loader", 4);
        } else {
            Enumeration enumeration = this.pathComponents.elements();
            while (enumeration.hasMoreElements() && uRL == null) {
                File file = (File)enumeration.nextElement();
                uRL = this.getResourceURL(file, string);
                if (uRL == null) continue;
                this.log("Resource " + string + " loaded from job loader", 4);
            }
        }
        if (uRL == null && !this.isParentFirst(string)) {
            URL uRL3 = uRL = this.parent == null ? super.getResource(string) : this.parent.getResource(string);
            if (uRL != null) {
                this.log("Resource " + string + " loaded from parent loader", 4);
            }
        }
        if (uRL == null) {
            this.log("Couldn't load Resource " + string, 4);
        }
        return uRL;
    }

    protected Enumeration findResources(String string) throws IOException {
        ResourceEnumeration resourceEnumeration = new ResourceEnumeration(string);
        Enumeration enumeration = this.parent != null && this.parent != this.getParent() ? this.parent.getResources(string) : new EmptyEnumeration();
        if (this.isParentFirst(string)) {
            return JobClassLoader.appendEnumeration(enumeration, resourceEnumeration);
        }
        return JobClassLoader.appendEnumeration(resourceEnumeration, enumeration);
    }

    protected URL getResourceURL(File file, String string) {
        try {
            if (!file.exists()) {
                return null;
            }
            if (file.isDirectory()) {
                File file2 = new File(file, string);
                if (file2.exists()) {
                    try {
                        return FILE_UTILS.getFileURL(file2);
                    }
                    catch (MalformedURLException malformedURLException) {
                        return null;
                    }
                }
            } else {
                ZipFile zipFile = this.getZipFileCache(file);
                ZipEntry zipEntry = zipFile.getEntry(string);
                if (zipEntry != null) {
                    try {
                        return new URL("jar:" + FILE_UTILS.getFileURL(file) + "!/" + zipEntry);
                    }
                    catch (MalformedURLException malformedURLException) {
                        return null;
                    }
                }
            }
        }
        catch (Exception exception) {
            exception.printStackTrace();
        }
        return null;
    }

    protected synchronized Class loadClass(String string, boolean bl) throws ClassNotFoundException {
        Class clazz = this.findLoadedClass(string);
        if (clazz != null) {
            return clazz;
        }
        if (this.isParentFirst(string)) {
            try {
                clazz = this.findBaseClass(string);
                this.log("Class " + string + " loaded from parent loader " + "(parentFirst)", 4);
            }
            catch (ClassNotFoundException classNotFoundException) {
                clazz = this.findClass(string);
                this.log("Class " + string + " loaded from job loader " + "(parentFirst)", 4);
            }
        } else {
            try {
                clazz = this.findClass(string);
                this.log("Class " + string + " loaded from job loader", 4);
            }
            catch (ClassNotFoundException classNotFoundException) {
                if (this.ignoreBase) {
                    throw classNotFoundException;
                }
                clazz = this.findBaseClass(string);
                this.log("Class " + string + " loaded from parent loader", 4);
            }
        }
        if (bl) {
            this.resolveClass(clazz);
        }
        return clazz;
    }

    private String getClassFilename(String string) {
        return string.replace('.', '/') + ".class";
    }

    protected Class defineClassFromData(File file, byte[] byArray, String string) throws IOException {
        return this.defineClass(string, byArray, 0, byArray.length);
    }

    private Class getClassFromStream(InputStream inputStream, String string, File file) throws IOException, SecurityException {
        ByteArrayOutputStream byteArrayOutputStream = new ByteArrayOutputStream();
        int n = -1;
        byte[] byArray = new byte[8192];
        while ((n = inputStream.read(byArray, 0, 8192)) != -1) {
            byteArrayOutputStream.write(byArray, 0, n);
        }
        byte[] byArray2 = byteArrayOutputStream.toByteArray();
        return this.defineClassFromData(file, byArray2, string);
    }

    public Class findClass(String string) throws ClassNotFoundException {
        this.log("Finding class " + string, 4);
        return this.findClassInComponents(string);
    }

    protected boolean isInPath(File file) {
        Enumeration enumeration = this.pathComponents.elements();
        while (enumeration.hasMoreElements()) {
            File file2 = (File)enumeration.nextElement();
            if (!file2.equals(file)) continue;
            return true;
        }
        return false;
    }

    /*
     * Enabled aggressive block sorting
     * Enabled unnecessary exception pruning
     * Enabled aggressive exception aggregation
     */
    private Class findClassInComponents(String string) throws ClassNotFoundException {
        Class clazz;
        InputStream inputStream = null;
        String string2 = this.getClassFilename(string);
        try {
            block10: {
                Enumeration enumeration = this.pathComponents.elements();
                while (enumeration.hasMoreElements()) {
                    File file = (File)enumeration.nextElement();
                    try {
                        inputStream = this.getResourceStream(file, string2);
                        if (inputStream == null) continue;
                        this.log("Loaded from " + file + " " + string2, 4);
                        clazz = this.getClassFromStream(inputStream, string, file);
                        break block10;
                    }
                    catch (SecurityException securityException) {
                        throw securityException;
                    }
                    catch (IOException iOException) {
                        this.log("Exception reading component " + file + " (reason: " + iOException.getMessage() + ")", 3);
                    }
                }
                throw new ClassNotFoundException(string);
            }
            Object var8_9 = null;
        }
        catch (Throwable throwable) {
            Object var8_10 = null;
            try {
                if (inputStream == null) throw throwable;
                inputStream.close();
                throw throwable;
            }
            catch (IOException iOException) {
                throw throwable;
            }
        }
        try {}
        catch (IOException iOException) {
            // empty catch block
            return clazz;
        }
        if (inputStream == null) return clazz;
        inputStream.close();
        return clazz;
    }

    private Class findBaseClass(String string) throws ClassNotFoundException {
        if (this.parent == null) {
            return this.findSystemClass(string);
        }
        return this.parent.loadClass(string);
    }

    public void addSystemPackageRoot(String string) {
        this.systemPackages.addElement(string + (string.endsWith(".") ? "" : "."));
    }

    public void addLoaderPackageRoot(String string) {
        this.loaderPackages.addElement(string + (string.endsWith(".") ? "" : "."));
    }

    public Class forceLoadClass(String string) throws ClassNotFoundException {
        this.log("force loading " + string, 4);
        Class clazz = this.findLoadedClass(string);
        if (clazz == null) {
            clazz = this.findClass(string);
        }
        return clazz;
    }

    protected static Enumeration appendEnumeration(Enumeration enumeration, Enumeration enumeration2) {
        return new CompoundEnumeration(enumeration, enumeration2);
    }

    public void jobStarted(JobEvent jobEvent) {
    }

    public void jobFinished(JobEvent jobEvent) {
        this.cleanup();
    }

    public void messageLogged(JobEvent jobEvent) {
    }

    static /* synthetic */ Class class$(String string) {
        try {
            return Class.forName(string);
        }
        catch (ClassNotFoundException classNotFoundException) {
            throw new NoClassDefFoundError(classNotFoundException.getMessage());
        }
    }

    private static final class CompoundEnumeration
    implements Enumeration {
        private final Enumeration e1;
        private final Enumeration e2;

        public CompoundEnumeration(Enumeration enumeration, Enumeration enumeration2) {
            this.e1 = enumeration;
            this.e2 = enumeration2;
        }

        public boolean hasMoreElements() {
            return this.e1.hasMoreElements() || this.e2.hasMoreElements();
        }

        public Object nextElement() throws NoSuchElementException {
            if (this.e1.hasMoreElements()) {
                return this.e1.nextElement();
            }
            return this.e2.nextElement();
        }
    }

    public static final class EmptyEnumeration
    implements Enumeration {
        public boolean hasMoreElements() {
            return false;
        }

        public Object nextElement() throws NoSuchElementException {
            throw new NoSuchElementException();
        }
    }

    private class ResourceEnumeration
    implements Enumeration {
        private String resourceName;
        private int pathElementsIndex;
        private URL nextResource;

        ResourceEnumeration(String string) {
            this.resourceName = string;
            this.pathElementsIndex = 0;
            this.findNextResource();
        }

        public boolean hasMoreElements() {
            return this.nextResource != null;
        }

        public Object nextElement() {
            URL uRL = this.nextResource;
            this.findNextResource();
            return uRL;
        }

        private void findNextResource() {
            URL uRL = null;
            while (this.pathElementsIndex < JobClassLoader.this.pathComponents.size() && uRL == null) {
                try {
                    File file = (File)JobClassLoader.this.pathComponents.elementAt(this.pathElementsIndex);
                    uRL = JobClassLoader.this.getResourceURL(file, this.resourceName);
                    ++this.pathElementsIndex;
                }
                catch (JobConfigurationException jobConfigurationException) {}
            }
            this.nextResource = uRL;
        }
    }

    public static final class PathTokenizer {
        private StringTokenizer tokenizer;
        private String lookahead = null;
        private boolean dosStyleFilesystem;

        public PathTokenizer(String string) {
            this.tokenizer = new StringTokenizer(string, ":;", false);
            this.dosStyleFilesystem = File.pathSeparatorChar == ';';
        }

        public boolean hasMoreTokens() {
            if (this.lookahead != null) {
                return true;
            }
            return this.tokenizer.hasMoreTokens();
        }

        public String nextToken() throws NoSuchElementException {
            String string = null;
            if (this.lookahead != null) {
                string = this.lookahead;
                this.lookahead = null;
            } else {
                string = this.tokenizer.nextToken().trim();
            }
            if (string.length() == 1 && Character.isLetter(string.charAt(0)) && this.dosStyleFilesystem && this.tokenizer.hasMoreTokens()) {
                String string2 = this.tokenizer.nextToken().trim();
                if (string2.startsWith("\\") || string2.startsWith("/")) {
                    string = string + ":" + string2;
                } else {
                    this.lookahead = string2;
                }
            }
            return string;
        }
    }
}

