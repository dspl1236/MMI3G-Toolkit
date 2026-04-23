# Component Protection Architecture — MMI3G+ Live System Analysis

**Date:** April 23, 2026
**System:** HN+R_US_AU_K0942_3 (QNX 6.3.2, SH7785 792MHz)
**Method:** Root shell via port 2323 (inetd ksh backdoor)

## Executive Summary

Component Protection (CP) on the Audi MMI3G+ operates through a
multi-layer architecture spanning MOST bus, IPC channels, native
C++ classes, and AES-128 encryption. This document consolidates
findings from binary string analysis, live filesystem exploration,
and process inspection.

## Architecture Overview

```
┌──────────────────────────────────────────────────┐
│  ODIS / VCDS / Diagnostic Tool                   │
│  (UDS Service 0x31 — RoutineControl)             │
└───────────────┬──────────────────────────────────┘
                │ CAN / K-Line / DoIP
                v
┌──────────────────────────────────────────────────┐
│  Gateway (J533)                                   │
│  Routes CP request to target ECU address          │
└───────────────┬──────────────────────────────────┘
                │ MOST Bus / CAN
                v
┌──────────────────────────────────────────────────┐
│  MMI3G+ (5F) — MMI3GApplication                   │
│  ┌─────────────────────────────────────────────┐ │
│  │ CSPHComponentProtectionSA.cpp               │ │
│  │  ├── SPHComponentProtection::RQST_AuthString│ │
│  │  ├── SPHComponentProtection::RPST_AuthString│ │
│  │  ├── FAZIT list check (IN/NOT IN LIST)      │ │
│  │  └── IKA key (DID 0x00BE, 34 bytes)         │ │
│  └────────────────┬────────────────────────────┘ │
│                   │ DSI IPC                       │
│  ┌────────────────v────────────────────────────┐ │
│  │ cipher-aes.so (IFS-resident)                │ │
│  │  ├── aes_encrypt_key128                     │ │
│  │  └── aes_decrypt_key128                     │ │
│  └─────────────────────────────────────────────┘ │
│  ┌─────────────────────────────────────────────┐ │
│  │ CryptoManager (FSC + CP dual role)          │ │
│  │  ├── CCryptoManagerImpl                     │ │
│  │  ├── CCryptoManagerDiagnosisImpl            │ │
│  │  ├── NDigitalRights namespace               │ │
│  │  └── CCMAccessSecSi (Secure Silicon)        │ │
│  └─────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────┘
```

## IPC Infrastructure (Live System)

### SCP Bus Devices
```
/dev/scp_nws  — Networking Service (NWSProcess)
/dev/scp_pss  — Phone/PSS Service (PSSBSSProcess) ← CP routes here
/dev/scp_sss  — Speech/SDS Service (SSSProcess)
```

### IPC Channels (/dev/ipc/)
```
ch2-ch5   — active (opened at 00:38)
ch6-ch7   — early init (00:02)
ch8       — active
ch9       — early init
ch10-ch11 — mixed
debug     — read-only debug channel
ioc/      — IOC directory (sub-channels)
onoff     — power state channel
watchdog  — system watchdog
```

## Cryptographic Keys (Live System)

### RSA Public Keys (/HBpersistence/Keys/)
```
DataKey/DK_public_signiert.bin    256 bytes  cksum=810658289
FSCKey/FSC_public_signiert.bin    256 bytes  cksum=810658289
MetainfoKey/MI_public_signiert.bin 256 bytes  cksum=810658289
```

**CRITICAL FINDING:** All three keys have IDENTICAL checksums.
This means they are either:
1. The same RSA-2048 public key used for all three purposes
2. Placeholder/default keys from factory provisioning
3. A master VW Group public key shared across all signing operations

These keys are used for FSC signature verification (confirming
activation codes are genuine VW-signed), data package integrity,
and metainfo validation during firmware updates.

### AES-128 Encryption (cipher-aes.so)
The CP challenge-response uses AES-128:
- `aes_encrypt_key128` — set up encryption key
- `aes_decrypt_key128` — set up decryption key
- Key source: IKA key from DID 0x00BE (34 bytes)
- The 34-byte IKA contains a 16-byte AES key + metadata

## CryptoManager Security Log

The Security_Exceptions.log shows CryptoManager status at every boot:
```
CM Report: Pr.Md 0, EL St. 1, Vin St. 1, State 20
```

Fields:
- **Pr.Md 0** = Protection Mode 0 (normal operation, not in service mode)
- **EL St. 1** = Exception List Status 1 (exception list present/valid)
- **Vin St. 1** = VIN Status 1 (VIN matches expected value)
- **State 20** = FSC system state 20 (0x14 = fully operational)

One anomalous entry on RTC reset boot:
```
1970-01-01_00:00  CM Report: Pr.Md 0, EL St. 1, Vin St. 1, State 12
```
- **State 12** (0x0C) = transitional/initializing state before reaching 20

## FSC System

### Active FSCs
```
/HBpersistence/FSC/0004000B.fsc  (202 bytes)
  SWID: 0x0004000B (Navigation Update)
  Date: 2015-03-23
  Signature: 128 bytes RSA
```

