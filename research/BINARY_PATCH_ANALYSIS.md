# libembeddedearth.so Binary Patch Analysis

## Overview
Two code patches are required to restore Google Earth on MMI3G+.
Both patches are in the **image processing/rendering pipeline**, not auth.
Auth bypass comes from **hostname redirects** in the binary's string table.

## PATCH 1 — Image Validation Check (0x343d20)
**Original:** `86 2f 1f c7 96 2f` (mov.l r8,@-r15; mova; mov.l r9,@-r15)
**Patched:** `01 e0 0b 00 09 00` (mov #1,r0; rts; nop — force return TRUE)

### Purpose
This function is a **validation check** in the image processing pipeline.
It returns 0 (fail) or non-zero (pass).

### Call Sites
- `0x356a5a` — Image loader (surrounded by JPEG EXIF processing code)
- `0x364db4` — Rendering engine (surrounded by GL/shader code)

### Control Flow (caller at 0x356a5a)
```
call PATCH1(object)        ; validate image data
tst r0, r0                 ; test return value
bf continue                ; if non-zero: continue (valid)
bra error_path             ; if zero: skip to error handler
```

When validation fails (r0=0), execution jumps to 0x356d60 which
sets error code 30 and calls cleanup routines.

### Why Force Return 1
The original function checks something about the tile data that fails
with redirected/proxy tile sources. Forcing TRUE skips this check,
allowing tiles from any source to be processed.

## PATCH 2 — Post-Validation Processing (0x3470a0)
**Original:** `86 2f 2d c7` (mov.l r8,@-r15; mova)
**Patched:** `0b 00 09 00` (rts; nop — skip entirely)

### Purpose
This function is called AFTER PATCH1 succeeds. It performs processing
that may set up DRM state or validate tile metadata. It calls:
- Internal function with parameter 2 (mode/type flag)
- Internal function with parameter -1 (disable/reset flag)
- Several other processing subfunctions

### Why Skip It
The processing this function does is either unnecessary or harmful
when tiles come from a non-Google-DRM source. Skipping it avoids
setting invalid state that would interfere with rendering.

## Hostname Redirects (~22 patches)
The binary contains hardcoded Google server URLs:
- `kh.google.com` → redirect to proxy IP
- `cbk0.google.com` → redirect for Street View
- `mw1.google.com` → redirect for weather overlays
- `geo.keyhole.com` → redirect for legacy endpoints

These hostname changes redirect ALL server communication through our proxy,
which handles auth (returns cached responses) and forwards tile requests
to the real kh.google.com servers.

## Architecture
```
Original: GEMMI → libembeddedearth.so → kh.google.com (Google's servers, now reject old clients)

Patched:  GEMMI → libembeddedearth.so (hostnames → proxy IP)
                     ↓
          Code patches bypass tile validation
                     ↓
          Proxy (port 80) → kh.google.com (real tiles)
```

## Key Insight
The code patches are NOT auth patches. They bypass tile data
validation in the image loader/renderer. Auth is handled entirely
by the hostname redirects pointing to our proxy which returns
cached auth responses.
