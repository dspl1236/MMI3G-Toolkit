# SWDL — MMI3G Software Download (Firmware Update) System

## Overview

SWDL (SoftWare DownLoad) is Harman-Becker's firmware update framework
for the HN+ platform (MMI3G+, RNS-850, PCM3.1). It handles everything
from verifying update media to flashing individual components across
multiple ECUs on the MOST bus.

## Update Media

Updates can come from:
- **DVD** (factory method) — `/fs/cd0`
- **SD card slot 1** — `/fs/sd0`
- **SD card slot 2** — `/fs/sd1`
- **USB** — `/fs/usb0`

The source is determined at runtime and stored in
`/HBpersistence/SWDL/update.txt`.

## metainfo2.txt — The Update Manifest

Every update package has a `metainfo2.txt` at its root. This is the
master manifest that describes every component to be updated:

```ini
[common]
release = "HN+R_US_AU_K0942_3"    # Train name
vendor = "HBAS"                     # Harman-Becker Automotive Systems
variant = "9411"                    # Target hardware variant
region = "USA"                      # Market region
```

### Component Sections

Each ECU/module gets its own section with versioning and checksums:

```ini
[MU9498]                            # Main Unit, variant 9498
VendorInfo="HarmanBecker"
DeviceDescription="MainUnit (9498, HW61)"
scriptPre = "./MU9498/preUpdateScript"     # Runs BEFORE flash
scriptPost = "./MU9498/postUpdateScript"   # Runs AFTER flash

[MU9498\ifs-root\41\default\Application]   # IFS for HW sample 41
FileName = "ifs-root.ifs"
FileSize = "43696842"
CheckSum = "772e7fa6"               # CRC32 of full file
CheckSum1 = "d8a11a19"              # CRC32 of chunk 1 (512KB)
CheckSum2..N = "..."                # Per-chunk checksums
Version = "2145"
InstalledComponent = "gemmi"        # Tracks sub-components
InstalledVersion = "2.0.0"
AppName = "ifs-root image"
FlashStartAddress = "0x00680000"    # Physical flash address
```

### Hardware Sample Numbers

Each component supports multiple hardware revisions:

| Sample | Description |
|--------|------------|
| 21 | Early hardware (Gen 1) |
| 31 | Revised hardware (Gen 2) |
| 41 | Current production (most common) |
| 51 | Updated production |
| 61 | Latest revision (K0942_6 only) |

Different hardware samples may get different firmware files
(different checksums) or link to the same file.

### File Deployment Types

**Flash images** (written to NOR flash):
```ini
FlashStartAddress = "0x00680000"    # Direct flash address
```
- `ipl` — Initial Program Loader (bootloader)
- `fpga` / `fpga-emg` — FPGA configuration
- `ifs-root` / `ifs-emg` — QNX Image File System (main firmware / emergency)
- `efs-system` / `efs-persist` / `efs-extended` — Flash file systems

**HDD deployments** (copied to hard drive partitions):
```ini
Destination = "/mnt/nav/gemmi"
DeleteDestinationDirBeforeCopy = "true"
IsDestinationInFFS = "false"        # false = HDD, true = flash FS
```
- `GEMMI` — Google Earth binaries → `/mnt/nav/gemmi/`
- `CombiStyles` — Instrument cluster map styles → `/mnt/nav/combi/styles/`
- `MapStyles` — Navigation map styles → `/mnt/nav/map/styles/`
- `sss` — Speech recognition/TTS data → `/mnt/sss/`
- `TMCConfig` — Traffic message channel config → `/mnt/nav/tmc/`

**ECU firmware** (flashed via MOST bus to peripheral controllers):
- `AH6` — Phone module (Cinterion AH6A)
- `ARU9438/9469/9471` — Radio/tuner units
- `Telit` — Cellular modem firmware
- `DVD` — DVD drive firmware
- `DU9466/DUA130` — Display units
- `KBD_FB8` — Keyboard/control panel
- `MuIOC` — Main unit I/O controller (V850 MCU)
- `MuINIC` — MOST network interface controller
- `MuGPS` — GPS receiver firmware
- `TVHybrid` — TV tuner module
- `AMPLCPKO` / `AMP_LC_P` — Audio amplifiers (LEAR)
- `BO_Q7` / `BoseG3_Q7` — Premium sound amplifiers
- `IDC_UDF` / `IDC_APN` — CD changer / Alpine modules

