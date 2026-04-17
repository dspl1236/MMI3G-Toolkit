# MMI3G Engineering Access System

The Green Engineering Menu (GEM) is backed by 36 `CEngineeringAccessPresCtrl*`
controller classes inside `MMI3GApplication`. Each controller exposes a
subsystem's internal state for reading and writing via DSI 64-bit keys.
Together they form an API that covers every component of the head unit.

This document catalogs every controller, its known keys, and the
implications for custom app development and firmware modification.

Source: string analysis of `MMI3GApplication` (10.7 MB SH4 ELF) from
MU9411 K0942_4 variant 41 (`8R0906961FB`).

## Architecture

### Request / Response Pattern

All engineering access uses a common base class pattern:

```
CEngineeringAccessPresCtrlBase
  → requestReadInt(key)        read a 32-bit value
  → requestReadString(key)     read a string
  → requestReadBuffer(key)     read a byte buffer
  → requestReadArray(key)      read an int array
  → requestWriteInt(key, val)  write a 32-bit value
  → requestWriteString(key)    write a string
  → requestWriteBuffer(key)    write a byte buffer
  → requestWriteArray(key)     write an int array
  → processEvent(event)        handle async DSI notifications
```

Keys are 64-bit DSI persistence addresses (`%llx` format in log strings).
Upper 32 bits = namespace, lower 32 bits = address. Each controller maps
its own set of human-readable key names to these addresses.

Responses are async — a `requestReadInt(key)` triggers a DSI read, and
the result arrives via `processEvent()` callback. Log messages indicate
availability: "data for key (%llx) is available: %d" (success) or
"data for key (%llx) is not available. Sending default: %d" (fallback).

### Source File Convention

Each controller has a `.cpp` source with naming:
```
CEngineeringAccessPresCtrl<Name>.cpp
```
And a persistence registration string:
```
project_presctrl_collect_persistence_CEngineeringAccessPresCtrl<Name>
```

### Log Prefix Convention

- `!PPC:` — error (problem detected)
- `#PPC:` — info (normal operation)
- `PPC:` — general trace

## Complete Controller Catalog

### 1. Addressbook
**File:** `CEngineeringAccessPresCtrlAddressbook.cpp`
**Capabilities:** Contact database read/write.

### 2. AmFmRadio
**File:** `CEngineeringAccessPresCtrlAmFmRadio.cpp`
**Capabilities:** AM/FM tuner engineering. Debug command handler:
`project_presctrl_collect_amfmtuner_triggerDebugCommand`.

### 3. AudioManagement
**File:** `CEngineeringAccessPresCtrlAudiomanagement.cpp`
**Capabilities:** Audio routing, source switching, volume control, fade,
entertainment connection management.
**Known operations:**
- Read volume info, active entertainment connection
- Write: source switch, fade to connection
- `reasonLowerEntBit` — entertainment lowering reason bitmap
- Debug: `AudioManagement_requestTriggerDebugCommand`
**Proxies:** `mSPHAMEngineeringProxyPtr` (audio management engineering)

### 4. Base
**File:** `CEngineeringAccessPresCtrlBase.cpp`
**Note:** Abstract base class. Implements request queuing:
"Queuing the Request: requestType = %d; key = %llx, pendingRequestId(%llx)"

### 5. Bluetooth
**File:** `CEngineeringAccessPresCtrlBluetooth.cpp`
**Known keys:**
- `BT_ON_OFF_ACTUAL` — current BT power state
- `BT_ON_OFF_STORED` — persisted BT power preference
- `BT_SNIFF_MODE_ON_OFF` — BT sniff mode toggle
- `ACTIVATE_A2DP` — A2DP audio streaming activation
- `AUTO_CONNECT` — auto-connect handset toggle
- `PASSKEY` — pairing passkey response
- `HFP` — Hands-Free Profile
- `disableHFPIfNoCradle` — conditional HFP disable
**Proxies:** `mSGBluetoothGapProxyPtr`, `mSPHBluetoothProxyPtr`, `mSPHBtPresCtrlProxyPtr`

### 6. Config
**File:** `CEngineeringAccessPresCtrlConfig.cpp`
**Capabilities:** System configuration persistence. Direct read/write
of IOC and SIS identifiers.
**Known operations:**
- `requestReadInt key(%llx)` / `requestWriteInt key(%llx) value(%x)`
- `requestReadString key(%llx)` / `requestWriteString key(%llx)`
- Handles IOC ID and SIS ID notifications
**Proxy:** `mPersistenceProxyPtr` — direct persistence access

