/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.jobs;

import de.audi.crypto.AESEngine;
import de.audi.crypto.CBCBlockCipher;
import de.audi.crypto.CryptoException;
import de.audi.crypto.KeyParameter;
import de.audi.crypto.PKCS1Encoding;
import de.audi.crypto.PaddedBufferedBlockCipher;
import de.audi.crypto.RSAEngine;
import de.audi.crypto.RSAKeyParameters;
import de.audi.tghu.development.jobs.Base64;
import de.audi.tghu.development.jobs.JobRunner;
import de.audi.tghu.development.jobs.SignedContent;
import de.audi.tghu.development.jobs.SignerInfo;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.math.BigInteger;
import java.security.InvalidKeyException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.NoSuchProviderException;
import java.security.SignatureException;
import java.text.MessageFormat;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;

public class SignatureBlockProcessor {
    static final String RSA_MODULUS = "AI2fepz64ZbVLru5KITtZkPSwHu0RDuAGDhhGhdxdtjlGLnKXhy5Ar24z/fvOE6ZS3rA4sySFfenX3VV9CGtf1+sXnMtHRnPOPJptuThVgnNgoyPcSayRyiec2M9OC5zy1MK5HRUEP+8LMJxTt89BgAe5MgVI7M+Pmq2sVhlNHvd";
    static final BigInteger RSA_PUBLIC_EXP = BigInteger.valueOf(17L);
    public static final String SHA1_STR = "SHA1";
    public static final String MD5_STR = "MD5";
    public static final String META_INF_MANIFEST_MF = "META-INF/MANIFEST.MF";
    public static final String META_INF_MANIFEST_SF = "META-INF/MANIFEST.SF";
    public static final String MF_ENTRY_NEWLN_NAME = "\nName: ";
    public static final String MF_ENTRY_NAME = "Name: ";
    public static final String MF_DIGEST_PART = "-Digest: ";
    public static final String digestManifestSearch = "-Digest-Manifest: ";
    public static final int digestManifestSearchLen = "-Digest-Manifest: ".length();
    private JobRunner runner;
    private final ZipFile signedBundle;
    private ArrayList signerInfos = new ArrayList();
    private HashMap contentMDResults = new HashMap();
    private byte[] scramblerKey;

    public SignatureBlockProcessor(JobRunner jobRunner, ZipFile zipFile) {
        this.runner = jobRunner;
        this.signedBundle = zipFile;
    }

    public SignedContent process() throws IOException, InvalidKeyException, SignatureException, NoSuchAlgorithmException, NoSuchProviderException {
        ZipEntry zipEntry = this.signedBundle.getEntry(META_INF_MANIFEST_MF);
        if (zipEntry == null) {
            return this.createUnsignedContent();
        }
        ZipEntry zipEntry2 = this.signedBundle.getEntry(META_INF_MANIFEST_SF);
        if (zipEntry2 == null) {
            return this.createUnsignedContent();
        }
        byte[] byArray = SignatureBlockProcessor.readIntoArray(this.signedBundle, zipEntry);
        this.processSigner(this.signedBundle, byArray, META_INF_MANIFEST_SF);
        SignerInfo[] signerInfoArray = this.signerInfos.toArray(new SignerInfo[this.signerInfos.size()]);
        Object object = this.contentMDResults.entrySet().iterator();
        while (object.hasNext()) {
            Map.Entry entry = object.next();
            ArrayList[] arrayListArray = (ArrayList[])entry.getValue();
            SignerInfo[] signerInfoArray2 = arrayListArray[0].toArray(new SignerInfo[arrayListArray[0].size()]);
            byte[][] byArray2 = (byte[][])arrayListArray[1].toArray((T[])new byte[arrayListArray[1].size()][]);
            entry.setValue(new Object[]{signerInfoArray2, byArray2});
        }
        object = new SignedContent(signerInfoArray, this.contentMDResults, this.scramblerKey);
        ((SignedContent)object).setContent(this.signedBundle);
        return object;
    }

    private SignedContent createUnsignedContent() {
        SignedContent signedContent = new SignedContent(new SignerInfo[0], this.contentMDResults, null);
        signedContent.setContent(this.signedBundle);
        return signedContent;
    }

