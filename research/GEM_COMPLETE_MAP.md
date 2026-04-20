# MMI3G Green Engineering Menu — Complete Screen Map
# Source: 183 ESD files from HN+R_US_AU_K0942_3
# Part of MMI-Toolkit: github.com/dspl1236/MMI3G-Toolkit

## Summary
- 183 screens total
- 35 screens with writable buttons
- 12 screens with script execution
- 17 screens with BIOSCtrl dropdowns
- 43 screens with choice toggles
- 32 screens with sliders

## Element Legend
- [RW] choice = toggle on/off (writable)
- [WR] button = one-shot write on press
- [WR] slider = adjustable numeric value
- [WR] BIOSCtrl = dropdown selector (writable)
- [EX] script = executes shell script
- [RO] keyValue = read-only display with polling


## AEVTest/

### AEVTest/FakeAudioSettings  (FakeAudio.esd)

- [RO] keyValue: "User Mute" poll:0ms → int per 234524 20155
- [RO] keyValue: "Foreground Src" poll:0ms → int per 234524 20151
- [WR] slider: "Volume" → per 234524 20016 20017 20018
- [WR] slider: "Treble" → per 234524 20019 20020 20021
- [WR] slider: "Bass" → per 234524 20022 20023 20024
- [WR] slider: "Counting Foo" → per 234524 21000 21001 21002
- [WR] slider: "Gray Bar" → per 234524 21000 21001 21002
- [WR] slider: "Gray Granny" → per 234524 21000 21001 21002

### AEVTest/FakeExtra  (Xtra.esd)

- [RO] keyValue: "XtraCountry" poll:0ms → String per 234524 22000
- [RO] keyValue: "XtraVersion" poll:0ms → int per 234524 22001
- [RW] choice: "XtraChoice1" → per 234524 24000
- [RO] keyValue: "XtraModulCount" poll:0ms → int per 234524 22002
- [RO] keyValue: "XtraType" poll:0ms → String per 234524 22003

### AEVTest/FunctionTest  (Fcttest.esd)

- [WR] button: "Say test text" → per 234524 30000 "Dies ist ein Test"

### AEVTest/NumListTest  (Numlisttest.esd)


### AEVTest/OnlineTraffic  (OnlineTraffic.esd)

- [EX] script: "Copy TPEG data snapshot"
- [EX] script: "Use Navteq"
- [EX] script: "Use INRIX"
- [EX] script: "Use Finkbeiner-Testserver"
- [EX] script: "Use TomTom"
- [EX] script: "Use ARC"

### AEVTest/Scripts  (Scripts.esd)

- [EX] script: "Start Script"

### AEVTest/SliderTest  (slidertest.esd)

- [WR] slider: "Absolute Slider" → per 234524 20019 -6 6
- [WR] slider: "Indexed Slider" → per 234524 20016 20017 20018

### AEVTest/TableTest  (tabletest.esd)

- [--] table
- [--] table


## AMFM/

### AMFM/DiagTest  (AMFMDiagTest.esd)

- [WR] button: "Enable Test Mode" → per 1 0x00010700 "enable"
- [WR] button: "Disable Test Mode" → per 1 0x00010701 "disable"
- [WR] slider: "Select FM Frequency" → per 1 0x00010805 875 1080
- [WR] slider: "Select MW Frequency" → per 1 0x00010806 531 1602
- [WR] slider: "Select LW Frequency" → per 1 0x00010807 153 279
- [WR] slider: "Seek FM" → per 1 0x00010706 0 2
- [WR] slider: "Seek MW" → per 1 0x00010707 0 2
- [WR] slider: "Seek LW" → per 1 0x00010708 0 2
- [RW] choice: "TP Swicth (inverted)" → per 1 0x001F0014
- [RO] keyValue: "Current Frequency" poll:1000ms → int per 1 0x00010100
- [RO] keyValue: "Current FieldStrength" poll:1000ms → int per 1 0x00010101

### AMFM/HD  (HD.esd)


### AMFM/SingleTunerTest  (AMFMSingleTunerTest.esd)

- [RW] choice: "Single Tuner Test Mode" → per 1 0x00010014
- [WR] slider: "Select Tuner 1 Frequency" → per 1 0x0001001C 875 1080
- [WR] slider: "Select Tuner 2 Frequency" → per 1 0x0001001D 875 1080
- [WR] slider: "Select Tuner 3 Frequency" → per 1 0x0001001E 875 1080
- [--] table

### AMFM/StationList  (AMFMStationList.esd)

- [--] table
- [--] table

### AMFM/TMCStationList  (AMFMTMCStationList.esd)

- [--] table
- [--] table

### AMFM/TestModeA  (AMFMTestModeA.esd)

- [WR] button: "Enable Test Mode A" → per 1 0x00010009 "enable"
- [--] table
- [--] table

### AMFM/TestModeC  (AMFMTestModeC.esd)

- [WR] button: "Enable Test Mode C" → per 1 0x0001000B "enable"
- [--] table
- [--] table

### AMFM/TestModeD  (AMFMTestModeD.esd)

- [WR] button: "Enable Test Mode D" → per 1 0x0001000C "enable"
- [--] table
- [--] table
- [--] table

### AMFM/TestModeE  (AMFMTestModeE.esd)

- [WR] button: "Enable Test Mode E" → per 1 0x0001000D "enable"
- [WR] slider: "Select Index" → per 1 0x00010513 0 50
- [--] table
- [--] table
- [--] table

### AMFM/TestModeV  (AMFMTestModeV.esd)

- [WR] button: "Enable Test Mode V" → per 1 0x0001000E "enable"
- [RO] keyValue: "Pool Version" poll:2000ms → String per 1 0x00010601
- [--] table

### AMFM/TunBandInfo  (AMFMBandInfo.esd)

- [RO] keyValue: "Region Code" poll:2000ms → String per 1 0x00010811
- [--] table


## Audiomanagement/

### Audiomanagement/AudioMisc  (AudioManagementMisc.esd)

- [RO] keyValue: "Mute pin state" poll:1000ms → int per 1 0x000B001F
- [WR] BIOSCtrl: "Mute behaviour actual" (3 options) → int per 1 0x000B001D
- [RO] keyValue: "Volume max" poll:10000ms → int per 1 0x000B001E
- [RO] keyValue: "Muting Reason" poll:1000ms → int per 1 0x000B0016
- [WR] slider: "lenses timer disp. 1 (100 ms)" → per 4 0x00040000 0 100
- [WR] slider: "lenses timer disp. 2 (100 ms)" → per 4 0x00040001 0 100

### Audiomanagement/InputGainOffset  (AudioManagementInputGainOffset.esd)

- [WR] slider: "MW" → per 1 0x000B0010 -13 13
- [WR] slider: "FM" → per 1 0x000B0011 -13 13
- [WR] slider: "MUCD" → per 1 0x000B0012 -13 13
- [WR] slider: "CDC" → per 1 0x000B0020 -13 13
- [WR] slider: "DAB" → per 1 0x000B0021 -13 13
- [WR] slider: "DVBT" → per 1 0x000B0022 -13 13
- [WR] slider: "TV" → per 1 0x000B0023 -13 13
- [WR] slider: "SDARS" → per 1 0x000B0024 -13 13
- [WR] slider: "TIM" → per 1 0x000B0025 -13 13
- [WR] slider: "MU AUX" → per 1 0x000B0026 -13 13
- [WR] slider: "MU AUX ADAPT" → per 1 0x000B0027 -13 13
- [WR] slider: "MU DVD" → per 1 0x000B0028 -13 13
- [WR] slider: "MU MFP" → per 1 0x000B0029 -13 13
- [WR] slider: "MU BT Device" → per 1 0x000B002A -13 13

### Audiomanagement/VolumeRangers  (AudioManagementVolumeRanger.esd)

- [WR] slider: "Entertainment lowering" → per 1 0x000B0000 0 60
- [WR] slider: "Entertainment min" → per 1 0x000B0001 0 60
- [WR] slider: "Entertainment max" → per 1 0x000B0002 0 60
- [WR] slider: "SDS min" → per 1 0x000B0003 0 60
- [WR] slider: "SDS max" → per 1 0x000B0004 0 60
- [WR] slider: "Navi min" → per 1 0x000B0005 0 60
- [WR] slider: "Navi max" → per 1 0x000B0006 0 60
- [WR] slider: "Telephone min" → per 1 0x000B0007 0 60
- [WR] slider: "Telephone max" → per 1 0x000B0008 0 60
- [WR] slider: "Traffic min" → per 1 0x000B0009 0 60
- [WR] slider: "Traffic max" → per 1 0x000B000A 0 60


## Car/

### Car/CarBusAssignment  (CarZBusAssignment.esd)

- [WR] BIOSCtrl: "Air condition" (9 options) → int per 3 0x0014003D
- [WR] BIOSCtrl: "Auxiliary heating" (9 options) → int per 3 0x0014003F
- [WR] BIOSCtrl: "Headup display" (9 options) → int per 3 0x00140040
- [WR] BIOSCtrl: "Adaptive cruise control" (9 options) → int per 3 0x00140041
- [WR] BIOSCtrl: "Suspension" (9 options) → int per 3 0x00140042
- [WR] BIOSCtrl: "Tyre pressure control (RDK)" (9 options) → int per 3 0x00140043
- [WR] BIOSCtrl: "Interior light" (9 options) → int per 3 0x00140044
- [WR] BIOSCtrl: "Exterior light" (9 options) → int per 3 0x00140045
- [WR] BIOSCtrl: "Park distance control" (9 options) → int per 3 0x00140046
- [WR] BIOSCtrl: "Rearview camera" (9 options) → int per 3 0x00140047
- [WR] BIOSCtrl: "Wiper" (9 options) → int per 3 0x00140048
- [WR] BIOSCtrl: "Doorlocking" (9 options) → int per 3 0x00140049
- [WR] BIOSCtrl: "Mirror" (9 options) → int per 3 0x0014004A
- [WR] BIOSCtrl: "On-board computer" (9 options) → int per 3 0x0014004B
- [WR] BIOSCtrl: "Seat memory front" (9 options) → int per 3 0x0014004C
- [WR] BIOSCtrl: "Clock" (9 options) → int per 3 0x0014004D
- [WR] BIOSCtrl: "Service intervall" (9 options) → int per 3 0x0014004E
- [WR] BIOSCtrl: "Central units master (ZEM)" (9 options) → int per 3 0x0014004F
- [WR] BIOSCtrl: "univ. garage door opener" (9 options) → int per 3 0x00140050
- [WR] BIOSCtrl: "Compass" (9 options) → int per 3 0x00140051
- [WR] BIOSCtrl: "Charisma" (9 options) → int per 3 0x00140053
- [WR] BIOSCtrl: "Night vision" (9 options) → int per 3 0x00140054
- [WR] BIOSCtrl: "Lane departure warning (HCA)" (9 options) → int per 3 0x00140055
- [WR] BIOSCtrl: "Lane change assist (SWA)" (9 options) → int per 3 0x00140056
- [WR] BIOSCtrl: "Braking way reduction (AWV)" (9 options) → int per 3 0x00140057
- [WR] BIOSCtrl: "Hybrid" (9 options) → int per 3 0x00140059
- [WR] BIOSCtrl: "Sideview camera" (9 options) → int per 3 0x0014005A
- [WR] BIOSCtrl: "rev. seat-belt tensionier (RGS)" (9 options) → int per 3 0x0014005B
- [WR] BIOSCtrl: "Traffic sign recognition (VZE)" (9 options) → int per 3 0x0014005D
- [WR] BIOSCtrl: "Rear seat entertainment" (9 options) → int per 3 0x0014005F
- [WR] BIOSCtrl: "Vehicle IdentNo activate (VIN)" (9 options) → int per 3 0x0014007C
- [WR] BIOSCtrl: "Oil level gauge" (9 options) → int per 3 0x0014007D
- [WR] BIOSCtrl: "Weariness recognition (MKE)" (9 options) → int per 3 0x0014005E
- [WR] BIOSCtrl: "Tilt angle display" (9 options) → int per 3 0x00140098
- [WR] BIOSCtrl: "Seat Heat" (9 options) → int per 3 0x0014007E

