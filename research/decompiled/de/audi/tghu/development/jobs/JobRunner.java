/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.jobs;

import de.audi.tghu.development.jobs.DefaultLogger;
import de.audi.tghu.development.jobs.IJobLogger;
import de.audi.tghu.development.jobs.Job;
import de.audi.tghu.development.jobs.JobConfigurationException;
import de.audi.tghu.development.jobs.JobDefinition;
import de.audi.tghu.development.jobs.JobEvent;
import de.audi.tghu.development.jobs.JobListener;
import de.audi.tghu.development.jobs.JobManifestScanJob;
import de.audi.tghu.development.jobs.TelnetLogger;
import de.audi.tghu.development.util.FileUtils;
import de.audi.tghu.development.util.IErrorTypeDelegate;
import java.io.File;
import java.lang.ref.WeakReference;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.util.Enumeration;
import java.util.Hashtable;
import java.util.Iterator;
import java.util.Vector;

public class JobRunner {
    private JobTypeTable jobTypeTable;
    private Hashtable jobClassDefinitions = new Hashtable();
    private boolean rebuildJobClassDefinitions = true;
    private Hashtable createdJobs = new Hashtable();
    private Vector listeners = new Vector();
    private boolean loggingMessage = false;
    static final IErrorTypeDelegate ERROR_DELEGATOR = new JobErrorTypeDelegate();
    static final FileUtils FILE_UTILS = FileUtils.newFileUtils(ERROR_DELEGATOR);
    private File baseDir;
    private Hashtable userProperties = new Hashtable();
    private JobManifestScanJob scanJob = null;
    private static IJobLogger LOGGER_INSTANCE = null;
    static /* synthetic */ Class class$de$audi$tghu$development$jobs$Job;
    static /* synthetic */ Class class$de$audi$tghu$development$jobs$JobRunner;

    public JobRunner() {
        this(null);
    }

    public JobRunner(JobListener jobListener) {
        this.jobTypeTable = new JobTypeTable(this);
        if (jobListener != null) {
            this.listeners.addElement(jobListener);
        }
        this.initBuildInJobs();
    }

    protected void initBuildInJobs() {
    }

    public synchronized boolean scan(String string, String string2, String string3) {
        this.baseDir = null;
        this.userProperties.clear();
        this.removeAllJobDefinitions();
        this.initBuildInJobs();
        if (this.scanJob == null) {
            this.scanJob = new JobManifestScanJob();
            this.scanJob.setRunner(this);
            this.scanJob.setJobName("jobScan");
        }
        try {
            this.scanJob.setScanDir(string);
            this.scanJob.setSearchPattern(string2);
            this.scanJob.setManifestName(string3);
            this.scanJob.execute();
            File file = this.scanJob.getManifestFile();
            if (file != null) {
                this.log("Jobmanifest: " + file);
                return true;
            }
        }
        catch (JobConfigurationException jobConfigurationException) {
            this.log(this.scanJob, jobConfigurationException.toString(), 1);
        }
        catch (Exception exception) {
            exception.printStackTrace();
        }
        this.log(this.scanJob, "Finished unsuccessful - ignored", 1);
        return false;
    }

    protected void setBasedir(String string) throws JobConfigurationException {
        this.setBaseDir(new File(string));
    }

    protected void setBaseDir(File file) throws JobConfigurationException {
        if (!(file = FILE_UTILS.normalize(file.getAbsolutePath())).exists()) {
            throw new JobConfigurationException("Basedir " + file.getAbsolutePath() + " does not exist");
        }
        if (!file.isDirectory()) {
            throw new JobConfigurationException("Basedir " + file.getAbsolutePath() + " is not a directory");
        }
        this.baseDir = file;
        this.setUserProperty("basedir", this.baseDir.getPath());
        String string = "Job base dir set to: " + this.baseDir;
        this.log(string, 3);
    }

