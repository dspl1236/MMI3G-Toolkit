# SIA Service Reset — Cross-Platform Discovery

## Date: May 6, 2026
## Source: MMI3GApplication string analysis (56,582 strings, K0821 firmware)

---

## The Discovery

MMI3GApplication (Audi MMI3G+) has a **complete service interval reset system**
built in. The reset command travels from the head unit to the instrument cluster
via two protocols: **BAP** (older clusters) and **CDEF** (newer clusters).

**Porsche PCM3Root has zero SIA code.** Porsche deliberately stripped the entire
service reset system from their firmware. PCM3Root has no `InspectionReset`,
no `SIA` strings, no `SPHCarKombi::RQST_InspectionReset` — nothing.

---

## BAP Protocol Overview

**BAP = Bedien- und Anzeigeprotokoll** (Control and Display Protocol).
A VW Group standard for communication between head units and instrument
clusters. Defined in VW specification BAP 3.0.

### Architecture

```
ASG (Application Software Group)  = Head unit (MMI3G / PCM)
FSG (Function Software Group)     = Instrument cluster, A/C, parking, etc.
LSG (Logical Software Group)      = Logical grouping of functions
```

ASG sends commands → FSG executes and reports status back.

### BAP Message Format

```
┌─────────┬──────────┬────────┬─────────────────┐
│ LSG ID  │ FKT ID   │ OpCode │ Payload         │
│ (1 byte)│ (1 byte) │ (1 byte)│ (variable)     │
└─────────┴──────────┴────────┴─────────────────┘
```

- **LSG ID** — Target module (e.g., 0x01 = Aircon, cluster has its own ID)
- **FKT ID** — Function within the LSG (e.g., InspectionReset, SetClock, etc.)
- **OpCode** — Operation type (Get, Set, Status, Error, etc.)
- **Payload** — Function-specific data

### BAP Transport

On Audi MMI3G+, BAP runs over **MOST** (fiber optic bus) via `BapCommDevCtrl`.
The `CBapCommDevCtrl` handles MOST-to-BAP translation.

On vehicles with CAN-only clusters, BAP can also run directly over CAN.
The `CACarDeviceList` tracks per-device: `IsBAPUsed` flag and `CAN-Bus` number.

### BAP vs CDEF

Both protocols coexist in MMI3GApplication:

| Feature | BAP | CDEF |
|---------|-----|------|
| Handler | `CCarKombiBAPHandler.cpp` | `CCarKombiCDEFHandler.cpp` |
| Transport | MOST (fiber optic) | CAN (direct) |
| Cluster type | Older (pre-MY2015) | Newer (MY2015+) |
| Reset command | `BAP - sendInspectionReset` | `CDEF - sendInspectionReset` |

Both converge at the same DSI interface:
`SPHCarKombi::RQST_InspectionReset` / `SPHCarKombiExt::RQST_InspectionReset`

---

## SIA (Service Interval Adjustment) System

### Data Fields

| Field | String | Description |
|-------|--------|-------------|
| OilDistance | `[Car][SIA] OilDistance %d` | km until oil change |
| OilTime | `[Car][SIA] OilTime %d` | days until oil change |
| InspectionDistance | `[Car][SIA] InspectionDistance %d` | km until inspection |
| InspectionTime | `[Car][SIA] InspectionTime %d` | days until inspection |
| OilDistanceStatus | `mSIAOilDistanceStatus %d` | status flags |
| OilDistanceUnit | `mSIAOilDistanceUnit %d` | unit encoding |

Combined status: `ServiceDistance - ServiceTime - OilDistance - OilTime - OilReset`

### DSI Update IDs

| UPD_ID | Direction | Description |
|--------|-----------|-------------|
| `UPD_ID_SIAOilInspection` | Cluster → MMI | Oil/inspection counter data |
| `UPD_ID_SIAServiceData` | Cluster → MMI | Service data (full record) |
| `UPD_ID_SIACapabilities` | Cluster → MMI | What resets are supported |
| `UPD_ID_SIAViewOptions` | Cluster → MMI | Display options for HMI |
| `UPD_ID_requestInspectionReset` | MMI → Cluster | **THE RESET COMMAND** |

### SIA Data Processing

```
processStatusSIA           — Main SIA data parser
processStatusSIADaten      — Raw SIA data bytes
processStatusSIAOilDistanceTime    — Oil distance/time extraction
processStatusSIAInspectionDistanceTime — Inspection distance/time
processStatusSIAReset      — Reset confirmation handler
processStatusSIAViewOptions — Display config
```

The SIA data arrives as a byte stream:
```
processStatusSIA - stream of size %d for func id %x
processStatusSIA - byte at pos %d: %d
processStatusSIA - Record pos: %d - No error
```

### Reset Flow (Audi MMI3G+)

```
1. User navigates to Car → Service menu in HMI
2. HMI calls requestInspectionReset
3. DSI framework dispatches:
   → SPHCarKombi::RQST_InspectionReset      (standard interface)
   → SPHCarKombiExt::RQST_InspectionReset   (extended interface)
4. Handler selects protocol based on cluster type:
   → BAP: CCarKombiBAPHandler → sendInspectionReset → MOST bus
   → CDEF: CCarKombiCDEFHandler → sendInspectionReset → CAN bus
5. Instrument cluster receives and resets counters
6. Cluster sends updated SIA data back:
   → processStatusSIAReset - No error
7. MMI updates display with new values
```

---

## Relevance to PCM-Forge (Porsche)

