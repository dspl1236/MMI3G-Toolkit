# Status screen

Every card shows a status screen while it runs. On MMI 3G+ units it is
`core/bin/mmi_splash`: full-screen art with a live band (the current step,
`n/m`, the elapsed time, a progress bar), then **DONE** or **FAILED**. On other
units, or if `mmi_splash` does not start within 2 s, `run.sh` falls back to
`core/bin/showScreen` with the PNGs.

| File | What |
|---|---|
| `core/bin/mmi_splash` | the status program (SH4 QNX). Built from PCM-Forge `tools/sh4-toolchain/forge_splash.c` at `4cfff72`: `EXTRA_CFLAGS=-DFORGE_MMI ./build.sh forge_splash.c mmi_splash` (md5 `72c56310d77b626e4d0b28f4d42d92dd`) |
| `core/lib/{running,done,failed}.bin` | the three screens for `mmi_splash`, 800x480 (`make_img.py --size 800x480` in the same PCM-Forge folder) |
| `core/lib/{running,done,failed}.png` | the same screens for `showScreen` |
| `tools/status-art/make_art.py` | draws all three (`python make_art.py OUTDIR`), plus previews with the live band filled in |

## How run.sh drives it

- `run.sh` starts it with the RUNNING and DONE images, a done-flag in
  `/fs/tmpfs`, and the FAILED image.
- Before each module it writes `a-b/n <module>` to `$FORGE_PROGRESS`, so the bar
  creeps through that module's share. A module can write its own line under
  the same share: `echo "${FORGE_MOD_RANGE} <what it is doing>" > "$FORGE_PROGRESS"`
  (wifi-sta does).
- At exit, `finish()` writes the done-flag. It is empty for DONE, or `FAIL` if
  `run.sh` stopped early or a module whose `module.json` sets
  `"exit_code_reports_failure": true` exited non-zero. Other modules' non-zero
  exits are logged as `[WARN]` only, since their exit status is not a verdict.
  The program's own log goes to `var/mmi_splash.log` on the card.

The live band is the centred 480x240 panel's lower strip (screen x 160-639,
y 304-359). `mmi_splash` clears only that strip each frame, so the art keeps it
plain background (`#0a0a0c`). The three RUNNING dots must sit where
`forge_splash.c`'s `FORGE_MMI` `DOT_X`/`DOT_Y` say. Fonts: DejaVu Sans / Sans
Mono (Bitstream Vera licence).

Tested on an Audi A6 (9411, K0942_3), 2026-11-26: RUNNING, DONE and FAILED, and
the OEM screen restored after each.
