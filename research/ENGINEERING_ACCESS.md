# MMI3G Engineering Access System

The Green Engineering Menu (GEM) exposes a comprehensive internal API
to every subsystem of the MMI3G head unit through a hierarchy of
**36 Engineering Access Presentation Controllers**. Each controller
wraps a specific domain (audio, navigation, Bluetooth, SWDL, FSC, etc.)
and provides `requestReadInt`, `requestReadString`, `requestReadBuffer`,
`requestWriteInt`, `requestWriteString`, and `requestWriteBuffer`
methods keyed by 64-bit DSI persistence addresses.

This document catalogs the controllers, their capabilities, and the
DSI constants that drive them. All data extracted from string analysis
of `MMI3GApplication` (10.7 MB SH4 ELF, build 9411, K0942_4 variant 41).

Source files: `CEngineeringAccessPresCtrl*.cpp` (35+ source files
compiled into the monolithic binary).

## Architecture

```
GEM Screen (ESD)
  |
  v
CEngineeringAccessPresCtrlBase          <-- base class, queues requests
  |
  |-- CEngineeringAccessPresCtrlConfig  <-- read/write persistence
  |-- CEngineeringAccessPresCtrlFscs   <-- FSC/activation codes
  |-- CEngineeringAccessPresCtrlSWDL   <-- firmware update control
  |-- CEngineeringAccessPresCtrlNavi   <-- navigation DSI values
  |-- ... (36 controllers total)
  |
  v
DSI Proxy/Stub layer (requestReadInt/requestWriteInt with 64-bit keys)
  |
  v
QNX IPC to target service (SPH*, SG*, SC* adapters)
```

Each controller has a persistence path registered with the DSI
framework: `project_presctrl_collect_persistence_CEngineeringAccessPresCtrl<Name>`.

Log prefix convention:
- `!PPC:` -- error
- `#PPC:` -- info / constructor trace
- `PPC:` -- normal operation


## Critical controllers

### CEngineeringAccessPresCtrlFscs -- FSC / Activation Code Management

Source: `CEngineeringAccessPresCtrlFscs.cpp`

The FSC controller interfaces with the CryptoManager subsystem to
query, import, and validate Feature Service Codes.

Key operations observed in strings:
- `set swid %.8x` -- set the active SWID for FSC operations
- `The status of %.8x is %d` -- query activation status of a SWID
- `Public Key Type %d` -- query which RSA public key is active
- `FscResponse %d` -- FSC validation result
- `CSPHCryptoManagerDiagnosisProxy` -- interfaces with diagnosis layer

DSI update IDs:
- `UPD_ID_areFSCsSigned` -- whether FSCs require signature validation
- `UPD_ID_fscList` -- list of all FSCs on the system
- `UPD_ID_illegalFSCs` -- list of FSCs that failed validation

CryptoManager class hierarchy:
- `CCryptoManagerComp` -- component shell
- `CCryptoManagerImpl` -- core implementation
- `CCryptoManagerDiagnosisImpl` -- diagnostic interface
- `CCryptoManagerHMIImpl` -- HMI interface
- `CCMFSCFacade` -- FSC facade pattern
- `CCMFscCheckJobPolicy` -- FSC check policy
- `CCMExceptionListCheckJobPolicy` -- exception list check
- `CCMAccessSecSi` -- Secure Silicon access
- `NDigitalRights` -- namespace for digital rights management
- `TDigitalRightsSignatureCheckJob` -- signature verification job
- `TDigitalRightsExceptionListCheckJob` -- exception list check job
- `TDigitalRightsFscDetailsJob` -- FSC detail query job
- `TDigitalRightsFileSystemCheckJob` -- filesystem check job

HMI integration:
- `SPHCryptoManagerHMI::RQST_importFSCs` -- import FSC files from media
- `SPHCryptoManagerHMI::RQST_fscDetails` -- query FSC details
- `SPHCryptoManagerHMI::RPST_importFSCs` -- response to import
- `SPHCryptoManagerHMI::RPST_fscDetails` -- response to details query
- `SPHCryptoManagerHMI::ATST_fscList` -- attribute: FSC list
- `SecureCodeActivation.SPHCryptoManager` -- service name

