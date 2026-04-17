# On-Car Test Checklist

Everything that needs to be verified on the live 2013 C7 A6 3.0T
(MMI3G+ HN+R, K0942_4).

## Phase 1: SD Card Tests (No Firmware Mods)

### 1.1 copie_scr.sh Execution
- [ ] Prepare SD card with XOR-encoded copie_scr.sh (use toolkit encoder)
- [ ] Insert in SD slot 1 → wait 30 sec → check for execution
- [ ] Insert in SD slot 2 → same test
- [ ] Verify: does `proc_scriptlauncher` [process 48] pick it up?
- [ ] Check `/var/` on SD card for output logs

### 1.2 GEM (Green Engineering Menu) Access
- [ ] Hold CAR + SETUP simultaneously for 3+ seconds
- [ ] Verify GEM appears (engineering menu)
- [ ] If not: enable via VCDS adaptation 5F channel 6
  - OR use gem-activator module via copie_scr.sh

### 1.3 Existing DTC Screens
- [ ] Navigate GEM → DTC → qualified_DTCs
- [ ] Note: are DTCs shown? How many? What codes?
- [ ] Compare visible DTCs against VCDS scan
  - If they MATCH → vehicle-wide DTC checker works!
  - If only MMI DTCs → need IOC diagnostic bus investigation
- [ ] Try "Clear error memory" button
- [ ] Navigate GEM → DTC → Show_single_DTC → test slider

### 1.4 Install Custom GEM Screens via SD Card
- [ ] Copy ToolkitDTC.esd to SD card engdefs/
- [ ] Execute install script via copie_scr.sh
- [ ] Verify new screens appear in GEM → Toolkit menu
- [ ] Test DTC_Overview screen (20-row table)

### 1.5 System Info Gathering
- [ ] Run system-info module (collect via copie_scr.sh):
  - `pidin` (running processes)
  - `uname -a` (kernel version)
  - `ifconfig` (network interfaces)
  - `df` (disk usage)
  - `ls /mnt/efs-persist/FSC/` (installed FSC files)
  - `cat /mnt/ifs-root/etc/version/ifs-root-version.txt`
  - `cat /HBpersistence/channels.bin` (DSI config)

## Phase 2: Telnet Access (Firmware Mod Required)

### 2.1 Enable Telnet
- [ ] Modify start_network.sh (add 4 lines for USB-Ethernet)
- [ ] Apply via patch_ifs.py → repack_ifs.py → mu_crc_patcher.py
- [ ] Flash modified IFS via SD card (see FLASH_RUNBOOK.md)
- [ ] Connect D-Link DUB-E100 USB-Ethernet adapter
- [ ] Set PC to 172.16.42.2/24
- [ ] `telnet 172.16.42.1` → verify root shell

### 2.2 Live System Exploration (via telnet)
- [ ] `pidin` — verify all 101 processes running
- [ ] `ls /mnt/efs-system/bin/` — confirm qconn, vi, mmecli
- [ ] `ls /mnt/efs-persist/FSC/` — list installed FSC files
- [ ] `cat /mnt/efs-persist/FSC/*.fsc | xxd | head` — FSC format
- [ ] Test qconn (GDB remote debug):
  - `/mnt/efs-system/bin/qconn &`
  - From PC: connect to 172.16.42.1:8000

### 2.3 IOC Diagnostic Bus Testing
- [ ] Find the IOC diagnostic bus interface:
  - `ls /dev/ipc/ioc/`
  - `ls /dev/ipc/ch*`
- [ ] Test `requestIocDiagBus` keys via DSI
- [ ] Check if vehicle-wide DTCs are accessible
- [ ] Map `CIOCPresCtrlGW` read keys for vehicle data

### 2.4 DSI Namespace Exploration
- [ ] Read DSI persistence data:
  - `per 1 0x0009xxxx` — instrument cluster coding
  - `per 2 0x0001xxxx` — DTC data (confirm vehicle-wide or MMI-only)
  - `per 3 0x0010xxxx` — navigation coding
  - `per 3 0x0015xxxx` — module coding bytes
  - `per 8 0x0005xxxx` — system commands

