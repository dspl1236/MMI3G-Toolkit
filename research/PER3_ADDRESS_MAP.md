# MMI3G Per 3 (CAN/Vehicle) Address Map
# Extracted from HN+R_EU_AU_K0942 efs-system.efs
# Source: Factory ESD screen definition files
#
# ⚠️  ENGINE PERFORMANCE DATA (RPM, speed, boost, coolant,
#     oil temp) IS NOT PRESENT in any factory ESD file.
#     It either exists at undiscovered per 3 addresses
#     (our scanner targets these gaps) or is not exposed
#     through the DSI persistence layer at all.
#
# Run the can-scanner module on your car to discover
# addresses in the unexplored gaps.
# ============================================================

## LIVE POLLED SENSOR DATA (keyValue with poll interval)

| Address      | Type   | Label                        | Poll  | ESD File              |
|-------------|--------|------------------------------|-------|-----------------------|
| 0x00000004  | int    | FOT temperature              | 1000  | Environment.esd       |
| 0x00000023  | int    | Battery voltage (x100 mV)    | 500   | Environment.esd       |
| 0x00000024  | int    | Cable code info (hex)        | 5000  | Environment.esd       |
| 0x00120000  | int    | Count down                   | 1000  | System.esd            |
| 0x00120002  | int    | HW index IT                  | 1000  | System.esd            |
| 0x00120003  | int    | Unexpected resets            | 1000  | System.esd            |
| 0x00300007  | int    | Connected HUC/BTHS (hex)     | 5000  | Bluetooth.esd         |
| 0x00500000  | int    | Eject Disabled               | 3000  | Media.esd             |


## STATIC STRING DATA (no polling)

| Address      | Type   | Label                        | ESD File              |
|-------------|--------|------------------------------|-----------------------|
| 0x00120004  | String | Train name                   | AAAVersion.esd        |
| 0x00120001  | String | Current version              | System.esd            |
| 0x00110006  | String | VW spare part number         | SparePartNumbers.esd  |
| 0x0011000A  | String | Serial number                | Environment.esd       |
| 0x0011000C  | String | VW system name               | Environment.esd       |
| 0x000103EE  | String | Spare part front display     | SparePartNumbers.esd  |
| 0x000103EF  | String | Spare part right display     | SparePartNumbers.esd  |
| 0x000103F0  | String | Spare part left display      | SparePartNumbers.esd  |
| 0x000103F1  | String | SW version front             | VersionMU.esd         |
| 0x000103F2  | String | SW version right             | VersionMU.esd         |
| 0x000103F3  | String | SW version left              | VersionMU.esd         |
| 0x00010400  | String | HW version front             | VersionMU.esd         |
| 0x00010401  | String | HW version right             | VersionMU.esd         |
| 0x00010402  | String | HW version left              | VersionMU.esd         |
| 0x00500009  | String | SW-Version (touchpad)        | AAAVersion.esd        |
| 0x0050000E  | String | HW-Version (touchpad)        | AAAVersion.esd        |
| 0x0050000F  | String | Touchpad-Version             | AAAVersion.esd        |


## TABLE DATA (structured)

| Address      | Type   | Label                        | ESD File              |
|-------------|--------|------------------------------|-----------------------|
| 0x00000001  | table  | SW version appl IOC          | System.esd            |
| 0x00000002  | table  | SW version bootloader IOC    | System.esd            |
| 0x00000003  | table  | HW version MU                | System.esd            |
| 0x00000021  | table  | MOST version                 | MOST.esd              |
| 0x00000022  | table  | SW version info IOC          | System.esd            |


## CAR DEVICE LIST (choice controls, 0x001000xx)

