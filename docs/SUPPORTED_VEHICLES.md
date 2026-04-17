# Supported Vehicles

## Fully Compatible

### MMI 3G High (HNav)
- Audi A4/S4 (B8) — 2008–2012
- Audi A5/S5/RS5 (B8) — 2008–2012
- Audi A6/S6 (C6) — 2009–2011
- Audi A8/S8 (D3) — 2008–2010
- Audi Q5/SQ5 (8R) — 2009–2012
- Audi Q7 (4L) — 2009–2015

### MMI 3G+ / MMI 3GP (HN+)
- Audi A1 (8X) — 2012–2018 (**variant ID 9436** — smaller/cheaper HU, same 3G+ class)
- Audi A4/S4/RS4 (B8.5) — 2012–2016
- Audi A5/S5/RS5 (B8.5) — 2012–2017
- Audi A6/S6/RS6 (C7) — 2012–2018
- Audi A7/S7/RS7 (C7) — 2012–2018
- Audi A8/S8 (D4) — 2010–2017
- Audi Q5/SQ5 (8R) — 2013–2017
- Audi Q7 (4L) — 2010–2015
- Audi TT/TTS (8J) — late models with 3G+
- Audi Q3 (8U) — 2012–2018

### VW RNS-850
- VW Touareg (7P) — 2011–2018

### Lamborghini Huracán
- Uses HN+ platform (`HN+_US_LB_P0xxx` train name), own 94xx variant.
  Not yet tested — community contributions welcome.

## Variant IDs

The `/etc/pci-3g_XXXX.cfg` file tells you which variant the unit is. Current
known IDs:

| ID   | Platform           | Models | Notes |
|------|--------------------|--------|-------|
| 9303 | MMI 3G Basic       | Various | Entry-level BNav, no HDD navigation |
| 9304 | MMI 3G Basic       | Various | Entry-level BNav, no HDD navigation |
| 9307 | MMI 3G High        | Various | HNav, 8GB HDD navigation |
| 9308 | MMI 3G High        | Various | HNav, 8GB HDD navigation |
| 9406–9411, 9425 | MMI 3G Plus | **A6, A7, A8, Q3** | K0942 train. Do NOT apply to A4/A5/Q5/Q7 |
| 9436 | MMI 3G Plus (A1)   | **A1 8X** | Smaller HU, same 3G+ software class |
| 9476 | MMI 3G Plus (Touareg) | **Touareg** | HN+ Touareg variant (per DrGER2) |
| 9478 | RNS-850 (VW)       | **Touareg 7P** | K0711 train, `_VW_` infix |
| 9498 | MMI 3G Plus        | **A4, A5, Q5, Q7** | K0942_6 train. Do NOT apply to A6/A7/A8/Q3 |

**Important:** HN+ firmware trains are model-specific. The MU version number
(e.g., MU9411 vs MU9498) identifies the target model group, not just a
software version. Applying the wrong train (e.g., flashing K0942_4 onto an
A4) will fail or produce a misconfigured system. The variant field in
`metainfo2.txt` is the authoritative check — the SWDL process verifies
the unit's variant against the manifest before flashing.

Credit: DrGER2 for the variant-to-model mapping correction.

## Not Compatible

- **MIB1 / MIB2 / MIB2.5 / MIB3** — Different ARM/Tegra platform
- **MMI 2G** — Older architecture
- **MIB4 / E3** — Linux-based new generation
- **Any non-Harman Becker head unit**

## Notes

- All MMI3G variants share the same QNX RTOS, copie_scr.sh
  encoding, and GEM screen definition format
- Some CAN bus data addresses may vary between car platforms
- Terminal 30 voltage (battery) and GPS data work on all variants
- The battery meter UI was removed in MMI3GP but the underlying
  data address still functions