### Why PCM3Root Can't Do This

Porsche removed the entire SIA subsystem from PCM3Root. There are:
- No `SPHCarKombi::RQST_InspectionReset`
- No `BAP - sendInspectionReset`
- No `CDEF - sendInspectionReset`
- No `UPD_ID_requestInspectionReset`
- No `processStatusSIA*` functions
- No `[Car][SIA]` logging

The Cayenne 958's instrument cluster still understands the reset command
(it's a VW Group platform cluster), but PCM3Root simply never sends it.
Porsche wants you to go to the dealer.

### Possible Paths for Porsche Service Reset

**Path 1: BAP/CDEF command injection via IOC**
The Cayenne's cluster is likely CDEF (2016 model year). If the IOC probe
captures CDEF frames on ch2/ch6/ch8, we can craft and inject the
InspectionReset CDEF command. Requires reverse-engineering the CDEF
frame format from captured traffic.

**Path 2: UDS via external OBD-II**
Standard approach: DiagnosticSessionControl → RoutineControl → reset.
VNCI 6154a + ODIS E17 via Touareg 7P platform compatibility.
This bypasses the PCM entirely.

**Path 3: Port the Audi SIA code concept**
Write a standalone QNX binary that implements the BAP/CDEF
sendInspectionReset. Deploy via USB script. Requires IOC probe data
to determine CAN arbitration IDs and CDEF frame format.

---

## Relevance to MMI3G-Toolkit (Audi)

### Root Shell Approach (Immediate)

With root shell access on the Audi A6 (192.168.0.154:2323), we can
potentially trigger the reset directly via DSI IPC:

1. **Find the DSI endpoint** — `SPHCarKombi` or `SPHCarKombiExt`
   registers as a DSI service. Find its process/channel.

2. **Send the DSI message** — `UPD_ID_requestInspectionReset`
   through the DSI framework.

3. **Or trace the BAP/CDEF handler** — find the binary-level function
   for `sendInspectionReset` and call it via GDB (qconn is available).

### ESD Engineering Screen Approach

The Audi engineering menu already has vehicle settings screens.
A custom ESD could expose:

```
screen ServiceReset Car

script
   value    sys 1 0x0100 "/scripts/service_reset.sh"
   label    ">> RESET OIL SERVICE <<"

script
   value    sys 1 0x0100 "/scripts/inspection_reset.sh"
   label    ">> RESET INSPECTION <<"

keyValue
   value    int per 3 0x0010001F
   label    "Service interval:"
   poll     3000
```

The `sys 1` command can execute any shell script. The script would
need to interface with the DSI framework or directly invoke the
BAP/CDEF command.

---

## Key Source Files (in MMI3GApplication)

| File | Purpose |
|------|---------|
| `CCarKombiBAPHandler.cpp` | BAP protocol handler for cluster |
| `CCarKombiCDEFHandler.cpp` | CDEF protocol handler for cluster |
| `CCarKombiPresCtrl.cpp` | Kombi presentation controller (UI) |
| `CSPHCarKombiSA.cpp` | DSI service adapter for Kombi |
| `CSPHCarKombiExtSA.cpp` | DSI service adapter for KombiExt |
| `CBapCommDevCtrl.cpp` | BAP communication device controller |
| `CSPHBapCommProxy.cpp` | BAP communication proxy |

---

## BAP Function Catalog (from MMI3GApplication)

### Kombi (Instrument Cluster)
- `sendInspectionReset` — Reset service interval
- `sendResetBCDisplayData` — Reset board computer display
- `sendSetBCDisplayData` — Set board computer display
- `sendSetClockDate` / `sendSetClockTime` — Set date/time
- `sendSetClockFormat` / `sendSetClockSource` — Clock config
- `sendSetLanguage` — Set display language
- `sendSetConsumptionUnit` — Fuel consumption unit
- `sendSetDistanceSpeedUnit` — Distance/speed unit
- `sendSetDistanceUnit` — Distance unit
- `sendSetTemperatureUnit` — Temperature unit
- `sendSetPressureUnit` — Tire pressure unit
- `sendSetVolumeUnit` — Volume unit
- `sendSetDateFormat` — Date format
- `sendSetWarningVelocityData` — Speed warning
- `sendSetShiftUpIndication` — Shift indicator

### Climate (A/C)
- `sendKlimaTemperatur` — Set temperature
- `sendKlimaLuftVerteilung` — Set air distribution
- `sendSitzHeizung` — Seat heating
- `sendSitzLueftung` — Seat ventilation
- `sendSwitchAUXHeater` — Aux heater
- `sendACMiddleExhaustion` — Middle vent

### Lights
- `sendSetDoorLockingAutoLock` — Auto lock
- `sendSetDoorLockingComfort` — Comfort locking
- `sendSetWiperServicePosition` — Wiper service position

---

## Next Steps

1. **IOC Probe (Porsche)** — Run the probe, capture CAN traffic from
   ch2/ch6/ch8. Look for BAP/CDEF frames to/from cluster.

2. **Root Shell Test (Audi)** — Connect to 192.168.0.154:2323,
   enumerate DSI services, find SPHCarKombi endpoint.

3. **BAP Frame Capture** — If BAP/CDEF traffic is visible on IOC
   channels, capture the InspectionReset frame format when triggered
   from a dealer tool (ODIS/PIWIS).

4. **Standalone Binary** — Write a QNX SH4 binary that sends the
   CDEF InspectionReset command via IOC, deploy via USB.
