# ESD Screen Format — GEM Engineering Screen Definitions

The Green Engineering Menu (GEM) renders its screens from `.esd` files
(Engineering Screen Definition) stored in `/mnt/efs-system/engdefs/`.
The GEM framework auto-discovers and indexes all `.esd` files in this
directory at boot time.

This document specifies the ESD format based on analysis of 173 screen
definition files extracted from the MU9411 K0942_4 efs-system.efs.

## Overview

ESD files are **plain ASCII text** with a simple hierarchical syntax.
No binary format, no XML parsing, no compilation step. Drop a `.esd`
file into engdefs, reboot, and the screen appears in the GEM menu.

## File structure

```
#############################################
#  Engineering screen definition
#  <author> <date>
#############################################

screen <ScreenName> <ParentScreen>

   <widget>
      value    <source> <namespace> <address> [params]
      label    "<display text>"
      [poll     <interval_ms>]
      [format   <multiplier> "<pattern>"]

   <widget>
      ...
```

## Screen declaration

```
screen <Name> <Parent>
```

- **Name**: screen identifier (shown in GEM menu)
- **Parent**: parent screen name. `Main` = top-level menu.
  Sub-screens reference their parent: `screen Radio Main`,
  `screen CurrentStation SDARS`, etc.

The GEM builds its menu tree from these parent-child relationships.

## Data sources

### `per` — DSI Persistence (most common)

```
value [type] per <namespace> <address>
```

Reads/writes a value through the DSI persistence layer. The 64-bit
address is the same key used by `CEngineeringAccessPresCtrl*::requestReadInt`.

- `int per 1 0x00020003` — read integer from namespace 1, address 0x00020003
- `String per 3 0x0011000A` — read string from namespace 3
- `per 1 0x00190002` — type inferred from widget context

Known namespaces:
- 0: Power/timer domain
- 1: General DSI persistence (largest — most engineering values)
- 2: DTC (diagnostic trouble codes) domain
- 3: System/identification domain
- 4: Performance/monitoring domain
- 5: IRC (Intelligent Resource Control) domain

### `sys` — System calls

```
value [type] sys <namespace> <address>
value sys 1 0x0100 "/path/to/script.sh"
```

Direct system calls. When a path is provided, the system executes
the script. Used by `script` widgets and Java system queries.

## Widget types

### keyValue — Read-only display

```
keyValue
   value    int per 1 0x00020003
   label    "Fan speed"
   poll     1000
```

Displays a label and its current value. `poll` interval in milliseconds
controls refresh rate. Common for monitoring temperatures, voltages,
versions, and status values.

Format modifier:
```
keyValue
   value    int per 3 0x00000023
   label    "battery voltage (x100 mV)"
   poll     500

keyValue
   value    int per 3 0x00000024
   format   2 hex
   label    "cable code info (hex)"
```

The `format` field: first arg is display width or multiplier, second
is the format pattern (`hex`, or a DecimalFormat string like `"####.##"`).

### slider — Adjustable value

```
slider
   value    per 1 0x0002000F 0 2
   label    "Mode"
   poll     0
```

The two trailing numbers after the address are min and max range.
`poll 0` means read once, don't auto-refresh.

Indexed slider variant (three addresses = value, min, max):
```
slider
   value    per 234524 20016 20017 20018
   label    "Indexed Slider"
   limits   keys
   poll     0
```

### choice — Boolean toggle / selection

```
choice
   value    per 1 0x001E0004
   label    "ignore region and variant"
```

Simple on/off toggle. The DSI value is read and displayed as a
boolean choice.

### button — Action trigger

```
button
   value    per 1 0x00050043 "0"
   label    "connect UMTS (channel 0)"
```

Writes the quoted value to the DSI address when pressed. The string
after the address is the value to write.

### script — Execute shell script

```
script
   value    sys 1 0x0100 "/scripts/myScript.sh"
   label    "Start Script"
```

Executes the specified shell script when activated. Scripts run with
system privileges on the QNX RTOS.

### table — Data table

