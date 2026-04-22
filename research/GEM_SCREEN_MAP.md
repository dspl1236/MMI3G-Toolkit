# GEM Engineering Menu — Complete Screen Map

> **Note:** This is an early version of the GEM screen map. For the complete,
> authoritative reference, see **GEM_COMPLETE_MAP.md** (1624 lines, every screen,
> every element, every per3 address).



> Extracted from VW RNS 850 EFS-system (HN+ P0534, MU9478)
> Applicable to: Audi MMI3G, VW RNS 850, Porsche PCM 3.1
> Date: April 19, 2026

## ESD File Format

Engineering Screen Definition (ESD) files are stored at `/mnt/flash/efs1/engdefs/`
(or `/HBpersistence/engdefs/` on some variants). They use a token-based text format.

### Element Types

| Element | Description | Properties |
|---------|-------------|------------|
| `screen` | Screen definition | `screen <Name> <Parent>` |
| `choice` | Toggle/dropdown | `value per <svc> <addr>`, `label` |
| `keyvalue` | Read-only display | `value <type> per <svc> <addr>`, `label`, `poll` |
| `BIOSCtrl` | Multi-option selector | `value`, `label`, `entry "<text>" <val>` |
| `button` | Action button | `value per <svc> <addr>`, `label` |
| `script` | Shell script exec | `value sys <svc> <addr> "<path>"`, `label` |
| `table` | Data table | `content per <svc> <addr>`, `columns`, `maxrows` |
| `slider` | Numeric slider | `value <type> per <svc> <addr>`, `label`, `range` |
| `export` | Data export | `value`, `label` |
| `speller` | Text input | `value`, `label` |

### Persistence Services

- Service 1 (`per 1`): Main system persistence
- Service 3 (`per 3`): Car/vehicle device persistence
- `sys 1`: System command execution

## Complete Screen Map (109 screens)

### Radio & Media
| # | Screen | Elements | Description |
|---|--------|----------|-------------|
| 2 | AMFM Radio | 2 | AM/FM tuner main |
| 3-12 | AMFM sub-screens | varies | Diag, test modes A/C/D/E/V, TMC |
| 29-43 | DAB (14 screens) | varies | Digital radio diagnostics |
| 56-63 | HD Radio (8 screens) | varies | HD Radio diagnostics |
| 82 | RUSirius Main | 2 | Sirius XM |
| 86-93 | SDARS (8 screens) | varies | Satellite radio |
| 96-99 | TIM (4 screens) | varies | Traffic info messages |

### Audio
| # | Screen | Elements | Description |
|---|--------|----------|-------------|
| 13 | InputGainOffset | 14 sliders | Audio input gain |
| 14 | AudioMisc | 2 sliders | Audio misc settings |
| 15 | VolumeRangers | 11 sliders | Volume ranges |

### Vehicle Configuration
| # | Screen | Elements | Description |
|---|--------|----------|-------------|
| 18 | CarCodingVehicle | 1 slider | Vehicle coding |
| 19 | **CarDeviceList** | **32 choices** | All vehicle modules! |
| 20 | CarDeviceList_2 | 2 choices | Extended devices |
| 21 | CarExtDeviceList | 8 choices | External devices |
| 22 | CarFunctionList | 7 choices | Function toggles |
| 23 | CarProtocollSwitch | 15 choices | Protocol toggles |
| 25 | CarMenuOperation | **37 sliders** | Menu operation params |

### Coding
| # | Screen | Elements | Description |
|---|--------|----------|-------------|
| 44 | connected_micro | 2 choices | Microphone coding |
| 45 | telephone_equipment | 2 choices | Telephone coding |
| 46 | internal_modules_1+2 | 13 (11 choice + 2 button) | Module coding |
| 47 | **Kombi Coding** | 6 (4 choice + 2 button) | Instrument cluster |

### Navigation
| # | Screen | Elements | Description |
|---|--------|----------|-------------|
| 68 | Nav Main | 1 button | Navigation main |
| 69 | DatabaseUpdate | 4 scripts | Nav DB update |
| 71 | **Engineering Nav** | 5 (1 choice + 4 script) | Nav engineering |
| 72-76 | GPS/Route sub-screens | varies | Position, satellites, route |
| 77 | Map Nav | 8 | Map display settings |
| 80 | TMC Nav | 2 | Traffic channel |
| 81 | TrafficOnline Nav | 19 | Online traffic |

### System
| # | Screen | Elements | Description |
|---|--------|----------|-------------|
| 17 | **Browser Main** | 3 | Web browser config |
| 26 | **Config Main** | 7 scripts | System config (DHCP/IP) |
| 28 | CrossUnitCom | 2 choices | Cross-unit communication |
| 52 | Display Main | 13 | Display diagnostics |
| 53 | EmergencyUpdate | 8 | Emergency firmware update |
| 54 | FrontCtrl Main | 1 button | Front controller |
| 64-66 | MOST | varies | MOST network |
| 94 | SDS Main | 16 | Speech dialog system |
| 95 | Serial_If_Test | **42 elements** | Serial interface test |

### Connectivity
| # | Screen | Elements | Description |
|---|--------|----------|-------------|
| 16 | Bluetooth Main | 2 choices | BT settings |
| 83-85 | SD slots | varies | SD card info |
| 106 | USB Main | 5 | USB diagnostics |
| 109 | WLAN Main | 4 | WiFi settings |

## Key Persistence Addresses

### Car Device List (per 3)
```
0x00100010  Air conditioning
0x00100011  Auxiliary heating
0x00100012  Head-up display
0x00100013  Adaptive Cruise Control
0x00100014  Suspension
0x00100015  Tyre pressure (RDK)
0x00100016  Interior light
0x00100017  Exterior light
0x00100018  Park distance control
0x00100019  Rearview camera
0x0010001A  Wiper
0x0010001B  Door locking
0x0010001C  Mirror
0x0010001D  On-board computer
0x0010001E  Clock
0x0010001F  Service interval
0x00100020  Central units master (ZEM)
0x00100021  Compass
0x00100022  Charisma
0x00100023  Lane departure warning (HCA)
0x00100024  Lane change assist (SWA)
0x00100025  ...more
```

### Navigation (per 1)
```
0x00030000  DB available
0x00030001  Demo mode active
0x00030002  Nav language (string)
0x00030003  Metric system
0x000300AE  Distance unit (km/miles)
```

### Kombi Coding (per 1)
```
0x0009000B  High Kombi toggle
0x0009000C  Audio display (on/off)
0x0009000D  Telephone display (on/off)
0x0009000E  Navigation display (on/off)
```

### Config (per 1)
```
0x00090003  IP assignment (string)
```