    public File getBaseDir() {
        if (this.baseDir == null) {
            try {
                this.setBasedir(".");
            }
            catch (JobConfigurationException jobConfigurationException) {
                jobConfigurationException.printStackTrace();
            }
        }
        return this.baseDir;
    }

    public synchronized void addJobListener(JobListener jobListener) {
        Vector vector = this.getJobListeners();
        vector.addElement(jobListener);
        this.listeners = vector;
    }

    public synchronized void removeJobListener(JobListener jobListener) {
        Vector vector = this.getJobListeners();
        vector.removeElement(jobListener);
        this.listeners = vector;
    }

    public Vector getJobListeners() {
        return (Vector)this.listeners.clone();
    }

    public void fireJobStarted(Job job) {
        JobEvent jobEvent = new JobEvent(job);
        Iterator iterator = this.listeners.iterator();
        while (iterator.hasNext()) {
            JobListener jobListener = (JobListener)iterator.next();
            jobListener.jobStarted(jobEvent);
        }
    }

    public void fireJobFinished(Job job, Throwable throwable) {
        JobEvent jobEvent = new JobEvent(job);
        jobEvent.setException(throwable);
        Iterator iterator = this.listeners.iterator();
        while (iterator.hasNext()) {
            JobListener jobListener = (JobListener)iterator.next();
            jobListener.jobFinished(jobEvent);
        }
    }

    protected void fireMessageLogged(Job job, String string, int n) {
        JobEvent jobEvent = new JobEvent(job);
        this.fireMessageLoggedEvent(jobEvent, string, n);
    }

    protected void fireMessageLogged(String string, int n) {
        JobEvent jobEvent = new JobEvent(this);
        this.fireMessageLoggedEvent(jobEvent, string, n);
    }

    /*
     * WARNING - Removed try catching itself - possible behaviour change.
     */
    private void fireMessageLoggedEvent(JobEvent jobEvent, String string, int n) {
        if (string.endsWith(IJobLogger.LINE_SEP)) {
            int n2 = string.length() - IJobLogger.LINE_SEP.length();
            jobEvent.setMessage(string.substring(0, n2), n);
        } else {
            jobEvent.setMessage(string, n);
        }
        JobRunner jobRunner = this;
        synchronized (jobRunner) {
            if (this.loggingMessage) {
                return;
            }
            try {
                this.loggingMessage = true;
                Iterator iterator = this.listeners.iterator();
                while (iterator.hasNext()) {
                    JobListener jobListener = (JobListener)iterator.next();
                    jobListener.messageLogged(jobEvent);
                }
            }
            finally {
                this.loggingMessage = false;
            }
        }
    }

    public void log(String string) {
        this.log(string, 2);
    }

    public void log(String string, int n) {
        this.fireMessageLogged(string, n);
    }

    public void log(Job job, String string, int n) {
        this.fireMessageLogged(job, string, n);
    }

    /*
     * WARNING - Removed try catching itself - possible behaviour change.
     */
    public Hashtable getJobDefinitions() {
        Hashtable hashtable = this.jobClassDefinitions;
        synchronized (hashtable) {
            JobTypeTable jobTypeTable = this.jobTypeTable;
            synchronized (jobTypeTable) {
                if (this.rebuildJobClassDefinitions) {
                    this.jobClassDefinitions.clear();
                    Iterator iterator = this.jobTypeTable.keySet().iterator();
                    while (iterator.hasNext()) {
                        String string = (String)iterator.next();
                        Class clazz = this.jobTypeTable.getJobClass(string);
                        if (clazz == null || !(class$de$audi$tghu$development$jobs$Job == null ? JobRunner.class$("de.audi.tghu.development.jobs.Job") : class$de$audi$tghu$development$jobs$Job).isAssignableFrom(clazz)) continue;
                        this.jobClassDefinitions.put(string, this.jobTypeTable.getJobClass(string));
                    }
                    this.rebuildJobClassDefinitions = false;
                }
            }
        }
        return this.jobClassDefinitions;
    }

