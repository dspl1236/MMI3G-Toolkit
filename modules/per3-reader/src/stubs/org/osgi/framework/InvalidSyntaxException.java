package org.osgi.framework;

public class InvalidSyntaxException extends Exception {
    public InvalidSyntaxException(String msg, String filter) { super(msg); }
}
