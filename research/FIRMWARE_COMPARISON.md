# Firmware Version Comparison

## Versions Analyzed

| Build | Part # | Release | Region | Variant |
|-------|--------|---------|--------|---------|
| MU9307 | 8R0906961CP | HNav_US_K0133_3 | USA | HNav base |
| **MU9411** | 8R0906961FB | HN+R_EU_K0942_4 | EU | AU_EU |
| **MU9498** | 8R0906961FE | HN+_US_K0942_6 | USA | AU3G_Nav_NAR |

## Binary Comparison: MU9411 vs MU9498

| File | Size | Bytes Changed | Notes |
|------|------|:---:|-------|
| MMI3GApplication | 10,702,848 | **4** | ELF header only — code identical |
| NavCore | 7,086,080 | **4** | ELF header only — code identical |
| MMI3GMedia | 8,298,496 | **2** | Version stamp |
| mmi3g-srv-starter.cfg | 107,016 | **2** | Version stamp |
| pidin | 59,686 | **0** | Byte-for-byte identical |
| ksh | 179,320 | **0** | Byte-for-byte identical |
| lsd.jxe | ~28MB | ~26M | Java recompilation |

### lsd.jxe Details
- Same 342 entries (no added/removed files)
- `sysconst.properties`: **IDENTICAL** (88 EOL flags, same values)
- `rom.classes`: 38KB smaller (minor class optimizations)
- `variant.properties`: Regional config difference only

### Variant Configuration
```
MU9411: EOLFLAG_HU_VARIANT=5  (EU)    variant=AU_EU
MU9498: EOLFLAG_HU_VARIANT=20 (AU3G)  variant=AU3G_Nav_NAR
```

HU_VARIANT=20 is undocumented. Known values:
5=EU, 6=NAR, 7=JP, 8=CN, 9=KR, 15=VW EU, 16=Bentley, 18=RSE Asia, **20=AU3G**

MU9498 adds `EOLFLAG_MMI_VARIANT=0` (not present in MU9411).

## IOC Firmware (from MU9498 package)

- **V850app.bin**: 589,760 bytes — Renesas V850 application firmware
- **V850bolo.bin**: 65,536 bytes — V850 bootloader
- Version string: `AUDI-3G-9411-C0-Version:-T01`
- Bus interfaces: LIN (3 instances), MOST, IPC, CAN (implied)
- Power management, diagnostics

## Conclusion

The entire K0942 firmware family shares identical native SH4 code.
Regional variants differ only in lsd.jxe configuration
(variant.properties, bundles.properties). The FSC signature bypass
patch at offset 0x001B11F6 is universal across all K0942 builds.