| Address      | Label                           |
|-------------|----------------------------------|
| 0x00100000  | Active HDD Nav DB               |
| 0x00100002  | Steering wheel derivation       |
| 0x00100004  | Configuration line              |
| 0x00100006  | Vehicle model line              |
| 0x00100008  | Vehicle derivation              |
| 0x00100010  | Air condition                   |
| 0x00100011  | Auxiliary heating               |
| 0x00100012  | Headup display                  |
| 0x00100013  | Adaptive Cruise Control         |
| 0x00100014  | Suspension                      |
| 0x00100015  | Tyre pressure (RDK)             |
| 0x00100016  | Interior light                  |
| 0x00100017  | Exterior light                  |
| 0x00100018  | Park distance control           |
| 0x00100019  | Rearview camera                 |
| 0x0010001A  | Wiper                           |
| 0x0010001B  | Doorlocking                     |
| 0x0010001C  | Mirror                          |
| 0x0010001D  | On-board computer               |
| 0x0010001E  | Clock                           |
| 0x0010001F  | Service interval                |
| 0x00100020  | Central units master (ZEM)      |
| 0x00100021  | Compass                         |
| 0x00100022  | Charisma (Drive Select)         |
| 0x00100023  | Lane departure warning (HCA)    |
| 0x00100024  | Lane change assist (SWA)        |
| 0x00100025  | Braking way reduction (AWV)     |
| 0x00100026  | Seat memory front               |
| 0x00100027  | Seat memory rear                |
| 0x00100028  | Hybrid                          |
| 0x00100029  | Univ garage door opener         |
| 0x0010002A  | Night vision                    |
| 0x0010002B  | Sideview camera                 |
| 0x0010002C  | Rev seat-belt tensioner (RGS)   |
| 0x0010002D  | Traffic sign recognition (VZE)  |
| 0x0010002E  | Rear seat entertainment         |
| 0x0010002F  | Weariness recognition (MKE)     |
| 0x00100030  | MFL                             |
| 0x00100031  | VIN                             |
| 0x00100032  | Battery level gauge             |
| 0x00100033  | Oil level gauge                 |
| 0x00100034  | Sliding roof                    |
| 0x00100035  | Trailer                         |
| 0x00100036  | Driver Monitoring               |
| 0x00100037  | Programmed Keys                 |
| 0x00100064  | Transmission (#24)              |
| 0x00100070  | Seat heating                    |
| 0x00100071  | Tilt angle display              |
| 0x00100088  | Day Night Map Mode              |
| 0x00100089  | RDK                             |


## CAN BUS ASSIGNMENT (BIOSCtrl, 0x001400xx)
# These define which CAN bus (Komfort vs Dashboard) each feature uses.
# Values: 0 = CAN Komfort, 1 = CAN Dashboard

| Address      | Feature                         |
|-------------|----------------------------------|
| 0x0014003D  | Air condition                   |
| 0x0014003F  | Auxiliary heating               |
| 0x00140040  | Headup display                  |
| 0x00140041  | Adaptive cruise control         |
| 0x00140042  | Suspension                      |
| 0x00140043  | Tyre pressure (RDK)             |
| 0x00140044  | Interior light                  |
| 0x00140045  | Exterior light                  |
| 0x00140046  | Park distance control           |
| 0x00140047  | Rearview camera                 |
| 0x00140048  | Wiper                           |
| 0x00140049  | Doorlocking                     |
| 0x0014004A  | Mirror                          |
| 0x0014004B  | On-board computer               |
| 0x0014004C  | Seat memory front               |
| 0x0014004D  | Clock                           |
| 0x0014004E  | Service interval                |
| 0x0014004F  | Central units master (ZEM)      |
| 0x00140050  | Univ garage door opener         |
| 0x00140051  | Compass                         |
| 0x00140053  | Charisma                        |
| 0x00140054  | Night vision                    |
| 0x00140055  | Lane departure warning (HCA)    |
| 0x00140056  | Lane change assist (SWA)        |
| 0x00140057  | Braking way reduction (AWV)     |
| 0x00140059  | Hybrid                          |
| 0x0014005A  | Sideview camera                 |
| 0x0014005B  | Rev seat-belt tensioner (RGS)   |
| 0x0014005D  | Traffic sign recognition (VZE)  |
| 0x0014005E  | Weariness recognition (MKE)     |
| 0x0014005F  | Rear seat entertainment         |
| 0x0014007C  | VIN activate                    |
| 0x0014007D  | Oil level gauge                 |
| 0x0014007E  | Seat Heat                       |
| 0x00140098  | Tilt angle display              |


## UNEXPLORED GAPS (scanner targets)
# These per 3 address ranges have NO factory ESD definitions.
# Engine performance data (if accessible) would be here.

| Range                  | Notes                                    |
|-----------------------|------------------------------------------|
| 0x00000005-0x00000022 | Between FOT temp and MOST version table  |
| 0x00000025-0x000000FF | After cable code, before per 3 config    |
| 0x00000100-0x000103ED | Large gap before display part numbers    |
| 0x00010403-0x0000FFFF | After HW versions                        |
| 0x00020000-0x0002FFFF | COMPLETELY UNUSED (GPS uses this on per 7)|
| 0x00030000-0x0003FFFF | COMPLETELY UNUSED on per 3               |
| 0x00040000-0x0004FFFF | COMPLETELY UNUSED                        |
| 0x00050001-0x00050008 | Gap in touchpad range                    |
| 0x00060000-0x000FFFFF | COMPLETELY UNUSED                        |


## PER 7 (GPS/Navigation) - All Factory Addresses

| Address      | Type   | Label (from ESD context)     |
|-------------|--------|------------------------------|
| 0x000200ae  | int    | (GPS related)                |
| 0x000200b4  | int    | (GPS related)                |
| 0x000200b5  | int    | (GPS related)                |
| 0x000200b6  | int    | (GPS related)                |
| 0x000200b8  | int    | (GPS related)                |
| 0x000200b9  | int    | (GPS related)                |
| 0x000200ba  | int    | (GPS related)                |
| 0x000200bb  | int    | GPS satellites used          |
| 0x000200bc  | int    | GPS satellites visible       |
| 0x000200bf  | int    | (GPS related)                |
| 0x000200c0  | int    | (GPS related)                |
| 0x000200c1  | int    | (GPS related)                |
| 0x000200c2  | int    | (GPS related)                |
| 0x000200c3  | int    | (GPS related)                |
| 0x000200c4  | int    | (GPS related)                |
| 0x000200d2  | int    | (GPS related)                |
| 0x000200dc  | int    | (GPS related)                |
| 0x000200dd  | int    | (GPS related)                |
| 0x0002021b  | int    | (GPS related)                |
| 0x00020226  | int    | (GPS related)                |


## RAW VAG CAN BUS IDs (Drivetrain Bus, 500kbps)
## Cross-reference for scanner results

These are the RAW CAN message IDs on the VAG drivetrain bus.
The GEM per 3 namespace is an abstraction — the CAN gateway
may or may not map these to per 3 addresses.

⚠️  The per 3 address numbers are NOT the same as raw CAN IDs.
    per 3 0x00000023 (voltage) does not mean CAN ID 0x023.
    The mapping is internal to Harman Becker's native code.

| CAN ID | Name     | Byte Layout                                     | Scaling                    |
|--------|----------|-------------------------------------------------|----------------------------|
| 0x280  | Motor_1  | b2=torque, b3:b2=RPM, b5=pedal%, b7=torque_req  | RPM = (b3<<8+b2) / 4      |
| 0x288  | Motor_2  | b1=coolant_temp, b6=power                        | Temp = b1 * 0.75 - 48 (°C)|
| 0x320  | Kombi    | b2=fuel_level, b4:b3=speed, b6:b5=speed_adj     | Speed in km/h              |
| 0x351  | Speed    | b1:b2=speed                                      | Speed = (b2<<8+b1) / 100  |
| 0x380  | Motor_3  | b1=intake_air_temp, b2=pedal_pos                 | Temp = b1 * 0.75 - 48 (°C)|
| 0x621  | Tank     | b3=fuel_level+warning                             |                            |
| 0x1A0  | Wheel    | b4=wheel_speed                                   | Speed = b4 * 1.25 (km/h)  |

Source: iDoka/awesome-automotive-can-id, v-ivanyshyn/parse_can_logs,
        RabbitECUProject, EVA2 CAN analysis, Audiforum CAN protocol thread

### How This Relates to Our Scanner

The scanner probes per 3 addresses through the GEM's DSI persistence layer.
If Harman Becker's CAN gateway maps Motor_1/Motor_2/etc. into per 3 address
space, those addresses would show RPM/coolant/speed values when polled.

If the scanner finds NO engine data in per 3 gaps, it means the CAN gateway
does NOT bridge drivetrain messages to the Java namespace. In that case,
the alternative approach would be:

1. **USB CAN adapter** — Arduino/ESP32 with MCP2515 reading the raw drivetrain
   bus, formatting data, and passing it to the MMI via USB serial
2. **Direct QNX CAN access** — The QNX RTOS has native CAN drivers. A shell
   script could potentially read /dev/can0 (if the device exists) and feed
   data through the GEM script console
3. **OBD-II PID queries** — Standard OBD-II PIDs (mode 01) work on all cars:
   PID 0x0C = RPM, PID 0x0D = Speed, PID 0x05 = Coolant temp,
   PID 0x0B = Intake MAP, PID 0x0F = Intake air temp
   An Arduino/ESP32 on the OBD port could query these and relay to MMI