### 2.5 NavCore Socket
- [ ] `netstat -an | grep 10099` — is NavCore socket listening?
- [ ] Try connecting: `telnet localhost 10099`
- [ ] Check what protocol it speaks

## Phase 3: FSC Bypass (Firmware Mod)

### 3.1 Apply FSC Patch
- [ ] Patch MMI3GApplication at offset 0x001B11F6
  - Replace: 0B 40 → 00 E0
- [ ] Deploy via patch_ifs.py + repack_ifs.py
- [ ] Flash and reboot
- [ ] Verify: does FSC validation pass for unsigned FSCs?

### 3.2 EOL Flag Unlock
- [ ] Modify lsd.jxe with eol_modifier.py:
  - --enable EOLFLAG_GOOGLE_EARTH
  - --enable EOLFLAG_ONLINE_SERVICES
  - --enable EOLFLAG_INNOVATIONFEATURES
  - --enable EOLFLAG_DEVICES_OFFROAD_NAVIGATION
- [ ] Deploy via patch_ifs.py
- [ ] Verify: do new menu items appear?

## Phase 4: PCM 3.1 (Porsche Cayenne 958)

### 4.1 PIWIS VM Setup
- [ ] Get PIWIS 3 VM working (fixing errors)
- [ ] Connect VNCI 6154a VCI cable to Cayenne OBD-II
- [ ] Verify PIWIS connects to PCM 3.1

### 4.2 Engineering Menu Entry
- [ ] Enter engineering code: `297646776cafd751`
- [ ] Try SOURCE + SOUND key combo after code entry
- [ ] Document all engineering menu screens
- [ ] Check for hidden activation options

## SD Card Capabilities Summary

### What copie_scr.sh Can Do (NO firmware mods)
1. **Install custom GEM screens** — copy .esd files to EFS
2. **Run shell scripts** — full root access, any QNX command
3. **Read system info** — processes, versions, disk usage
4. **Collect logs** — syslog, error logs, DSI traces
5. **Modify EFS files** — persistent changes that survive reboot
6. **Install persistent boot hooks** — modify mmelauncher.cfg
7. **Kill/restart processes** — e.g., kill vdev-logvolmgr for nav unlock
8. **Read/write DSI persistence** — via per3 addresses
9. **Dump firmware** — copy IFS/EFS to SD card for analysis
10. **Network setup** — configure IP, start services

### What Requires Firmware Modification
1. **FSC signature bypass** — patch MMI3GApplication (IFS mod)
2. **Telnet access** — modify start_network.sh (IFS mod)
3. **EOL flag changes** — modify lsd.jxe (IFS mod)
4. **Custom native binaries** — add to IFS or EFS
5. **Process graph changes** — modify mmi3g-srv-starter.cfg

### SD Card File Structure
```
SD Card Root/
├── copie_scr.sh          ← XOR-encoded launcher (REQUIRED)
├── run.sh                ← Decoded payload script
├── engdefs/              ← Custom GEM screen files
│   ├── ToolkitDTC.esd
│   ├── ToolkitMain.esd
│   └── ToolkitDiag.esd
├── scripts/              ← Helper scripts
│   ├── sysinfo.sh
│   ├── dtc_check.sh
│   └── network_setup.sh
└── var/                  ← Output logs saved here
```

### Auto-Execution Paths
| Path | Trigger |
|------|---------|
| `copie_scr.sh` at SD root | proc_scriptlauncher detects SD insert |
| `/SwdlAutoRun.txt` at media root | Triggers firmware update |
| `/HBpersistence/SWDL/autoExec.sh` | Auto-execute on boot |
| `/HBpersistence/SWDL/TestMDscript.sh` | Pre/post update hooks |
| `/HBpersistence/SWDL/AutoHandlePopUp.txt` | Auto-accept update dialogs |
| `/HBpersistence/SWDL/SwdlProductionMode.txt` | Production SWDL mode |