### Car/CarCodingVehicle  (CarCodingVehicle.esd)

- [WR] BIOSCtrl: "steering wheel der." (3 options) → int per 3 0x00100002
- [WR] BIOSCtrl: "Vehicle derivat" (8 options) → int per 3 0x00100008
- [WR] BIOSCtrl: "Configuration line" (5 options) → int per 3 0x00100004
- [WR] BIOSCtrl: "Vehicle model line" (20 options) → int per 3 0x00100006
- [WR] slider: "Select No of Screen" → per 1 0x0009000A 0 0x00090008

### Car/CarDeviceList  (CarDeviceList.esd)

- [RW] choice: "Air condition: " → per 3 0x00100010
- [RW] choice: "Auxiliary heating: " → per 3 0x00100011
- [RW] choice: "Headup display: " → per 3 0x00100012
- [RW] choice: "Adaptive Cruise Ctrl: " → per 3 0x00100013
- [RW] choice: "Suspension: " → per 3 0x00100014
- [RW] choice: "Tyre pressure control (RDK): " → per 3 0x00100015
- [RW] choice: "Interior light: " → per 3 0x00100016
- [RW] choice: "Exterior light: " → per 3 0x00100017
- [RW] choice: "Park distance control: " → per 3 0x00100018
- [RW] choice: "Rearview camera: " → per 3 0x00100019
- [RW] choice: "Wiper: " → per 3 0x0010001A
- [RW] choice: "Doorlocking: " → per 3 0x0010001B
- [RW] choice: "Mirror: " → per 3 0x0010001C
- [RW] choice: "On-board computer: " → per 3 0x0010001D
- [RW] choice: "Clock: " → per 3 0x0010001E
- [RW] choice: "Service intervall : " → per 3 0x0010001F
- [RW] choice: "Central units master (ZEM): " → per 3 0x00100020
- [RW] choice: "Compass: " → per 3 0x00100021
- [RW] choice: "Charisma: " → per 3 0x00100022
- [RW] choice: "Lane departure warning (HCA): " → per 3 0x00100023
- [RW] choice: "Lane change assist (SWA): " → per 3 0x00100024
- [RW] choice: "Braking way reduction (AWV): " → per 3 0x00100025
- [RW] choice: "Seat memory front: " → per 3 0x00100026
- [RW] choice: "Seat memory rear: " → per 3 0x00100027
- [RW] choice: "Hybrid: " → per 3 0x00100028
- [RW] choice: "univ. garage door opener: " → per 3 0x00100029
- [RW] choice: "Night vision: " → per 3 0x0010002A
- [RW] choice: "Sideview camera: " → per 3 0x0010002B
- [RW] choice: "rev. seat-belt tensionier (RGS): " → per 3 0x0010002C
- [RW] choice: "Traffic sign recognition (VZE): " → per 3 0x0010002D
- [RW] choice: "Rear seat entertainment: " → per 3 0x0010002E
- [RW] choice: "Weariness recognition (MKE): " → per 3 0x0010002F

### Car/CarDeviceList_2  (CarDeviceList_2.esd)

- [RW] choice: "Seat heating: " → per 3 0x00100070
- [RW] choice: "Tilt angle display: " → per 3 0x00100071
- [RW] choice: "Day Night Map Mode: " → per 3 0x00100088
- [RW] choice: "RDK: " → per 3 0x00100089

### Car/CarExtDeviceList  (CarExtDeviceList.esd)

- [RW] choice: "MFL: " → per 3 0x00100030
- [RW] choice: "VIN: " → per 3 0x00100031
- [RW] choice: "Battery level gauge: " → per 3 0x00100032
- [RW] choice: "Oil level gauge: " → per 3 0x00100033
- [RW] choice: "Sliding roof: " → per 3 0x00100034
- [RW] choice: "Trailer: " → per 3 0x00100035
- [RW] choice: "Driver Monitoring: " → per 3 0x00100036
- [RW] choice: "Programmed Keys: " → per 3 0x00100037

### Car/CarFunctionList  (CarFunctionList.esd)

- [RW] choice: "PDC entertainment dimming 1: " → per 3 0x00100040
- [RW] choice: "PDC entertainment dimming 2: " → per 3 0x00100041
- [RW] choice: "AM/FM toggle: " → per 3 0x00100042
- [RW] choice: "Oil level gauge extended: " → per 3 0x00100043
- [RW] choice: "Bord book: " → per 3 0x00100044
- [RW] choice: "MFL jokerfunction: " → per 3 0x00100045
- [RW] choice: "MFL type (STD/PA): " → per 3 0x00100046

### Car/CarMenuOperation  (CarZMenuOperation.esd)

- [WR] slider: "Adaptive cruise control: " → per 3 0x00140000 0 31
- [WR] slider: "Interior light: " → per 3 0x00140001 0 31
- [WR] slider: "Parking system: " → per 3 0x00140002 0 31
- [WR] slider: "Braking way reduction (AWV): " → per 3 0x00140003 0 31
- [WR] slider: "Lane departure warning (HCA): " → per 3 0x00140004 0 31
- [WR] slider: "Lane change assist (SWA): " → per 3 0x00140005 0 31
- [WR] slider: "Exterior light: " → per 3 0x00140006 0 31
- [WR] slider: "Battery level gauge: " → per 3 0x00140007 0 31
- [WR] slider: "Window: " → per 3 0x00140008 0 31
- [WR] slider: "Air condition: " → per 3 0x00140009 0 31
- [WR] slider: "On-board computer: " → per 3 0x0014000A 0 31
- [WR] slider: "Tyre pressure control (RDK): " → per 3 0x0014000B 0 31
- [WR] slider: "Wiper: " → per 3 0x0014000C 0 31
- [WR] slider: "Service intervall : " → per 3 0x0014000D 0 31
- [WR] slider: "Seat memory: " → per 3 0x0014000E 0 31
- [WR] slider: "Central lock system: " → per 3 0x0014000F 0 31
- [WR] slider: "Compass: " → per 3 0x00140010 0 31
- [WR] slider: "Charisma: " → per 3 0x00140011 0 31
- [WR] slider: "Oil level gauge: " → per 3 0x00140012 0 31
- [WR] slider: "Vehicle IdentNo activate (VIN): " → per 3 0x00140013 0 31
- [WR] slider: "Clock: " → per 3 0x00140014 0 31
- [WR] slider: "Suspension: " → per 3 0x00140015 0 31
- [WR] slider: "Headup display: " → per 3 0x00140016 0 31
- [WR] slider: "Central units master (ZEM): " → per 3 0x00140017 0 31
- [WR] slider: "Hybrid: " → per 3 0x00140018 0 31
- [WR] slider: "Bord book: " → per 3 0x00140019 0 31
- [WR] slider: "univ. garage door opener: " → per 3 0x0014001A 0 31
- [WR] slider: "Night vision: " → per 3 0x0014001B 0 31
- [WR] slider: "Sideview camera: " → per 3 0x0014001C 0 31
- [WR] slider: "rev. seat-belt tensionier (RGS): " → per 3 0x0014001D 0 31
- [WR] slider: "MFL joker key: " → per 3 0x0014001E 0 31
- [WR] slider: "Auxiliary heating: " → per 3 0x0013FFFF 0 31
- [WR] slider: "Traffic sign recognition (VZE): " → per 3 0x0013FFFE 0 31
- [WR] slider: "Rear seat entertainment: " → per 3 0x0013FFFD 0 31
- [WR] slider: "Weariness recognition (MKE): " → per 3 0x0013FFFC 0 31
- [WR] slider: "Programmed Key(Ang. Schl.): " → per 3 0x0013FFFB 0 31
- [WR] slider: "Tilt angle display: " → per 3 0x0013FFFA 0 31

### Car/CarProtocollSwitch  (CarProtocollSwitch.esd)

- [RW] choice: "Air condition: " → per 3 0x00100050
- [RW] choice: "Auxiliary heating: " → per 3 0x00100051
- [RW] choice: "Adaptive cruise control: " → per 3 0x00100052
- [RW] choice: "Suspension: " → per 3 0x00100053
- [RW] choice: "Tyre pressure control (RDK): " → per 3 0x00100054
- [RW] choice: "Interior light: " → per 3 0x00100055
- [RW] choice: "Exterior light: " → per 3 0x00100056
- [RW] choice: "Park distance control: " → per 3 0x00100057
- [RW] choice: "Wiper: " → per 3 0x00100058
- [RW] choice: "Doorlocking: " → per 3 0x00100059
- [RW] choice: "On-board computer: " → per 3 0x0010005A
- [RW] choice: "Clock: " → per 3 0x0010005B
- [RW] choice: "Service intervall : " → per 3 0x0010005C
- [RW] choice: "Braking way reduction (AWV): " → per 3 0x0010005D
- [RW] choice: "Seat memory: " → per 3 0x0010005E