### 7. Cradle
**File:** `CEngineeringAccessPresCtrlCradle.cpp`
**Capabilities:** Phone cradle diagnostics.
**Proxy:** `mSCradleDiagnoseProxyPtr`

### 8. Dab
**File:** `CEngineeringAccessPresCtrlDab.cpp`
**Capabilities:** DAB digital radio engineering.
**Debug:** `project_presctrl_collect_dabtuner_triggerDebugCommand`

### 9. Dvd
**File:** `CEngineeringAccessPresCtrlDvd.cpp`
**Known keys:**
- `CURRENT_DRIVE_TEMPERATURE` — current optical drive temp
- `MAX_DRIVE_TEMPERATURE` — maximum recorded drive temp
- `INSERTED_DISK_STATE` — disk slot state / drive state
- `INSERTED_DISK_TYP` — media type (CD-Audio, DVD-Video, VCD, SVCD, etc.)
- `IS_DISK_IN_DRIVE` — boolean disk presence
- `EJECT_KEY_STATE` — eject button state
- `INTERACTION_STATE` — playback mode/state
- `REGIONCODE_OF_INSERTED_DVD` — region code of current disc
- `REGION_CODE_ACTUAL` — system region code setting
- `PLAYBACKSTATE_*` — PLAYING, PAUSED, STOPPED, SEEK_SLOWFW, SEEK_SLOWBW
**Write operations:** EJECT command, DVD test start/stop
**Media type conversion:** CD-Audio, DVD-Video, DVD-Audio, Video-CD, SVCD, CDROM/DVDROM
**Proxies:** `mSGDriveProxyPtr`, `mSGMmeDVDProxyPtr`, `mSGMmePlaybackProxyPtr`,
`mSPDiagDVDTestProxyPtr`, `mSPHMediaProxyPtr`, `mSPHMediaRightProxyPtr`,
`mSPHKeyPanelProxyPtr`

### 10. Fscs ⚠️ CRITICAL
**File:** `CEngineeringAccessPresCtrlFscs.cpp`
**Capabilities:** FSC (Freischaltcode) activation code management.
**Known operations:**
- `set swid %.8x` — set Software ID for activation
- `The status of %.8x is %d` — query activation status of a feature
- `Public Key Type %d` — read the public key type used for FSC verification
- `FscResponse %d` — FSC validation response
- `Data invalid` — FSC data validation failure
**Proxy:** `CSPHCryptoManagerDiagnosisProxy` — crypto manager for FSC operations
**Note:** This is the GEM-accessible interface to the FSC subsystem.
It can query which features are activated and their status codes.
The `set swid` operation suggests SWIDs can be set from GEM,
which may be relevant to nav DB activation.

### 11. Hdd
**File:** `CEngineeringAccessPresCtrlHdd.cpp`
**Known keys:**
- `HDD_CURRENT_TEMPERATURE` — current HDD temp
- `HDD_MAX_TEMPERATURE` — maximum recorded HDD temp
- Parking mode enable/disable
- Media storage size management
**Write operations:** `requestWriteInt` for parking mode, media store size
**Error:** "value for storing media (%d) is too big"

### 12. Hmi
**File:** `CEngineeringAccessPresCtrlHmi.cpp`
**Capabilities:** HMI attribute control, jukebox reset, infotainment recording.
**Known operations:** Jukebox reset trigger.
**Proxies:** `mSPHDiagHMIAttribsProxyPtr`, `mSPHDiagHMIMethodsProxyPtr`,
`mSPHInfotainmentRecorderProxyPtr`, `mSPHWlanProxyPtr`

### 13. Mme
**File:** `CEngineeringAccessPresCtrlMme.cpp`
**Capabilities:** Media management engine — play engine left/right, drive control, DTCP.
**Proxies:** `mPlayEngineProxyLeft`, `mPlayEngineProxyRight`, `mSGDriveProxyPtr`, `mSPDTCPSetupProxyPtr`

### 14. Most
**File:** `CEngineeringAccessPresCtrlMost.cpp`
**Capabilities:** MOST bus allocation table read, sync routing.
**Proxies:** `mHBMOSTServiceBrokerProxyPtr`, `mHBSyncRoutingProxyPtr`

### 15. MostCombi
**File:** `CEngineeringAccessPresCtrlMostCombi.cpp`
**Capabilities:** MOST combination device engineering.

### 16. MostCombiStats
**File:** `CEngineeringAccessPresCtrlMostCombiStats.cpp`
**Capabilities:** MOST combination device statistics.

