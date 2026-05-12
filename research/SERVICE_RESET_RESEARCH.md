# Service Reset Research — SIA / Oil / Inspection

> Consolidated from SIA_SERVICE_RESET_DISCOVERY.md and OIL_SERVICE_RESET_ARCHITECTURE.md.
> For Porsche-specific UDS findings, see PCM-Forge research/SERVICE_RESET_RESEARCH.md.

## Reset Command Architecture

The oil/inspection reset uses two parallel paths through the DSI framework:

**CDEF path** (CAN Data Exchange Format): `CCarKombiCDEFHandler.sendInspectionReset()` → CAN bus → Cluster. Used on PCM 3.1 and some Audi variants with CAN-connected clusters.

**BAP path** (Bedien- und Anzeigeprotokoll): `BAP - sendInspectionReset` → MOST fiber → Cluster. Used on Audi MMI3G+ with MOST-connected clusters.

Both triggered via DSI: `SPHCarKombi::RQST_InspectionReset` / `SPHCarKombiExt::RQST_InspectionReset`

## SIA Data Model

| Field | Description |
|-------|-------------|
| OilDistance | Distance until oil service (km) |
| OilTime | Time until oil service (days) |
| OilReset | Oil service reset flag |
| InspectionDistance | Distance until inspection |
| InspectionTime | Time until inspection |
| ServiceDistance | Distance until next service |
| ServiceTime | Time until next service |

DSI Update IDs: `UPD_ID_SIAOilInspection`, `UPD_ID_SIAServiceData`, `UPD_ID_SIACapabilities`

## BAP Protocol (Audi MMI3G+)

BAP header (2 bytes): `[LSG_ID:6][FKT_high:2] [FKT_low:4][OpCode:4]`

LSG 0x11 = Cluster, FKT 0x03 = SIA. OpCodes: GET=0, SET=1, STATUS=2, ERROR=3.

IPC transport: Type 0x0F Sub 0x03 on ch5 (A6). Live capture during reset showed status byte transitions `06→05→08→06` confirming cluster acknowledgment, but the SET command travels via MOST (not visible on IPC channels).

## CDEF Function Map (from MMI3GApplication)

CCarKombiCDEFHandler sends to cluster (LSG 0x11): sendInspectionReset, sendSetClockTime, sendSetClockDate, sendSetBCDisplayData, sendResetBCDisplayData, sendSetLanguage, sendSetDistanceUnit, sendSetTemperatureUnit, sendSetConsumptionUnit, and more.

## Audi MMI3G+ Reset Paths

**Root shell (immediate):** Write BAP SET command directly to `/dev/ipc/ch5`. Requires binary write capability — ksh `echo -ne` and `printf` don't support `\x` escapes on QNX. Need `awk` or cross-compiled tool.

**GEM ESD screen:** Create custom ESD with `sys 1 0x0100` script button that executes the reset. Would give touchscreen oil reset from the engineering menu.

## BAP Function Catalog (from MMI3GApplication strings)

### Kombi (Instrument Cluster)
SIA status/reset, clock time/date, BC display data, language, units, warning velocity, shift up indication, interior light values.

### Climate (A/C)
Temperature, fan speed, mode, recirculation, seat heating, defrost.

### Lights
Turn signals, low/high beam, fog lights, DRL.

## Source Files
- `MMI3GApplication` (10.7MB SH4 LE, K0821/K0942)
- `CCarKombiCDEFHandler.cpp`, `CCarKombiBAPHandler.cpp`
- `CSPHCarKombi.cpp`, `CSPHCarKombiExt.cpp`
- Live IPC captures from A6 root shell