## Coding/

### Coding/Kombi  (DiagnoseKombi.esd)

- [RW] choice: "High Kombi: " → per 1 0x0009000B
- [RW] choice: "Audio (Off): " → per 1 0x0009000C
- [RW] choice: "Telephone (Off): " → per 1 0x0009000D
- [RW] choice: "Navigation (Off): " → per 1 0x0009000E

### Coding/connected_micro  (DiagnoseCode15Micro.esd)

- [RW] choice: "Micro 1: " → per 3 0x0015000E
- [RW] choice: "Micro 2: " → per 3 0x0015000F

### Coding/internal_modules_1+2  (DiagnoseCodeIntModules_1-2.esd)

- [RW] choice: "SDS (Off): " → per 3 0x00150010
- [RW] choice: "NAVI (Off): " → per 3 0x00150011
- [RW] choice: "PSD (Off): " → per 3 0x00150012
- [RW] choice: "VZA (Off): " → per 3 0x00150013
- [RW] choice: "ECALL (Off): " → per 3 0x00150014
- [RW] choice: "Online POI (Off): " → per 3 0x00150015
- [RW] choice: "Online Portal (Off): " → per 3 0x00150016
- [RW] choice: "Online Navi (Off): " → per 3 0x00150017
- [RW] choice: "Offroad Navigation (Off): " → per 3 0x00150019
- [RW] choice: "Online POI voice (Off): " → per 3 0x0015001A

### Coding/telephone_equipment  (DiagnoseCode17Telefon.esd)

- [RW] choice: "cradle: " → per 3 0x00150006
- [RW] choice: "eCall: " → per 3 0x00150007
- [WR] BIOSCtrl: "3-button module: " (4 options) → int per 3 0x00150008


## Config/

### Config/PacketCounter  (ConfigPacketCounter.esd)

- [RW] choice: "Show Packet Statistic" → per 1 0x00230006
- [--] table


## DAB/

### DAB/BackgroundScan  (DABBackgroundScan.esd)

- [WR] slider: "No Sync Freq Checks" → per 1 0x00110051 0 9
- [WR] slider: "Last Sync Freq Checks" → per 1 0x00110052 0 9
- [WR] slider: "Sync Freq Checks" → per 1 0x00110053 0 9
- [WR] slider: "Num Last Sync Freqs" → per 1 0x00110054 0 9
- [WR] slider: "Insertion Threshold" → per 1 0x00110055 0 15
- [WR] slider: "Deletion Threshold" → per 1 0x00110056 0 15
- [WR] slider: "DAB Internal Link Threshold" → per 1 0x00110057 0 5

### DAB/ComponentList  (DABComponentList.esd)

- [--] table
- [--] table

### DAB/CurrentStation  (DABCurrentStation.esd)

- [--] table
- [--] table
- [--] table
- [WR] slider: "Seek up/down/scan/abort" → per 1 0x00110035 0 3
- [RO] keyValue: "Seek Status" poll:1000ms → String per 1 0x00110036

### DAB/DataServiceFilter  (DABDataServiceFilter.esd)

- [RW] choice: "Type Unknown" → per 1 0x00110058
- [RW] choice: "Type SLS" → per 1 0x00110059
- [RW] choice: "Type BWS" → per 1 0x0011005A
- [RW] choice: "PAD of Current SID" → per 1 0x0011005C
- [RW] choice: "All PAD" → per 1 0x0011005D
- [RW] choice: "All NPAD" → per 1 0x0011005E
- [RW] choice: "All Ensembles" → per 1 0x0011005F
- [RW] choice: "Valid URL" → per 1 0x00110060
- [RW] choice: "Additional Dummy" → per 1 0x0011005B

### DAB/DataServiceList  (DABDataServiceList.esd)

- [--] table

### DAB/DiagTest  (DABDiagTest.esd)

- [WR] button: "Enable Test Mode" → per 1 0x0011002E "enable"
- [WR] button: "Disable Test Mode" → per 1 0x0011002F "disable"
- [WR] slider: "Select Frequency by Index" → per 1 0x00110001 0 100
- [WR] slider: "Select Service by Index" → per 1 0x00110003 0 10
- [RO] keyValue: "Current Frequency" poll:2000ms → int per 1 0x0011002C
- [RO] keyValue: "Current Quality" poll:1000ms → int per 1 0x00110030
- [RO] keyValue: "Number of Audio Services" poll:2000ms → int per 1 0x00110004
- [RO] keyValue: "Number of Frequencies" poll:5000ms → int per 1 0x00110005

### DAB/EnsembleList  (DABEnsembleList.esd)

- [--] table
- [--] table

### DAB/LinkingDelay  (DABLinkingDelay.esd)

- [RW] choice: "Test Mode" → per 1 0x00110026
- [--] table

### DAB/MOTDecoder  (DABMOTDecoder.esd)

- [RW] choice: "Test Mode" → per 1 0x00110026
- [--] table

### DAB/MuteHandling  (DABMuteHandling.esd)

- [WR] slider: "Norm FIC BER Thresh. Mute" → per 1 0x00110049 0 15
- [WR] slider: "Audio Qual Treshold 1 Mute" → per 1 0x0011004A 0 100
- [WR] slider: "Audio Qual Treshold 2 Mute" → per 1 0x0011004B 0 100
- [WR] slider: "Norm FIC BER Thresh. Dem." → per 1 0x0011004C 0 15
- [WR] slider: "Audio Qual Thresh. Demute" → per 1 0x0011004D 0 100
- [WR] slider: "Mute Duration (500 ms)" → per 1 0x0011004E 0 6
- [WR] slider: "Mute Ramp Duration (50 ms)" → per 1 0x0011004F 0 60
- [WR] slider: "Demute Ramp Dur. (50 ms)" → per 1 0x00110050 0 60

### DAB/PIList  (DABPIList.esd)

- [RW] choice: "Test Mode (enable PIList)" → per 1 0x00110026
- [--] table
- [--] table
- [--] table

### DAB/QualityInfo  (DABQualityInfo.esd)

- [RW] choice: "Test Mode" → per 1 0x00110026
- [RO] keyValue: "Sync Status" poll:500ms → String per 1 0x0011001C
- [RO] keyValue: "Mute Status" poll:500ms → String per 1 0x0011001D
- [RO] keyValue: "Service Component Status" poll:1000ms → String per 1 0x00110013
- [RO] keyValue: "Linking Status" poll:1000ms → String per 1 0x00110032
- [--] table
- [--] table

### DAB/ServiceList  (DABServiceList.esd)

- [--] table
- [--] table

### DAB/Settings  (DABSettings.esd)

- [RW] choice: "Linking Feature" → per 1 0x00110033
- [WR] slider: "Linking Mode Off/DAB/On" → per 1 0x00110031 0 2
- [WR] slider: "Linking Delay Off/Fix/Auto" → per 1 0x00110037 0 2
- [WR] slider: "Enforce Linking Off/DAB/FM" → per 1 0x0011003B 1 3
- [WR] slider: "DAB Qual Linking Threshold" → per 1 0x0011003C 0 7
- [WR] slider: "Link Back Delay" → per 1 0x0011003D 0 65
- [RW] choice: "Display QualityInfo" → per 1 0x00110038
- [RW] choice: "Test Mode" → per 1 0x00110026
- [RW] choice: "DRC Switch" → per 1 0x00110034
- [RW] choice: "Foreground Module" → per 1 0x00110048
- [WR] slider: "Basic notification delay" → per 1 0x00110063 0 60
- [WR] slider: "Medium priority notiifcation delay" → per 1 0x00110064 0 60
- [WR] slider: "Low priority notiifcation delay" → per 1 0x00110065 0 60


## DTC/

### DTC/Show_single_DTC  (Dtc_single.esd)

- [WR] slider: "select dtc" → per 2 0x00010001 0 100
- [--] table

### DTC/changed_DTCs  (Dtc_changed.esd)

- [--] table

### DTC/control  (Dtc_control.esd)

- [WR] slider: "select dtc" → per 2 0x00010001 0 100
- [WR] button: "Send test passed" → per 2 0x00010006 ClearErrmem
- [WR] button: "Send test failed" → per 2 0x00010007 ClearErrmem
- [WR] button: "Clear error memory" → per 2 0x00010008 ClearErrmem

### DTC/qualified_DTCs  (Dtc_qualified.esd)

- [--] table

### DTC/untested_DTCs  (Dtc_untested.esd)

- [--] table


## Diagnose/

### Diagnose/Coding  (DiagnoseCoding.esd)

- [WR] BIOSCtrl: "active HDD Nav DB (#1)" (18 options) → int per 3 0x00100000
- [WR] BIOSCtrl: "Transmission (#24)" (3 options) → int per 3 0x00100064
- [WR] BIOSCtrl: "RSE remote control:" (3 options) → int per 3 0x0015001B

### Diagnose/Optical_Drive  (DiagnoseDrive.esd)

- [RO] keyValue: "RegionCode Changes" poll:5000ms → int per 1 0x00160000
- [RO] keyValue: "Region Code (Drive)" poll:5000ms → int per 1 0x00160010
- [RO] keyValue: "Region Code (Disc)" poll:3000ms → int per 1 0x00160001
- [RO] keyValue: "Disc Type" poll:3000ms → int per 1 0x00160006
- [RO] keyValue: "Disc State" poll:3000ms → int per 1 0x00160005
- [RO] keyValue: "Eject Disabled" poll:3000ms → int per 3 0x00500000
- [RO] keyValue: "Current Temperature" poll:3000ms → int per 1 0x00160009
- [RO] keyValue: "Maximum Temperature" poll:3000ms → int per 1 0x0016000A
- [WR] button: "Reset Max. Temperature" → per 1 0x00160021 1
- [WR] button: "Reset RegionCode Counter" → per 1 0x00160012 1

### Diagnose/Parental_Mgmt_Level  (DiagnosePml.esd)

- [RO] keyValue: "current value" poll:100ms → int per 1 0x00160002
- [WR] button: "Reset Level" → per 1 0x00160013 "ResetLevel"
- [WR] button: "Reset Password" → per 1 0x00160022 "ResetPassword"

### Diagnose/Settings  (DiagnoseSettings.esd)

- [WR] button: "Trigger Import Dataset(/HBpersistence/Datasets_VAS)" → per 8 0x00059000  " "


## Engineering/