### 17. Navi
**File:** `CEngineeringAccessPresCtrlNavi.cpp`
**Known keys:**
- GPS: `NUM_OF_LOCKED_SATELLITES`, `NUM_OF_PHASE_LOCKED_SATTELITES`,
  `QUALITY_STATE_AGC_VALUE`, `QUALITY_STATE_GPS_NOISE`
- Nav DB: `DATABASE_CHECKING`, `DATABASE_CRC_CHECKING`, `DELETE_CONSUMER_DATA`
- License: `LICENSE_NUMBER`, `LICENSE_ACTIVATION_DATE`, `LICENSE_ACTIVATION_TIME`,
  `LICENSE_EXPIRATION_DATE`
- Connection: `CONNECTION_LAST_DATE`, `CONNECTION_LAST_TIME`, `CONNECTION_LAST_STATUS`
- PSD (Predictive Speed Data): 20+ `PSD_DATASET_*` keys — road profile data
  for ACC/predictive driving (ADAS, atlas, clothoid, FRC levels 0-7,
  guidance, IPD, urban, offroad lengths, tree horizon/segment averages,
  UTC timestamps, on/off toggle)
**Write operations:** `requestWriteInt`, `requestWriteString` for nav settings
**Note:** PSD data is the predictive road model used by ACC and
transmission shift strategy. Engineering access can read and toggle it.

### 18. RadioUnit
**File:** `CEngineeringAccessPresCtrlRadioUnit.cpp`
**Capabilities:** Radio unit hardware info, device info events.

### 19. SWDL ⚠️ CRITICAL
**File:** `CEngineeringAccessPresCtrlSWDL.cpp`
**Capabilities:** Software download control from GEM.
**Known operations:**
- `requestReadInt key(%llx)` — read SWDL state values
- `requestWriteInt key(%llx) value(%x)` — write SWDL control values
**Note:** This controller bridges the GEM to the SWDL state machine
(`CASWDLManagerStates`). Through it, the GEM can potentially trigger
firmware update operations: start, abort, query status, control
the update source (DVD, USB, network).

### 20. Sd
**File:** `CEngineeringAccessPresCtrlSd.cpp`
**Capabilities:** SD card device info, extended device info.
**Proxy:** `mSPHMlDeviceInfoProxyPtr`
**Note:** Searches SD devices and reads device info. Key for
understanding how the MMI discovers SD-delivered content.

### 21. Sdars
**File:** `CEngineeringAccessPresCtrlSdars.cpp` (Sirius/XM)
**Debug:** `project_presctrl_collect_sdarstuner_triggerDebugCommand`

### 22. Sds (Speech Dialogue System)
**File:** `CEngineeringAccessPresCtrlSds.cpp`
**Capabilities:** Speech recognition engineering. Read/write DSI values.

### 23. SerialIfTest
**File:** `CEngineeringAccessPresCtrlSerialIfTest.cpp`
**Capabilities:** Serial interface testing — ETC, iPod, VICS ports.
**Known keys:**
- `START_SERIAL_TEST_IPOD` — trigger iPod serial test
- `START_SERIAL_TEST_VICS` — trigger VICS serial test
- `START_STOP_SERIAL_TEST_ETC` — toggle ETC serial test
**Proxies:** `mSPDiagSerETCProxyPtr`, `mSPDiagSerIPODProxyPtr`, `mSPDiagSerVICSProxyPtr`
**Note:** These serial tests exercise the physical UART connections.
Useful for hardware debugging.

### 24. System ⚠️ CRITICAL
**File:** `CEngineeringAccessPresCtrlSystem.cpp`
**Capabilities:** System-level operations including **file system write**.
**Known keys:**
- `HFP_PASS_KEY` — HFP passkey read
- General int/string/buffer read/write via DSI keys
**File write:** `requestWriteString` can write to files:
"The file %s could not be opened for write" (error path confirms
the success path writes to arbitrary files)
**Note:** This is the most powerful engineering access controller.
File write capability means the GEM can modify system files
on the running system — configs, scripts, potentially even
firmware components in writable partitions.

### 25. Telephony
**File:** `CEngineeringAccessPresCtrlTelephony.cpp`
**Known keys:**
- `GSM_ON_OFF_ACTUAL` — GSM modem power state
- `ACCEPT_CALL` — trigger call acceptance
- `EMERGENCY_LED_ON_OFF` — eCall LED control
- `NB_OF_CONNECTED_HUC` — number of connected handsets
- `SIMID` — SIM card identifier
- eCall test mode: `UPD_ID_responseSetECallTestModePersistent`
- Phone power: `UPD_ID_responseTelPower`
- Cradle/handset count: `UPD_ID_responseGetBthsInCradleCount`, `UPD_ID_responseGetCradleCount`
**Write:** Phone number buffer write, eCall LED toggle