```
table
   content  per 1 0x00130001
   label    "Central Registry"
   poll     10000
   columns  ( "Number" String 150 ) ( "DeviceID" String 150 )
   maxrows  46
   orientation horizontal
```

Displays tabular data from a DSI array source. Column definitions
specify name, type, and width. `orientation` is `horizontal` (default)
or `vertical`.

### BIOSCtrl — Enumerated dropdown

```
BIOSCtrl
   value    int per 3 0x0011000E
   label    "Watchdog SH4 status:"
   entry    "8 minutes" 32
   entry    "60 minutes" 240
   entry    "disabled" 241
   poll     1000
```

Dropdown selector where each `entry` maps a display string to a
numeric value. Named "BIOSCtrl" because it was originally used for
BIOS-level configuration.


## Key screens for modding

### SWDL.esd — Firmware update control

```
screen SWDL Main
   keyValue  "count down"          int per 3 0x00120000  poll 1000
   keyValue  "HW index IT"         int per 3 0x00120002  poll 1000
   keyValue  "unexpected resets"   int per 3 0x00120003  poll 1000
   keyValue  "current version"     String per 3 0x00120001  poll 1000
   choice    "user defined mode"   per 1 0x001E0000
   choice    "ignore region and variant"  per 1 0x001E0004
```

The `ignore region and variant` toggle (DSI key `0x001E0004`) bypasses
the variant checking during firmware updates. Combined with
`user defined mode` (`0x001E0000`), this enables cross-variant flashing
directly from the GEM — no ODIS required.

### Scripts.esd — Script execution

```
screen Scripts AEVTest
   script
      value  sys 1 0x0100 "/scripts/myScript.sh"
      label  "Start Script"
```

Custom scripts can be triggered from GEM. Place scripts on writable
storage and reference them here.

### System.esd — System control

Key DSI addresses:
- `per 3 0x00110013` — production mode status
- `per 1 0x00050043` — connect UMTS
- `per 3 0x00000023` — battery voltage (×100 mV)
- `per 1 0x00050035` — system tone selection (range 10-13)
- `per 3 0x0011000A` — serial number
- `per 3 0x0011000C` — VW system name
- `per 1 0x5003b` — CPU load
- `per 1 0x00050045` — activate LSD development mode
- `per 1 0x00050046` — activate LSD production mode
- `per 1 0x00050047` — activate LSD consolidated mode

### EepromFlags.esd — EEPROM configuration

- `per 3 0x0011000D` — import multimedia lock status (slider 0-3)
- `per 3 0x0011000E` — Watchdog SH4 status (8min / 60min / disabled)

### JavaSys.esd — Java runtime

- `sys 1 1` — free runtime memory (KB)
- `sys 1 0x002` — total runtime memory (KB)
- `sys 1 0x003` — trigger garbage collection


## Complete ESD file catalog (173 files)

### System / Main
Main.esd, System.esd, Config.esd, OnOffTimer.esd, Onoff.esd,
EepromFlags.esd, Environment.esd, JavaSys.esd, CoreDump.esd,
SparePartNumbers.esd, Internal.esd, CrossUnitCom.esd

### Firmware / Update
SWDL.esd, Scripts.esd

### Diagnostics
Diagnose.esd, DiagnoseCoding.esd, DiagnoseSettings.esd,
DiagnoseCode15Micro.esd, DiagnoseCode17Telefon.esd,
DiagnoseCodeIntModules_1-2.esd, DiagnoseDrive.esd,
DiagnoseKombi.esd, DiagnosePml.esd, DiagnoseSet0300Telefon.esd,
DiagnoseSet0400Media.esd, DiagnoseSet1000Ami.esd,
DiagnoseSetA00WLAN.esd

### DTC (Diagnostic Trouble Codes)
Dtc.esd, Dtc_changed.esd, Dtc_control.esd, Dtc_qualified.esd,
Dtc_single.esd, Dtc_untested.esd

