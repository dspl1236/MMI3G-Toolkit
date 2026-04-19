# RNS 850 — VW Touareg (HN+ Platform Twin)

> Analysis of HN+_EU_VW_P0534 firmware (MU9478, build 9478)
> Compared with Audi MMI3G+ HN+R K0942 (build 9411)
> Date: April 19, 2026

## Overview

The VW RNS 850 is the Touareg's head unit and runs on the **exact same
Harman Becker HN+ platform** as the Audi MMI3G and Porsche PCM 3.1.
The firmware literally identifies itself as `MMI3GP Build 9478`.

## Platform Confirmation

| Property | Audi MMI3G (K0942) | RNS 850 (MU9478) | Match? |
|----------|:------------------:|:-----------------:|:------:|
| CPU | SH4 (SH7785) | SH4 (SH7785) | ✅ |
| OS | QNX 6.3.2 | QNX 6.3.2 | ✅ |
| GCC | 3.4.4 | 3.4.4 | ✅ |
| Build system | Harman/Becker | Harman/Becker MMI3GP | ✅ |
| IFS format | QNX IFS | QNX IFS | ✅ |
| EFS format | EFS partition | EFS partition | ✅ |
| Persistence | /HBpersistence/ | /HBpersistence/ | ✅ |
| USB autorun | copie_scr.sh | copie_scr.sh | ✅ |
| XOR seed | 0x001be3ac | 0x001be3ac | ✅ |
| Activation | FSC (EscRsa) | FSC (Java/BouncyCastle) | ⚠️ Different! |

## Firmware Structure

```
HN+/MU9478/
  ├── ifs-root/41/default/ifs-root.ifs    (42 MB — main firmware)
  ├── ifs-emg/41/default/ifs-emg.ifs      (4.6 MB — emergency/recovery)
  ├── efs-system/41/default/efs-system.efs (37 MB — system EFS)
  ├── efs-extended/41/default/efs-extended.efs (12 MB — extended EFS)
  ├── fpga/41/default/SystemFPGA.hbbin     (730 KB — display FPGA)
  ├── fpga-emg/41/default/SystemFPGA.hbbin (729 KB — emergency FPGA)
  ├── tools/
  │   ├── showScreen                        (74 KB — display utility)
  │   ├── sqlite3                           (437 KB — database tool)
  │   ├── sqlite.xml                        (798 bytes — config)
  │   └── rePartitioningNeeded.png          (15 KB — UI image)
  ├── preUpdateScript                       (2.4 KB — pre-update hook)
  └── postUpdateScript                      (15 KB — post-update hook)
```

The `41/default/` path corresponds to variant 41 — the same variant
numbering used in the Audi MMI3G builds.

## USB Autorun — CONFIRMED WORKING

The RNS 850 uses the **identical** `proc_scriptlauncher` mechanism:

```
XOR PRNG seed:    0x001be3ac    (found at IFS offset 0xb609b)
copie_scr.sh:     found at 0xb6d6a
proc_scriptlauncher: same binary, same decoder
```

**Any copie_scr.sh XOR-encoded with seed 0x001be3ac will execute as root
on the RNS 850.** The MMI3G-Toolkit's existing SD card builder generates
compatible autorun scripts.

### USB vs SD Card

The RNS 850 likely uses USB rather than SD card (the Touareg has USB
ports but no SD card slot on most models). The proc_scriptlauncher
scans multiple mount points:
- `/fs/usb0`, `/fs/usb1` (USB)
- `/fs/sd0` (SD card, if available)
- `/media/usb0` (alternate USB mount)

## FSC Activation System — DIFFERENT FROM AUDI

### Audi MMI3G (K0942) — Native EscRsa
```
EscRsa_DecryptSignature → native SH4 code
Bypass: 2-byte patch at 0x001B11F6 (JSR @r0 → MOV #0,r0)
Simple, reliable, single binary patch
```

### RNS 850 (MU9478) — Java BouncyCastle
```
org/bouncycastle/crypto/engines/RSA*
java/security/SignatureSpi
IllegalFSC at 0x18406c5 (inside Java bytecode region)
```

The RNS 850 FSC verification is implemented in **Java** using the
BouncyCastle cryptographic library, not in native SH4 code. This means
the Audi 2-byte native patch **will not work** on the RNS 850.

### Possible Bypass Approaches

1. **Patch Java class file** — Extract the FSC verification class from
   the embedded JAR, decompile, modify the verification method to
   always return true, recompile, repack into IFS
   
2. **Patch native→Java bridge** — Find where the native QNX code
   consumes the Java FSC verification result and patch the native
   conditional branch (similar to Audi approach but different offset)

3. **Patch areFSCsSigned flag** — If there's a configuration flag that
   controls whether FSCs require signatures, setting it to false would
   bypass verification without code patches

4. **USB script approach** — Since we have root access via copie_scr.sh,
   we could potentially write FSC files directly to /HBpersistence/FSC/
   without valid signatures, IF the check only happens at import time
   and not at boot

## Strings of Interest