### FSC Validation Pipeline
```
1. FSC file parsed: header (SWID, flags) + timestamp + signature
2. CCMFscCheckJobPolicy validates against RSA public key
3. TDigitalRightsSignatureCheckJob verifies signature
4. CCMExceptionListCheckJobPolicy checks exception list
5. Result stored in UPD_ID_fscList / UPD_ID_illegalFSCs
```

## Component Protection Flow (Challenge-Response)

Based on binary string analysis (126 CP references in MMI3GApplication):

```
1. Diag tool sends RoutineControl Start (0x31 01 XX YY)
   → RoutiContrStartRoutiCompoProte

2. MMI3GApplication receives via MOST/CAN → CP proxy

3. CSPHComponentProtectionSA processes:
   a. Checks FAZIT list ("FAZIT IN LIST AVAILABLE")
   b. If found → generates challenge via RQST_AuthString
   c. Reads IKA key from DID 0x00BE
   d. AES-128 encrypts challenge with IKA key
   e. Returns challenge to diag tool

4. Diag tool computes response:
   a. Uses same IKA key (obtained from GEKO/online)
   b. AES-128 processes challenge
   c. Sends response via RPST_AuthString

5. MMI3GApplication verifies:
   a. Decrypts response
   b. Compares with expected value
   c. If match → CP authenticated → feature unlocked
```

## CP Key Storage Locations

### Where CP keys are NOT stored (confirmed via live search):
- No files named `*compo*`, `*cprot*`, `*fazit*`, `*ika*` anywhere on filesystem
- Not in `/HBpersistence/` as named files
- Not in `/mnt/efs-persist/` as named files

### Where CP keys likely ARE stored:
1. **DataPST.db** (51,200 bytes at `/HBpersistence/DataPST.db`)
   - QNX QDB format (not standard SQLite)
   - CP keys stored as persistence entries with 64-bit DSI addresses
   - Namespace + address pair identifies each CP value

2. **EEPROM via I2C** (`dev-i2c-hbfpga` available)
   - IKA key may be in hardware EEPROM on the main board
   - Accessed via `dev-i2c-hbfpga` driver

3. **Runtime memory** of MMI3GApplication (PID 204844)
   - Address space: 11,194,368 bytes (`/proc/204844/as`)
   - CP keys loaded into RAM at boot from persistence

## Process Map (Live System)

| PID | Process | CP Role |
|-----|---------|---------|
| 204844 | MMI3GApplication | Main CP handler, CSPHComponentProtectionSA |
| 204845 | MMI3GNavigation | CP-protected feature (navigation) |
| 245823 | MMI3GMedia | CP references (70 strings) |
| 266243 | MMI3GMisc | CP references (79 strings) |
| 348224 | MMI3GTelephone | Telephony subsystem |
| 221194 | j9 (lsd.jxe) | Java HMI, DSIComponentProtection proxy |
| 290883 | NWSProcess | Network, uses /dev/scp_nws |
| 331844 | PSSBSSProcess | Phone/PSS, uses /dev/scp_pss |
| 507983 | gemmi_final | Google Earth renderer |

## Available Tools for Further Exploration

| Tool | Path | Purpose |
|------|------|---------|
| `qconn` | /bin/qconn | QNX remote debug agent — enables GDB |
| `nc.shle` | /usr/bin/nc.shle | Netcat — file transfer |
| `qdbc` | /usr/bin/qdbc | QDB database client |
| `mmecli` | /bin/mmecli | MME CLI interface |
| `nicinfo` | /bin/nicinfo | Network interface details |
| `rdhex` | /usr/bin/rdhex | Read hex (script, needs investigation) |
| `wrhex` | /usr/bin/wrhex | Write hex |
| `vi` | /bin/vi | Text editor |
| `sloginfo` | /bin/sloginfo | System log viewer |
| `grep` | /usr/bin/grep | Basic grep (no -o flag) |

## Next Steps

### Immediate (root shell available)
1. **Start qconn** — enables remote GDB debugging of MMI3GApplication
   ```
   qconn &
   ```
   Then from a cross-compiled GDB, attach to PID 204844 and inspect
   CP data structures in memory.

2. **Transfer DataPST.db** for offline analysis:
   ```
   cat /HBpersistence/DataPST.db | nc.shle -w 3 <PC_IP> 9999
   ```

3. **Transfer RSA keys** for analysis:
   ```
   cat /HBpersistence/Keys/FSCKey/FSC_public_signiert.bin | nc.shle -w 3 <PC_IP> 9998
   ```

4. **Investigate rdhex/wrhex** — may provide direct EEPROM access

5. **Check I2C bus** for EEPROM:
   ```
   dev-i2c-hbfpga  (check if running or start it)
   ```

### Offline Analysis
1. Parse DataPST.db with QNX QDB tools or reverse-engineer format
2. Extract RSA public key from signed .bin files (DER/BER encoded)
3. Cross-reference CP routine IDs from ES_LIBCompoProteGen3V12.sd.db
4. Set up SH4 cross-GDB for remote debugging via qconn