## Update Flow

```
1. Insert update media (DVD/SD/USB)
2. SWDL reads metainfo2.txt
3. Determines source path and release info
4. For each [Component]:
   a. Check current version vs update version
   b. If newer: run preUpdateScript (if exists)
   c. Flash/copy the component files
   d. Verify checksums (per-chunk CRC32)
   e. Run postUpdateScript (if exists)
5. Store update state in /HBpersistence/SWDL/
6. Reboot
```

### Pre/Post Update Scripts

These are ksh scripts that run before and after each component update:

**preUpdateScript** (runs before flash):
- Deletes obsolete files (old JXE, old FSC codes)
- Handles version migration (BT device list, SSP support)
- Checks compatibility

**postUpdateScript** (runs after flash):
- Creates `usedhcp` flag file
- Uses `sqlite3` to clean up HMI database (DataPST.db)
- Shows repartitioning status via `showScreen`
- Handles Bluetooth migration
- Makes scripts executable

## GEMMI as SWDL Component

```ini
[GEMMI]
VendorInfo="HarmanBecker"
DeviceDescription="GoogleEarthMMI"

[GEMMI\nav\0\default\Dir]
Version = "8025"
Source = ""
FileSize = "26672558"                        # 26.7MB
Destination = "/mnt/nav/gemmi"               # NAV HDD partition
DeleteDestinationDirBeforeCopy = "true"       # Clean install
IsDestinationInFFS = "false"                  # HDD, not flash
Executables = "/gemmi_final;/mapStylesWrite;/run_gemmi.sh;/pg.sh;
               /debug_gemmi.sh;/target_install.sh"
UseForUnit = "MU and RSU"                    # Main unit + rear seat
```

This confirms:
- GEMMI deploys to `/mnt/nav/gemmi/` via SWDL
- The entire directory is wiped and replaced on update
- Multiple executables are marked for chmod +x
- Works on both main unit (MU) and rear seat entertainment (RSU)

## Flash Memory Map (MU9498)

```
Address       Image              Size
0x00000000    ipl                 63KB
0x00040000    fpga               746KB
0x00100000    fpga-emg           746KB
0x001C0000    ifs-emg            4.9MB
0x00680000    ifs-root          43.7MB    ← Main firmware
0x03100000    efs-extended      12.0MB
0x03D00000    efs-system        38.8MB    ← Writable config/apps
0x06200000    efs-persist       30.4MB    ← Persistence data
```

Total flash: ~130MB mapped

## Variant Compatibility

The variant ID in metainfo2.txt determines which hardware the update
targets. Known variants:

| Variant | Platform | Notes |
|---------|----------|-------|
| 9304 | MMI 3G Basic | Older, no nav |
| 9308 | MMI 3G High | With nav |
| 9411 | MMI 3G+ (Audi) | Andrew's car |
| 9436 | MMI 3G+ (A1 8X) | DrGER2 |
| 9478 | RNS-850 (VW) | Daredoole's Touareg |
| 9498 | MMI 3G+ (newer HW) | K0942_6 firmware |

**Cross-variant compatibility:** Component-level updates (GEMMI,
MapStyles, speech) deploy to the HDD and are hardware-independent.
IFS/EFS images are hardware-specific and must match the variant.

## Security

- Per-chunk CRC32 verification during flash
- Pre/post scripts have CRC validation in metainfo2.txt
- No code signing on update scripts (ksh scripts run as root)
- `copie_scr.sh` autorun is separate from SWDL — both coexist

## References

- `8R0906961ES/metainfo2.txt` — K0942_3 (Andrew's firmware)
- `8R0906961FE/metainfo2.txt` — K0942_6 (newer Audi firmware)
- `DVDRNS850V711US/metainfo2.txt` — K0711 (RNS-850 NAR)
- `research/FIRMWARE_UPDATE_FORMAT.md` — Additional format notes
- `research/IFS_FORMAT.md` — IFS decompression details