### Engineering/Route  (NavEngRoute.esd)

- [RO] keyValue: "is route calculation active" poll:2000ms → int per 1 0x00030016
- [RO] keyValue: "route guidance active" poll:3000ms → int per 1 0x00030007
- [RO] keyValue: "air distance next dest" poll:5000ms → int per 1 0x00030008
- [RO] keyValue: "current street" poll:2000ms → String per 1 0x0003000B
- [RO] keyValue: "direction next dest" poll:1000ms → int per 1 0x0003000C
- [RO] keyValue: "distance next dest" poll:2000ms → int per 1 0x0003000D
- [RO] keyValue: "time next dest (min)" poll:10000ms → int per 1 0x0003000F
- [RO] keyValue: "next street turn to" poll:1000ms → String per 1 0x00030010
- [RO] keyValue: "street length" poll:3000ms → int per 1 0x0003001D

### Engineering/position  (NavEngPosition.esd)

- [--] table
- [RO] keyValue: "height" poll:1000ms → int per 1 0x00030019


## Environment/

### Environment/HDD  (Hdd.esd)

- [RO] keyValue: "HDD model" poll:10000ms → String per 1 0x000E0040
- [RO] keyValue: "HDD firmware revision" poll:10000ms → String per 1 0x000E0041
- [RO] keyValue: "HDD serial number" poll:10000ms → String per 1 0x000E0042
- [RO] keyValue: "HDD current temperature" poll:1000ms → int per 1 0x000E0043
- [RO] keyValue: "HDD max temperature" poll:10000ms → int per 1 0x000E0044
- [RO] keyValue: "HDD power state" poll:1000ms → int per 1 0x000E0045

### Environment/SparePartNumbers  (SparePartNumbers.esd)

- [RO] keyValue: "VW spare part number:" → String per 3 0x00110006
- [RO] keyValue: "spare part num front display:" → String per 3 0x000103EE
- [RO] keyValue: "spare part num right display:" → String per 3 0x000103EF
- [RO] keyValue: "spare part num left display:" → String per 3 0x000103F0


## GPS/

### GPS/Coordinates  (NavGpsCoord.esd)

- [RO] keyValue: "Height" poll:1000ms → int per 7 0x000200bf
- [RO] keyValue: "Height ocean" poll:1000ms → int per 7 0x000200c3
- [RO] keyValue: "latitude degree" poll:10000ms → int per 7 0x000200b4
- [RO] keyValue: "latitude minute" poll:3000ms → int per 7 0x000200b5
- [RO] keyValue: "latitude second" poll:1000ms → int per 7 0x000200b6
- [RO] keyValue: "longitude degree" poll:10000ms → int per 7 0x000200b8
- [RO] keyValue: "longitude minute" poll:3000ms → int per 7 0x000200b9
- [RO] keyValue: "longitude second" poll:1000ms → int per 7 0x000200ba

### GPS/SatInfo  (NavGpsSatInfo.esd)

- [RO] keyValue: "GPS fix" poll:1000ms → int per 7 0x000200ae
- [RO] keyValue: "HDOP" poll:1000ms → int per 7 0x000200c1
- [RO] keyValue: "PDOP" poll:1000ms → int per 7 0x000200c0
- [RO] keyValue: "VDOP" poll:1000ms → int per 7 0x000200c2
- [RO] keyValue: "used satellites" poll:1000ms → int per 7 0x000200bb
- [RO] keyValue: "visible satellites" poll:1000ms → int per 7 0x000200bc


## HD/

### HD/HDAdditionalStationInfo  (HDAddStationInfo.esd)

- [RO] keyValue: "Digital Audio Playing" poll:2000ms → String per 1 0x0001090E
- [RO] keyValue: "Digital Audio Available" poll:2000ms → String per 1 0x0001090F
- [RO] keyValue: "Program Playing" poll:2000ms → int per 1 0x00011000
- [RO] keyValue: "Programs Available" poll:2000ms → int per 1 0x00011001
- [RO] keyValue: "Quality" poll:2000ms → int per 1 0x00011002
- [RO] keyValue: "Station Name" poll:2000ms → String per 1 0x00011003
- [RO] keyValue: "Artist Name" poll:2000ms → String per 1 0x00011004
- [RO] keyValue: "Album Title" poll:2000ms → String per 1 0x00011005
- [RO] keyValue: "Song Title" poll:2000ms → String per 1 0x00011006

### HD/HDBer  (HDBer.esd)

- [WR] button: "Measurement Reset" → per 1 0x00011029 "enable"
- [WR] slider: "HDBerSwitch Off/On" → per 1 0x0001102A 0 1
- [--] table

### HD/HDBlending  (HDBlending.esd)

- [WR] slider: "HDBlending Type" → per 1 0x00010908 1 4
- [WR] slider: "HDBlending Threshold" → per 1 0x00010907 0 7
- [--] table

### HD/HDPSDInfo  (HDPSDInfo.esd)

- [RO] keyValue: "Genre" poll:2000ms → String per 1 0x0001102B
- [RO] keyValue: "Language" poll:2000ms → int per 1 0x0001102C
- [RO] keyValue: "Short Description" poll:2000ms → String per 1 0x0001102D
- [RO] keyValue: "Content Field" poll:2000ms → String per 1 0x0001102E
- [RO] keyValue: "Price" poll:2000ms → String per 1 0x0001102F
- [RO] keyValue: "Valid Until" poll:2000ms → String per 1 0x00011030
- [RO] keyValue: "Contact URL" poll:2000ms → String per 1 0x00011031
- [RO] keyValue: "Received As" poll:2000ms → int per 1 0x00011032
- [RO] keyValue: "Name Of Seller" poll:2000ms → String per 1 0x00011033
- [RO] keyValue: "COMR Description" poll:2000ms → String per 1 0x00011034
- [RO] keyValue: "MIME Type" poll:2000ms → String per 1 0x00011035

### HD/HDPerformance  (HDPerformance.esd)

- [RO] keyValue: "SIS Frame Acq Time" poll:2000ms → int per 1 0x00011014
- [RO] keyValue: "Audio Acq Time" poll:2000ms → int per 1 0x00011015
- [RO] keyValue: "Signal To Noise Ratio" poll:2000ms → int per 1 0x00011016
- [RO] keyValue: "Analog Audio Time" poll:2000ms → int per 1 0x00011017
- [RO] keyValue: "Blending Counter" poll:2000ms → int per 1 0x00011018

### HD/HDTest  (HDTest.esd)

- [WR] slider: "Select FM Frequency" → per 1 0x00010900 875 1080
- [WR] slider: "Select HDSubChannel" → per 1 0x00010901 0 8
- [WR] slider: "HDSwitch undef/auto/analog/dig" → per 1 0x00010903 0 3
- [WR] slider: "HDCalibration Off/On" → per 1 0x00011028 0 1

### HD/HDTestDataStatus  (HDTestDataStatus.esd)

- [RO] keyValue: "Primary Service Mode" poll:2000ms → int per 1 0x0001100B
- [RO] keyValue: "Acquired Digital Signal" poll:2000ms → String per 1 0x0001100C
- [RO] keyValue: "Passed SISCRC" poll:2000ms → String per 1 0x0001100D
- [RO] keyValue: "Acquired Digital Audio" poll:2000ms → String per 1 0x0001100E
- [RO] keyValue: "Enable Blend" poll:2000ms → String per 1 0x0001100F
- [RO] keyValue: "Codec Mode" poll:2000ms → int per 1 0x00011010
- [RO] keyValue: "Digital TX Audio Gain" poll:2000ms → int per 1 0x00011011
- [RO] keyValue: "Blend TX Control" poll:2000ms → int per 1 0x00011012
- [RO] keyValue: "Quality Indicator" poll:2000ms → int per 1 0x00011013


## HDD/

### HDD/SMART  (Smart.esd)



## IRC/

### IRC/Trigger  (IRCTrigger.esd)

- [RW] choice: "system temperature" → per 5 0x00010001
- [RW] choice: "system DVD drive temp high" → per 5 0x00010002
- [RW] choice: "system CD drive temp high" → per 5 0x00010003
- [RW] choice: "system DVD drive temp low" → per 5 0x00010004
- [RW] choice: "system CD drive temp low" → per 5 0x00010005
- [RW] choice: "system DVD drive damaged" → per 5 0x00010006
- [RW] choice: "system CD drive damaged" → per 5 0x00010007
- [RW] choice: "system drive read error" → per 5 0x00010008
- [RW] choice: "system HDD defect" → per 5 0x00010009
- [RW] choice: "system HDD pressure" → per 5 0x0001000A
- [RW] choice: "system overheat" → per 5 0x0001000B
- [RW] choice: "system drive error" → per 5 0x0001000C
- [RW] choice: "phone not functional" → per 5 0x0001000D
- [RW] choice: "phone temperature off" → per 5 0x0001000E
- [RW] choice: "phone secco blocked" → per 5 0x0001000F
- [RW] choice: "IRC exception" → per 5 0x0001003D
- [RW] choice: "IRC reset" → per 5 0x0001003E
- [RW] choice: "IRC hotkey" → per 5 0x0001003F


## MOST/

### MOST/AllocationTable  (MOSTAllocTable.esd)

- [RO] keyValue: "Num of allocated channels" poll:1000ms → int per 1 0x00130002

### MOST/CentralRegistry  (MOSTCenReg.esd)

- [--] table


## Main/

### Main/"EepromFlags"  (AAAVersion.esd)

- [EX] script: "Start Script"
- [RO] keyValue: "Train name" → String per 3 0x00120004

### Main/AEVTest  (Aevtest.esd)


### Main/Addressbook  (Addressbook.esd)

- [RW] choice: "PB-DL OADB cancel active:" → per 1 0x000C0000
- [RW] choice: "OPP OADB cancel active:" → per 1 0x000C0001
- [EX] script: "copy db  to sdcard"
- [EX] script: "copy tef to sdcard"
- [EX] script: "delete db"

### Main/Audiomanagement  (AudioManagement.esd)


### Main/Bluetooth  (Bluetooth.esd)

- [RW] choice: "Link key restriction active" → per 4 0x00020001
- [RW] choice: "A2DP Activation" → per 1 0x000F0026

### Main/Browser  (Browser.esd)

- [EX] script: "Delete Old Non-ISO Boardbook"

### Main/Bths  (Bths.esd)

- [--] table
- [--] table

### Main/Config  (Config.esd)