OTP (One-Time Programmable) fuse integration:
- `isSwidInOTP` -- check if SWID is burned into OTP
- `swid in OTP %.8x` -- SWID found in OTP
- `swid in OTP (static) %.8x` -- static/factory SWID in OTP
- `%d swids found in OTP` -- count of OTP SWIDs

Some features may be hardware-locked via OTP fuses, not just
software-gated via FSC files. The GEM can query which SWIDs are
in OTP vs. filesystem-activated.


### CEngineeringAccessPresCtrlSWDL -- Software Download Control

Source: `CEngineeringAccessPresCtrlSWDL.cpp`

Controls the firmware update subsystem from the GEM.

Operations:
- `requestReadInt key(%llx)` -- read SWDL state
- `requestWriteInt key(%llx) value(%x)` -- trigger SWDL operations

DSI update IDs:
- `UPD_ID_DomainStatus_SWDL` -- SWDL domain status
- `UPD_ID_SWDLRunning` -- whether SWDL is currently active
- `UPD_ID_SwdlActive` -- SWDL active flag

Power management integration:
- `SPHPowerManagement::ATST_SwdlActive` -- keeps system awake during flash
- `COnOffPresCtrl` monitors SWDL state to prevent shutdown during flash

SWDL implementation classes (from the SWDL subsystem, not the GEM controller):
- `CASWDLAccessSecSi.cpp` -- Secure Silicon access during update
- `CASWDLAutoRun.cpp` -- auto-run handler for media-triggered updates
- `CASWDLCheckedSocketStream.cpp` -- verified network stream
- `CASWDLClient.cpp` -- SWDL client
- `CASWDLClientBaseHelper.cpp` -- client helpers
- `CASWDLCompatibilityManager.cpp` -- version compatibility checks
- `CASWDLEintrRetries` -- interrupt retry handling
- `CASWDLFileAccesWorker` -- file access worker thread
- `CASWDLFileCopyManager` -- file copy state machine
- `CASWDLManagerStates` -- overall SWDL state machine
- `CASWDLRsuComMaster` -- RSU communication master
- `CASWDLRsuComSlave` -- RSU communication slave
- `CASWDLSvmManager` -- SVM (ODIS) integration
- `CASWDownloadCtrlDataContainer` -- central state container


### CEngineeringAccessPresCtrlSystem -- System File Access

Source: `CEngineeringAccessPresCtrlSystem.cpp`

Can read system values AND write files to the filesystem.

Operations:
- `requestReadInt key(%llx)` -- read system values
- `requestReadString` -- read strings (e.g., `HFP_PASS_KEY`)
- `requestReadBuffer` -- read binary data
- `requestWriteString: The file %s could not be opened for write` --
  confirms file-write capability through the GEM

GEM screens can write arbitrary files to writable mount points
(`/HBpersistence/`, `/mnt/efs-persist/`, SD card). This is a
powerful primitive for custom app deployment.


### CEngineeringAccessPresCtrlConfig -- Persistence Configuration

Source: `CEngineeringAccessPresCtrlConfig.cpp`

Read/write the persistence database (per3) through GEM.

Operations:
- `requestReadInt key(%llx)` -- read per3 int
- `requestReadString key(%llx)` -- read per3 string
- `requestWriteInt key(%llx) value(%x)` -- write per3 int
- `requestWriteString key(%llx)` -- write per3 string
- Handles both IOC IDs and SIS IDs


## Hardware interface controllers

### CEngineeringAccessPresCtrlNavi (59 strings)

