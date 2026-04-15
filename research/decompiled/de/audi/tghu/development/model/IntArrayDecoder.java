/*
 * Decompiled with CFR 0.152.
 */
package de.audi.tghu.development.model;

import de.audi.tghu.development.model.DecoderConsumer;

public class IntArrayDecoder {
    private DecoderConsumer consumer;
    private int[] data;

    public IntArrayDecoder(int[] nArray, DecoderConsumer decoderConsumer) {
        this.consumer = decoderConsumer;
        this.data = new int[nArray.length];
        System.arraycopy(nArray, 0, this.data, 0, nArray.length);
    }

    public void decode() {
        for (int i = 0; i < this.data.length; ++i) {
            this.consumer.consumeElement(3, new Integer(this.data[i]));
        }
    }
}

