# EFS File Inventory

Full scan of efs-system.efs (MU9411 K0942_4 variant 41) using
brute-force dirent pattern matching across all 148 flash units.

## Summary

- **3,645 files** across 148 flash units (38.8 MB image)
- **57 directories** forming a complete Unix-like filesystem
- **3 symlinks**
- **183 ESD files** (GEM engineering screen definitions)

## Key Debug Tools (EFS-only, not in IFS)

| Tool | Size | Purpose |
|------|------|---------|
| `qconn` | ~66 KB | **QNX remote debug agent** — enables GDB remote debugging |
| `vi` | ~68 KB | Text editor for live editing |
| `mmecli` | ~96 KB | Multimedia engine CLI |
| `NvSpy` | ~34 KB | NVIDIA GPU monitoring |
| `nicinfo` | ~10 KB | Network interface info |
| `qkcp` | ~18 KB | QNX kernel crash dump processor |
| `fdisk` | ~53 KB | Disk partitioning |
| `dcheck` | ~8 KB | Filesystem check |
| `devb-umass` | ~31 KB | USB mass storage driver |
| `io-usb` | ~100 KB | USB stack |
| `dspwatch` | ~443 KB | DSP monitoring |
| `testapp-*` | various | Test applications |

## Remote Debugging with qconn

After enabling telnet access (see `docs/FLASH_RUNBOOK.md`):

```bash
# On MMI via telnet:
/mnt/efs-system/bin/qconn &

# On PC (with QNX Momentics IDE or standalone GDB):
# Connect to 172.16.42.1:8000
# Enables: breakpoints, memory inspection, register examination,
# call traces on the LIVE running system
```

## Directory Structure (57 directories)

Root level: /mnt/efs-system, bin, sbin, lsd
HMI resources: HMIAddressBookD4, HMICarD4, HMIInfoD4, HMIMediaD4,
  HMINaviD4, HMIPhoneD4, HMISettingsD4, HMISystemD4, HMIToneD4,
  HMITunerD4
System: etc, scripts, lib, usr, Connectivity, GEMMI
Data: images, audiofiles, splashscreens, SpellerCharacterSets
Config: engdefs (183 .esd files), system, config, version
Persistence: CVA, pss, nws, sss, pssbss, projectdefaults

## Scan Method

Brute-force pattern matching across the entire EFS image:
1. Scan every 4-byte aligned position for valid dirent headers
   (struct_size=8, valid namelen, ASCII name, stat_size=20)
2. Filter by valid file types (DIR=0x4, FILE=0x8, LINK=0xa)
3. Results include extent pointers (unit, index) for future
   content extraction once the F3S extent mapping is decoded