### Version Info (AAA prefix = sort to top of menu)
AAAVersion.esd, AAA1VersionMU.esd, AAA2VersionRU.esd,
AAA3VersionDU.esd, AAA4VersionAudio.esd, AAA5VersionTelephony.esd,
AAA6VersionMost.esd, AAA7VersionBt.esd,
AAA8VersionInstrumentCluster.esd, AAA9VersionFrontCtrl.esd,
AAA11VersionMuSh4.esd, AAA12VersionMuIoc.esd

### Audio
AudioManagement.esd, AudioManagementInputGainOffset.esd,
AudioManagementMisc.esd, AudioManagementVolumeRanger.esd,
FakeAudio.esd

### Radio / Tuner
Radio.esd, AMFM.esd, AMFMBandInfo.esd, AMFMDiagTest.esd,
AMFMSingleTunerTest.esd, AMFMStationList.esd,
AMFMTMCStationList.esd, AMFMTestModeA/C/D/E/V.esd,
TunerAnnouncement.esd, TunerAnnouncementFilter.esd,
TunerAnnouncementStatus.esd

### DAB Digital Radio
DAB.esd, DABBackgroundScan.esd, DABComponentList.esd,
DABCurrentStation.esd, DABDataServiceFilter.esd,
DABDataServiceList.esd, DABDiagTest.esd, DABEnsembleList.esd,
DABLinkingDelay.esd, DABMOTDecoder.esd, DABMuteHandling.esd,
DABPIList.esd, DABQualityInfo.esd, DABServiceList.esd,
DABSettings.esd

### Satellite Radio (SiriusXM)
SDARS.esd, SDARSCategroyList.esd, SDARSCurrentStation.esd,
SDARSGeneralInfo.esd, SDARSRadioText.esd,
SDARSServiceStatus.esd, SDARSStationList.esd,
SDARSVersionInfo.esd

### HD Radio
HD.esd, HDAddStationInfo.esd, HDBer.esd, HDBlending.esd,
HDPSDInfo.esd, HDPerformance.esd, HDTest.esd,
HDTestDataStatus.esd

### Navigation
Nav.esd, NavCopy.esd, NavDiag.esd, NavEngPosition.esd,
NavEngRoute.esd, NavEngRouteTables.esd, NavEngineering.esd,
NavGPS.esd, NavGpsCoord.esd, NavGpsSatInfo.esd,
NavMapEng.esd, NavPSD.esd, NavSensoric.esd,
NavTmcEng.esd, NavTrafficOnline.esd

### TMC / Traffic
TmcChina.esd, TmcChinaStations.esd, TmcChinaStatus.esd,
OnlineTraffic.esd

### TIM
TIM.esd, TIMMessageList.esd, TIMStatusInfo.esd, TIMTimerList.esd

### Media
Media.esd, MediaBt.esd, MediaPlayer.esd, Hdd.esd

### DVD
Display.esd (DVD display controls)

### SD Card
SD.esd, SD-Slot1.esd, SD-Slot2.esd

### USB
USB.esd

### Bluetooth
Bluetooth.esd, Bths.esd

### Telephony
Telephony.esd, TelephonyConnectedDevices.esd,
TelephonyDebugUMTS.esd, TelephonyProvider.esd,
TelephonyScripts.esd, TelephonyStates.esd,
TelephonyUMTSE2DTRIG.esd

### WiFi
WLAN.esd

### TV
TV.esd, TvTables.esd, Tvtpeg.esd, TvtpegFilter.esd,
TvtpegSNITables.esd, TvtpegTpegData.esd

### MOST Bus
MOST.esd, MOSTAllocTable.esd, MOSTCenReg.esd,
MostCombi.esd, MostCombiStats.esd

### Car / Vehicle
Car.esd, CarCodingVehicle.esd, CarDeviceList.esd,
CarDeviceList_2.esd, CarExtDeviceList.esd,
CarFunctionList.esd, CarProtocollSwitch.esd,
CarZBusAssignment.esd, CarZMenuOperation.esd

### Radio Unit Hardware
RU.esd, RUSirius.esd

### Front Controller
Front.esd

### IRC (Intelligent Resource Control)
IRC.esd, IRCTrigger.esd