    public Job createJob(String string) throws JobConfigurationException {
        Job job = this.createNewJob(string);
        if (job != null) {
            this.addCreatedJob(string, job);
        }
        return job;
    }

    private Job createNewJob(String string) throws JobConfigurationException {
        Class clazz = this.getComponentClass(string);
        if (clazz == null || !(class$de$audi$tghu$development$jobs$Job == null ? (class$de$audi$tghu$development$jobs$Job = JobRunner.class$("de.audi.tghu.development.jobs.Job")) : class$de$audi$tghu$development$jobs$Job).isAssignableFrom(clazz)) {
            return null;
        }
        Job job = (Job)this.createComponent(string);
        if (job == null) {
            return null;
        }
        job.setJobName(string);
        this.log("   +Job: " + string, 4);
        return job;
    }

    public Class getComponentClass(String string) {
        JobDefinition jobDefinition = this.getDefinition(string);
        return jobDefinition == null ? null : jobDefinition.getJobClass(this);
    }

    public JobDefinition getDefinition(String string) {
        return this.jobTypeTable.getDefinition(string);
    }

    public Object createComponent(String string) {
        JobDefinition jobDefinition = this.getDefinition(string);
        return jobDefinition == null ? null : jobDefinition.create(this);
    }

    public void addJobDefinition(String string, Class clazz) throws JobConfigurationException {
        this.checkJobClass(clazz);
        JobDefinition jobDefinition = new JobDefinition();
        jobDefinition.setName(string);
        jobDefinition.setClassLoader(clazz.getClassLoader());
        jobDefinition.setClass(clazz);
        jobDefinition.setClassName(clazz.getName());
        this.updateJobDefinition(jobDefinition);
    }

    /*
     * WARNING - Removed try catching itself - possible behaviour change.
     */
    private void updateJobDefinition(JobDefinition jobDefinition) {
        String string = jobDefinition.getName();
        JobTypeTable jobTypeTable = this.jobTypeTable;
        synchronized (jobTypeTable) {
            this.rebuildJobClassDefinitions = true;
            JobDefinition jobDefinition2 = this.jobTypeTable.getDefinition(string);
            if (jobDefinition2 != null) {
                if (this.sameDefinition(jobDefinition, jobDefinition2)) {
                    return;
                }
                this.log("Trying to override old definition of job " + string, jobDefinition.similarDefinition(jobDefinition2, this) ? 3 : 1);
                this.invalidateCreatedJobs(string);
            }
            this.log("   +Job: " + string + " " + jobDefinition.getClassName(), 4);
            this.jobTypeTable.put(string, jobDefinition);
        }
    }

    /*
     * WARNING - Removed try catching itself - possible behaviour change.
     */
    public void removeAllJobDefinitions() {
        JobTypeTable jobTypeTable = this.jobTypeTable;
        synchronized (jobTypeTable) {
            this.rebuildJobClassDefinitions = true;
            this.invalidateAllCreatedJobs();
            this.log("Clear all job definitions", 4);
            this.jobTypeTable.clear();
        }
    }

    /*
     * WARNING - Removed try catching itself - possible behaviour change.
     */
    private void addCreatedJob(String string, Job job) {
        Hashtable hashtable = this.createdJobs;
        synchronized (hashtable) {
            Vector<WeakReference<Job>> vector = (Vector<WeakReference<Job>>)this.createdJobs.get(string);
            if (vector == null) {
                vector = new Vector<WeakReference<Job>>();
                this.createdJobs.put(string, vector);
            }
            vector.addElement(new WeakReference<Job>(job));
        }
    }

