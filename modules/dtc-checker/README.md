# DTC Checker Module

Onboard Diagnostic Trouble Code reader for the MMI3G.

## How It Works

The MMI3G's V850 IOC (I/O Controller) already has full diagnostic
capability through the vehicle's CAN bus using VW/Audi's TP2.0
transport protocol. The IOC communicates DTCs to the SH4 main CPU
via DSI namespace 2 (IPC channel 2).

```
GEM Screen → DSI per 2 → IPC ch2 → V850 IOC (TP2.0) → CAN → ECUs
```

The firmware already includes three DTC screens (by M. Wolf at
Harman Becker), but they're limited to 10 rows and split across
separate screens. This module provides a unified view with 20 rows.

## Screens

### DTC_Overview (Main)
Shows all qualified (active) DTCs in a single table with:
- **Code**: Standard OBD DTC code (P0xxx, B0xxx, C0xxx, U0xxx)
- **Status**: Current DTC status
- **Name**: Human-readable description
- **Clear All DTCs** button

### DTC_Detail
Select a specific DTC by number and view detailed status flags:
- **!T**: Test not completed
- **S**: Stored in memory
- **A**: Currently active
- **L**: Last cleared

### DTC_Control
Send test results or clear error memory for specific DTCs.

## Installation

Copy `ToolkitDTC.esd` to the SD card's engdefs directory:
```
SD:\HBpersistence\engdefs\ToolkitDTC.esd
```

Or use the toolkit builder to include this module.

## Access

1. Hold **CAR + SETUP** simultaneously (3 seconds)
2. Navigate to **Toolkit → DTC_Overview**

## DSI Addresses

| Address | Type | Function |
|---------|------|----------|
| per 2 0x00010001 | slider | Select DTC by index |
| per 2 0x00010002 | table | Single DTC detail |
| per 2 0x00010003 | table | All qualified DTCs |
| per 2 0x00010006 | button | Send test passed |
| per 2 0x00010007 | button | Send test failed |
| per 2 0x00010008 | button | Clear error memory |

## V850 IOC Diagnostic Protocol

The V850 IOC firmware implements:
- **TP2.0** (cfTP20): VW/Audi diagnostic transport over CAN
- **MOST diagnostics** (cfDiagMost): MOST bus diagnostic channel
- **KWP2000** (KWPC/KWPS): Keyword Protocol client/server
- **Gateway** (cfappgateway): Vehicle bus gateway

These protocols allow the IOC to communicate with ALL vehicle ECUs
that support VW/Audi diagnostic protocols, including engine,
transmission, ABS, airbag, instrument cluster, and more.