- [RO] keyValue: "IP assignment: " poll:1000ms → String per 1 0x00090003
- [EX] script: "Activate DHCP"
- [EX] script: "Activate fixed IP"
- [EX] script: "Install Fair Mode"
- [EX] script: "Uninstall Fair Mode"
- [EX] script: "Show Network Configuration"
- [EX] script: "Show IP Settings"
- [EX] script: "Show Adapter Settings"
- [EX] script: "Modify Reset On ASAD-Error"
- [RO] keyValue: "language HMI system: " → String per 1 0x00090004
- [RO] keyValue: "language Navi TTS : " → String per 1 0x00090005
- [RO] keyValue: "language SDS: " → String per 1 0x00090006

### Main/CrossUnitCom  (CrossUnitCom.esd)

- [RW] choice: "Wait for domains" → per 1 0x00050048
- [RW] choice: "Wait for audio domains" → per 1 0x00050049

### Main/DTC  (Dtc.esd)


### Main/Diagnose  (Diagnose.esd)


### Main/Display  (Display.esd)

- [RW] choice: "clamp 58d 0:=->100; 1:=->255" → per 3 0x00010027
- [WR] button: "override other brightness setting devices" → per 3 0x0001001D ""
- [WR] slider: "Select brightness value" → per 3 0x0001001C 2 255

### Main/EepromFlags  (EepromFlags.esd)

- [WR] slider: "import MM lock status: " → per 3 0x0011000D 0 3
- [WR] BIOSCtrl: "Watchdog SH4 status:" (3 options) → int per 3 0x0011000E

### Main/Environment  (Environment.esd)

- [RO] keyValue: "FOT temperature" poll:1000ms → int per 3 0x00000004
- [RO] keyValue: "Bluetooth device address" poll:10000ms → String per 1 0x00050038
- [RO] keyValue: "WLAN device address" poll:10000ms → String per 1 0x00050039

### Main/FrontCtrl  (Front.esd)

- [WR] BIOSCtrl: "Baud Rate Normal" (7 options) → int per 3 0x0050000B
- [WR] BIOSCtrl: "Baud Rate SWDL" (7 options) → int per 3 0x0050000C
- [WR] button: "activate baud rate" → per 3 0x0050000D ""

### Main/GoogleEarth  (GoogleEarth.esd)

- [EX] script: "Restart GEMMI (volatile)"
- [EX] script: "Shutdown GEMMI (volatile)"
- [EX] script: "Start GEMMI (volatile)"
- [EX] script: "Deactivate GEMMI (persistent)"
- [EX] script: "Activate GEMMI (persistent)"
- [EX] script: "Get GEMMI Cache Status"
- [EX] script: "Delete Cache GEMMI"
- [EX] script: "Get Info GEMMI"
- [WR] button: "Open DataConnection (ApplicationID=0)" → per 1 0x00050043 "0"
- [WR] button: "Close DataConnection (ApplicationID=0)" → per 1 0x00050044 "0"

### Main/IRC  (IRC.esd)


### Main/Java  (JavaSys.esd)

- [RO] keyValue: "Free Runtime Memory (KB)" poll:1000ms → int sys 1 1
- [RO] keyValue: "Total Runtime Memory (KB)" poll:1000ms → int sys 1 0x002
- [WR] button: "Garbage Collect" → sys 1 0x003 ""

### Main/MOST  (MOST.esd)


### Main/Main  (Main.esd)


### Main/MostCombi  (MostCombi.esd)

- [RW] choice: "Enable static frame rate" → per 1 0x00210004
- [WR] slider: "static frame rate (fps)" → per 1 0x00210005 5 100
- [WR] slider: "dynamic frame rate (fps)" → per 1 0x0021000B 5 100
- [WR] slider: "Resend delay (ms)" → per 1 0x00210003 100 1000
- [WR] slider: "Resend delay overlay (ms)" → per 1 0x0021000F 0 500
- [RW] choice: "Enable empty picture on recalc" → per 1 0x00210010
- [WR] slider: "Delay empty picture (100ms)" → per 1 0x00210011 1 20
- [WR] slider: "Delay recalc picture (100ms)" → per 1 0x00210012 10 50
- [WR] slider: "Show recalc picture (100ms)" → per 1 0x00210013 5 20
- [RW] choice: "Enable Fading" → per 1 0x00210000
- [RW] choice: "Enable KombiViewDebugMode" → per 1 0x0021000C
- [RW] choice: "Enable ZLIB Overlay" → per 1 0x00210002
- [RW] choice: "Enable ZLIB Kamerafahrt" → per 1 0x0021000D
- [RW] choice: "Latency measure" → per 1 0x00210009

### Main/Nav  (Nav.esd)

- [WR] button: "Activate PSD" → per 1 0x00030065 "activate PSD"

### Main/OnOffTimer  (OnOffTimer.esd)

- [WR] slider: "OFF 1 delay (Sec)" → per 3 0x00140102 0 255
- [WR] slider: "OFF 2 delay (Sec)" → per 3 0x00140103 0 255
- [WR] slider: "Standby delay (Min)" → per 3 0x00140104 0 30
- [WR] slider: "Power down delay (Min)" → per 3 0x00140105 0 30
- [WR] slider: "Power down delay 2 (Sec)" → per 3 0x00140106 0 255
- [WR] slider: "Watchdog behaviour" → per 3 0x00140107 0 3
- [WR] slider: "BEM shutdown delay (Min)" → per 3 0x00130002 0 60
- [WR] slider: "Transport delay (Sec)" → per 0 0x0002059d 0 60
- [RW] choice: "Power down timer state" → per 0 0x0002044b
- [WR] button: "reset all timer values" → per 1 0x00050037 ""
- [WR] button: "reset all timers to test" → per 1 0x00050041 ""

### Main/RU  (RU.esd)

- [RO] keyValue: "Fan speed" poll:1000ms → int per 1 0x00020003
- [RO] keyValue: "FOT temperatur RU" poll:1000ms → int per 1 0x00020004
- [RO] keyValue: "Amplifier temperatur RU" poll:1000ms → int per 1 0x00020005
- [RO] keyValue: "FOT temperatur RU Max" → int per 1 0x00020006
- [RO] keyValue: "Amplifier temperatur RU max" → int per 1 0x00020007

### Main/RUSirius  (RUSirius.esd)

- [WR] slider: "Mode" → per 1 0x0002000F 0 2

### Main/Radio  (Radio.esd)


### Main/SD  (SD.esd)

- [--] table

### Main/SDS  (SDS.esd)

- [RO] keyValue: "Last recognized confidence" poll:1000ms → int per 1 0x000D0037
- [--] table
- [--] table
- [RO] keyValue: "Last rule" poll:1000ms → String per 1 0x000d0001
- [RO] keyValue: "Last recognized word" poll:1000ms → String per 1 0x000d0035
- [RO] keyValue: "Last not enrolled word" poll:1000ms → String per 1 0x000d0038
- [RO] keyValue: "Dialog version" poll:1000ms → String per 1 0x000D0009
- [RO] keyValue: "Current language" poll:1000ms → String per 1 0x000D000B
- [RO] keyValue: "Current CSF string" poll:1000ms → String per 1 0x000d0034
- [RW] choice: "SDS Mic1" → per 1 0x000D0026
- [RW] choice: "SDS Reference chanel" → per 1 0x000D0027
- [RW] choice: "NADul 1" → per 1 0x000D0028
- [RW] choice: "NADul 2" → per 1 0x000D0029
- [RW] choice: "NAD reference" → per 1 0x000D002A
- [RW] choice: "NADdl" → per 1 0x000D002B
- [RW] choice: "BTul 1" → per 1 0x000D002C
- [RW] choice: "BTul 2" → per 1 0x000D002D
- [RW] choice: "BT reference" → per 1 0x000D002E
- [RW] choice: "BTdl" → per 1 0x000D002F
- [RW] choice: "BTHSul" → per 1 0x000D0030
- [RW] choice: "BTHSdl" → per 1 0x000D0031
- [WR] button: "Start record" → per 1 0x000D0032 "/HBpersistence/audio"
- [WR] button: "Stop record" → per 1 0x000D0033 "/HBpersistence/audio"

### Main/SWDL  (SWDL.esd)

- [RO] keyValue: "count down" poll:1000ms → int per 3 0x00120000
- [RO] keyValue: "HW index IT" poll:1000ms → int per 3 0x00120002
- [RO] keyValue: "unexpected resets" poll:1000ms → int per 3 0x00120003
- [RO] keyValue: "current version" poll:1000ms → String per 3 0x00120001
- [RW] choice: "user defined mode" → per 1 0x001E0000
- [RW] choice: "ignore region and variant" → per 1 0x001E0004

### Main/Serial_If_Test  (SerialIfTest.esd)

- [RW] choice: "Start serial Test for ETC" → per 1 0x001A0000
- [--] table
- [RO] keyValue: "State of last cycle ETC" poll:100ms → int per 1 0x001A0004
- [RW] choice: "Start serial Test for VICS" → per 1 0x001A0005
- [--] table
- [RO] keyValue: "State of last cycle VICS" poll:100ms → int per 1 0x001A0009
- [RW] choice: "Start serial Test for IPOD" → per 1 0x001A000A
- [--] table
- [RO] keyValue: "State of last cycle IPOD" poll:100ms → int per 1 0x001A000D

### Main/System  (System.esd)

- [RW] choice: "is production mode active: " → per 3 0x00110013
- [WR] button: "connect UMTS (channel 0)" → per 1 0x00050043 "0"
- [WR] button: "disconnect UMTS (channel 0)" → per 1 0x00050044 "0"
- [RO] keyValue: "battery voltage (x100 mV)" poll:500ms → int per 3 0x00000023
- [WR] slider: "Choose system tone" → per 1 0x00050035 10 13
- [RW] choice: "is system tone active: " → per 1 0x00050036
- [RO] keyValue: "Serial number" → String per 3 0x0011000A
- [RO] keyValue: "VW system name" → String per 3 0x0011000C
- [RO] keyValue: "cable code info (hex)" poll:5000ms → int per 3 0x00000024
- [RO] keyValue: "connected HUC/BTHS (hex)" poll:5000ms → int per 3 0x00300007
- [WR] slider: "PerfLoad Freq. (sec)" → per 4 0x0001003 0 10
- [RO] keyValue: "CPU" poll:2000ms → int per 1 0x5003b
- [WR] slider: "No, Memory, CPU" → per 4 0x00001007 0 2
- [WR] BIOSCtrl: "kind of state line" (11 options) → int per 4 0x00010000
- [WR] button: "activate LSD developement" → per 1 0x00050045 "0"
- [WR] button: "activate LSD production" → per 1 0x00050046 "0"
- [WR] button: "activate LSD consolidated" → per 1 0x00050047 "0"
- [WR] BIOSCtrl: "summer time" (4 options) → int per 3 0x0014001F

