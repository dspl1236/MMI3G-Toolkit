/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  de.audi.tghu.hmi.view.HMITerminalImpl
 *  fi.hybrid.a2dg.Graphics2D
 *  fi.hybrid.hwg.Composite
 *  fi.hybrid.hwg.Graphics
 */
package de.audi.tghu.development.widget;

import de.audi.tghu.development.renderer.ScreenRenderer;
import de.audi.tghu.development.widget.Widget;
import de.audi.tghu.hmi.view.HMITerminalImpl;
import fi.hybrid.a2dg.Graphics2D;
import fi.hybrid.hwg.Composite;
import fi.hybrid.hwg.Graphics;

public class SpellerWidget
extends Widget {
    private char[] charTable = new char[]{'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '\u00c4', '\u00d6', '\u00dc', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9'};
    protected StringBuffer input = new StringBuffer(30);
    protected int currChar;

    public SpellerWidget(ScreenRenderer screenRenderer) {
        super(null, screenRenderer);
        this.input.append("This is a test");
        this.currChar = 0;
    }

    public boolean processKey(int n) {
        boolean bl = false;
        switch (n) {
            case 17: {
                this.input.append(this.charTable[this.currChar]);
                bl = true;
                break;
            }
        }
        return bl;
    }

    public boolean processEncoder(int n, int n2) {
        boolean bl = false;
        switch (n) {
            case 17: {
                int n3;
                for (n3 = (this.currChar + n2) % this.charTable.length; n3 < 0; n3 += this.charTable.length) {
                }
                this.currChar = n3;
                bl = true;
                break;
            }
        }
        return bl;
    }

    public void render(Graphics graphics, Graphics2D graphics2D, Composite composite) {
        super.render(graphics, graphics2D, composite);
        if (!this.isVisible()) {
            return;
        }
    }

    public void cleanup(HMITerminalImpl hMITerminalImpl) {
        super.cleanup(hMITerminalImpl);
    }
}