    private void processSigner(ZipFile zipFile, byte[] byArray, String string) throws IOException, SignatureException, InvalidKeyException, NoSuchAlgorithmException, NoSuchProviderException {
        ZipEntry zipEntry = zipFile.getEntry(string);
        byte[] byArray2 = SignatureBlockProcessor.readIntoArray(zipFile, zipEntry);
        byte[] byArray3 = this.decrypt(byArray2, byArray);
        String string2 = SignatureBlockProcessor.getDigAlgFromSF(byArray3);
        if (string2 == null) {
            throw new SignatureException(MessageFormat.format("Error occurs parsing the .SF file to find out the digest algorithm in this jar: {0}", zipFile.getName()));
        }
        this.verifyManifestAndSignatureFile(byArray, byArray3);
        SignerInfo signerInfo = SignerInfo.getSignerInfo(string2);
        this.populateMDResults(byArray3, signerInfo);
        this.signerInfos.add(signerInfo);
    }

    private byte[] decrypt(byte[] byArray, byte[] byArray2) throws IOException {
        String string = new String(byArray2);
        int n = (string = SignatureBlockProcessor.stripContinuations(string)).indexOf("SF-Key: ");
        if (n != -1) {
            int n2;
            int n3;
            this.log("Extracting SF-Key from jar: " + this.signedBundle.getName(), 4);
            int n4 = string.indexOf(10, n += 8);
            String string2 = string.substring(n, n4 - 1);
            byte[] byArray3 = Base64.decode(string2.getBytes());
            RSAKeyParameters rSAKeyParameters = new RSAKeyParameters(false, new BigInteger(Base64.decode(RSA_MODULUS.getBytes())), RSA_PUBLIC_EXP);
            PKCS1Encoding pKCS1Encoding = new PKCS1Encoding(new RSAEngine());
            pKCS1Encoding.init(false, rSAKeyParameters);
            byte[] byArray4 = pKCS1Encoding.processBlock(byArray3, 0, byArray3.length);
            PaddedBufferedBlockCipher paddedBufferedBlockCipher = new PaddedBufferedBlockCipher(new CBCBlockCipher(new AESEngine()));
            paddedBufferedBlockCipher.init(false, new KeyParameter(byArray4));
            this.scramblerKey = new byte[4];
            System.arraycopy(byArray4, 0, this.scramblerKey, 0, 4);
            int n5 = paddedBufferedBlockCipher.getBlockSize();
            int n6 = paddedBufferedBlockCipher.getOutputSize(n5);
            byte[] byArray5 = new byte[n5];
            byte[] byArray6 = new byte[n6];
            ByteArrayInputStream byteArrayInputStream = new ByteArrayInputStream(byArray);
            ByteArrayOutputStream byteArrayOutputStream = new ByteArrayOutputStream(byArray.length);
            while ((n3 = ((InputStream)byteArrayInputStream).read(byArray5, 0, n5)) > 0) {
                n2 = paddedBufferedBlockCipher.processBytes(byArray5, 0, n3, byArray6, 0);
                if (n2 <= 0) continue;
                byteArrayOutputStream.write(byArray6, 0, n2);
            }
            try {
                n2 = paddedBufferedBlockCipher.doFinal(byArray6, 0);
                if (n2 > 0) {
                    byteArrayOutputStream.write(byArray6, 0, n2);
                }
            }
            catch (CryptoException cryptoException) {
                SecurityException securityException = new SecurityException(MessageFormat.format("Either the manifest file or the signature file has been tampered in this jar: {0}", this.signedBundle.getName()));
                this.log(securityException.getMessage(), 0);
                throw securityException;
            }
            byteArrayOutputStream.close();
            this.log("Loaded .SF from jar: " + this.signedBundle.getName(), 4);
            byArray = byteArrayOutputStream.toByteArray();
        }
        return byArray;
    }

    static synchronized MessageDigest getMessageDigest(JobRunner jobRunner, String string) {
        try {
            return MessageDigest.getInstance(string);
        }
        catch (NoSuchAlgorithmException noSuchAlgorithmException) {
            if (jobRunner != null) {
                jobRunner.log(noSuchAlgorithmException.getMessage(), 0);
            }
            return null;
        }
    }