### Main/Telephony  (Telephony.esd)

- [RO] keyValue: "signal quality" poll:1000ms → int per 1 0x00060002
- [RO] keyValue: "register state" poll:1000ms → int per 1 0x00060003
- [RO] keyValue: "network type" poll:1000ms → int per 1 0x00060005
- [RO] keyValue: "UMTS module installed: " poll:1000ms → String per 1 0x0009000F
- [--] table
- [RO] keyValue: "mic mute state" poll:1000ms → int per 1 0x00060007
- [RO] keyValue: "NAD temp state" → String per 1 0x0006002B
- [RO] keyValue: "NAD temperature" poll:1000ms → int per 1 0x0006004F
- [RO] keyValue: "handsfree activity" poll:1000ms → int per 1 0x0006003B
- [RO] keyValue: "number of connected devices" poll:1000ms → int per 1 0x000F0002
- [RO] keyValue: "BT connection state" poll:1000ms → int per 1 0x000F0000
- [RO] keyValue: "GSM power state" poll:1000ms → int per 1 0x0006003F

### Main/Tv  (TV.esd)

- [RO] keyValue: "tuner state" poll:1000ms → int per 1 0x00040000
- [RO] keyValue: "selected source" poll:1000ms → int per 1 0x00040003
- [RO] keyValue: "TV norm area" poll:1000ms → int per 1 0x00040004
- [RO] keyValue: "Audio format" poll:3000ms → int per 1 0x00040005
- [RO] keyValue: "Terminal mode" poll:2000ms → int per 1 0x00040006
- [RO] keyValue: "Key panel state" poll:2000ms → int per 1 0x00040007
- [RO] keyValue: "Diversity state" poll:2000ms → int per 1 0x00040008
- [RO] keyValue: "AV 1 norm" poll:2000ms → int per 1 0x00040009
- [RO] keyValue: "AV 2 norm" poll:2000ms → int per 1 0x0004000A

### Main/Tvtpeg  (Tvtpeg.esd)

- [RO] keyValue: "switch status" poll:1000ms → int per 1 0x00250001
- [RO] keyValue: "device available" poll:1000ms → int per 1 0x00250002
- [RO] keyValue: "tpeg status" poll:1000ms → int per 1 0x00250004
- [WR] slider: "Tpeg switch" → per 1 0x00250000 0 1

### Main/USB  (USB.esd)

- [RW] choice: "Hub + iPod/USB cable support" → per 1 0x00180008
- [RO] keyValue: "Num of attached devices" poll:1000ms → int per 1 0x00180000
- [RO] keyValue: "Used bus, device address" poll:1000ms → String per 1 0x00180001
- [WR] slider: "select USB log. bus" → per 1 0x00180007 0 9
- [WR] slider: "select USB device address" → per 1 0x00180002 1 64
- [--] table

### Main/WLAN  (WLAN.esd)

- [RW] choice: "Adaption 0x13 WLAN ON:" → per 1 0x00230005
- [RW] choice: "wlan running" → per 1 0x00230008
- [RO] keyValue: "SSID:" poll:2000ms → String per 1 0x00230003
- [RO] keyValue: "password:" poll:2000ms → String per 1 0x00230004
- [RO] keyValue: "mac:" poll:2000ms → String per 1 0x00230000
- [WR] button: "set simple default password" → per 1 0x00230009 "setpasswd"


## Main��/

### Main��/Car  (Car.esd)



## Main���/

### Main���/Trace  (Trace.esd)



## Media/

### Media/MediaBluetooth  (MediaBt.esd)

- [RO] keyValue: "SPD record (hex)" → int per 4 0x00020000

### Media/MediaPlayer  (MediaPlayer.esd)

- [--] table
- [RO] keyValue: "Int drive temp status" poll:2000ms → String per 1 0x00100024


## MostCombi/

### MostCombi/Statistics  (MostCombiStats.esd)

- [RO] keyValue: "latency" poll:1000ms → String per 1 0x00220000
- [RO] keyValue: "size last fullframe" poll:1000ms → int per 1 0x00220001
- [RO] keyValue: "size last baseframe" poll:1000ms → int per 1 0x00220002
- [RO] keyValue: "size last overlay" poll:1000ms → String per 1 0x00220003
- [RO] keyValue: "actual framerate" poll:1000ms → String per 1 0x00220004
- [RO] keyValue: "eventdrops mapviewer" poll:2000ms → int per 1 0x00220009
- [RO] keyValue: "framedrops compression" poll:2000ms → int per 1 0x00220005
- [RO] keyValue: "framedrops Most" poll:2000ms → String per 1 0x00220006
- [RO] keyValue: "combi errors" poll:2000ms → int per 1 0x0022000A
- [RO] keyValue: "compress errors" poll:2000ms → int per 1 0x00220007
- [RO] keyValue: "picnum compr/sent" poll:1000ms → String per 1 0x00220008


## Nav/

### Nav/DatabaseUpdate  (NavCopy.esd)

- [EX] script: "List HDD Database info"
- [WR] BIOSCtrl: "active HDD Nav DB" (18 options) → int per 3 0x00100000
- [WR] BIOSCtrl: "internal region code" (7 options) → int per 3 0x0011000F
- [EX] script: "Re-check database (will need reboot)"
- [EX] script: "Delete database (will need reboot)"
- [EX] script: "Delete Nav HDD partition"

### Nav/DiagValues  (NavDiag.esd)

- [RO] keyValue: "ON_HDD_AVAILABLE" poll:10000ms → int per 1 0x0003004D
- [RO] keyValue: "ON_HDD_INFO" poll:10000ms → String per 1 0x0003004E
- [RO] keyValue: "DB_VERSION_INFO" poll:10000ms → String per 1 0x0003001A
- [RO] keyValue: "ON_SD_AVAILABLE" poll:10000ms → int per 1 0x0003004F
- [RO] keyValue: "ON_SD_INFO" poll:10000ms → String per 1 0x00030050
- [RO] keyValue: "ON_DVD_AVAILABLE" poll:10000ms → int per 1 0x0003004B
- [RO] keyValue: "ON_DVD_INFO" poll:10000ms → String per 1 0x0003004C
- [RO] keyValue: "ACTIVE_NAV_DATABASE" poll:10000ms → int per 1 0x0003005F
- [RO] keyValue: "ALMANACH_COUNTER" poll:10000ms → int per 1 0x0003005C

### Nav/Engineering  (NavEngineering.esd)

- [RO] keyValue: "DB available" poll:1000ms → int per 1 0x00030000
- [RO] keyValue: "Demo mode active" poll:1000ms → int per 1 0x00030001
- [WR] BIOSCtrl: "NavLanguage" (17 options) → String per 1 0x00030002
- [RO] keyValue: "metric system" poll:1000ms → int per 1 0x00030003
- [WR] BIOSCtrl: "distance unit" (3 options) → int per 1 0x000300AE
- [RO] keyValue: "ready to work" poll:1000ms → int per 1 0x00030004
- [RO] keyValue: "is busy" poll:2000ms → int per 1 0x00030014
- [RO] keyValue: "path to config base" poll:0ms → String per 1 0x00030018
- [RW] choice: "Kalibr. Screen aus" → per 1418463180   648518346341285888
- [EX] script: "set data base"
- [EX] script: "Backup .CVA files"
- [EX] script: "Remove calibration"
- [EX] script: "Restore existing calibration data"

### Nav/Map  (NavMapEng.esd)

- [RW] choice: "Enable custom scroll speeds" → per 1 0x00030069
- [WR] slider: "Scroll frame rate (fps)" → per 1 0x00030060 1 30
- [WR] slider: "Time between steps(*10ms) " → per 1 0x00030061 100 300
- [WR] slider: "Speed for step 1 (pixel/s)" → per 1 0x00030062 0 100
- [WR] slider: "Speed for step 2 (pixel/s)" → per 1 0x00030063 50 150
- [WR] slider: "Speed for step 3 (pixel/s)" → per 1 0x00030064 50 300
- [WR] button: "Enable Satellite Images" → per 1 0x00030094 1
- [WR] button: "Disable Satellite Images" → per 1 0x00030095 0

### Nav/PSD  (NavPSD.esd)

- [RO] keyValue: "PSD on/off" poll:3000ms → int per 1 0x0003008A
- [RO] keyValue: "PSD disabled" poll:3000ms → int per 1 0x0003008E
- [WR] button: "Enable PSD in demo mode" → per 1 0x000300A9 PsdDemoMode
- [RO] keyValue: "customes experience (diag)" poll:3000ms → int per 1 0x0003008F
- [RO] keyValue: "navigation information (diag)" poll:3000ms → int per 1 0x00030090
- [WR] button: "Next Set" → per 1 0x0003006f nextSet
- [RO] keyValue: "Datasetnumber" poll:3000ms → int per 1 0x00030093
- [RO] keyValue: "start" poll:3000ms → int per 1 0x00030070
- [RO] keyValue: "end" poll:3000ms → int per 1 0x00030071
- [RO] keyValue: "distance" poll:3000ms → int per 1 0x00030072
- [RO] keyValue: "customer experience (int.)" poll:3000ms → int per 1 0x00030073
- [RO] keyValue: "navigation information (int.)" poll:3000ms → int per 1 0x00030074
- [RO] keyValue: "RG %" poll:3000ms → int per 1 0x00030075
- [RO] keyValue: "FRC0 %" poll:3000ms → int per 1 0x00030076
- [RO] keyValue: "FRC1 %" poll:3000ms → int per 1 0x00030077
- [RO] keyValue: "FRC2 %" poll:3000ms → int per 1 0x00030078
- [RO] keyValue: "FRC3 %" poll:3000ms → int per 1 0x00030079
- [RO] keyValue: "FRC4 %" poll:3000ms → int per 1 0x0003007A
- [RO] keyValue: "FRC5 %" poll:3000ms → int per 1 0x0003007B
- [RO] keyValue: "FRC6 %" poll:3000ms → int per 1 0x0003007C
- [RO] keyValue: "FRC7 %" poll:3000ms → int per 1 0x0003007D
- [RO] keyValue: "offroad %" poll:3000ms → int per 1 0x0003007E
- [RO] keyValue: "ATLAS %" poll:3000ms → int per 1 0x0003007F
- [RO] keyValue: "ADAS %" poll:3000ms → int per 1 0x00030080
- [RO] keyValue: "Klothoiden %" poll:3000ms → int per 1 0x00030081
- [RO] keyValue: "urban %" poll:3000ms → int per 1 0x00030082
- [RO] keyValue: "IPD %" poll:3000ms → int per 1 0x00030083
- [RO] keyValue: "error <10m %" poll:3000ms → int per 1 0x00030084
- [RO] keyValue: "error <50m %" poll:3000ms → int per 1 0x00030085
- [RO] keyValue: "error >50m %" poll:3000ms → int per 1 0x00030086
- [RO] keyValue: "reset" poll:3000ms → int per 1 0x00030087
- [RO] keyValue: "segments" poll:3000ms → int per 1 0x00030088
- [RO] keyValue: "horizon" poll:3000ms → int per 1 0x00030089

