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
| **lte-setup** | ✅ Ready | Provision LTE mobile data via USB Ethernet (3G+ only) |
| **can-scanner** | ✅ Ready | CAN bus address scanner — discover RPM, boost, coolant, speed data |
| **jvm-extract** | ✅ Ready | Extract J9 JVM and UI framework for reverse engineering custom menus |
| **game-loader** | ✅ Ready | Java game launcher — run games from SD card on the MMI's J9 JVM |
| **diag-tool** | 🔧 Alpha | UDS diagnostic scanner — auto-scan modules, read/clear DTCs, ECU info |
| **splash-screen** | ✅ Ready | Custom boot splash screen with image formatter app |

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
│   ├── build_sd.py         # SD card assembler
│   └── encoder.py          # copie_scr.sh XOR encoder
├── core/
│   ├── copie_scr_plain.sh  # Launcher template (auto-encoded)
│   └── uninstall.sh        # Universal uninstaller
├── modules/
│   ├── gauges-dashboard/   # Live telemetry screens
│   │   ├── module.json
│   │   ├── engdefs/        # GEM screen definitions
│   │   └── scripts/        # Helper scripts
│   ├── system-info/        # System reporter (planned)
│   ├── gem-activator/      # GEM enabler (planned)
│   ├── nav-unblocker/      # Nav DB bypass (planned)
│   └── lte-setup/          # LTE provisioning (3G+ only)
│   └── splash-screen/      # Boot screen (planned)
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
- **[megusta1337](https://github.com/megusta1337)** — copie_scr.sh decryption research
- **[cmbsolutions](https://github.com/cmbsolutions)** — copie_scr.sh encoding tools
- **[romangarms](https://github.com/romangarms)** — Java-on-Audi-MMI-3G JVM research
- **Audizine, A5OC, VWVortex, ClubTouareg** communities — Thousands of posts of collective knowledge

## Related Projects

- **[PCM-Forge](https://github.com/dspl1236/PCM-Forge)** — Sister project for Porsche PCM 3.1 (same Harman Becker platform). Activation code algorithm fully cracked via SH4 firmware reverse engineering. Web tool at [dspl1236.github.io/PCM-Forge](https://dspl1236.github.io/PCM-Forge/)

## Disclaimer

This toolkit modifies files on your MMI3G head unit's flash storage. While all changes are reversible and the risk of bricking is very low (the QNX OS runs from separate NVRAM, not the HDD/flash we modify), **use at your own risk**. No warranty is expressed or implied. This project is not affiliated with Audi, Volkswagen, or Harman Becker.

## License

MIT
