/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.util;

public interface IErrorTypeDelegate {
    public RuntimeException createRuntimeException(String var1);

    public RuntimeException createRuntimeException(Throwable var1);

    public RuntimeException createRuntimeException(String var1, Throwable var2);
}

