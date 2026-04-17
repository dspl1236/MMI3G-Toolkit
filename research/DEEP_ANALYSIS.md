# Deep Analysis — Firmware Corners

Exploring the less-documented subsystems of the MMI3G+ HN+R platform.

## Update Scripts (preUpdateScript / postUpdateScript)

### preUpdateScript — Key Findings

1. **FSC Restoration**: `restore_fsc()` copies FSCs from
   `/mnt/efs-persist/FSC/illegal/signature/` back to
   `/mnt/efs-persist/FSC/`. Confirms FSCs can be moved to
   "illegal" status and then restored by the update system.

2. **CRC Bypass**: Generates `sed 's/^CRC = .*/skipCrc = true/g'`
   to rewrite update.txt — Harman's OWN script disables CRC
   checking during F-sample hardware detection.

3. **Variant Aliasing**: MU9406→MU9411, MU9407→MU9411, ...,
   MU9410→MU9411. All old variant numbers map to MU9411.

4. **Hardware Sample Detection**: Uses `pidin -p devf-generic ar`
   to check for `-D` flag (ECC mode) to detect F-sample hardware.
   Three sample types: E1 (0xE1), D1 (0xD1), F1/F2 (0xF1/0xF2).

5. **Reboot Mechanism**: Copies `reboot` tool from update media
   with checksum verification (138851247), then calls it.

### postUpdateScript — Key Findings

1. **sqlite3 Database Cleanup**: Deletes 17 KOMO compression
   settings from DataPST.db (RAM, flash, AND backup copies).
   Keys 0x50000-0x50010 in namespace 4.

2. **Phone Persistence Migration**: `phonePersistenceConverter`
   converts phone data between software trains.

3. **Bluetooth SSP Migration**: If upgrading from pre-SOP6
   software, deletes bss.ddb and bss.bak (Bluetooth device list)
   to prevent cyclic reset. Also clears BT list from DataPST.db
   (namespace 1846283667, key 72057594037862401).

4. **HDD Repartitioning**: Checks for 187.4GB partition, shows
   `rePartitioningNeeded.png` via `showScreen` tool if missing.

5. **DHCP**: Creates `/HBpersistence/usedhcp` if not using fixed
   address 172.16.250.24.

## FPGA Configuration

- **SystemFPGA.hbbin**: 746,512 bytes — identical across all 3
  hardware variants (41/51/61). Single universal bitstream.
- **fpga-emg**: Emergency FPGA (fallback if main FPGA fails).
  Same size and content as main FPGA.
- **Custom Harman FPGA**: Interfaces with audio (deva-ctrl-hb_fpga.so),
  IDE storage (devb-eide-hbfpga), I2C bus (dev-i2c-hbfpga),
  and the NVIDIA GPU.

## NVIDIA GPU / DSP

- **TI DM642 DSP**: Loaded by NvElfLoader via `.nvidia.dspcode`
  section in ELF files. Uses COFF format embedded in ELF.
- **Display config**: 8 graphics layers, video on layer 6.
  dispidx=3, numlayers=8, videobind=6.
- **5 GPU processes**: devg-NVMiniRM (resource mgr) → devg-NVTS
  (texture server) → devg-NVMEM (memory) → GPIOSet → NvElfLoader.

## NavCore — 35-Module Navigation Engine

6.8MB SH4 ELF, dynamically linked. Internal name:
`AudiMMI3G_PLUS_NavCore`. Uses DSI channel `/dev/ipc/ch5`.

