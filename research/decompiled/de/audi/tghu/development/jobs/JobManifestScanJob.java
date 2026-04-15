/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.jobs;

import de.audi.tghu.development.jobs.IJobLogger;
import de.audi.tghu.development.jobs.Job;
import de.audi.tghu.development.jobs.JobClassLoader;
import de.audi.tghu.development.jobs.JobConfigurationException;
import de.audi.tghu.development.jobs.JobDefinition;
import de.audi.tghu.development.jobs.JobListener;
import de.audi.tghu.development.jobs.JobRunner;
import de.audi.tghu.development.util.DirectoryScanner;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.Iterator;
import java.util.Properties;

public class JobManifestScanJob
extends Job {
    static final String JOB_NAME = "jobScan";
    private static final String PROP_CLASSPATH = "classpath";
    private static final String PROP_PREFIX_JOB = "job.";
    private static final String PROP_OPTION_LOGGER = "__option.logger";
    private String dir;
    private String pattern;
    private String name;
    private File manifest;
    static /* synthetic */ Class class$de$audi$tghu$development$jobs$JobRunner;

    public void setScanDir(String string) {
        this.dir = string;
    }

    public void setSearchPattern(String string) {
        this.pattern = string;
    }

    public void setManifestName(String string) {
        this.name = string;
    }

    public File getManifestFile() {
        return this.manifest;
    }

    public void execute() throws Exception {
        this.manifest = null;
        DirectoryScanner directoryScanner = new DirectoryScanner(JobRunner.ERROR_DELEGATOR);
        directoryScanner.setBasedir(this.dir);
        directoryScanner.setIncludes(new String[]{this.pattern});
        String string = "Scanning " + this.dir + "/" + this.pattern + " for Jobmanifest '" + this.name + "'";
        this.log(string, 3);
        directoryScanner.scan();
        if (directoryScanner.getIncludedFilesCount() > 0) {
            File file = new File(directoryScanner.getBasedir(), directoryScanner.getIncludedFiles()[0]);
            String string2 = file.getAbsolutePath();
            string2 = string2.substring(0, string2.length() - this.name.length());
            this.parseManifest(string2, file);
            this.manifest = file;
        }
    }

    /*
     * Enabled aggressive block sorting
     * Enabled unnecessary exception pruning
     * Enabled aggressive exception aggregation
     */
    private void parseManifest(String string, File file) throws JobConfigurationException {
        Object object2;
        String string2;
        Properties properties;
        block11: {
            this.log("Parsing Jobmanifest: " + file, 3);
            properties = new Properties();
            FileInputStream fileInputStream = null;
            try {
                try {
                    fileInputStream = new FileInputStream(file);
                    properties.load(fileInputStream);
                }
                catch (IOException iOException) {
                    throw new JobConfigurationException("Unable to parse " + file.getAbsolutePath(), iOException);
                }
                string2 = null;
                if (fileInputStream == null) break block11;
            }
            catch (Throwable throwable) {
                Object var7_6 = null;
                if (fileInputStream == null) throw throwable;
                try {
                    ((InputStream)fileInputStream).close();
                    throw throwable;
                }
                catch (Exception exception) {
                    // empty catch block
                }
                throw throwable;
            }
            try {}
            catch (Exception object2) {}
            ((InputStream)fileInputStream).close();
        }
        this.handleLoggerOptions(properties.getProperty(PROP_OPTION_LOGGER));
        JobRunner jobRunner = this.getRunner();
        jobRunner.setBasedir(string);
        ClassLoader classLoader = (class$de$audi$tghu$development$jobs$JobRunner == null ? (class$de$audi$tghu$development$jobs$JobRunner = JobManifestScanJob.class$("de.audi.tghu.development.jobs.JobRunner")) : class$de$audi$tghu$development$jobs$JobRunner).getClassLoader();
        string2 = properties.getProperty(PROP_CLASSPATH);
        if (string2 != null) {
            object2 = string2.trim();
            classLoader = new JobClassLoader(classLoader, jobRunner, (String)object2);
        }
        object2 = properties.propertyNames();
        while (object2.hasMoreElements()) {
            String string3 = (String)object2.nextElement();
            String string4 = properties.getProperty(string3);
            if (string3.startsWith(PROP_PREFIX_JOB) && string3.length() > 4) {
                string3 = string3.substring(4);
                JobDefinition jobDefinition = new JobDefinition();
                jobDefinition.setName(string3);
                jobDefinition.setClassName(string4);
                jobDefinition.setClassLoader(classLoader);
                Class clazz = jobDefinition.getJobClass(jobRunner);
                if (clazz != null) {
                    jobRunner.addJobDefinition(string3, clazz);
                    continue;
                }
                this.log("Job definition skipped: " + string3 + " (" + jobDefinition.getClassName() + ") - failure during processing", 3);
                continue;
            }
            jobRunner.setUserProperty(string3, string4);
        }
    }

    private void handleLoggerOptions(String string) {
        if (string == null || string.length() == 0) {
            return;
        }
        boolean bl = false;
        int n = 2;
        string = string.trim();
        char[] cArray = string.toCharArray();
        block8: for (int i = 0; i < cArray.length; ++i) {
            switch (cArray[i]) {
                case 'e': {
                    bl = true;
                    continue block8;
                }
                case '0': {
                    n = 0;
                    continue block8;
                }
                case '1': {
                    n = 1;
                    continue block8;
                }
                case '2': {
                    n = 2;
                    continue block8;
                }
                case '3': {
                    n = 3;
                    continue block8;
                }
                case '4': {
                    n = 4;
                    continue block8;
                }
            }
        }
        JobRunner jobRunner = this.getRunner();
        if (jobRunner != null) {
            Iterator iterator = jobRunner.getJobListeners().iterator();
            while (iterator.hasNext()) {
                JobListener jobListener = (JobListener)iterator.next();
                if (!(jobListener instanceof IJobLogger)) continue;
                IJobLogger iJobLogger = (IJobLogger)jobListener;
                iJobLogger.setEmacsMode(bl);
                iJobLogger.setMessageOutputLevel(n);
            }
        }
    }

    static /* synthetic */ Class class$(String string) {
        try {
            return Class.forName(string);
        }
        catch (ClassNotFoundException classNotFoundException) {
            throw new NoClassDefFoundError(classNotFoundException.getMessage());
        }
    }
}

