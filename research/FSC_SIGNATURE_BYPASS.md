# FSC Signature Bypass — EscRsa Patch

## Overview

The MMI3G FSC (Feature Service Code) system uses RSA signature
verification via `EscRsa_DecryptSignature` from Harman's "Embedded
Security" library. A single 2-byte patch in MMI3GApplication
bypasses all FSC signature validation.

## Patch Specification

```
Binary:       MMI3GApplication
Build:        9411 C1 D1-15515A (K0942_4 variant 41)
File size:    10,702,848 bytes

File offset:  0x001B11F6
Virtual addr: 0x081F11F6

Original:     0B 40    (JSR @r0 — calls signature verify function)
Patched:      00 E0    (MOV #0, r0 — forces success return value)
```

## How it works

The NDigitalRights FSC verification flow:

```
0x081f11ee: MOV.L r0 ← 0x08046694   ; load verify function address
0x081f11f4: MOV #20, r6              ; param setup
0x081f11f6: JSR @r0                  ; CALL verify ← PATCH THIS
0x081f11f8: (delay slot)             ; executes before call
0x081f11fa: TST r0,r0                ; test return: 0 = success
0x081f11fc: BT/S → 0x081f1266        ; branch to SUCCESS cleanup
```

After the patch, `MOV #0, r0` forces r0 = 0 (success).
`TST r0,r0` then sets T = 1 (zero), and `BT/S` always takes
the success branch, bypassing all signature validation.

## Applying the patch

```bash
# Method 1: Direct binary patch
python3 -c "
with open('MMI3GApplication', 'r+b') as f:
    f.seek(0x1b11f6)
    f.write(b'\x00\xe0')
"

# Method 2: Using the toolkit pipeline
python3 tools/patch_ifs.py ifs_decomp.ifs ifs_patched.ifs \
    --replace usr/apps/MMI3GApplication=./MMI3GApplication_patched
python3 tools/repack_ifs.py ifs_patched.ifs ifs-root.ifs
```

## Crypto chain (for reference)

The FSC system uses:
- `EscSha1_Init` / `EscSha1_Update` / `EscSha1_Calc` — SHA-1 hash
- `EscRsa_DecryptSignature` — RSA signature verification
- FSC file magic: `0x8080`
- Public key queryable via `UPD_ID_requestGetPublicKey`
- `ExceptionList.txt` uses MD5 signatures (separate mechanism)

The OTP (One-Time Programmable) fuses are for component protection
only, not an FSC gate. Patching the RSA check bypasses FSC entirely.

## Analysis method

Found using radare2 (`r2`) with SH4 disassembler:
1. Located string `"%s EscRsa_DecryptSignature failed %d"` at 0x08872fb0
2. Traced literal pool reference at 0x081f1340 → format string address
3. Identified containing function (NDigitalRights verification pipeline)
4. Found `JSR @r0` at 0x081f11f6 calling function pointer 0x08046694
5. Verified TST/BT/S pattern following the call (success = r0 == 0)

## Caveats

- This patch is verified for build 9411 C1 D1-15515A (K0942_4 v41)
- Different firmware builds may have the offset at a different location
- Search for `0B 40` (JSR @r0) near `EscRsa_DecryptSignature` strings
  to find the equivalent offset in other builds
- A second EscRsa string exists at 0x0888926c (SWDL context, separate path)
- The M.I.B community uses the identical technique on MHI2/PCM4.0

## Same approach as M.I.B

The M.I.B (More Incredible Bash) community patches Porsche PCM 4.0
firmware using the same method: NOP out the `CHBJobDMBVerify`
signature verification function call. This is the Audi MMI3G
equivalent of that patch.