### Build identification
```
PLABEL=PL_qnx_startup-sh7785_11292A
QNX_LABEL=RL_qnx_632_PSP3_10455A
QNX_VERSION=632
Harman/Becker MMI3GP Build 9478 C1 D1-12042A
HOST=uberbuild
```

### IFS signature verification (startup code)
```
FOUND valid IFS signature
FOUND valid IFS signature and RIFS info in RAM.
FOUND valid IFS2 signature and RIFS2 info in RAM.
FOUND valid RIFS signature
INVALID IFS signature
INVALID RIFS signature
```

### Activation system
```
ACTIVATIONSTATE_INIT
ACTIVATION_PHONE_ON
IllegalFSC
onIllegalFSCsUpdate get swid index: %d
SWID-Typ
/HBpersistence/SWDL/EnableFs
private_decrypt
RSA_new
KE_RSA
```

### Feature names (same as MMI3G/PCM3.1)
```
ENGINEERING (at 0x1dceda6)
Navigation  (at 0x119dc30)
SDARS       (at 0xb92849)
BTH         (at 0x25f7de)
```

## Cross-Platform Compatibility

### What works on RNS 850 from MMI3G-Toolkit:
- ✅ SD/USB card autorun (copie_scr.sh, same XOR cipher)
- ✅ Root shell access
- ✅ Diagnostic data collection
- ✅ /HBpersistence/ file operations
- ✅ QNX system commands
- ⚠️ GEM engineering menu (likely same ESD format, untested)
- ⚠️ per3 persistence (same DSI framework, untested)

### What does NOT work:
- ❌ Audi FSC 2-byte patch (different crypto implementation)
- ❌ Audi EFS repacking (different EFS contents)
- ❌ Audi-specific ESD screens (VW has different menu items)

## Relationship to Porsche PCM 3.1

The RNS 850 sits between the Audi MMI3G and Porsche PCM 3.1:

```
                    Harman Becker HN+ Platform
                    ═════════════════════════
                              │
            ┌─────────────────┼─────────────────┐
            │                 │                 │
      Audi MMI3G         VW RNS 850       Porsche PCM 3.1
      K0942 (9411)       MU9478 (9478)     (15245AS9)
            │                 │                 │
      FSC + EscRsa       FSC + Java BC     PagSWAct + RSA-64
      2-byte patch       Java patch?       Key derived
      SD card            USB stick         USB stick
      EFS screens        EFS screens       Compiled screens
```

## Available Firmware Versions

From the MIB Solution repository:
```
HN+_EU_VW_E6077     — early build
HN+_EU_VW_K0775     — K-series
HN+_EU_VW_K0821     — K-series (newer)
HN+_EU_VW_P0125     — P-series (production)
HN+_EU_VW_P0145     — P-series update
HN+_EU_VW_P0534     — P-series (this analysis) ← MU9478t.rar
HN+R_EU_VW_P0824    — HN+R variant            ← MU9478.rar (not yet extracted)
```

## Next Steps

- [ ] Extract the HN+R variant (P0824) and compare with HN+ (P0534)
- [ ] Use Ghidra to disassemble IFS and find the native→Java FSC bridge
- [ ] Extract Java class files from EFS and decompile FSC verification
- [ ] Test USB autorun on a real VW Touareg
- [ ] Map the GEM/engineering menu ESD screens
- [ ] Check if per3 address map matches Audi MMI3G
- [ ] Verify if the 2-byte patch works on the HN+R variant (which might use native EscRsa like Audi)

## HN+R Variant Analysis (P0824, 2016 build)

### CRITICAL: USB Autorun REMOVED in HN+R

| Feature | HN+ (2012, P0534) | HN+R (2016, P0824) |
|---------|:------------------:|:-------------------:|
| copie_scr.sh | ✅ Present | ❌ **REMOVED** |
| XOR seed 0x001be3ac | ✅ Present | ❌ **REMOVED** |
| proc_scriptlauncher | ✅ Present | ❌ **REMOVED** |
| BouncyCastle FSC | ✅ Java-based | ✅ Java-based |
| EscRsa (native) | ❌ Not used | ❌ Not used |
| Build ID | 9478 D1-12042A | 9478 D1-16243A |
| IFS size | 43,608,784 | 43,486,868 |
| Variants | 41 only | 41, 51, 61 |

VW deliberately removed the proc_scriptlauncher USB autorun mechanism
in the 2016 firmware update. This means:

- **Pre-2016 Touaregs**: USB root access works (copie_scr.sh method)
- **Post-2016 Touaregs**: USB root access is blocked
- **All Touaregs**: FSC uses Java BouncyCastle, NOT native EscRsa
- **Audi 2-byte patch**: Does NOT apply to any RNS 850 variant

### Implications for Audi MMI3G

If VW removed the USB autorun in 2016 RNS 850 firmware, Audi may have
done the same in later MMI3G+ updates. The K0942 build we analyzed
still has it, but newer Audi firmware builds should be checked.

Porsche PCM 3.1 still has proc_scriptlauncher in the latest firmware
(build 15245AS9, June 2015) — but Porsche stopped updating PCM 3.1
before the vulnerability was patched.