    MessageDigest getMessageDigest(String string) {
        try {
            return MessageDigest.getInstance(string);
        }
        catch (NoSuchAlgorithmException noSuchAlgorithmException) {
            if (this.runner != null) {
                this.runner.log(noSuchAlgorithmException.getMessage(), 0);
            }
            return null;
        }
    }

    private void populateMDResults(byte[] byArray, SignerInfo signerInfo) throws NoSuchAlgorithmException {
        String string = new String(byArray);
        int n = string.indexOf(MF_ENTRY_NEWLN_NAME);
        int n2 = string.length();
        while (n != -1 && n < n2) {
            String string2;
            int n3 = string.indexOf(MF_ENTRY_NEWLN_NAME, n + 1);
            if (n3 == -1) {
                n3 = string.length();
            }
            String string3 = string.substring(n + 1, n3);
            String string4 = SignatureBlockProcessor.getEntryFileName(string3 = SignatureBlockProcessor.stripContinuations(string3));
            if (string4 != null && (string2 = SignatureBlockProcessor.getDigestLine(string3, signerInfo.getMessageDigestAlgorithm())) != null) {
                String string5 = SignatureBlockProcessor.getDigestAlgorithmFromString(string2);
                if (!string5.equalsIgnoreCase(signerInfo.getMessageDigestAlgorithm())) continue;
                byte[] byArray2 = SignatureBlockProcessor.getDigestResultsList(string2);
                ArrayList[] arrayListArray = (ArrayList[])this.contentMDResults.get(string4);
                if (arrayListArray == null) {
                    arrayListArray = new ArrayList[]{new ArrayList(), new ArrayList()};
                    this.contentMDResults.put(string4, arrayListArray);
                }
                arrayListArray[0].add(signerInfo);
                arrayListArray[1].add(byArray2);
            }
            n = n3;
        }
    }

    private static byte[] getDigestResultsList(String string) {
        byte[] byArray = null;
        if (string != null) {
            String string2 = string;
            int n = string2.indexOf(MF_DIGEST_PART);
            if ((n += MF_DIGEST_PART.length()) >= string2.length()) {
                byArray = null;
            }
            String string3 = string2.substring(n);
            try {
                byArray = Base64.decode(string3.getBytes());
            }
            catch (Throwable throwable) {
                byArray = null;
            }
        }
        return byArray;
    }

    private static String getDigestAlgorithmFromString(String string) throws NoSuchAlgorithmException {
        if (string != null) {
            int n = string.indexOf(MF_DIGEST_PART);
            String string2 = string.substring(0, n);
            if (string2.equalsIgnoreCase(MD5_STR)) {
                return MD5_STR;
            }
            if (string2.equalsIgnoreCase(SHA1_STR)) {
                return SHA1_STR;
            }
            throw new NoSuchAlgorithmException(string2 + " digest algorithm is not supported!");
        }
        return null;
    }

    private static String getEntryFileName(String string) {
        int n = string.indexOf(MF_ENTRY_NAME);
        if (n == -1) {
            return null;
        }
        int n2 = string.indexOf(10, n);
        if (n2 == -1) {
            return null;
        }
        if (string.charAt(n2 - 1) == '\r') {
            --n2;
        }
        if ((n += MF_ENTRY_NAME.length()) >= n2) {
            return null;
        }
        return string.substring(n, n2);
    }

    private static String calculateDigest(MessageDigest messageDigest, byte[] byArray) {
        return new String(Base64.encode(messageDigest.digest(byArray)));
    }

    protected void log(String string, int n) {
        if (this.runner != null) {
            this.runner.log(string, n);
        }
    }

