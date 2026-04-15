/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.jobs;

import de.audi.tghu.development.jobs.JobClassLoader;
import de.audi.tghu.development.jobs.JobConfigurationException;
import de.audi.tghu.development.jobs.JobRunner;
import java.lang.reflect.Constructor;
import java.lang.reflect.InvocationTargetException;

public class JobDefinition {
    private String name;
    private Class clazz;
    private ClassLoader classLoader;
    private String className;
    static /* synthetic */ Class class$de$audi$tghu$development$jobs$JobRunner;

    public ClassLoader getClassLoader() {
        return this.classLoader;
    }

    public void setClassLoader(ClassLoader classLoader) {
        this.classLoader = classLoader;
    }

    public String getClassName() {
        return this.className;
    }

    public void setClassName(String string) {
        this.className = string;
    }

    public void setClass(Class clazz) {
        this.clazz = clazz;
        if (clazz == null) {
            return;
        }
        if (this.classLoader == null) {
            this.classLoader = clazz.getClassLoader();
        }
        if (this.className == null) {
            this.className = clazz.getName();
        }
    }

    public String getName() {
        return this.name;
    }

    public void setName(String string) {
        this.name = string;
    }

    public Class getJobClass(JobRunner jobRunner) {
        if (this.clazz != null) {
            return this.clazz;
        }
        try {
            this.clazz = this.classLoader == null ? Class.forName(this.className) : this.classLoader.loadClass(this.className);
        }
        catch (NoClassDefFoundError noClassDefFoundError) {
            jobRunner.log("Could not load a dependent class (" + noClassDefFoundError.getMessage() + ") for type " + this.name, 4);
        }
        catch (ClassNotFoundException classNotFoundException) {
            jobRunner.log("Could not load class (" + this.className + ") for type " + this.name, 4);
        }
        return this.clazz;
    }

    public Object create(JobRunner jobRunner) {
        return this.create0(jobRunner);
    }

    private Object create0(JobRunner jobRunner) {
        Class clazz = this.getJobClass(jobRunner);
        if (clazz == null) {
            return null;
        }
        Object object = this.createAndSet(jobRunner, clazz);
        return object;
    }

    private Object createAndSet(JobRunner jobRunner, Class clazz) throws JobConfigurationException {
        try {
            Constructor constructor = null;
            boolean bl = false;
            try {
                constructor = clazz.getConstructor(new Class[0]);
                bl = true;
            }
            catch (NoSuchMethodException noSuchMethodException) {
                constructor = clazz.getConstructor(class$de$audi$tghu$development$jobs$JobRunner == null ? (class$de$audi$tghu$development$jobs$JobRunner = JobDefinition.class$("de.audi.tghu.development.jobs.JobRunner")) : class$de$audi$tghu$development$jobs$JobRunner);
                bl = false;
            }
            Object var5_11 = null;
            var5_11 = bl ? constructor.newInstance(new Object[0]) : constructor.newInstance(jobRunner);
            jobRunner.setRunnerReference(var5_11);
            return var5_11;
        }
        catch (InvocationTargetException invocationTargetException) {
            Throwable throwable = invocationTargetException.getTargetException();
            throw new JobConfigurationException("Could not create type " + this.name + " due to " + throwable, throwable);
        }
        catch (NoClassDefFoundError noClassDefFoundError) {
            String string = "Type " + this.name + ": A class needed by class " + clazz + " cannot be found: " + noClassDefFoundError.getMessage();
            throw new JobConfigurationException(string, noClassDefFoundError);
        }
        catch (Throwable throwable) {
            throw new JobConfigurationException("Could not create type " + this.name + " due to " + throwable, throwable);
        }
    }

    public boolean sameDefinition(JobDefinition jobDefinition, JobRunner jobRunner) {
        if (jobDefinition == null) {
            return false;
        }
        if (jobDefinition.getClass() != this.getClass()) {
            return false;
        }
        return jobDefinition.getJobClass(jobRunner).equals(this.getJobClass(jobRunner));
    }

    public boolean similarDefinition(JobDefinition jobDefinition, JobRunner jobRunner) {
        ClassLoader classLoader;
        if (jobDefinition == null) {
            return false;
        }
        if (this.getClass() != jobDefinition.getClass()) {
            return false;
        }
        if (!this.getClassName().equals(jobDefinition.getClassName())) {
            return false;
        }
        ClassLoader classLoader2 = jobDefinition.getClassLoader();
        if (classLoader2 == (classLoader = this.getClassLoader())) {
            return true;
        }
        return classLoader != null && classLoader2 != null && classLoader2 instanceof JobClassLoader && classLoader instanceof JobClassLoader && ((JobClassLoader)classLoader2).getClasspath().equals(((JobClassLoader)classLoader).getClasspath());
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