Extensive read/write access to navigation subsystem:
- GPS satellite counts: `NUM_OF_LOCKED_SATELLITES`, `NUM_OF_PHASE_LOCKED_SATTELITES`
- GPS quality: `QUALITY_STATE_AGC_VALUE`, `QUALITY_STATE_GPS_NOISE`
- Database checking: `DATABASE_CHECKING`, `DATABASE_CRC_CHECKING`
- License info: `LICENSE_ACTIVATION_DATE`, `LICENSE_EXPIRATION_DATE`, `LICENSE_NUMBER`
- Connection state: `CONNECTION_LAST_DATE`, `CONNECTION_LAST_STATUS`
- PSD (Predictive Speed Data): 20+ dataset parameters for ADAS
- Consumer data deletion: `DELETE_CONSUMER_DATA`

### CEngineeringAccessPresCtrlDvd (90 strings -- largest)

Complete DVD drive diagnostic interface:
- Temperature: `CURRENT_DRIVE_TEMPERATURE`, `MAX_DRIVE_TEMPERATURE`
- Disk state: `INSERTED_DISK_STATE`, `IS_DISK_IN_DRIVE`
- Region codes: `REGIONCODE_OF_INSERTED_DVD`, `REGION_CODE_ACTUAL`
- Drive commands: `EJECT`, loader state
- Media type detection: CD-Audio, DVD-Video, DVD-Audio, SVCD, VCD
- Playback states: playing, paused, stopped, seek
- Parental lock: `PML_STATUS`
- Test modes: `requestStartDVDTest`, `requestStopDVDTest`

### CEngineeringAccessPresCtrlBluetooth (28 strings)

- Power control: `BT_ON_OFF_ACTUAL`, `BT_ON_OFF_STORED`
- A2DP streaming activation
- Sniff mode: `BT_SNIFF_MODE_ON_OFF`
- Autopairing and passkey
- Allocation table queries

### CEngineeringAccessPresCtrlTelephony (46 strings)

- GSM power: `GSM_ON_OFF_ACTUAL`
- SIM card: `SIMID`
- eCall: `EMERGENCY_LED_ON_OFF`, `requestSetECallTestModePersistent`
- Handset counts: `NB_OF_CONNECTED_HUC`
- Call control: `UPD_ID_AcceptCall`
- File management: can delete files

### CEngineeringAccessPresCtrlHdd (26 strings)

- Temperature: `HDD_CURRENT_TEMPERATURE`, `HDD_MAX_TEMPERATURE`
- Parking mode control
- Media storage capacity
- HDD diagnostics

### CEngineeringAccessPresCtrlAudioManagement (25 strings)

- Source switching with fade transitions
- Volume control: `UPD_ID_Volume`
- Entertainment connection management
- Mute: `LC_MUTE_ENT`
- Audio lowering reasons

### CEngineeringAccessPresCtrlWlan (16 strings)

WiFi diagnostics, IP diagnostics, WiFi state management.

### CEngineeringAccessPresCtrlHmi (15 strings)

HMI controls, jukebox reset, infotainment recorder.

### CEngineeringAccessPresCtrlSerialIfTest (25 strings)

Serial interface testing for ETC, iPod, VICS with per-interface statistics.

### CEngineeringAccessPresCtrlMost (20 strings)

MOST bus allocation table, sync routing, service broker.

### CEngineeringAccessPresCtrlSd (44 strings)

SD card device info, device search, media list integration.


## Remaining controllers

| Controller | Strings | Domain |
|-----------|---------|--------|
| Usb | 9 | USB device management |
| Video | 8 | Video management |
| Mme | 14 | Media engine (play, DTCP) |
| MostCombi | 11 | MOST bus combination |
| MostCombiStats | 5 | MOST statistics |
| Cradle | 7 | Phone cradle |
| VWTouchData | 7 | VW touch panel |
| TraceScope | 8 | Trace level control |
| Sds | 17 | Speech dialogue |
| VersionInfos | 3 | Version queries |
| AmFmRadio | 4 | AM/FM tuner |
| Addressbook | 3 | Contacts |
| Dab | 3 | DAB digital radio |
| Tv | 3 | TV tuner |
| Sdars | 2 | SiriusXM satellite radio |
| Tim | 2 | TIM |
| Tmc | 2 | Traffic Message Channel |
| TunerAnnouncement | 1 | Radio announcements |
| RadioUnit | 5 | Radio hardware |