### 26. Tim
**File:** (reference only: `CEngineeringAccessPresCtrlTim`)
**Debug:** `project_presctrl_collect_timtuner_triggerdebugcommand`

### 27. Tmc
**File:** (reference only: `CEngineeringAccessPresCtrlTmc`)
**Capabilities:** Traffic Message Channel engineering.

### 28. TraceScope
**File:** `CEngineeringAccessPresCtrlTraceScope.cpp`
**Capabilities:** Runtime trace/logging control.
**Known operations:**
- `requestReadInt` / `requestReadString` — read trace scope settings
- `requestWriteInt key(%llx) value(%x)` — set trace scope
- `requestWriteString key(%llx) value %s` — set trace scope string
**Error:** "value for trace scope (%d) is too big"
**Note:** Controls the MMI's internal debug logging. Setting
appropriate trace scopes enables detailed logging of specific
subsystems to the HDD or SD card.

### 29. TunerAnnouncement
**File:** (persistence reference only)
**Capabilities:** Radio announcement engineering.

### 30. Tv
**File:** `CEngineeringAccessPresCtrlTv.cpp`
**Capabilities:** TV tuner video management.
**Proxy:** `mSGVideoManagementProxyPtr`

### 31. Usb
**File:** `CEngineeringAccessPresCtrlUsb.cpp`
**Capabilities:** USB device info, removable media.
**Proxies:** `mSGRemovableMediaProxyPtr`, `mSPHMedialistProxyPtr`

### 32. VWTouchData
**File:** `CEngineeringAccessPresCtrlVWTouchData.cpp`
**Capabilities:** VW/Audi touch panel data.
**Proxy:** `mSPHKeyPanelProxyPtr`

### 33. VersionInfos
**File:** `CEngineeringAccessPresCtrlVersionInfos.cpp`
**Capabilities:** Version information for all system components.

### 34. Video
**File:** `CEngineeringAccessPresCtrlVideo.cpp`
**Capabilities:** Video output management.
**Proxy:** `mSGVideoManagementProxyPtr`

### 35. Wlan
**File:** `CEngineeringAccessPresCtrlWlan.cpp`
**Capabilities:** WiFi/WLAN engineering.
**Proxies:** `mSPHIpDiagProxyPtr`, `mSPHWlanDiagProxyPtr`, `mSPHWlanProxyPtr`

## Debug Command Infrastructure

A `requestTriggerDebugCommand` mechanism is available across multiple
subsystems. Each accepts `command`, `param1`, `param2` (and sometimes `param3`)
as integer parameters:

```
callBackTriggerDebugCommand - command: %d - param1: %d - param2:%d
```

Subsystems with debug commands:
- AM/FM tuner
- DAB tuner
- SDARS tuner
- TIM tuner
- Car facade (vehicle integration)
- Car parking system
- Key panel
- On/Off controller
- System info
- HMI sync (rear)
- MOST RSU adapter

The key panel debug command handler (`CKeyPanelDevCtrl::requestTriggerDebugCommand`)
is particularly interesting — it suggests button combinations can trigger
debug functionality.

## Reboot Triggers

Three reboot mechanisms accessible from engineering access:

| Trigger | Target | Use |
|---------|--------|-----|
| `requestTriggerReboot %d` | Main CPU | Soft reboot, parameter controls mode |
| `requestTriggerRebootPanel` | Display panel | Panel-only reboot |
| `requestTriggerIocBoloReboot` | IOC bootloader | IOC re-enters bootloader mode |

The IOC bootloader reboot is significant — it puts the I/O Controller
into a state where firmware can be reflashed. Combined with the SWDL
engineering access, this could enable IOC firmware updates from the GEM.

## Security Infrastructure

### SecSi (Secure Silicon)

OTP (One-Time Programmable) memory access and flash lock management:

```
SecSi: hw sample %x -> offset 0x400    (hardware sample detection)
SecSi: Locking down flash: %d          (flash write protection)
SecSi: Retry to read OTP %d            (OTP read with retry)
SecSi: content %.2x%.2x%.2x%.2x...    (OTP content dump)
SecSi: Send SIGUSR2 to devf-generic    (signal flash driver)
```

Two implementations:
- `CASWDLAccessSecSi` — SWDL uses SecSi during firmware flashing
- `CCMAccessSecSi` — Crypto Manager uses SecSi for key storage

Hardware sample detection maps sample codes to flash offsets:
- e1 → no offset (E-sample, direct access)
- Other samples → offset 0x400

