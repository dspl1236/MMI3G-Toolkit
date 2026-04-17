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


## Complete patch table (all 5 call sites)

Analysis found 19 literal pool entries referencing the
`EscRsa_DecryptSignature` function (at 0x08046694). Of those,
5 have confirmed JSR → TST → BT/S patterns:

| # | File Offset | Virtual Address | Patch |
|---|------------|-----------------|-------|
| 1 | `0x0150A6` | `0x080550A6` | `0B40` → `00E0` |
| 2 | `0x02CED4` | `0x0806CED4` | `0B40` → `00E0` |
| 3 | `0x03EA28` | `0x0807EA28` | `0B40` → `00E0` |
| 4 | `0x1B11F6` | `0x081F11F6` | `0B40` → `00E0` |
| 5 | `0x593AB6` | `0x085D3AB6` | `0B40` → `00E0` |

All 5 patches replace `JSR @r0` (call EscRsa_DecryptSignature)
with `MOV #0, r0` (force success), causing the subsequent
`TST r0,r0` / `BT/S` to always take the success branch.

### Applying all 5 patches

```bash
python3 -c "
patches = [0x0150a6, 0x02ced4, 0x03ea28, 0x1b11f6, 0x593ab6]
with open('MMI3GApplication', 'r+b') as f:
    for offset in patches:
        f.seek(offset)
        original = f.read(2)
        assert original == b'\x0b\x40', f'Unexpected bytes at 0x{offset:x}: {original.hex()}'
        f.seek(offset)
        f.write(b'\x00\xe0')
        print(f'  Patched 0x{offset:06x}: {original.hex()} -> 00e0')
print('All 5 EscRsa verification calls patched.')
"
```

### Note on other binaries

The EscRsa library is statically linked into ALL 5 main binaries:
- MMI3GApplication (10.7 MB) — patched above
- MMI3GMedia (8.3 MB)
- MMI3GNavigation (6.8 MB)
- MMI3GMisc
- MMI3GTelephone

Each binary has 2 EscRsa string instances. The same analysis
approach (search for literal pool entries containing the function
address, find JSR→TST→BT/S pattern) can be applied to the other
binaries. The FSC check primarily runs in MMI3GApplication.

## Cross-Version Verification (MU9411 vs MU9498)

Comparison of MMI3GApplication across the K0942 firmware family:

| Build | Part # | Size | Patch @ 0x1B11F6 | Code |
|-------|--------|------|:---:|------|
| MU9411 | 8R0906961FB (K0942_4) | 10,702,848 | `0B 40` ✓ | Baseline |
| MU9498 | 8R0906961FE (K0942_6) | 10,702,848 | `0B 40` ✓ | **4 bytes differ** |

Only 4 bytes differ between builds — all in the ELF header metadata.
The actual SH4 machine code is **100% identical**. This means:

- **The FSC patch works on the ENTIRE K0942 family** (builds 9411–9498+)
- One universal patch covers at minimum 87 firmware revisions
- NavCore, MMI3GMedia also only differ by 2–4 header bytes
- EOL flags are identical across both versions (88 flags each)
- QNX system tools (pidin, ksh) are byte-for-byte identical

The only significant binary difference is lsd.jxe (Java HMI),
which is fully recompiled between versions but contains the
same EOL flag configuration and feature set.

## AudiFSC.txt — Supported FSC Codes

Extracted from 8R0906961ES (K0942_3) AudiSupportedFscs package.

### FSC Code Ranges
| Code Range | Count | Description |
|-----------|:---:|------------|
| 0006.0000 | 1 | ISO Image Language CD |
| 0004.0000–0004.003F | 64 | Navigation database (map regions) |
| 0004.0100 | 1 | Navigation feature |
| 0004.0600–0004.063F | 64 | Navigation database (extended) |

### Audi Signatures (MD5)
8 MD5 signatures used for ExceptionList.txt validation:
```
7D436BDFAD0582AF0E3B013D8132590B
92C63ECF027D5CFC637608E2767BC6CF
8886438CAC25AD676D53F6E73D352E0F
C272DE3D70841E4B2CFBC3618B0C9524
F6B2876032119E6C1D1CAE7E21C7E511
F85D56D5E0B065D9C5FC67F99D6D0F05
FE0469FD144846E5B5348187D080C1D9
0AEF736963183DC7A6B56943ADB137DB
```

These signatures are used for the ExceptionList mechanism (separate
from the RSA signature verification bypassed at 0x001B11F6).
The FSC code 0004.XXYY maps navigation regions where XX=major
and YY=minor variant (0x00-0x3F = 64 regions per major).
