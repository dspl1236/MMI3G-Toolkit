"""MMI3G-Toolkit status screens for mmi_splash (800x480): RUNNING, DONE, FAILED.

    python make_art.py [OUTDIR]

Writes running.png, done.png, failed.png (what the card ships, baked to .bin by
make_img.py --size 800x480) and preview_*.png (the same with the live band the
splash draws on the unit: step label, n/m, timer, bar), for review.

The live band is the 480x240 panel's lower strip, centred: screen x 160..639,
y 304..359. mmi_splash clears it with COL_BG every frame, so the art keeps it
plain BG. The three RUNNING dots are drawn here at the panel's DOT_X/DOT_Y; the
splash dims two of them per frame.
Fonts: DejaVu Sans / Sans Mono (Bitstream Vera licence, free to embed).
"""
import os
import sys

import matplotlib
from PIL import Image, ImageDraw, ImageFont

FONTS = os.path.join(os.path.dirname(matplotlib.__file__), "mpl-data", "fonts", "ttf")


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


W, H = 800, 480
PX, PY = 160, 120                    # the 480x240 panel's place (mmi_splash centres it)
BG = (10, 10, 12)                    # COL_BG 0xff0a0a0c: the band is cleared with this
LINE = (28, 28, 32)
GRAY = (138, 138, 144)
DIM = (74, 74, 80)
WHITE = (236, 236, 238)
RED = (196, 30, 58)                  # the toolkit's #c41e3a
GREEN = (47, 191, 113)
AMBER = (240, 160, 32)
DOT_X = (310, 330, 350)              # forge_splash.c DOT_X, DOT_Y (FORGE_MMI), 11x11
DOT_Y = 151
DOT_RUN = ((4, 6), (2, 8), (1, 9), (1, 9), (0, 10), (0, 10), (0, 10), (1, 9), (1, 9), (2, 8), (4, 6))
BAR = (24, 220, 455, 229)            # forge_splash.c BAR_X1, BAR_Y1, BAR_X2, BAR_Y2
TXT_Y = 198


def spaced(d, xy, text, f, fill, gap):
    x, y = xy
    for ch in text:
        d.text((x, y), ch, font=f, fill=fill)
        x += d.textlength(ch, font=f) + gap
    return x


def frame(accent, kicker):
    im = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(im)
    # header: the logo bars, the name, the SD card mark
    for i, (c, h) in enumerate(((GRAY, 16), (RED, 22), (RED, 18))):
        x = 28 + i * 7
        d.rectangle((x, 30 - h, x + 3, 30), fill=c)
    spaced(d, (62, 13), "MMI3G-TOOLKIT", font("DejaVuSans-Bold.ttf", 14), WHITE, 2)
    d.ellipse((682, 17, 688, 23), fill=accent)
    spaced(d, (698, 13), "SD CARD", font("DejaVuSans-Bold.ttf", 12), GRAY, 2)
    d.line((0, 44, W, 44), fill=LINE)
    # the edge ticks of the toolkit's style
    for y in range(80, 440, 64):
        d.line((14, y, 20, y), fill=LINE)
        d.line((W - 21, y, W - 15, y), fill=LINE)
    # kicker over the title
    spaced(d, (PX + 24, PY + 56), kicker, font("DejaVuSans-Bold.ttf", 12), GRAY, 3)
    d.rectangle((PX + 24, PY + 80, PX + 64, PY + 82), fill=accent)
    # footer
    d.line((0, 440, W, 440), fill=LINE)
    return im, d


def footer(d, text, colour):
    d.ellipse((28, 457, 34, 463), fill=colour)
    spaced(d, (44, 452), text, font("DejaVuSans-Bold.ttf", 11), colour, 2)
    f = font("DejaVuSans.ttf", 11)
    t = "github.com/dspl1236/MMI3G-Toolkit"
    d.text((W - 28 - d.textlength(t, font=f), 452), t, font=f, fill=DIM)


