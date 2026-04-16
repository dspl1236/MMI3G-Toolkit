# MMI3G-Toolkit

**Modular SD card toolkit for Audi/VW MMI 3G, MMI 3G+, and RNS-850 infotainment systems.**

Pick the tools you want, build an SD card, insert it, done.

**[Launch Web App →](https://dspl1236.github.io/MMI3G-Toolkit/app/)** — Module selector, splash screen formatter, and build instructions right in your browser.

---

## What Is This?

MMI3G-Toolkit is a collection of modules that extend your MMI3G head unit through the built-in SD card script execution mechanism. It includes a Python builder that assembles your selected modules into a ready-to-use SD card — handling the `copie_scr.sh` encoding automatically.

**No VCDS required for most modules. No permanent modifications. No soldering.**

The toolkit runs on the existing QNX operating system inside your head unit. Modules install custom screens into the Green Engineering Menu (GEM) and helper scripts into flash storage. Everything can be cleanly uninstalled.

## Supported Vehicles

Any Audi or VW with a Harman Becker MMI 3G family head unit:

| Platform | Years | Vehicles |
|----------|-------|----------|
| **MMI 3G High** | 2008–2012 | A4/A5/A6/A8/Q5/Q7 (B8, C6, D3) |
| **MMI 3G+** | 2012–2018 | A4/A5/A6/A7/A8/Q5/Q7 (B8.5, C7, D4) |
| **RNS-850** | 2011–2018 | VW Touareg (7P) |

See [docs/SUPPORTED_VEHICLES.md](docs/SUPPORTED_VEHICLES.md) for full details.

## Available Modules

| Module | Status | Description |
|--------|--------|-------------|
| **gauges-dashboard** | ✅ Ready | Live telemetry — battery voltage, GPS, system info, data logging |
| **system-info** | ✅ Ready | One-shot system reporter — full MMI state dump to SD |
| **gem-activator** | ✅ Ready | Enable the Green Engineering Menu without VCDS |
| **nav-unblocker** | ✅ Ready | Bypass nav database activation (Keldo/DrGER2 method) |
| **lte-setup** ⚠️ | ✅ Ready | Provision LTE mobile data via USB Ethernet (**requires hardware — see below**) |
| **can-scanner** | ✅ Ready | CAN bus address scanner — discover RPM, boost, coolant, speed data |
| **jvm-extract** | ✅ Ready | Extract J9 JVM and UI framework for reverse engineering custom menus |
| **game-loader** | ✅ Ready | Java game launcher — run games from SD card on the MMI's J9 JVM |
| **diag-tool** ⚠️ | 🔧 Alpha | UDS diagnostic scanner — auto-scan modules, read/clear DTCs (**needs VAG-COM cable for real hardware use**) |
| **splash-screen** | ✅ Ready | Custom boot splash screen with image formatter app |
| **password-finder** | ✅ Ready | Dump stored Wi-Fi/hotspot passwords, Bluetooth keys, Audi Connect credentials (read-only, inspired by jilleb/mib2-toolbox) |
| **variant-dump** | ✅ Ready | Comprehensive per3 adaptation dump — 90+ car-device, CAN-assignment, and identification values to SD |
| **map-parser** | ✅ Ready | Extract nav database descriptor (acios_db.ini), FSC activation state, map metadata |
| **long-coding** | 🔧 Alpha | Live display of current adaptation values via GEM screens. Read-only — edit with VCDS/ODIS |

> **⚠️ = external hardware required.** Every other module is pure software — SD card in, job done. The hardware-required modules are flagged so you know before building your SD card.

## Hardware Requirements

Most modules run entirely on the MMI itself and need nothing beyond a FAT32 SD card. Two modules are different:

### lte-setup (to replace the defunct 3G modem)

After the 3G cellular network shutdown (US 2022, EU ongoing), the MMI3G+'s built-in modem is dead. This module reroutes the MMI's network stack through a USB Ethernet adapter to an external LTE router. You'll need:

| Part | Specific models | Notes |
|------|-----------------|-------|
| **USB Ethernet adapter** | D-Link DUB-E100 rev A4/B1, or Gembird NIC-U1 | Must use the **ASIX AX88772** chipset — other chipsets have no QNX driver on the MMI |
| **AMI-to-USB Type A cable** | Generic AMI/MDI adapter | The MMI has an AMI connector, not a standard USB port |
| **LTE router** | TP-Link TL-MR3020, Digi WR11 XT, or similar | Any router that serves DHCP on the 192.168.0.x subnet |
| **LTE SIM** | Any data-only plan | 1–2 GB/month is usually plenty |
| **DC-DC power** | 12V → 5V converter | For powering the router from the fuse panel |

**Platform compatibility:** MMI 3G+ and RNS-850 only. **MMI 3G High does NOT have the ASIX driver** — don't waste money on hardware for a 3G High unit.

The module is based on [DrGER2/MMI3GP-LAN-Setup](https://github.com/DrGER2/MMI3GP-LAN-Setup). Total parts cost is typically $100–150. Once configured, you'll get Google Earth overlay, online POI, weather, and other Audi Connect services back via LTE.

### diag-tool (for UDS diagnostics against real modules)

The diag-tool module can run in two modes:
- **Simulated mode** — no hardware required, exercises the UDS stack against simulated modules. Useful for development.
- **Live mode** — talks to actual vehicle ECUs via the standard OBD-II port. Needs a VAG-COM compatible interface (VCDS HEX cable, VNCI 6154a, or similar) and a laptop to run the diagnostic host — the MMI itself doesn't originate UDS traffic to other modules.

Live mode is currently alpha and undocumented; use VCDS or ODIS for production diagnostics work.

## Quick Start

### Requirements
- Python 3.6+
- A 32GB SDHC card (not SDXC) formatted as FAT32
- An Audi/VW with MMI 3G, 3G+, or RNS-850
- Green Engineering Menu enabled (via VCDS or gem-activator module)

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

### Install to Your Car

1. Copy the contents of `./sdcard/` to your FAT32 SD card root
2. Start your car and wait for MMI to fully boot (3+ minutes — verify NAV, MEDIA, PHONE all work)
3. Insert the SD card into slot 1 or 2
4. Wait 30–60 seconds (the script runs silently)
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
│   ├── build_sd.py          # SD card assembler
│   └── encoder.py           # copie_scr.sh XOR encoder
├── core/
│   ├── copie_scr_plain.sh   # Launcher template (auto-encoded)
│   └── uninstall.sh         # Universal uninstaller
├── modules/
│   ├── gauges-dashboard/    # Live telemetry — voltage, GPS, data logging
│   ├── system-info/         # One-shot system state dump to SD
│   ├── gem-activator/       # Enable GEM without VCDS
│   ├── nav-unblocker/       # Nav database activation bypass
│   ├── can-scanner/         # CAN bus address discovery tool
│   ├── jvm-extract/         # Extract J9 JVM + UI framework
│   ├── game-loader/         # Java game launcher for MMI
│   ├── diag-tool/           # UDS diagnostic scanner (alpha)
│   ├── lte-setup/           # LTE mobile data provisioning (3G+)
│   └── splash-screen/       # Custom boot splash screen
├── research/
│   ├── ARCHITECTURE.md      # Decompiled Java UI framework (152 classes)
│   ├── PER3_ADDRESS_MAP.md  # CAN/vehicle data address map
│   ├── IOACTIVE_V850_REFERENCE.md  # V850 IOC RE methodology
│   └── custom-dash/         # Custom dashboard development guide
├── app/                     # Web app (GitHub Pages)
└── docs/
    ├── SUPPORTED_VEHICLES.md
    └── CONTRIBUTING.md
```

## Contributing

Want to add a module? See [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) for the module format, ESD screen reference, and guidelines.

Module ideas welcome — open an issue to discuss before building.

## Credits & Acknowledgments

This project builds on years of community research:

- **[DrGER2](https://github.com/DrGER2)** — MMI3G+ research pioneer. His repositories (MMI3G-Info, MMI3G-Navdb-Unblocker, MMI3GP-LAN-Setup, copie_src.sh, MMI3G-HDD-Prep-Tool, MMI3G-CRC32Sum, GEMMI-Monitor) are the foundation this toolkit extends
- **[jilleb](https://github.com/jilleb)** — MIB1/MIB2 toolbox author. The mib1-toolbox and mib2-toolbox screen layouts inspired the `password-finder`, `variant-dump`, `map-parser`, and `long-coding` modules in this toolkit. Though MIB2 targets different hardware (ARM/Tegra vs our SH4), the GEM screen pattern, adaptation-channel concept, and toolbox structure all came from his work
- **[megusta1337](https://github.com/megusta1337)** — copie_scr.sh decryption research
- **[cmbsolutions](https://github.com/cmbsolutions)** — copie_scr.sh encoding tools
- **[romangarms](https://github.com/romangarms)** — Java-on-Audi-MMI-3G JVM research
- **Audizine, A5OC, VWVortex, ClubTouareg** communities — Thousands of posts of collective knowledge

## Related Projects

- **[PCM-Forge](https://github.com/dspl1236/PCM-Forge)** — Sister project for Porsche PCM 3.1 (same Harman Becker platform). Activation code algorithm fully cracked via SH4 firmware reverse engineering. Web tool at [dspl1236.github.io/PCM-Forge](https://dspl1236.github.io/PCM-Forge/)
- **[jilleb/mib2-toolbox](https://github.com/jilleb/mib2-toolbox)** — The canonical MIB2-HIGH toolbox (848 ⭐). Targets MIB2/MIB2.5 units in newer VAG vehicles (Tegra ARM + QNX 6.5). Different hardware from MMI3G+ but the GEM-screen approach is identical
- **[jilleb/mib1-toolbox](https://github.com/jilleb/mib1-toolbox)** — MIB1-HIGH predecessor to the MIB2 toolbox. Closer in platform to our MMI3G+ work
- **[jilleb/odis2vcp](https://github.com/jilleb/odis2vcp)** — Converts ODIS XML datasets to VCP XML format. Useful if you're extracting data via ODIS E17 and want to use it with VCP/VCDS-style tools
- **[jilleb/binary_tools](https://github.com/jilleb/binary_tools)** — Simple Python scripts for binary file comparison. PCM-Forge's `tools/diff_fw.py` is an extended version of this approach
- **[harman-f/MHI2_US_POG11_K5186_1-MU1476-AIO](https://github.com/harman-f/MHI2_US_POG11_K5186_1-MU1476-AIO)** — Porsche PCM 4 / MIB2 firmware patching (CarPlay/AndroidAuto/GEM enablement). Different platform, same activation-code identifier scheme

## Disclaimer

This toolkit modifies files on your MMI3G head unit's flash storage. While all changes are reversible and the risk of bricking is very low (the QNX OS runs from separate NVRAM, not the HDD/flash we modify), **use at your own risk**. No warranty is expressed or implied. This project is not affiliated with Audi, Volkswagen, or Harman Becker.

## License

MIT