## Debug command system

A `requestTriggerDebugCommand` handler exists across multiple subsystems.
Each takes a command ID + two parameters:

```
callBackTriggerDebugCommand - command: %d - param1: %d - param2: %d
```

Subsystems with debug command handlers:
- Key panel
- On/off control
- AM/FM tuner, DAB tuner, satellite tuner, TIM tuner
- Car facade, parking system
- HMI sync (rear display)
- System info
- Audio management


## System reboot triggers

Three reboot levels:

| Trigger | Effect |
|---------|--------|
| `requestTriggerReboot %d` | Normal system reboot (parameter controls mode) |
| `requestTriggerRebootPanel` | Panel/display reboot only |
| `requestTriggerIocBoloReboot` | IOC bootloader reboot -- reboots the I/O Controller into bootloader mode for IOC firmware update |


## DSI engineering mode constants

| UPD_ID | Purpose |
|--------|---------|
| `isEngineeringMode` | Query: is engineering mode active? |
| `engineeringMenuState` | Current engineering menu state |
| `engineering` | Engineering mode flag |
| `diagnosticMode` | Diagnostic mode flag |
| `requestEnterEngineeringSession` | Enter engineering session |
| `requestExitEngineeringSession` | Exit engineering session |

Factory reset variants:
- `requestFactoryReset`
- `requestResetFactorySettings`
- `requestResetToFactorySettings`
- `requestRestoreFactorySettings`
- `requestRevertToFactorySettings`
- `requestRevertCallstacks`
- `requestSetAPSFactoryDefault`
- `requestInspectionReset`

Total DSI API surface: **2,386 UPD_ID constants** across all subsystems.


## SecSi -- Secure Silicon subsystem

The SecSi module manages hardware security features.

Hardware sample to OTP offset mapping:
- E1 sample: no OTP offset (base)
- Other samples: offset 0x400

OTP operations:
- Read with retry
- Content dump and sanity check
- SWID enumeration from OTP fuses

Flash operations:
- Flash partition locking via `Locking down flash`
- Signals `SIGUSR2` to `devf-generic` flash driver

Security logging:
- `/HBpersistence/FSC/Logs/Security_Exceptions.log`


## DSI self-test mode

A built-in self-test exercises the entire DSI stack:

```
notification-id %d: starting selftest (all responses/notifications
with sample values are sent)...
```

Sends synthetic DSI notifications with sample data through all
registered listeners. Useful for testing custom DSI clients without
live vehicle data.


## Network references

- `/dev/shmem/TelitAmsshd` -- SSH daemon (Telit modem subsystem)
- `172.16.250.248` -- MMI network IP (per M.I.B documentation)


## Implications for custom app development

1. **GEM screens can call any controller** -- custom ESD screen
   definitions can invoke read/write on any of the 36 controllers
   using the appropriate 64-bit DSI key.

2. **File write capability** -- the System controller can write
   files to writable mount points, enabling GEM-triggered deployment.

3. **FSC import from media** -- `SPHCryptoManagerHMI::RQST_importFSCs`
   means FSC files can be imported from SD/USB through the GEM.

4. **SWDL from GEM** -- the SWDL controller has write methods,
   suggesting firmware updates can be initiated from the engineering
   menu (confirmed by `03 Remove HBUPDATE.def from USB` /
   `04 Activate HBUPDATE.def on USB` found in PCM3Reload IFS2).

5. **Debug commands** -- a generic `command + param1 + param2` RPC
   interface across 11+ subsystems.

6. **IOC bootloader reboot** -- enables IOC firmware updates without
   physical board access.


## References

- `MMI3GApplication` build 9411 C1 D1-15515A, QNX 6.3.2
- Source: `CEngineeringAccessPresCtrl*.cpp` (529 strings, 36 controllers)
- DSI interface specs: `research/DSI_ARCHITECTURE.md`
- GEM activation: `modules/gem-activator/`
- Per3 addresses: `research/PER3_ADDRESS_MAP.md`