Security log: `/HBpersistence/FSC/Logs/Security_Exceptions.log`

### Factory Reset

Multiple reset entry points:
- `requestRevertToFactorySettings` — full factory reset
- `requestResetToFactorySettings` — alias
- `requestRestoreFactorySettings` — alias
- `requestFactoryReset` — alias
- `requestResetFactorySettings` — alias
- `requestSetAPSFactoryDefault` — APS (Audio Pilot System) reset
- `requestRevertCallstacks` — call history reset

## DSI Self-Test Mode

Built-in diagnostic self-test:

```
notification-id %d: starting selftest (all responses/notifications with sample values are sent)...
```

When triggered, the DSI stack sends synthetic responses with sample values
to all registered listeners. This exercises the complete notification
pipeline without requiring real hardware state changes. Useful for
verifying DSI client implementations (like per3-reader) in isolation.

## SWDL Class Hierarchy

The complete Software Download (SWDL) implementation:

| Class | Purpose |
|-------|---------|
| `CASWDLManagerStates` | Overall state machine (dumped with `dumpState`/`dumpStates`) |
| `CASWDLClient` | Client-side SWDL interface |
| `CASWDLAutoRun` | Auto-run handler (SD card auto-update) |
| `CASWDLFileCopyManager` | File copy state machine with selection/progress |
| `CASWDLFileCopyThread` | Threaded file copy (Check + Write variants) |
| `CASWDLFileAccesWorker` | File access worker thread |
| `CASWDLImageManager` | Flash image management |
| `CASWDLScriptManager` | Update script execution |
| `CASWDLCompatibilityManager` | Version/variant compatibility checking |
| `CASWDLAccessSecSi` | Secure silicon access during flash |
| `CASWDLSvmManager` | SVM (Software Version Management) for ODIS |
| `CASWDLRsuComMaster/Slave` | RSU communication for satellite tuner updates |
| `CASWDLDeviceTable` | Device enumeration |
| `CASWDLContainerEvent` | State machine events |
| `CASWDLMainUVersions` | Main unit version tracking |
| `CASWDLOnOffClient` | Power management (requestStart/Stop/Restart) |
| `CASWDLDigitalRight` | DRM/digital rights during update |
| `CASWDLTestMD` | Update test mode |

The `CASWDLAutoRun` class is significant — it handles automatic
firmware updates from inserted media. Combined with the `skipCrc = true`
bypass and the GEM's SWDL engineering access, this provides a
complete pathway for SD-card-triggered firmware modification.

## Implications for Custom App Development

### Path 1: GEM Screen + Engineering Access (easiest)

Custom GEM screens (ESD files) can call any engineering access
controller's read/write methods via DSI keys. A GEM screen that
calls `CEngineeringAccessPresCtrlConfig::requestWriteInt` can
modify system configuration. A screen that calls
`CEngineeringAccessPresCtrlSystem::requestWriteString` can
write to arbitrary files.

This is the mechanism our existing toolkit modules use (gauges-dashboard,
system-info, etc.). The engineering access catalog above shows the
full range of what's accessible from GEM.

### Path 2: OSGi Bundle + DSI (per3-reader pattern)

A Java OSGi bundle dropped into the `lsd.jxe` classpath can register
as a `DSIPersistenceListener` and receive async DSI notifications
from any subsystem. The per3-reader module demonstrates this pattern.

With the engineering access catalog, a bundle could:
- Monitor GPS satellite count in real time
- Read HDD/DVD temperatures
- Query FSC activation status
- Trigger debug commands across subsystems
- Control trace scope for targeted logging

### Path 3: Native Binary + DSI (future)

A native SH4 binary could use the DSI C++ API directly
(`libdsiservice.so`) to perform the same operations. This requires
the SH4 cross-compiler (not yet set up) but would give the
highest performance and lowest-level access.

### Path 4: Firmware Modification (now possible)

With the complete firmware pipeline (inflate → patch → repack → CRC),
the engineering access controllers themselves can be modified. For
example, removing the "Invalid key!" checks would allow writing to
keys that are currently read-only, or adding new engineering screens
that expose additional functionality.

## References

- `MMI3GApplication` — primary binary, 10.7 MB SH4 ELF
- `DSI_ARCHITECTURE.md` — DSI IPC framework documentation
- `HMI_ARCHITECTURE.md` — boot sequence and process graph
- `FIRMWARE_UPDATE_FORMAT.md` — SWDL verification and bypass
- `PER3_READER.md` — per3-reader OSGi bundle design
