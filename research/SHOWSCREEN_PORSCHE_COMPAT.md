# showScreen Porsche PCM3.1 Compatibility
# Part of PCM-Forge research

## Problem

showScreen works on Audi MMI3G+ but NOT on Porsche PCM3.1.
PNGs do not display — binary fails silently.

## Root Cause

showScreen connects to the display via `lmgrHMIConnect` — a
**layermanagerV2-only** function that doesn't exist in the
Porsche layermanager V1.

```
showScreen needs:              Audi V2    Porsche V1
─────────────────────────────────────────────────────
lmgrHMIConnect                   ✓          ❌ MISSING
lmgrRegisterDisplayable          ✓          ✓
lmgrGetVfb                       ✓          ✓
lmgrUpdateVfb                    ✓          ✓
```

The Porsche uses `lmgrComponentConnect` instead.

## Hardware Compatibility

Both platforms are SH4 (SH7785) running QNX 6.3.2, both have
libgf.so.1. The binary WOULD run — it just can't connect to
the Porsche display manager.

```
            Audi MMI3G+              Porsche PCM3.1
CPU:        SH7785 (SH4A)           SH7785 (SH4A) ✓ same
QNX:        6.3.2                    6.3.2         ✓ same
GPU:        NVIDIA (devg-NVMiniRM)   Carmine (devg-carmine)
Display:    layermanagerV2           layermanager (V1)
libgf:      libgf.so.1              libgf.so.1    ✓ same
Connect:    lmgrHMIConnect           lmgrComponentConnect
Device:     /dev/layermanager        /dev/layermanager ✓ same
```

## How showScreen Works

1. Opens /dev/layermanager
2. Calls lmgrHMIConnect (devctl) ← FAILS on Porsche
3. Calls lmgrRegisterDisplayable (devctl)
4. Loads PNG via img_lib_attach
5. Creates gf_surface, blits PNG to framebuffer
6. Calls lmgrGetVfb + lmgrUpdateVfb to push to screen

The lmgr calls are NOT imported symbols — they're inline devctl
calls with specific command codes baked into the binary. The
"lmgrHMIConnect failed" strings are just error messages.

## Fix Options

### Option 1: Ghidra RE showScreen (52KB)
Decompile showScreen, find the devctl command code for HMIConnect,
patch it to the Porsche ComponentConnect code. Need to also find
the ComponentConnect devctl code from PCM3Root.

### Option 2: Write a Porsche-native showScreen
52KB binary with only libgf.so.1 dependency — relatively simple.
Use lmgrComponentConnect instead of lmgrHMIConnect. Needs QNX SH4
cross-compiler (or compile on target if tools available).

### Option 3: Use PCM3Root's built-in display
PCM3Root has CustomBootscreen support — it loads PNGs from
/HBpersistence/CustomBootscreen_XXX.bin. This is the boot splash
system. Could potentially hijack it for status display, but it's
designed for boot-time use, not runtime.

### Option 4: Skip showScreen on Porsche
Just don't display status PNGs on PCM. The scripts still work —
they just run without visual feedback. Users check pcm_ran.txt
to confirm completion.

## Status

showScreen binary is Audi-only. Porsche compatibility requires
either binary patching or a rewrite. Documenting for future work.
