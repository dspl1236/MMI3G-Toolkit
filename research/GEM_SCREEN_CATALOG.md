# MMI3G GEM Screen Catalog

> **Note:** This is a quick-reference catalog. For full element-level details,
> see **GEM_COMPLETE_MAP.md**.


# Source: HN+R_US_AU_K0942_3 factory ESD files (138 screens)
# Part of MMI3G-Toolkit: github.com/dspl1236/MMI3G-Toolkit

## ESD Element Types

| Element | Function | Writable? |
|---|---|---|
| `keyValue` | Read per3 value + optional polling | Read-only |
| `choice` | Toggle boolean per3 value | **YES — toggle on/off** |
| `BIOSCtrl` | Select from dropdown, writes per3 | **YES — select & write** |
| `button` | Write per3 value on press | **YES — one-shot write** |
| `slider` | Adjust numeric per3 value | **YES — slider write** |
| `script` | Call shell script on press | **YES — runs /scripts/*.sh** |
| `label` | Static text | Read-only |

## Per3 Namespace Map

| Namespace | Prefix | Purpose |
|---|---|---|
| per 1 | 0x0005xxxx | System control (UMTS, LSD, telephony) |
| per 2 | 0x0001xxxx | DTC control (clear, test pass/fail) |
| per 3 | 0x0010xxxx | DEVICE_LIST coding (32 feature toggles) |
| per 3 | 0x0011xxxx | System info (serial, VW name) |
| per 3 | 0x0012xxxx | System state (train, version, resets) |
| per 3 | 0x0014xxxx | PROTOCOLL_SWITCH coding |
| per 3 | 0x0000xxxx | Live sensor data (battery, cable code) |
| per 3 | 0x0030xxxx | Connectivity (HUC/BTHS) |
| per 4 | 0x0001xxxx | Performance monitoring |
| per 8 | 0x0005xxxx | Dataset import trigger |

## Writable Screens (can change car configuration!)

### Car/CarDeviceList — 32 feature toggles
All `choice` elements — toggle on/off from GEM:
- 0x00100010: Air condition
- 0x00100011: Auxiliary heating
- 0x00100012: Headup display (HUD)
- 0x00100013: Adaptive Cruise Control (ACC)
- 0x00100014: Air suspension
- 0x00100015: Tyre pressure control (RDK)
- 0x00100016: Interior light
- 0x00100017: Exterior light
- 0x00100018: Park distance control (PDC)
- 0x00100019: Rearview camera (RVC)
- 0x0010001A: Wiper
- 0x0010001B: Doorlocking
- 0x0010001C: Mirror
- 0x0010001D: On-board computer
- 0x0010001E: Clock
- 0x0010001F: Service interval
- 0x00100020: Seat memory front
- 0x00100021: Seat memory rear
- 0x00100022: RSE device (rear seat entertainment)
- 0x00100023: Central unit master
- 0x00100024: MKE
- 0x00100025: Compass
- 0x00100026: Universal garage door opener (UGDO)
- 0x00100027: Night vision
- 0x00100028: Lane departure warning (HCA)
- 0x00100029: Lane change assist (SWA)
- 0x0010002A: Braking way reduction (AWV)
- 0x0010002B: VZE (traffic sign recognition)
- 0x0010002C: Side view cameras
- 0x0010002D: Hybrid
- 0x0010002E: Reversible belt pretensioner
- 0x0010002F: RDK (2nd generation)

### Car/CarCodingVehicle — Vehicle identity
BIOSCtrl selectors (writable dropdown):
- 0x00100002: Steering wheel derivat (Left/Right)
- 0x00100008: Vehicle derivat (Limousine/Avant/Coupe/Cabrio/Sportback/Allroad/SUV)
- 0x00100004: Configuration line (Standard/S-line/S-Model/RS-Model)
- 0x00100006: Vehicle model line
- 0x00100064: Transmission (FWD/RWD)
- 0x0010000C: Cluster variant
- 0x0010000A: Telephone equipment
- 0x0010000E: Connected microphone
- 0x00100068: Available displays

### Diagnose/Coding — Region & modules
- 0x00100000: Active HDD nav DB (EU/NA/SA/AGCC/Korea/Japan/China/etc.)
- 0x00100064: Transmission derivat

### DTC/control — Clear error memory!
Three writable buttons:
- per 2 0x00010006: "Send test passed"
- per 2 0x00010007: "Send test failed"
- per 2 0x00010008: **"Clear error memory"** ← clears DTCs!

### System — UMTS, LSD modes, battery
- per 1 0x00050043: Connect UMTS (channel 0)
- per 1 0x00050044: Disconnect UMTS (channel 0)
- per 1 0x00050045: **Activate LSD development mode**
- per 1 0x00050046: Activate LSD production mode
- per 1 0x00050047: Activate LSD consolidated mode
- per 3 0x00110013: Production mode check
- per 3 0x00000023: Battery voltage (x100 mV, polled)
- per 3 0x0014001F: Summer time algorithm

### DiagnoseSettings — Dataset import
- per 8 0x00059000: Trigger import from /HBpersistence/Datasets_VAS

## Script-Callable Screens

### GoogleEarth — Full GEMMI control (8 script buttons!)
All call `/scripts/GEMMI/*.sh`:
- restartGEMMI.sh (volatile)
- shutdownGEMMI.sh (volatile)
- startGEMMI.sh (volatile)
- deactivateGEMMI.sh (persistent)
- activateGEMMI.sh (persistent)
- getCacheStatus.sh
- deleteCacheGEMMI.sh
- getInfoGEMMI.sh

### AEVTest/Scripts — Generic script runner
- Calls `/scripts/myScript.sh` (template path)

### Trace/MMEVerbosity — 2 script buttons
### main/Media — 1 script button

## Script Path Format
```
script
    value    sys 1 0x0100 "/scripts/path/to/script.sh"
    label    "Button Label"
```
Scripts are relative to `/mnt/efs-system/`.
**Key question**: Can we use absolute paths to SD card?
e.g. `/mnt/sdcard10t12/scripts/tool.sh`

## Live Polled Data (keyValue with poll interval)

| Address | Label | Poll (ms) | Screen |
|---|---|---|---|
| 0x00000023 | Battery voltage (x100 mV) | 500 | System |
| 0x00000024 | Cable code info (hex) | 5000 | System |
| 0x00120000 | Count down | 1000 | System |
| 0x00120002 | HW index IT | 1000 | System |
| 0x00120003 | Unexpected resets | 1000 | System |
| 0x00300007 | Connected HUC/BTHS (hex) | 5000 | System |
| 0x00500000 | Eject Disabled | 3000 | Media |