    private void verifyManifestAndSignatureFile(byte[] byArray, byte[] byArray2) throws SignatureException {
        String string = new String(byArray2);
        int n = (string = SignatureBlockProcessor.stripContinuations(string)).indexOf(digestManifestSearch);
        if (n != -1) {
            int n2 = string.lastIndexOf(10, n);
            String string2 = null;
            if (n2 != -1) {
                String string3 = string.substring(n2 + 1, n);
                if (string3.equalsIgnoreCase(MD5_STR)) {
                    string2 = SignatureBlockProcessor.calculateDigest(this.getMessageDigest(MD5_STR), byArray);
                } else if (string3.equalsIgnoreCase(SHA1_STR)) {
                    string2 = SignatureBlockProcessor.calculateDigest(this.getMessageDigest(SHA1_STR), byArray);
                }
                int n3 = string.indexOf(10, n += digestManifestSearchLen);
                String string4 = string.substring(n, n3 - 1);
                if (!string4.equals(string2)) {
                    SignatureException signatureException = new SignatureException(MessageFormat.format("Either the manifest file or the signature file has been tampered in this jar: {0}", this.signedBundle.getName()));
                    this.log(signatureException.getMessage(), 0);
                    throw signatureException;
                }
            }
        }
    }

    private static String getDigAlgFromSF(byte[] byArray) {
        String string = new String(byArray);
        String string2 = null;
        int n = string.indexOf(MF_ENTRY_NEWLN_NAME);
        int n2 = string.length();
        if (n != -1 && n < n2) {
            int n3 = string.indexOf(MF_ENTRY_NEWLN_NAME, n + 1);
            if (n3 == -1) {
                n3 = string.length();
            }
            string2 = string.substring(n + 1, n3);
            string2 = SignatureBlockProcessor.stripContinuations(string2);
        }
        if (string2 != null) {
            String string3 = SignatureBlockProcessor.getDigestLine(string2, null);
            return SignatureBlockProcessor.getMessageDigestName(string3);
        }
        return null;
    }

    private static String getDigestLine(String string, String string2) {
        String string3 = null;
        int n = string.indexOf(MF_DIGEST_PART);
        if (n == -1) {
            return null;
        }
        while (n != -1) {
            int n2;
            int n3 = string.lastIndexOf(10, n);
            if (n3 == -1) {
                return null;
            }
            int n4 = string.indexOf(10, n);
            if (n4 == -1) {
                return null;
            }
            int n5 = n4;
            if (string.charAt(n5 - 1) == '\r') {
                --n5;
            }
            if ((n2 = n3 + 1) >= n5) {
                return null;
            }
            String string4 = string.substring(n2, n5);
            String string5 = SignatureBlockProcessor.getMessageDigestName(string4);
            if (string2 != null && string2.equalsIgnoreCase(string5)) {
                return string4;
            }
            string3 = string4;
            n = string.indexOf(MF_DIGEST_PART, n4);
        }
        return string3;
    }

    private static String getMessageDigestName(String string) {
        int n;
        String string2 = null;
        if (string != null && (n = string.indexOf(MF_DIGEST_PART)) != -1) {
            string2 = string.substring(0, n);
        }
        return string2;
    }

    private static String stripContinuations(String string) {
        if (string.indexOf("\n ") < 0) {
            return string;
        }
        StringBuffer stringBuffer = new StringBuffer(string.length());
        int n = string.indexOf("\n ");
        int n2 = 0;
        while (n >= 0) {
            stringBuffer.append(string.substring(n2, n - 1));
            n2 = n + 2;
            n = n + 2 < string.length() ? string.indexOf("\n ", n + 2) : -1;
        }
        if (n2 < string.length()) {
            stringBuffer.append(string.substring(n2));
        }
        return stringBuffer.toString();
    }

    static byte[] readIntoArray(ZipFile zipFile, ZipEntry zipEntry) throws IOException {
        byte[] byArray;
        int n = (int)zipEntry.getSize();
        InputStream inputStream = zipFile.getInputStream(zipEntry);
        int n2 = SignatureBlockProcessor.readFully(inputStream, byArray = new byte[n]);
        if (n2 != n) {
            throw new IOException("Couldn't read all of " + zipEntry.getName() + ": " + n2 + " != " + n);
        }
        return byArray;
    }

    private static int readFully(InputStream inputStream, byte[] byArray) throws IOException {
        int n;
        int n2 = byArray.length;
        int n3 = 0;
        while ((n = inputStream.read(byArray, n3, n2)) > 0) {
            n2 -= n;
            n3 += n;
        }
        return n3;
    }
}