    /*
     * WARNING - Removed try catching itself - possible behaviour change.
     */
    private void invalidateCreatedJobs(String string) {
        Hashtable hashtable = this.createdJobs;
        synchronized (hashtable) {
            Vector vector = (Vector)this.createdJobs.get(string);
            if (vector != null) {
                Enumeration enumeration = vector.elements();
                while (enumeration.hasMoreElements()) {
                    WeakReference weakReference = (WeakReference)enumeration.nextElement();
                    Job job = (Job)weakReference.get();
                    if (job == null) continue;
                    job.markInvalid();
                }
                vector.removeAllElements();
                this.createdJobs.remove(string);
            }
        }
    }

    /*
     * WARNING - Removed try catching itself - possible behaviour change.
     */
    public void invalidateAllCreatedJobs() {
        Hashtable hashtable = this.createdJobs;
        synchronized (hashtable) {
            Enumeration enumeration = this.createdJobs.keys();
            while (enumeration.hasMoreElements()) {
                String string = (String)enumeration.nextElement();
                Vector vector = (Vector)this.createdJobs.get(string);
                if (vector == null) continue;
                Enumeration enumeration2 = vector.elements();
                while (enumeration2.hasMoreElements()) {
                    WeakReference weakReference = (WeakReference)enumeration2.nextElement();
                    Job job = (Job)weakReference.get();
                    if (job == null) continue;
                    job.markInvalid();
                }
                vector.removeAllElements();
                this.createdJobs.remove(string);
            }
        }
    }

    private boolean sameDefinition(JobDefinition jobDefinition, JobDefinition jobDefinition2) {
        boolean bl = this.validDefinition(jobDefinition);
        boolean bl2 = bl == this.validDefinition(jobDefinition2);
        return bl2 && (!bl || jobDefinition.sameDefinition(jobDefinition2, this));
    }

    private boolean validDefinition(JobDefinition jobDefinition) {
        return jobDefinition.getJobClass(this) != null;
    }

    protected void checkJobClass(Class clazz) throws JobConfigurationException {
        if (!Modifier.isPublic(clazz.getModifiers())) {
            String string = clazz + " is not public";
            this.log(string, 0);
            throw new JobConfigurationException(string);
        }
        if (Modifier.isAbstract(clazz.getModifiers())) {
            String string = clazz + " is abstract";
            this.log(string, 0);
            throw new JobConfigurationException(string);
        }
        try {
            clazz.getConstructor(null);
        }
        catch (NoSuchMethodException noSuchMethodException) {
            String string = "No public no-arg constructor in " + clazz;
            this.log(string, 0);
            throw new JobConfigurationException(string);
        }
        catch (LinkageError linkageError) {
            String string = "Could not load " + clazz + ": " + linkageError;
            this.log(string, 0);
            throw new JobConfigurationException(string, linkageError);
        }
        if (!(class$de$audi$tghu$development$jobs$Job == null ? (class$de$audi$tghu$development$jobs$Job = JobRunner.class$("de.audi.tghu.development.jobs.Job")) : class$de$audi$tghu$development$jobs$Job).isAssignableFrom(clazz)) {
            String string = "Not a Job class: " + clazz;
            this.log(string, 0);
            throw new JobConfigurationException(string);
        }
    }

    protected final void setRunnerReference(Object object) {
        if (object instanceof Job) {
            ((Job)object).setRunner(this);
            return;
        }
        try {
            Method method = object.getClass().getMethod("setRunner", class$de$audi$tghu$development$jobs$JobRunner == null ? (class$de$audi$tghu$development$jobs$JobRunner = JobRunner.class$("de.audi.tghu.development.jobs.JobRunner")) : class$de$audi$tghu$development$jobs$JobRunner);
            if (method != null) {
                method.invoke(object, this);
            }
        }
        catch (Throwable throwable) {
            // empty catch block
        }
    }

    public File resolveFile(String string) {
        return FILE_UTILS.resolveFile(this.baseDir, string);
    }

    public synchronized void setUserProperty(String string, String string2) {
        this.log("Setting user property: " + string + " -> " + string2, 4);
        this.userProperties.put(string, string2);
    }

