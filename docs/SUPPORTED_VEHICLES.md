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

### VW RNS-850
- VW Touareg (7P) — 2011–2018

## Variant IDs

The `/etc/pci-3g_XXXX.cfg` file tells you which variant the unit is. Current
known IDs:

| ID   | Platform           | Notes |
|------|--------------------|-------|
| 9304 | MMI 3G Basic       | Entry-level HU, no MMI High / Plus features |
| 9308 | MMI 3G High        | Hard-drive navigation, 8GB HDD on early units |
| 9411 | MMI 3G Plus        | Main A4/A5/A6/A7/A8/Q5/Q7 3G+ hardware |
| 9436 | MMI 3G Plus (A1)   | Audi A1 8X — same software class, smaller physical unit |
| 9478 | RNS-850 (VW)       | VW Touareg 7P — `_VW_` train name infix confirms |

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
