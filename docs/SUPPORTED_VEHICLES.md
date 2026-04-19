# Supported Vehicles

## Platform Family — Harman HN+

All vehicles below share the Harman Becker HN+ platform:
- **CPU**: Renesas SH4 (SH7785)
- **OS**: QNX 6.3.2
- **Autorun**: copie_scr.sh (XOR seed 0x001be3ac)
- **RSA Key**: 1024-bit, e=17 — **shared across ALL brands**

## Fully Compatible

### Audi MMI 3G High (HNav)
- Audi A4/S4 (B8) — 2008–2012
- Audi A5/S5/RS5 (B8) — 2008–2012
- Audi A6/S6 (C6) — 2009–2011
- Audi A8/S8 (D3) — 2008–2010
- Audi Q5/SQ5 (8R) — 2009–2012
- Audi Q7 (4L) — 2009–2015

### Audi MMI 3G+ / MMI 3GP (HN+)
- Audi A1 (8X) — 2012–2018 (variant 9436, smaller HU)
- Audi A4/S4/RS4 (B8.5) — 2012–2016
- Audi A5/S5/RS5 (B8.5) — 2012–2017
- Audi A6/S6/RS6 (C7) — 2012–2018
- Audi A7/S7/RS7 (C7) — 2012–2018
- Audi A8/S8 (D4) — 2010–2017
- Audi Q5/SQ5 (8R) — 2013–2017
- Audi Q7 (4L) — 2010–2015
- Audi TT/TTS (8J) — late models with 3G+
- Audi Q3 (8U) — 2012–2018

**FSC Bypass**: Native EscRsa — 2-byte SH4 assembly patch (`fsc_patcher.py`)

### VW RNS 850
- VW Touareg (7P) — 2011–2018
- VW Phaeton (3D) — 2011–2016

**FSC Bypass**: Java BouncyCastle — 1-byte bytecode patch (`rns850_fsc_patcher.py`)

Note: HN+ (pre-2016) supports USB autorun via copie_scr.sh.
HN+R (2016+) has USB autorun **REMOVED** — requires alternative access.

### Porsche PCM 3.1 (via PCM-Forge)
- Porsche 911 (991 / 991.2) — 2012–2019
- Porsche Boxster/Cayman (981) — 2012–2016
- Porsche Cayenne (958) — 2011–2018
- Porsche Panamera (970) — 2010–2016
- Porsche Macan (95B) — 2014–2018

**FSC Bypass**: PagSWAct — RSA-64 private key derived (see PCM-Forge repo)

79 bootscreens mapped including unreleased variants:
Macan hybrid (073), Macan S e-hybrid (074), 911 R (088), 911 Club Sport (087)

### Lamborghini Huracán
- Uses HN+ platform (`HN+_US_LB_P0xxx` train name)
- Own 94xx variant ID — not yet tested

## Variant IDs

| ID   | Platform           | Models | Notes |
|------|--------------------|--------|-------|
| 9303 | MMI 3G Basic       | Various | Entry-level BNav |
| 9307–9308 | MMI 3G High  | Various | HNav, 8GB HDD |
| 9406–9411 | MMI 3G Plus  | **A6, A7, A8, Q3** | K0942 train |
| 9436 | MMI 3G Plus (A1)   | **A1 8X** | Smaller HU |
| 9476 | MMI 3G Plus        | **Touareg** | HN+ variant |
| 9478 | RNS-850            | **Touareg 7P** | 3 HW variants (41/51/61) |
| 9498 | MMI 3G Plus        | **A4, A5, Q5, Q7** | K0942_6 train |

## FSC Bypass Cross-Reference

| Brand | Method | Patch | Tool | Key |
|-------|--------|-------|------|-----|
| Audi | EscRsa (native SH4) | 2 bytes | `fsc_patcher.py` | RSA-1024, e=17 |
| VW | BouncyCastle (Java) | **1 byte** | `rns850_fsc_patcher.py` | RSA-1024, e=17 (SAME!) |
| Porsche | PagSWAct | Key derived | PCM-Forge | RSA-64 (different) |

## Not Compatible

- **MIB / MIB2 / MIB3** — ARM platform (2015+)
- **MHIG** — ARM + QNX/Linux, no copie_scr.sh
- **MMI 2G** — Older architecture
- **RCD 330 / Desay SV** — NXP i.MX, Linux
- **Any non-Harman Becker head unit**
