# Oil Service Reset — Architecture Decoded from MMI3GApplication Binary

## Discovery Date: May 8, 2026
## Source: strings analysis of D:\MMI\ifs_extract\MMI3GApplication (10.7MB SH4 ELF)

## Reset Command Architecture

The oil/inspection reset travels through **two parallel paths**:

### Path 1: CDEF (CAN Data Exchange Format)
- Handler: `CCarKombiCDEFHandler` (CCarKombiCDEFHandler.cpp)
- Method: `CDEF - sendInspectionReset`
- Transport: CAN bus via V850 IOC
- Used on: Platforms with CAN-connected clusters (PCM 3.1, some Audi variants)

### Path 2: BAP (Bedien- und Anzeigeprotokoll)
- Method: `BAP - sendInspectionReset`
- Transport: MOST fiber optic ring
- Used on: Audi MMI3G+ with MOST-connected clusters

### DSI Framework (abstraction layer)
Both paths are triggered through the DSI (Device Service Interface):
- `SPHCarKombi::RQST_InspectionReset` — base CarKombi interface
- `SPHCarKombiExt::RQST_InspectionReset` — extended CarKombi interface
- Event chain: `CSPHCarKombiRequestEvent` → handler → CDEF or BAP

## SIA Data Model (Service Interval Adjustment)

### Status Functions (cluster → MMI, periodic reporting)
- `SPHCarKombi::ATST_SIAOilInspection` — oil + inspection distances/times
- `SPHCarKombi::ATST_SIAServiceData` — full service data
- `SPHCarKombi::ATST_SIACapabilities` — available SIA functions
- `processStatusSIAReset` — reset confirmation handler

### Request Functions (MMI → cluster, user-triggered)
- `requestInspectionReset` / `request_InspectionReset`
- `sendInspectionReset` (called by both CDEF and BAP handlers)

### Data Fields
| Field | Description |
|-------|-------------|
| OilDistance | Distance until oil service (km) |
| OilTime | Time until oil service (days) |
| OilReset | Oil service reset flag |
| InspectionDistance | Distance until inspection |
| InspectionTime | Time until inspection |
| ServiceDistance | Distance until next service |
| ServiceTime | Time until next service |

### DSI Update IDs
- `UPD_ID_SIAOilInspection` — triggers on oil/inspection data change
- `UPD_ID_SIAServiceData` — triggers on service data change
- `UPD_ID_SIACapabilities` — triggers on capability change

## CDEF Function Map

All CDEF commands sent by CCarKombiCDEFHandler to cluster (LSG 0x11):

| Function | CDEF Method |
|----------|-------------|
| **Inspection Reset** | `sendInspectionReset` |
| Set Clock Time | `sendSetClockTime` |
| Set Clock Date | `sendSetClockDate` |
| Set BC Display Data | `sendSetBCDisplayData` |
| Reset BC Display | `sendResetBCDisplayData` |
| Set Language | `sendSetLanguage` |
| Set Units | `sendSet{Distance,Pressure,Volume,Temperature,Consumption}Unit` |

## IPC Capture Analysis

### Baseline (idle)
- BAP header: `12 02` → LSG=4, FKT=32, OpCode=2 (STATUS)
- Payload: `1A 01 00 00 00 00 00 00 00 00 00 00 00 00`

### During Oil Service Reset
- BAP header: `44 02` → LSG=17 (0x11=Cluster!), FKT=0, OpCode=2 (STATUS)
- Payload byte 2 transitions: `06` → `05` → `08` → `06`
- All messages OpCode 2 (STATUS) — SET command goes via MOST, not IPC ch5

## Implications for Cayenne PCM 3.1

The Cayenne uses CDEF path (CAN, not MOST):
`CCarKombiCDEFHandler` → `SPHCarKombi proxy` → CDEF encoder → CAN → Cluster

Next: Ghidra disassembly of `sendInspectionReset` for CDEF CAN message format,
or direct UDS via OBD2 (RoutineControl 0x31 / WriteDataByIdentifier 0x2E).
