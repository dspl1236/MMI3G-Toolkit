# MMI3G Boot Process Graph

101 processes, 105 interfaces, parsed from mmi3g-srv-starter.cfg
(variant 9411, K0942_4). Managed by srv-starter-QNX.

## Critical boot chain

```
pci-sh7785 [46]
  → dev-ipc [3] → ipc interface (DSI backbone)
  → dev-sysregs [6] → io-audio [18], devc-ser [11]
  → io-pkt-v4-hc [20] → socket interface (network)
  → io-usb [22] → vdev-medialaunch [60] → medialauncher
  → devf-generic [12] → flash filesystem
  → io-display [19] → layermanagerV2 [28]
    → MMI3GApplication [61]
    → lsd.sh [62] (Java HMI)
```

## Key processes

| # | Process | Depends on | Provides | Role |
|---|---------|------------|----------|------|
| 46 | pci-sh7785 | (none) | pci | PCI bus — first process |
| 3 | dev-ipc | pci | ipc | DSI messaging backbone |
| 6 | dev-sysregs | pci | sysregs | System registers |
| 20 | io-pkt-v4-hc | pci | socket | TCP/IP network stack |
| 22 | io-usb | usbPowerMonitor | io-usb | USB stack |
| 12 | devf-generic | pci | — | Flash filesystem driver |
| 19 | io-display | io-media | io-display | Display driver |
| 28 | layermanagerV2 | io-display | layermanager | Graphics compositor |
| 61 | MMI3GApplication | layermanager | gracenotekeyavailable | Main app (10.7MB SH4) |
| 62 | lsd.sh | pci | — | Java HMI launcher |
| 90 | NavCore | ndr | — | Navigation engine |
| 48 | proc_scriptlauncher | medialauncher | — | **copie_scr.sh handler** |
| 56 | start_network.sh | medialauncher | — | Network (telnet target) |
| 93 | vdev-logvolmgr | startLVM | — | **FSC bypass target** |
| 70 | ejecthandler | ipc | ejecthandler_installed | Media eject handler |

## Process categories

### Hardware drivers (started first)
pci-sh7785, dev-sysregs, dev-adjmanager, dev-ipc, dev-nvram,
dev-videoctrl, dev-mv2trace, devc-ser8250hb, devf-generic,
devb-eide-hbfpga, devb-sdc-hbfpga, io-audio, io-display,
io-pkt-v4-hc, io-usb, io-media-nvidia, usbPowerMonitor

### Media / filesystem
io-fs-media (4 instances), mcd, mmelauncher, mme-update,
mount, df (3 instances), devf-ram (2 instances), flashctl (2)

### Core services
pipe, mqueue, multicored, ipc-test, servicebroker

### Display / HMI
layermanagerV2, MMI3GApplication, lsd.sh, run_gemmi.sh,
NvElfLoader, devg-NVMiniRM, devg-NVTS, devg-NVMEM, GPIOSet

### Navigation
NavCore, vdev-flexgps, ndr

### Media management
srv_drivehandler, ejecthandler, gracenote_srvr, vdev-medialaunch

### Networking / scripts
start_network.sh, proc_scriptlauncher, PSSBSSProcess.sh,
SSSProcess, NWSProcess.sh, runAMRController.sh

### Persistence / security
mmi3g-flashctl, vdev-logvolmgr, adb_prep.sh, checkFreeMem

### Shutdown
parkHDD.sh, shutdown_flash.sh, shutdown_hook.sh

## Interface dependency map (105 interfaces)

The srv-starter-QNX process manager starts processes in dependency
order based on interface availability. A process won't start until
all its RequiresInterface entries are satisfied by other processes'
ProvidesInterface.

## Implications for modding

1. **proc_scriptlauncher [48]** handles SD card script execution
   (copie_scr.sh). It depends on medialauncher, which depends on
   io-usb. Scripts run after USB and media detection.

2. **start_network.sh [56]** also depends on medialauncher. Our
   telnet modification runs at this point in the boot sequence.

3. **vdev-logvolmgr [93]** is the last-to-start security process.
   The FSC race condition exploit targets the window between
   media mount and logvolmgr's security checks.

4. **MMI3GApplication [61]** depends on layermanager but NOT on
   ipc directly — it uses DSI through libdsiservice which connects
   to the ipc interface on its own.

5. Adding a new process: edit mmi3g-srv-starter.cfg to add a
   Process entry with appropriate interface dependencies. The
   srv-starter will manage startup ordering automatically.