def running():
    im, d = frame(RED, "SD CARD  ·  WORKING")
    d.text((PX + 22, PY + 112), "RUNNING", font=font("DejaVuSans-Bold.ttf", 52), fill=WHITE)
    for x in DOT_X:
        for r, (a, b) in enumerate(DOT_RUN):
            d.line((PX + x + a, PY + DOT_Y + r, PX + x + b, PY + DOT_Y + r), fill=RED)
    d.text((PX + 24, PY + 262), "Keep the MMI on and the card in until DONE.",
           font=font("DejaVuSans.ttf", 15), fill=GRAY)
    footer(d, "DO NOT REMOVE THE SD CARD", RED)
    return im


def ending(word, colour, mark, kicker, line1, line2, foot):
    im, d = frame(colour, kicker)
    x0, y0 = PX + 24, PY + 122
    d.ellipse((x0, y0, x0 + 44, y0 + 44), outline=colour, width=4)
    if mark == "check":
        d.line((x0 + 11, y0 + 23, x0 + 19, y0 + 31, x0 + 33, y0 + 14), fill=colour, width=5, joint="curve")
    else:
        d.rectangle((x0 + 20, y0 + 10, x0 + 24, y0 + 27), fill=colour)
        d.rectangle((x0 + 20, y0 + 32, x0 + 24, y0 + 36), fill=colour)
    d.text((x0 + 60, PY + 112), word, font=font("DejaVuSans-Bold.ttf", 52), fill=WHITE)
    f = font("DejaVuSans.ttf", 15)
    d.text((PX + 24, PY + 262), line1, font=f, fill=GRAY)
    d.text((PX + 24, PY + 284), line2, font=f, fill=GRAY)
    footer(d, foot, colour)
    return im


def band(im, label, right, fill, colour):
    """What mmi_splash draws over the band (approximated with DejaVu Sans Mono)."""
    d = ImageDraw.Draw(im)
    f = font("DejaVuSansMono.ttf", 13)
    d.text((PX + BAR[0], PY + TXT_Y), label, font=f, fill=(216, 216, 220))
    d.text((PX + BAR[2] + 1 - d.textlength(right, font=f), PY + TXT_Y), right, font=f, fill=GRAY)
    x1, y1, x2, y2 = PX + BAR[0], PY + BAR[1], PX + BAR[2], PY + BAR[3]
    d.rectangle((x1, y1, x2, y2), fill=LINE, outline=(42, 42, 46))
    if fill:
        d.rectangle((x1 + 1, y1 + 1, x1 + 1 + int((x2 - x1 - 2) * fill), y2 - 1), fill=colour)
    return im


def dim_dots(im, active):
    d = ImageDraw.Draw(im)
    for i, x in enumerate(DOT_X):
        if i == active:
            continue
        for r, (a, b) in enumerate(DOT_RUN):
            d.line((PX + x + a, PY + DOT_Y + r, PX + x + b, PY + DOT_Y + r), fill=(70, 18, 28))
    return im


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.abspath(__file__))
    shots = {
        "running": running(),
        "done": ending("DONE", GREEN, "check", "SD CARD  ·  FINISHED",
                       "Finished. You can take the card out.",
                       "Restart the MMI if the card's notes say to.", "SD CARD CAN BE REMOVED"),
        "failed": ending("FAILED", AMBER, "bang", "SD CARD  ·  STOPPED",
                         "A step refused; nothing after it ran.",
                         "The log is in var/ on the SD card.", "SEE var/ ON THE SD CARD"),
    }
    for name, im in shots.items():
        im.save(os.path.join(out, f"{name}.png"))
    band(dim_dots(shots["running"].copy(), 1), "Installing station files", "3/6  0:09", 0.5, RED) \
        .save(os.path.join(out, "preview_running.png"))
    band(shots["done"].copy(), "6 steps done", "0:24", 1.0, GREEN).save(os.path.join(out, "preview_done.png"))
    band(shots["failed"].copy(), "Storing networks", "4/6  0:13", 0.62, AMBER) \
        .save(os.path.join(out, "preview_failed.png"))
    print("wrote", out)


if __name__ == "__main__":
    main()