### Trace / Debug
Trace.esd, TraceInternFBlock.esd, TraceMMEVerbosity.esd,
TraceScope.esd

### SMART Data
Smart.esd, StoreSmart.esd, ViewSmart.esd

### Browser
Browser.esd

### Google Earth
GoogleEarth.esd

### Gracenote
Gracenote.esd

### Addressbook
Addressbook.esd

### SDS (Speech)
SDS.esd

### Serial Interface Test
SerialIfTest.esd

### Xtra (aGPS)
Xtra.esd

### Test Screens
Aevtest.esd, Fcttest.esd, Numlisttest.esd,
slidertest.esd, tabletest.esd


## Creating custom GEM screens

1. Write a `.esd` file following the format above
2. Place it in `/mnt/efs-system/engdefs/` (requires EFS write access)
3. Reboot the MMI
4. The screen appears in the GEM menu under its declared parent

For SD-card-based deployment without modifying the EFS, the toolkit's
`gem-activator` module copies engdefs to the appropriate location
during the copie_scr.sh execution window.

### Example: Custom system monitor screen

```
#############################################
#  Custom system monitor
#  MMI3G-Toolkit
#############################################
screen  ToolkitMonitor Main

   keyValue
      value    int per 3 0x00000023
      label    "Battery (x100 mV)"
      poll     500

   keyValue
      value    int per 1 0x5003b
      label    "CPU Load"
      poll     2000

   keyValue
      value    int sys 1 1
      label    "Java Free Memory (KB)"
      format   0.0009765625 "####.##"
      poll     1000

   script
      value    sys 1 0x0100 "/fs/sda1/scripts/my_tool.sh"
      label    "Run Custom Script"
```


## References

- Extracted from: MU9411 K0942_4 variant 41 efs-system.efs
- Engineering access controllers: `research/ENGINEERING_ACCESS.md`
- DSI architecture: `research/DSI_ARCHITECTURE.md`
- Per3 address map: `research/PER3_ADDRESS_MAP.md`
- GEM activation: `modules/gem-activator/`

## CRITICAL: Block Format Requirement

**Discovered 2026-04-21 during car testing.**

The GEM ESD parser requires **multi-line block format**. Single-line
inline syntax is silently ignored — screens appear in the menu but
display NO data.

### Correct (block format — WORKS):

```
screen	MyScreen	Toolkit

   keyValue
      value    int per 3 0x00000023
      label    "Battery (x100 mV)"
      poll     500

   script
      value    sys 1 0x0100 "/scripts/myscript.sh"
      label    ">> Run Script <<"
```

### WRONG (inline format — screen appears but is BLANK):

```
screen MyScreen Toolkit

keyValue value int per 3 0x00000023 label "Battery (x100 mV):"
poll 500

script value sys 1 0x0100 "/scripts/myscript.sh" label ">> Run Script <<"
```

### Key syntax rules:

- `screen` line uses **tabs** as separators: `screen\tName\tParent`
- `keyValue` and `script` keywords on their own line, indented 3 spaces
- `value`, `label`, `poll` each on separate lines, indented 6 spaces
- Empty line between each keyValue/script block
- Comments start with `#` (full line only)

### Parent Group Requirement

The parent name in the `screen` directive MUST be either:
- A **firmware-defined group**: Main, Config, Car, Coding, Nav, Version,
  MOST, Display, Settings, Radio, etc.
- Another **custom screen name** already defined in an ESD file

Custom parent names (e.g., "Gauges", "Scanner") are **silently ignored** —
the screen definition is loaded but never appears in the GEM menu tree.

The MMI-Toolkit uses this hierarchy:
```
Main (firmware)
  ├── GamesMenu (top-level, like Audi's factory games)
  └── Toolkit (our root screen)
        ├── ToolkitDiag / ToolkitSWDL
        ├── GaugesDashboard / Network / System
        ├── ScannerEngine1..10
        ├── DTC_Overview / Detail / Control
        └── CodingMain / BusRouting / CarConfig
```
