# MMI3G-Toolkit

**Modular SD card toolkit for Audi/VW MMI 3G, MMI 3G+, and RNS-850 infotainment systems.**

Pick the tools you want, build an SD card, insert it, done.

**[Launch Web App →](https://dspl1236.github.io/MMI3G-Toolkit/app/)** — Module selector, splash screen formatter, and build instructions right in your browser.

---

## What Is This?

MMI3G-Toolkit is a collection of 20 modules that extend your MMI3G head unit through the built-in SD card script execution mechanism. It includes a Python builder and a web app that assemble your selected modules into a ready-to-use SD card — handling the `copie_scr.sh` encoding automatically.

**No VCDS required for most modules. No permanent modifications. No soldering.**

The toolkit runs on the existing QNX operating system inside your head unit. Modules install custom screens into the Green Engineering Menu (GEM) and helper scripts into flash storage. Everything can be cleanly uninstalled.

## Google Earth Restoration (NEW)

Reverse engineering of the GEMMI protocol has revealed that Google's tile server (`kh.google.com/dbRoot.v5`) is still alive (HTTP 200) and the authentication endpoint (`/geauth`) has been removed (HTTP 404). The `google-earth` module provides a complete restoration path:

1. **`ge_probe.sh`** — Safe diagnostic: checks GEMMI binaries, network, EOL flags, variant
2. **`ge_enable.sh`** — Adds `disableAuthKey` to `drivers.ini` (may be all that's needed)
3. **`ge_deploy.sh`** — Fallback: deploys GEMMI binaries from SD card to `/mnt/nav/gemmi/`
4. **`ge_restore.sh`** — Clean revert of all changes

The original `google-earth` module still pulls its GEMMI payload from [GitHub Release assets](https://github.com/dspl1236/MMI3G-Toolkit/releases/tag/v1.0-gemmi). The `google-earth-p0824-deploy` module bundles the EU VW P0824 donor payload directly so users do not need to source those files separately.

See [research/EOL_FLAGS_AND_GOOGLE_EARTH.md](research/EOL_FLAGS_AND_GOOGLE_EARTH.md) for the full protocol analysis including per-variant RANGE flags, self-provisioning theory, and server endpoint map.

## Building Your Own Apps

As of April 2026 the toolkit ships tools that extract the complete MMI3G+ firmware: the `efs-system` flash filesystem, the QNX `ifs-root` boot image (LZO-compressed), and individual QNX-deflate-wrapped binaries. Every SH4 ELF on your head unit — including `MMI3GApplication` itself — is now available for analysis and, with the right toolchain, for extension.

See **[docs/CUSTOM_APPS.md](docs/CUSTOM_APPS.md)** for a developer guide covering the five mechanisms for running your own code: SD scripts, flash-persistent scripts, GEM screens, OSGi bundles, and native SH4 binaries. See **[research/HMI_ARCHITECTURE.md](research/HMI_ARCHITECTURE.md)** for the full 101-process boot graph and hook points.

## Modifying Firmware

The complete custom firmware pipeline is built and verified:

```
inflate_ifs.py  →  patch_ifs.py / build_ifs.py  →  repack_ifs.py  →  mu_crc_patcher.py
  decompress          modify files                   recompress         fix CRCs
```

Or use the one-command wrapper:
```bash
python3 tools/mu_repack.py --mu-dir ./MU9411 --variant 41 \
    --replace mnt/ifs-root/usr/bin/start_network.sh=./modified.sh \
    --output ./patched/
```

All integrity checks are CRC32 (bypassable with `skipCrc = true`). The LZO recompression produces **byte-identical output** to Harman's own `lzo1x_999` compressor.

**Driver injection without reflash:** QNX loads `.so` drivers dynamically. Custom or patched drivers can be loaded from writable storage (`/mnt/efs-system/`, `/mnt/persistence/`, or SD card) via `LD_LIBRARY_PATH` or `mount -T io-pkt` — no IFS reflash required. Harman already planned for this (commented-out `LD_LIBRARY_PATH` line in `dhcp-up`). See [research/CUSTOM_DRIVER_INJECTION.md](research/CUSTOM_DRIVER_INJECTION.md).

**FSC signature bypass:** A 2-byte patch in MMI3GApplication (`0x0B40` → `0x00E0` at file offset `0x1B11F6`) replaces the `JSR @r0` call to `EscRsa_DecryptSignature` with `MOV #0, r0`, forcing the signature check to always return success. See [research/FSC_SIGNATURE_BYPASS.md](research/FSC_SIGNATURE_BYPASS.md).

**Feature unlocking:** The `eol_modifier.py` tool modifies EOL flags in `lsd.jxe` to enable hidden features like Google Earth, online services, offroad navigation, and instrument cluster tabs.

**Telnet access:** The firmware already includes `inetd`, `telnetd`, `io-pkt-v4-hc`, and `devn-asix.so` (USB-Ethernet driver). Adding 4 lines to `start_network.sh` gives a root shell at `172.16.42.1` via a D-Link DUB-E100 adapter.

See **[research/ENGINEERING_ACCESS.md](research/ENGINEERING_ACCESS.md)** for shell access details and **[research/FIRMWARE_UPDATE_FORMAT.md](research/FIRMWARE_UPDATE_FORMAT.md)** for the metainfo2.txt specification.

## Supported Vehicles

Any Audi or VW with a Harman Becker MMI 3G family head unit:

| Platform | Years | Vehicles |
|----------|-------|----------|
| **MMI 3G High** | 2008–2012 | A4/A5/A6/A8/Q5/Q7 (B8, C6, D3) |
| **MMI 3G+** | 2012–2018 | A4/A5/A6/A7/A8/Q5/Q7 (B8.5, C7, D4) |
| **MMI 3G+ (A1)** | 2012–2018 | A1 8X (variant ID 9436, smaller HU but same 3G+ class) |
| **RNS-850** | 2011–2018 | VW Touareg (7P) |

See [docs/SUPPORTED_VEHICLES.md](docs/SUPPORTED_VEHICLES.md) for full details.

## Available Modules

| Module | Status | Description |
|--------|--------|-------------|
| **system-info** | ✅ Tested | One-shot system reporter — full MMI state dump to SD |
| **gem-activator** ⚠️ | ✅ Tested | GEM infrastructure setup. **Setting the enable bit requires VCDS/ODIS** — adaptation 5F channel 6 = 1 |
| **gauges-dashboard** | ✅ Tested | Live telemetry — battery voltage, GPS, system info, data logging |
| **dtc-checker** | ✅ Tested | Read and display diagnostic trouble codes from the GEM |
| **gemmi-dump** | ✅ Tested | Extract Google Earth (GEMMI) binaries to SD for analysis |
| **password-finder** | ✅ Tested | Dump stored Wi-Fi/hotspot passwords, Bluetooth keys, Audi Connect credentials |
| **variant-dump** | ✅ Tested | Comprehensive per3 adaptation dump — 90+ values to SD |
| **map-parser** | ✅ Tested | Extract nav database descriptor, FSC activation state, map metadata |
| **nav-unblocker** | ✅ Ready | Bypass nav database activation (Keldo/DrGER2 method) |
| **lte-setup** ⚠️ | ✅ Ready | Provision LTE mobile data via USB Ethernet (**requires hardware**) |
| **can-scanner** | ✅ Ready | CAN bus address scanner — discover RPM, boost, coolant, speed data |
| **jvm-extract** | ✅ Ready | Extract J9 JVM and UI framework for reverse engineering |
| **game-loader** | ✅ Ready | Java game launcher — run games on the MMI's J9 JVM |
| **splash-screen** | ✅ Ready | Custom boot splash screen with image formatter app |
| **persistence-dump** | ✅ Ready | Dump persistence data and configuration |
| **dns-refresh-probe** | 🧪 Alpha | One-shot route/DNS diagnostic that rewrites `/etc/resolv.conf` to the SD override or gateway and logs before/after checks |
| **google-earth** | 🧪 Alpha | Google Earth restoration — probe, enable, deploy, restore. [GEMMI binaries](https://github.com/dspl1236/MMI3G-Toolkit/releases/tag/v1.0-gemmi) auto-included from GitHub Release |
| **google-earth-gemmi-wrappers** | 🧪 Alpha | Install legacy `/scripts/GEMMI/*.sh` controls expected by the OEM Google Earth screen |
| **google-earth-p0824-deploy** | 🧪 Alpha | Deploy bundled EU VW `P0824` GEMMI donor payload to `/mnt/nav/gemmi` with backup |
| **google-earth-p0824-restore** | 🧪 Alpha | Restore `/mnt/nav/gemmi` to the pre-donor state saved by the P0824 deploy card |
| **diag-tool** ⚠️ | 🧪 Alpha | UDS diagnostic scanner (**needs VAG-COM cable for live mode**) |
| **long-coding** | 🧪 Alpha | Live display of current adaptation values via GEM screens |
| **per3-reader** ⚠️ | 🧪 Alpha | OSGi DSI persistence bridge. See [research/PER3_READER.md](research/PER3_READER.md) |
| **per3-writer** | 📐 Design | Persistence write capability (planned) |

> **⚠️ = external tool required.** Every other module is pure software — SD card in, job done.

## One-Time Prerequisite: Enable GEM with VCDS

Before any GEM-screen module does anything visible, the MMI's GEM enable bit must be set. This is a **one-time** operation performed with a diagnostic tool — not from an SD card.

| Tool | Path |
|------|------|
| VCDS / VCP | Address `5F` (Information Electr.) → Adaptation (10) → Channel `6` → Value `1` → Save |
| ODIS E17 | Address `5F` → Adaptation → Channel `6` → Value `1` |

Reboot the MMI after saving (hold MENU + rotary knob + upper-right soft key for ~3 seconds). Then hold **CAR + BACK** (MMI 3G+) or **CAR + SETUP** (3G High) for ~5 seconds to open the GEM.

**Why can't an SD script do this?** The adaptation value lives in module 5F's persistent memory and is only writable over UDS (the OBD diagnostic protocol). The MMI's QNX system does not ship a UDS client binary, so there is no way for a shell script running on the head unit to set the flag. The `gem-activator` module in this toolkit only prepares the filesystem — the enable bit itself must be set with VCDS or ODIS.

## Hardware Requirements

Most modules run entirely on the MMI itself and need nothing beyond a FAT32 SD card. Two modules are different:

### lte-setup (to replace the defunct 3G modem)

After the 3G cellular network shutdown (US 2022, EU ongoing), the MMI3G+'s built-in modem is dead. This module reroutes the MMI's network stack through a USB Ethernet adapter to an external LTE router. You'll need:

| Part | Specific models | Notes |
|------|-----------------|-------|
| **USB Ethernet adapter** | D-Link DUB-E100 rev A4/B1, or Gembird NIC-U1 | Must use the **ASIX AX88772/A/B** chipset — the AX88772D is NOT supported by the QNX driver |
| **AMI-to-USB Type A cable** | Generic AMI/MDI adapter | The MMI has an AMI connector, not a standard USB port |
| **LTE router** | TP-Link TL-MR3020, Digi WR11 XT, or similar | Any router that serves DHCP on the 192.168.0.x subnet |
| **LTE SIM** | Any data-only plan | 1–2 GB/month is usually plenty |
| **DC-DC power** | 12V → 5V converter | For powering the router from the fuse panel |

**Platform compatibility:** MMI 3G+ and RNS-850 only. **MMI 3G High does NOT have the ASIX driver** — don't waste money on hardware for a 3G High unit.

The module is based on [DrGER2/MMI3GP-LAN-Setup](https://github.com/DrGER2/MMI3GP-LAN-Setup). Total parts cost is typically $100–150. Once configured, you'll get Google Earth overlay, online POI, weather, and other Audi Connect services back via LTE.

## Quick Start

### Requirements
- Python 3.6+
- A 32GB SDHC card (not SDXC) formatted as FAT32
- An Audi/VW with MMI 3G, 3G+, or RNS-850
- Green Engineering Menu enabled (via VCDS: address 5F, adaptation channel 6 = 1)

### Build an SD Card

```bash
# Clone the repo
git clone https://github.com/dspl1236/MMI3G-Toolkit.git
cd MMI3G-Toolkit

# List available modules
python builder/build_sd.py --list

# Build with the gauges dashboard
python builder/build_sd.py -m gauges-dashboard -o ./sdcard

# Build with everything that's ready
python builder/build_sd.py --all -o ./sdcard

# Build directly to your SD card drive (Windows)
python builder/build_sd.py --all -o F:\
```

Or use the **[web app](https://dspl1236.github.io/MMI3G-Toolkit/app/)** — no Python required.

### Install to Your Car

1. Copy the contents of `./sdcard/` to your FAT32 SD card root
2. Start your car and wait for MMI to fully boot (3+ minutes — verify NAV, MEDIA, PHONE all work)
3. Insert the SD card into slot 1 or 2
4. Wait 30–60 seconds (the script runs silently — status PNGs display on screen if supported)
5. Remove the SD card
6. Open the Green Engineering Menu (hold **CAR + BACK** on C7, or **CAR + SETUP** on older models)
7. Your new screens appear in the GEM menu

### Uninstall

```bash
# Build an uninstall SD card
python builder/build_sd.py --uninstall -o ./sdcard
```
Or manually delete the `.esd` files from `/mnt/efs-system/engdefs/` using any SD card script.

## How It Works

All MMI3G family systems include a background process (`proc_scriptlauncher`) that monitors SD card insertion and executes an XOR-encoded script called `copie_scr.sh`. This toolkit:

1. **Encodes** the launcher script automatically (no external tools needed)
2. **Generates** a combined `run.sh` that installs your selected modules
3. **Copies** GEM screen definitions (`.esd` files) to MMI flash storage
4. **Installs** helper scripts for data logging and diagnostics
5. **Logs** everything to the SD card for troubleshooting

The GEM screens use the MMI's built-in Java VM to display live vehicle data through key-value polling. Scripts execute as root on the QNX RTOS with full filesystem access.

## Project Structure

```
MMI3G-Toolkit/
├── builder/
│   ├── build_sd.py              # SD card assembler
│   ├── encoder.py               # copie_scr.sh XOR encoder
│   └── generate_manifest.py     # Web app manifest generator
├── core/
│   ├── copie_scr_plain.sh       # Launcher template (auto-encoded)
│   ├── platform.sh              # QNX shims, variant detection, logstamp helpers
│   └── uninstall.sh             # Universal uninstaller
├── modules/                     # 20 modules (12 ready, 4 alpha, 1 design)
│   ├── system-info/             # One-shot system state dump to SD
│   ├── gem-activator/           # engdefs/ setup (enable bit still needs VCDS)
│   ├── gauges-dashboard/        # Live telemetry — voltage, GPS, data logging
│   ├── dtc-checker/             # Read diagnostic trouble codes
│   ├── gemmi-dump/              # Extract GEMMI/Google Earth binaries
│   ├── google-earth/            # Google Earth restoration (probe/enable/deploy/restore)
│   ├── password-finder/         # Dump stored Wi-Fi/BT/Audi Connect credentials
│   ├── variant-dump/            # Per3 adaptation dump (90+ values)
│   ├── map-parser/              # Nav database + FSC state extractor
│   ├── persistence-dump/        # Persistence data dump
│   ├── nav-unblocker/           # Nav database activation bypass
│   ├── lte-setup/               # LTE mobile data provisioning (3G+)
│   ├── can-scanner/             # CAN bus address discovery tool
│   ├── jvm-extract/             # Extract J9 JVM + UI framework
│   ├── game-loader/             # Java game launcher for MMI
│   ├── splash-screen/           # Custom boot splash screen
│   ├── diag-tool/               # UDS diagnostic scanner (alpha)
│   ├── long-coding/             # Live adaptation values display (GEM)
│   ├── per3-reader/             # OSGi DSI persistence bridge (alpha)
│   └── per3-writer/             # Persistence write capability (design)
├── research/                    # 31 research documents (9,217 lines)
│   ├── ENGINEERING_ACCESS.md          # 36 GEM controllers, 529 strings, full DSI key catalog
│   ├── ESD_SCREEN_FORMAT.md           # GEM screen definition spec (7 widget types, 173 screens)
│   ├── FSC_SIGNATURE_BYPASS.md        # 2-byte patch bypasses all FSC validation
│   ├── FIRMWARE_UPDATE_FORMAT.md      # SWDL manifest, CRC32, skipCrc bypass
│   ├── SWDL_UPDATE_SYSTEM.md          # Complete firmware update system documentation
│   ├── CUSTOM_DRIVER_INJECTION.md     # Load drivers without IFS reflash (3 methods)
│   ├── EOL_FLAGS_AND_GOOGLE_EARTH.md  # Google Earth protocol, server status, self-provisioning
│   ├── RNS850_ANALYSIS.md             # RNS-850 NAR IFS comparison, GEMMI differences
│   ├── DATA_CONNECTIVITY_OPTIONS.md   # USB ethernet, LTE, WiFi, driver compatibility
│   ├── ARCHITECTURE.md                # Decompiled Java UI framework (152 classes)
│   ├── DSI_ARCHITECTURE.md            # DSI IPC class map (Proxy/Stub/Event pattern)
│   ├── HMI_ARCHITECTURE.md            # Boot sequence, 101-process graph, hook points
│   ├── IFS_FORMAT.md                  # QNX IFS format + Harman LZO quirk
│   ├── F3S_FORMAT.md                  # MMI3G EFS on-disk format notes
│   ├── PER3_ADDRESS_MAP.md            # CAN/vehicle data address map
│   ├── PER3_READER.md                 # DSI persistence read paths + per3-reader design
│   ├── JAVA_APP_DEVELOPMENT.md        # Java app development guide for MMI3G
│   ├── GEM_COMPLETE_MAP.md            # Complete GEM screen map (1,624 lines)
│   ├── PLATFORM_FAMILY.md             # HN+ platform variants
│   ├── PROCESS_GRAPH.md               # QNX process tree
│   ├── USB_ETHERNET_COMPATIBILITY.md  # ASIX chipset compatibility matrix
│   ├── IOACTIVE_V850_REFERENCE.md     # V850 IOC RE methodology
│   └── ... (31 total)
├── tools/                       # Firmware tools (not shipped to SD)
│   ├── inflate_ifs.py           # Decompress LZO/UCL compressed IFS images
│   ├── extract_qnx_ifs.py      # Extract files from a decompressed QNX IFS
│   ├── build_ifs.py             # Construct QNX IFS from file tree
│   ├── patch_ifs.py             # Replace files in decompressed IFS
│   ├── repack_ifs.py            # Recompress IFS (byte-identical to Harman)
│   ├── mu_crc_patcher.py        # Recompute/skip SWDL firmware CRCs
│   ├── mu_repack.py             # One-command firmware modification pipeline
│   ├── eol_modifier.py          # Unlock hidden features in lsd.jxe
│   ├── walk_f3s_efs.py          # List contents of efs-system.efs
│   ├── extract_f3s_efs.py       # Extract filesystem from EFS
│   └── ...
├── docs/app/                    # Web app (GitHub Pages)
└── docs/
    ├── SUPPORTED_VEHICLES.md
    ├── CUSTOM_APPS.md           # Developer guide: 5 ways to run your own code
    └── CONTRIBUTING.md
```

## Contributing

Want to add a module? See [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) for the module format, ESD screen reference, and guidelines.

Module ideas welcome — open an issue to discuss before building.

Community PRs are actively merged — thanks to **daredoole** for web app builder parity fixes.

## Credits & Acknowledgments

This project builds on years of community research:

- **[DrGER2](https://github.com/DrGER2)** — MMI3G+ research pioneer. His repositories (MMI3G-Info, MMI3G-Navdb-Unblocker, MMI3GP-LAN-Setup, copie_src.sh, MMI3G-HDD-Prep-Tool, MMI3G-CRC32Sum, GEMMI-Monitor) are the foundation this toolkit extends
- **[jilleb](https://github.com/jilleb)** — MIB1/MIB2 toolbox author. The mib1-toolbox and mib2-toolbox screen layouts inspired the `password-finder`, `variant-dump`, `map-parser`, and `long-coding` modules in this toolkit
- **[megusta1337](https://github.com/megusta1337)** — copie_scr.sh decryption research
- **[cmbsolutions](https://github.com/cmbsolutions)** — copie_scr.sh encoding tools
- **[romangarms](https://github.com/romangarms)** — Java-on-Audi-MMI-3G JVM research
- **daredoole** — Community contributor, web app builder fixes, RNS-850 testing
- **Congo / audi-mib.bg** — Google Earth restoration research and server infrastructure
- **Audizine, A5OC, VWVortex, ClubTouareg** communities — Thousands of posts of collective knowledge

## Related Projects

- **[PCM-Forge](https://github.com/dspl1236/PCM-Forge)** — Sister project for Porsche PCM 3.1 (same Harman Becker platform). Activation code algorithm fully cracked via SH4 firmware reverse engineering. Web tool at [dspl1236.github.io/PCM-Forge](https://dspl1236.github.io/PCM-Forge/)
- **[jilleb/mib2-toolbox](https://github.com/jilleb/mib2-toolbox)** — The canonical MIB2-HIGH toolbox. Targets MIB2/MIB2.5 units in newer VAG vehicles (Tegra ARM + QNX 6.5). Different hardware from MMI3G+ but the GEM-screen approach is identical
- **[jilleb/mib1-toolbox](https://github.com/jilleb/mib1-toolbox)** — MIB1-HIGH predecessor to the MIB2 toolbox. Closer in platform to our MMI3G+ work

## Disclaimer

This toolkit modifies files on your MMI3G head unit's flash storage. While all changes are reversible and the risk of bricking is very low (the QNX OS runs from separate NVRAM, not the HDD/flash we modify), **use at your own risk**. No warranty is expressed or implied. This project is not affiliated with Audi, Volkswagen, or Harman Becker.

## License

MIT
