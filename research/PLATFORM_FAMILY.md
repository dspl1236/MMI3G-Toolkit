# Harman HN+ Platform Family — Cross-Platform Comparison

> Three head units, one platform, three activation strategies
> Updated: April 19, 2026

## The Family

All three head units are built on Harman Becker's HN+ (Harman Navigation Plus)
platform. They share the same CPU, OS, build system, and USB autorun mechanism.

| | Audi MMI3G+ | VW RNS 850 | Porsche PCM 3.1 |
|---|:---:|:---:|:---:|
| **Vehicle** | A4/A5/A6/A7/A8/Q5/Q7 | Touareg 7P | 911/Cayenne/Panamera/Macan/Boxster |
| **Years** | 2010–2016 | 2010–2016 | 2010–2016 |
| **CPU** | SH4A (SH7785) @ 792MHz | SH4A (SH7785) @ 792MHz | SH4A (SH7785) @ 792MHz |
| **RAM** | 476MB | 476MB | 476MB |
| **OS** | QNX 6.3.2 | QNX 6.3.2 | QNX 6.3.2 |
| **Display** | 800×480 | 800×480 | 800×480 |
| **Storage** | HDD + Flash | HDD + Flash | HDD + Flash |
| **Media** | SD card (x2) | USB | USB |
| **Build ID** | MMI3GP K0942 | MMI3GP MU9478 | PCM3.1 15245AS9 |

## Autorun Mechanism (Identical)

All three use `proc_scriptlauncher` with the same XOR PRNG cipher:

```
Seed:     0x001be3ac
Trigger:  copie_scr.sh on removable media
Decoder:  proc_scriptlauncher (identical binary)
Access:   Runs as root under /bin/ksh
```

A single XOR-encoded `copie_scr.sh` works on all three platforms.

## Activation Systems (Different!)

### Audi MMI3G — FSC + Native EscRsa
```
Format:   FSC (Feature Service Code) files
Crypto:   RSA-1024 + SHA-1 (native EscRsa library)
Bypass:   2-byte SH4 patch (JSR @r0 → MOV #0,r0)
Location: MMI3GApplication offset 0x001B11F6
Status:   ✅ SOLVED — single binary patch
```

### VW RNS 850 — FSC + Java BouncyCastle
```
Format:   FSC (same framework as Audi)
Crypto:   RSA via Java BouncyCastle library
Bypass:   Patch Java class OR native→Java bridge
Location: Inside Java layer (IFS offset ~0x184xxxx)
Status:   🔬 RESEARCH — Java layer needs analysis
```

### Porsche PCM 3.1 — PagSWAct + RSA-64
```
Format:   PagSWAct.002 (28-byte binary records)
Crypto:   RSA-64 (trivially factorable modulus)
Bypass:   Key derived — generate codes for any VIN
Keys:     N=0x69f39c927ef94985, E=0x4c1c5eeaf397c0b3
Status:   ✅ SOLVED — generate activation codes directly
Tool:     https://github.com/dspl1236/PCM-Forge
```

## Engineering Menu

| | Audi GEM | VW GEM | Porsche Engineering |
|---|---|---|---|
| Format | Plain-text .esd files | Plain-text .esd files (likely) | Compiled into binary |
| Extensible? | YES — drop .esd, reboot | YES (likely) | NO |
| Controllers | 36 PresCtrl classes | Similar | ~18 sections |
| Access | Long-press SETUP | Unknown | Via Engineering activation |

## Key Paths

| Path | Purpose | All Three? |
|------|---------|:----------:|
| `/HBpersistence/` | Writable flash storage | ✅ |
| `/HBpersistence/FSC/` | FSC activation files | Audi + VW |
| `/HBpersistence/PagSWAct.002` | Porsche activation | Porsche only |
| `/mnt/efs-system/` | EFS system partition | Audi + VW |
| `/mnt/share/` | HDD shared data | ✅ |
| `/mnt/data/` | HDD data partition | ✅ |
| `/mnt/ifs1/` | IFS1 application code | ✅ |

## Tools Compatibility

| Tool | Audi | VW RNS 850 | Porsche |
|------|:----:|:----------:|:-------:|
| MMI3G-Toolkit SD builder | ✅ | ⚠️ USB variant needed | ❌ |
| PCM-Forge activation codes | ❌ | ❌ | ✅ |
| copie_scr.sh autorun | ✅ | ✅ | ✅ |
| FSC 2-byte patch | ✅ | ❌ (Java layer) | N/A |
| GEM ESD screens | ✅ | ⚠️ Untested | N/A |
| per3 persistence reader | ✅ | ⚠️ Untested | N/A |
| Boot screen swap | N/A | N/A | ✅ (SubID system) |

## Repository Map

```
MMI3G-Toolkit (this repo)
  ├── Audi MMI3G+ activation, GEM, diagnostics
  ├── VW RNS 850 research (NEW)
  └── Shared platform documentation

PCM-Forge (github.com/dspl1236/PCM-Forge)
  ├── Porsche PCM 3.1 activation codes
  ├── Boot screen system
  ├── Firmware variant analysis
  └── USB stick builder (web + desktop)
```

## MHIG (MIB High G) — Next Generation (Out of Scope)

The MHIG represents the architectural break from the HN+ platform:

| Property | HN+ (MMI3G/RNS850/PCM3.1) | MHIG (MIB High G) |
|----------|:--------------------------:|:------------------:|
| CPU | SH4 (SH7785) | ARM |
| OS | QNX 6.3.2 only | QNX + Linux dual-OS |
| App layer | QNX native | 716MB Linux filesystem |
| IFS format | Standard IFS | CIFS (Compressed IFS) |
| USB autorun | copie_scr.sh + XOR | **REMOVED** |
| FSC | Native/Java RSA | DSI-based structured API |
| Firmware ID | MMX1 (MMX gen 1) | — |

Analyzed firmware: `MHIG_US_AU_K2019 MU0406 8V0906961AF` (Audi A3, 2014)

The copie_scr.sh autorun mechanism does not exist on MHIG — this is
where the HN+ platform family ends and a new generation begins.
The MMI3G-Toolkit is not applicable to MHIG or later platforms.