    public synchronized Object getUserProperty(String string) {
        if (string == null) {
            return null;
        }
        return this.userProperties.get(string);
    }

    public Hashtable getUserProperties() {
        return new Hashtable(this.userProperties);
    }

    public void executeJob(String string) throws JobConfigurationException {
        if (string == null) {
            String string2 = "No job specified";
            throw new JobConfigurationException(string2);
        }
        Job job = this.createJob(string);
        if (job == null) {
            String string3 = "No definition of job " + string + " available";
            throw new JobConfigurationException(string3);
        }
        job.perform();
    }

    public void syncExec(Job job) {
        if (job == null) {
            return;
        }
        job.perform();
    }

    public void asyncExec(Job job) {
        if (job == null) {
            return;
        }
        JobThread jobThread = new JobThread(job);
        jobThread.start();
    }

    public static synchronized IJobLogger getDefaultJobLogger(boolean bl) {
        if (LOGGER_INSTANCE == null) {
            if (bl) {
                TelnetLogger telnetLogger = new TelnetLogger();
                telnetLogger.setPort(10147);
                telnetLogger.activateOptions();
                LOGGER_INSTANCE = telnetLogger;
            } else {
                DefaultLogger defaultLogger = new DefaultLogger();
                defaultLogger.setOutputPrintStream(System.out);
                defaultLogger.setErrorPrintStream(System.err);
                LOGGER_INSTANCE = defaultLogger;
            }
        }
        return LOGGER_INSTANCE;
    }

    static /* synthetic */ Class class$(String string) {
        try {
            return Class.forName(string);
        }
        catch (ClassNotFoundException classNotFoundException) {
            throw new NoClassDefFoundError(classNotFoundException.getMessage());
        }
    }

    private class JobThread
    extends Thread {
        private Job job;

        public JobThread(Job job) {
            this.setName("Job-" + this.getName());
            this.setPriority(4);
            this.job = job;
        }

        /*
         * WARNING - Removed try catching itself - possible behaviour change.
         */
        public void run() {
            if (this.job != null) {
                try {
                    this.job.perform();
                }
                finally {
                    this.job = null;
                }
            }
        }
    }

    private static class JobErrorTypeDelegate
    implements IErrorTypeDelegate {
        private JobErrorTypeDelegate() {
        }

        public RuntimeException createRuntimeException(String string) {
            return new JobConfigurationException(string);
        }

        public RuntimeException createRuntimeException(Throwable throwable) {
            return new JobConfigurationException(throwable);
        }

        public RuntimeException createRuntimeException(String string, Throwable throwable) {
            return new JobConfigurationException(string, throwable);
        }
    }

    private static class JobTypeTable
    extends Hashtable {
        private static final long serialVersionUID = 1L;
        private JobRunner runner;

        public JobTypeTable(JobRunner jobRunner) {
            this.runner = jobRunner;
        }

        public JobDefinition getDefinition(String string) {
            return (JobDefinition)super.get(string);
        }

        public Object get(Object object) {
            return this.getJobClass((String)object);
        }

        public Object create(String string) {
            JobDefinition jobDefinition = this.getDefinition(string);
            return jobDefinition == null ? null : jobDefinition.create(this.runner);
        }

        public Class getJobClass(String string) {
            JobDefinition jobDefinition = this.getDefinition(string);
            return jobDefinition == null ? null : jobDefinition.getJobClass(this.runner);
        }

        public boolean contains(Object object) {
            boolean bl;
            if (object instanceof Class) {
                Iterator iterator = this.values().iterator();
                for (bl = false; iterator.hasNext() && !bl; bl |= ((JobDefinition)iterator.next()).getJobClass(this.runner) == object) {
                }
            }
            return bl;
        }

        public boolean containsValue(Object object) {
            return this.contains(object);
        }
    }
}