### Nav/Sensorik  (NavSensoric.esd)

- [RO] keyValue: "RIZ" poll:1000ms → int per 7 0x000200d2
- [RO] keyValue: "Counter" poll:1000ms → int per 7 0x000200dd
- [RO] keyValue: "Summe" poll:1000ms → int per 7 0x000200dc
- [RO] keyValue: "Calibration Level" poll:1000ms → int per 7 0x00020226
- [RO] keyValue: "Gyro Settings" poll:1000ms → int per 7 0x0002021b

### Nav/Tmc  (NavTmcEng.esd)

- [RW] choice: "Tmc Engeneering Mode" → per 1 0x00080006
- [RO] keyValue: "Messages in list." poll:1000ms → int per 1 0x00080002
- [RO] keyValue: "Messages on route." poll:1000ms → int per 1 0x00080001
- [RO] keyValue: "Messages in system" poll:1000ms → int per 1 0x00080008
- [RO] keyValue: "Tmc available" poll:1000ms → int per 1 0x00080007
- [RO] keyValue: "TPEG selected provider" poll:1000ms → String per 1 0x0008000A
- [RO] keyValue: "TPEG Number of TEC-messages" poll:1000ms → int per 1 0x0008000B
- [RO] keyValue: "TPEG Number of TFP-messages" poll:1000ms → int per 1 0x0008000C
- [RO] keyValue: "TPEG consumed data in Kbytes" poll:1000ms → int per 1 0x0008000D
- [WR] button: "TPEG reset information data" → per 1 0x0008000E "resetInformationData"
- [WR] BIOSCtrl: "TMC Sets" (20 options) → int per 1 0x0003008B

### Nav/TrafficOnline  (NavTrafficOnline.esd)

- [RO] keyValue: "Application State" poll:3000ms → int per 4 0x00001016
- [RO] keyValue: "Request Timer Setting" poll:3000ms → int per 4 0x00001017
- [RO] keyValue: "Connection Last State" poll:3000ms → int per 4 0x00001018
- [RO] keyValue: "Connection Last Date" poll:3000ms → String per 1 0x000300A1
- [RO] keyValue: "Connection Last Time" poll:3000ms → String per 1 0x000300A2
- [RO] keyValue: "Connection Last Session" poll:3000ms → String per 4 0x0000101B
- [WR] BIOSCtrl: "TPEG endpoint URL" (4 options) → int per 4 0x00001013
- [WR] BIOSCtrl: "TPEG content source" (8 options) → int per 4 0x00001014
- [RW] choice: "Authentication Off: " → per 4 0x00001015


## Nav��/

### Nav��/GPS  (NavGPS.esd)



## Radio/

### Radio/AMFM  (AMFM.esd)

- [WR] button: "Disable Test Mode" → per 1 0x0001000F "disable"
- [RO] keyValue: "Selected Test Mode" poll:1000ms → String per 1 0x00010008
- [--] table

### Radio/DAB  (DAB.esd)

- [RO] keyValue: "Detected Device" poll:2000ms → String per 1 0x00110025

### Radio/SDARS  (SDARS.esd)


### Radio/TIM  (TIM.esd)


### Radio/TmcChina  (TmcChina.esd)


### Radio/TunerAnnouncement  (TunerAnnouncement.esd)



## Route/

### Route/POIList  (NavEngRouteTables.esd)

- [--] table
- [--] table
- [--] table
- [--] table


## SD/

### SD/SD-Slot1  (SD-Slot1.esd)

- [--] table

### SD/SD-Slot2  (SD-Slot2.esd)

- [--] table


## SDARS/

### SDARS/CategoryList  (SDARSCategroyList.esd)

- [--] table

### SDARS/CurrentStation  (SDARSCurrentStation.esd)

- [RO] keyValue: "Number" poll:2000ms → int per 1 0x0012000A
- [RO] keyValue: "SID" poll:2000ms → int per 1 0x0012000B
- [RO] keyValue: "Short Name" poll:2000ms → String per 1 0x0012000C
- [RO] keyValue: "Long Name" poll:2000ms → String per 1 0x0012000D
- [RO] keyValue: "Subscription" poll:2000ms → String per 1 0x0012000E
- [RO] keyValue: "Category" poll:2000ms → int per 1 0x0012000F

### SDARS/GeneralInfo  (SDARSGeneralInfo.esd)

- [RO] keyValue: "Detected Device" poll:2000ms → String per 1 0x00120000
- [RO] keyValue: "Provider" poll:2000ms → String per 1 0x00120001
- [RO] keyValue: "Electronic Serial Code" poll:5000ms → String per 1 0x00120002
- [RO] keyValue: "ESC Data Module" poll:5000ms → String per 1 0x00120003
- [RO] keyValue: "Quality Composite" poll:2000ms → String per 1 0x00120006
- [RO] keyValue: "Quality Satellite" poll:2000ms → String per 1 0x00120007
- [RO] keyValue: "Quality Terrestrial" poll:2000ms → String per 1 0x00120008

### SDARS/RadioText  (SDARSRadioText.esd)

- [RO] keyValue: "Station Number" poll:2000ms → int per 1 0x00120011
- [RO] keyValue: "Artist Name Short" poll:2000ms → String per 1 0x00120012
- [RO] keyValue: "Artist Name Long" poll:2000ms → String per 1 0x00120013
- [RO] keyValue: "Artist ID" poll:2000ms → String per 1 0x00120014
- [RO] keyValue: "Program Title Short" poll:2000ms → String per 1 0x00120015
- [RO] keyValue: "Program Title Long" poll:2000ms → String per 1 0x00120016
- [RO] keyValue: "Program ID" poll:2000ms → String per 1 0x00120017
- [RO] keyValue: "Composer" poll:2000ms → String per 1 0x00120018

### SDARS/ServiceStatus  (SDARSServiceStatus.esd)

- [RO] keyValue: "Audio status" poll:2000ms → String per 1 0x00120019
- [RO] keyValue: "Antenna status" poll:2000ms → String per 1 0x0012001A
- [RO] keyValue: "Audio List update status" poll:2000ms → String per 1 0x0012001B
- [RO] keyValue: "Audio Update percentage" poll:2000ms → int per 1 0x0012001C
- [RO] keyValue: "Audio Subscription" poll:2000ms → String per 1 0x0012001D
- [RO] keyValue: "Data update status" poll:2000ms → String per 1 0x0012001F
- [RO] keyValue: "Data Subscription" poll:2000ms → String per 1 0x00120020

### SDARS/StationList  (SDARSStationList.esd)

- [--] table

### SDARS/VersionInfo  (SDARSVersionInfo.esd)

- [--] table


## SMART/

### SMART/StoreSMART  (StoreSmart.esd)

- [WR] BIOSCtrl: "Medium to store" (4 options) → int per 1 0x000E0010
- [WR] button: "Store SMART" → per 1 0x000E0030 "Store SMART"

### SMART/ViewSMART  (ViewSmart.esd)

- [--] table


## Settings/

### Settings/TEL_Settings  (DiagnoseSet0300Telefon.esd)

- [WR] slider: "Delay reference signal (ms): " → per 3 0x0014002C 0 12
- [WR] BIOSCtrl: "Mic sensiblity: " (3 options) → int per 3 0x0014002D
- [RW] choice: "HFP activation: " → per 3 0x00150001
- [RW] choice: "BT activation: " → per 3 0x00150002
- [RW] choice: "NAD activation: " → per 3 0x00150003
- [RW] choice: "NAD operation mode: " → per 3 0x00150018
- [RW] choice: "HFP activation type: " → per 3 0x00150004
- [WR] BIOSCtrl: "BT default visibility: " (3 options) → int per 3 0x00150005

### Settings/WLAN_Settings  (DiagnoseSetA00WLAN.esd)

- [RW] choice: "WLAN activation: " → per 3 0x00140032
- [WR] slider: "max channel number: " → per 3 0x00140033 0 13

### Settings/ami_aux  (DiagnoseSet1000Ami.esd)

- [WR] BIOSCtrl: "AMI" (2 options) → int per 3 0x0015000B
- [WR] BIOSCtrl: "AMI BT" (2 options) → int per 3 0x0015000C
- [WR] BIOSCtrl: "AUX" (2 options) → int per 3 0x0015000D

### Settings/import_multimedia  (DiagnoseSet0400Media.esd)

- [RW] choice: "Ripping: " → per 3 0x00150009
- [RW] choice: "Copying: " → per 3 0x0015000A


## System/

### System/CoreDump  (CoreDump.esd)

- [WR] button: "activate multiple core" → per 1 0x0005003C ""
- [WR] button: "deactivate multiple core" → per 1 0x0005003D ""

### System/Internal  (Internal.esd)

- [WR] BIOSCtrl: "internal region code" (7 options) → int per 3 0x0011000F


## TIM/

### TIM/MessageList  (TIMMessageList.esd)

- [WR] button: "Enable Frequency Update" → per 1 0x0007000E "enable"
- [WR] button: "Disable Frequency Update" → per 1 0x0007000F "disable"
- [RO] keyValue: "Update Status" poll:10000ms → String per 1 0x00070010
- [--] table

### TIM/StatusInfo  (TIMStatusInfo.esd)