### Module List
| Module | Purpose |
|--------|---------|
| NavCore_ADAS | Speed limits, sign recognition |
| NavCore_ADAS_IPC | ADAS inter-process communication |
| NavCore_CDM | Central Data Manager (accepts MOST!) |
| NavCore_DBM | Database Manager (map data) |
| NavCore_DBW | Database Writer |
| NavCore_GIZ | Geofence / Interest Zones |
| NavCore_GRM | Guidance Route Manager |
| NavCore_ICB | Instrument Cluster Bridge |
| NavCore_JM1/JM2 | Junction Maneuver (turns) |
| NavCore_LWT | Lane/Way Topology |
| NavCore_MCR | Map Content Reader |
| NavCore_MLC | Map Layer Control |
| NavCore_MMI | HMI interface |
| NavCore_MRD | Map Rendering |
| NavCore_NAS/NASR | Address Search |
| NavCore_NDL | Navigation Data Loader |
| NavCore_POR | POI/Route |
| NavCore_RBH | Route Block Handler |
| NavCore_RLC | Route Layer Control |
| NavCore_RTD | Route Data |
| NavCore_SCT | Scene/Section |
| NavCore_SEC/SEC_RDR | Security / Reader |
| NavCore_SOB/SOT | Sort/Object |
| NavCore_SPE | Speed |
| NavCore_SQA | Search Quality Assessment |
| NavCore_SYS | System |
| NavCore_Socket_10099 | TCP socket (port 10099) |
| NavCore_TMC | Traffic Message Channel |
| NavCore_WAI | Waypoint/AI |
| NavCore_ZLF | Zone/Layer File |

### Debug API
- `HBDebug_dumpThreads` — dump all thread states
- `HBDebug_dumpComponentRegistry` — dump component registry
- `HBDebug_getQueueStates` — dump message queues
- `--dsitrace=` — DSI trace flag
- `--dsiservicebroker=` — DSI service broker
- `--enable-kernel-trace` / `--disable-kernel-trace`

### Internal Wiki
Reference: `http://naviwiki.harmanbecker.com/wiki/`

## IOC (I/O Controller) — PowerPC Core

The IOC is a separate PowerPC processor handling vehicle bus
communication. It communicates with the SH4 main CPU via DSI
channel `/dev/ipc/ioc/ch5`.

### IOC Controllers
- CIOCPresCtrlFront — Front panel
- CIOCPresCtrlGW — Gateway (vehicle bus bridge)
- CIOCPresCtrlOnOff — Power management
- CIOCPresCtrlPersistence — Persistent settings
- CIOCDiagBusCtrl — Diagnostic bus (OBD-II)
- CIOCLogDevCtrlBase — Logical device base class

### Vehicle Functions via MOST Bus
Central locking status (ZentralVerriegelung):
- AutoLock — automatic locking
- ComfortOpenFront — comfort opening front windows
- ComfortOpenRear — comfort opening rear windows
- ComfortOpenSunRoof — comfort opening sunroof
- HeckLock — trunk lock
- HeckRollo — trunk cover/shade
- MirrorProtection — mirror fold on lock
- NumberOfDoors — door configuration
- NumberOfWindows — window configuration
- TheftWarning — theft alarm status

## MOST Bus / INIC

- **INIC**: Intelligent Network Interface Controller (MOST bus chip)
- **I2C Communication**: INIC accessed via I2C at 0x480000
  through dev-i2c-hbfpga (hardware-specific to 9411)
- **INIC Firmware Update**: Via `start_inic_update_driver.sh` +
  `dev-inic-flasher` + `inic-flasher`
- NavCore's CDM module accepts MOST communication directly

## Auto-Execution Paths (Summary)

| Path | Trigger |
|------|---------|
| /SwdlAutoRun.txt | Root of SD card → auto firmware update |
| /HBpersistence/SWDL/autoExec.sh | Auto-execute script |
| /HBpersistence/SWDL/TestMDscript.sh | Pre/post update hooks |
| /HBpersistence/SWDL/AutoHandlePopUp.txt | Auto-accept dialogs |
| /HBpersistence/SWDL/SwdlProductionMode.txt | Production mode |
| storagetype=18 | SD card detection in copie_scr.sh |
| proc_scriptlauncher [48] | copie_scr.sh handler process |