- [RO] keyValue: "TIM Status" poll:1000ms → String per 1 0x00070005
- [RO] keyValue: "Time Position" poll:1000ms → int per 1 0x00070006
- [RO] keyValue: "Announcement Running" poll:1000ms → String per 1 0x001F0011
- [RO] keyValue: "Announcement Station-Name" poll:2000ms → String per 1 0x001F0001
- [RO] keyValue: "FM-TP Availablity" poll:2000ms → String per 1 0x001F0012
- [RO] keyValue: "DAB-Traffic Available" poll:2000ms → String per 1 0x001F0013
- [RO] keyValue: "Memory Usage (%)" poll:2000ms → int per 1 0x00070007
- [RO] keyValue: "Free Message List Rows" poll:2000ms → int per 1 0x00070008
- [WR] button: "Start Recording" → per 1 0x0007000B "start"
- [WR] button: "Stop Recording" → per 1 0x0007000C "stop"
- [WR] button: "Delete List" → per 1 0x0007000D "delete"
- [WR] button: "Use Async Channel" → per 1 0x00070011 "async"
- [WR] button: "Use Control Channel" → per 1 0x00070012 "control"

### TIM/TimerList  (TIMTimerList.esd)

- [RO] keyValue: "Number of timers" poll:3000ms → int per 1 0x00070013
- [RO] keyValue: "Recording after shutdown" poll:3000ms → String per 1 0x00070014
- [--] table


## Telephony/

### Telephony/BTConnectedDevices  (TelephonyConnectedDevices.esd)

- [--] table

### Telephony/TelephonyDebugUMTS  (TelephonyDebugUMTS.esd)

- [RO] keyValue: "State:" poll:1000ms → String per 1 0x00060078
- [WR] button: "Activate" → per 1 0x00060072 "activate"
- [WR] button: "Deactivate" → per 1 0x00060073 "deactivate"
- [WR] button: "Restart" → per 1 0x00060077 "restart"
- [RO] keyValue: "QXDM Server addr:port" poll:1000ms → String per 1 0x00060074
- [RW] choice: "Inhibit WLAN -> Internet routing" → per 1 0x00060075
- [RW] choice: "Keep activated after restart" → per 1 0x00060076
- [RW] choice: "activate wlan" → per 1 0x00230008
- [RO] keyValue: "SSID:" poll:2000ms → String per 1 0x00230003
- [RO] keyValue: "password:" poll:2000ms → String per 1 0x00230004
- [WR] button: "set simple default password" → per 1 0x00230009 "setpasswd"

### Telephony/TelephonyProvider  (TelephonyProvider.esd)

- [--] table

### Telephony/TelephonyScript  (TelephonyScripts.esd)

- [RO] keyValue: "State:" poll:1000ms → String per 1 0x00060012
- [WR] button: "Activate" → per 1 0x00060010 "activate"
- [WR] button: "Deactivate" → per 1 0x00060011 "deactivate"

### Telephony/TelephonyStates  (TelephonyStates.esd)

- [--] table

### Telephony/TelephonyUMTSE2DTRIG  (TelephonyUMTSE2DTRIG.esd)

- [WR] slider: "E2D offset : " → per 1 0x00060079 0 100
- [WR] slider: "E3A offset : " → per 1 0x0006007A 0 50
- [WR] button: "Set values" → per 1 0x0006007B "activate"
- [RO] keyValue: "Dataset CRC" poll:1000ms → int per 1 0x0006007C
- [RO] keyValue: "Dataset Version" poll:1000ms → int per 1 0x0006007D
- [WR] slider: "E1E offset : " → per 1 0x0006007E 0 50
- [WR] slider: "E1F offset : " → per 1 0x0006007F 0 50
- [WR] button: "Set E1 values" → per 1 0x00060080 "activate"


## TmcChina/

### TmcChina/TmcChinaStations  (TmcChinaStations.esd)

- [--] table

### TmcChina/TmcChinaStatus  (TmcChinaStatus.esd)

- [RO] keyValue: "Device Available" poll:2000ms → String per 1 0x00200003
- [RO] keyValue: "TMC Switch" poll:2000ms → String per 1 0x00200004
- [RO] keyValue: "TMC Status" poll:2000ms → String per 1 0x00200005
- [--] table
- [--] table


## Trace/

### Trace/InternFBlock  (TraceInternFBlock.esd)

- [RW] choice: "Audio Trace" → per 1 0x000A0100
- [RW] choice: "Telephone Trace" → per 1 0x000A0101
- [RW] choice: "Navigation Trace" → per 1 0x000A0102
- [RW] choice: "Car Trace" → per 1 0x000A0103
- [RW] choice: "Media Trace" → per 1 0x000A0104
- [RW] choice: "SWDL" → per 1 0x000A0105

### Trace/MMEVerbosity  (TraceMMEVerbosity.esd)

- [EX] script: "Enable MME Verbosity"
- [EX] script: "Disable MME Verbosity"

### Trace/TraceScope  (TraceScope.esd)

- [RO] keyValue: "Active scope application: " poll:0ms → String per 1 0x000A0001
- [RO] keyValue: "Active scope J9: " poll:0ms → String per 1 0x000A0004
- [EX] script: "remove the flashed scope settings. Effective after reboot"
- [WR] BIOSCtrl: "Trace scope" (50 options) → int per 1 0x000A0002
- [WR] button: "Activate" → per 1 0x000A0000 " "


## TunerAnnouncement/

### TunerAnnouncement/Filter  (TunerAnnouncementFilter.esd)

- [RW] choice: "All" → per 1 0x001F0002
- [RW] choice: "FM TP" → per 1 0x001F0003
- [RW] choice: "FM PTY31" → per 1 0x001F0004
- [RW] choice: "DAB Alarm" → per 1 0x001F0005
- [RW] choice: "DAB Road Traffic" → per 1 0x001F0006
- [RW] choice: "DAB Transport" → per 1 0x001F0007
- [RW] choice: "DAB Warning" → per 1 0x001F0008
- [RW] choice: "DAB News" → per 1 0x001F0009
- [RW] choice: "DAB Area Weather" → per 1 0x001F000A
- [RW] choice: "DAB Event Announcement" → per 1 0x001F000B
- [RW] choice: "DAB Special Event" → per 1 0x001F000C
- [RW] choice: "DAB Program Information" → per 1 0x001F000D
- [RW] choice: "DAB Sport Report" → per 1 0x001F000E
- [RW] choice: "DAB Financial Report" → per 1 0x001F000F

### TunerAnnouncement/Status  (TunerAnnouncementStatus.esd)

- [RO] keyValue: "Station Name" poll:2000ms → String per 1 0x001F0001
- [--] table


## Tv/

### Tv/TvTables  (TvTables.esd)

- [--] table
- [--] table


## Tvtpeg/

### Tvtpeg/SNIData  (TvtpegSNITables.esd)

- [RO] keyValue: "SID_A" poll:1000ms → int per 1 0x00250006
- [RO] keyValue: "SID_B" poll:1000ms → int per 1 0x00250007
- [RO] keyValue: "SID_C" poll:1000ms → int per 1 0x00250008
- [RO] keyValue: "Version Number" poll:1000ms → int per 1 0x00250009
- [RO] keyValue: "Character Table Identifier" poll:1000ms → int per 1 0x0025000A
- [--] table

### Tvtpeg/TpegData  (TvtpegTpegData.esd)

- [RO] keyValue: "SID_A" poll:1000ms → int per 1 0x00250010
- [RO] keyValue: "SID_B" poll:1000ms → int per 1 0x00250011
- [RO] keyValue: "SID_C" poll:1000ms → int per 1 0x00250012
- [RO] keyValue: "EncrInd" poll:1000ms → int per 1 0x00250013

### Tvtpeg/TpegFilter  (TvtpegFilter.esd)

- [WR] button: "Delete Filter" → per 1 0x0025000B "reset"
- [RO] keyValue: "filter status" poll:1000ms → int per 1 0x0025000C
- [--] table


## Version/

### Version/FrontCtrl  (AAA9VersionFrontCtrl.esd)

- [RO] keyValue: "SW-Version" → String per 3 0x00500009
- [RO] keyValue: "HW-Version" → String per 3 0x0050000E
- [RO] keyValue: "Touchpad-Version" → String per 3 0x0050000F

### Version/Gracenote  (Gracenote.esd)

- [RW] choice: "Gracenote available" → per 1 0x0010002D
- [RO] keyValue: "Version" → String per 1 0x00100029
- [RO] keyValue: "Spare part number" → String per 1 0x0010002B
- [RO] keyValue: "System name" → String per 1 0x0010002C

### Version/InstrumentCluster  (AAA8VersionInstrumentCluster.esd)

- [--] table

### Version/VersionAudio  (AAA4VersionAudio.esd)

- [--] table

### Version/VersionBt  (AAA7VersionBt.esd)

- [--] table

### Version/VersionDU  (AAA3VersionDU.esd)

- [RO] keyValue: "SW version front" → String per 3 0x000103F1
- [RO] keyValue: "SW version left" → String per 3 0x000103F3
- [RO] keyValue: "SW version right" → String per 3 0x000103F2
- [RO] keyValue: "HW version front" → String per 3 0x00010400
- [RO] keyValue: "HW version right" → String per 3 0x00010401
- [RO] keyValue: "HW version left" → String per 3 0x00010402

### Version/VersionMU  (AAA1VersionMU.esd)

- [RO] keyValue: "MU Version" → String per 1 0x0000100D
- [RO] keyValue: "Data base version" → String per 1 0x0003001A
- [RO] keyValue: "FPGA" → String per 1 0x00000002
- [RO] keyValue: "GPS-Version" → int per 7 0x000200c4
- [--] table

### Version/VersionMost  (AAA6VersionMost.esd)

- [--] table

### Version/VersionRU  (AAA2VersionRU.esd)

- [--] table
- [--] table
- [RO] keyValue: "DA710 version" poll:3000ms → String per 1 0x0002000B
- [RO] keyValue: "ATMEGA version" poll:3000ms → String per 1 0x0002000C
- [--] table
- [--] table
- [RO] keyValue: "HD Software Version 1" poll:5000ms → String per 1 0x00020014
- [RO] keyValue: "HD Software Version 2" poll:5000ms → String per 1 0x00020015

### Version/VersionTelephony  (AAA5VersionTelephony.esd)

- [--] table


## VersionMU/

### VersionMU/VersionMuIoc  (AAA12VersionMuIoc.esd)

- [--] table
- [--] table
- [--] table

### VersionMU/VersionMuSh4  (AAA11VersionMuSh4.esd)

- [--] table


## main/

### main/Media  (Media.esd)

- [EX] script: "Delete Backup Folders"

### main/OnOff  (Onoff.esd)

- [--] table

