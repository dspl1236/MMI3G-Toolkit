# IOActive V850 / Harman IOC Research Reference

## Source
"Remote Exploitation of an Unaltered Passenger Vehicle"
Chris Valasek (IOActive) & Charlie Miller
https://ioactive.com/wp-content/uploads/pdfs/IOActive_Remote_Car_Hacking.pdf

## Why This Matters for MMI3G-Toolkit

The 2014 Jeep Cherokee Uconnect system uses the same architecture as MMI3G:
- QNX RTOS on the main application processor
- Renesas V850 IOC chip as the CAN bus gateway
- Harman (Kardon) built the Uconnect, Harman (Becker) built the MMI3G
- Same parent company, similar design patterns

Miller & Valasek fully reverse engineered the V850 IOC on the Jeep,
documented the SPI communication protocol between the head unit and V850,
and successfully flashed modified V850 firmware to send/receive arbitrary
CAN messages. Their methodology is directly applicable to our project.

## Key Sections Relevant to MMI3G

### V850 Modes (p.48)
The V850 has multiple operating modes including a bootloader mode
for firmware updates. The IOC can be reflashed from the head unit
via SPI without physical access to the chip.

### Updating the V850 (p.48)
Documents the firmware update protocol — how the main CPU sends
new firmware to the V850 via SPI. The MMI3G likely uses a similar
mechanism (the MuIOC component in firmware updates flashes V850app.bin).

### Reverse Engineering IOC (p.50-63)
Complete RE methodology for the V850:
- IDA Pro / Ghidra analysis of V850 binary
- Identifying CAN message handlers
- Mapping the SPI command interface
- Finding the CAN TX/RX functions
- Locating the message routing tables

### SPI Communications (p.67-69)
The head unit communicates with the V850 via SPI bus:
- SPI message protocol format documented
- Commands for reading V850 version, status
- Commands for sending/receiving CAN frames
- The V850 acts as a CAN gateway controlled by SPI

### Sending CAN Messages Through the V850 (p.70)
They modified the V850 firmware to accept arbitrary CAN frames
from the head unit and transmit them on the vehicle CAN buses.
For our purposes, we need the REVERSE — reading CAN frames from
the powertrain bus and passing them to the head unit.

### Cyber Physical CAN Messages (p.85-86)
Documents actual CAN message IDs for vehicle functions:
- Turn signals, door locks
- RPM readings
- Diagnostic CAN messages
- UDS SecurityAccess procedures

## Applicability to MMI3G In-Car Diagnostics

### Reading Engine Data (Our Goal)
Miller/Valasek proved the V850 can be reprogrammed to bridge
CAN data between buses. For our use case:

1. Patch V850app.bin to add CAN RX handlers for Motor_1 (0x280),
   Motor_2 (0x288), Speed (0x320) on the Antrieb/Powertrain bus
2. Extract RPM, coolant, speed from the CAN frame bytes
3. Write the extracted values to per 3 slots via the PERS subsystem
4. The SH4/Java layer reads them through DSI persistence
5. Our custom AppDevelopment.jar displays them as gauges

### Full VCDS-Like Diagnostics (Future Goal)
A more ambitious application would be a full diagnostic tool
running on the MMI itself:

1. The V850 IOC can send/receive on ALL CAN buses
2. UDS diagnostic requests (ISO 14229) can query any ECU
3. A Java application on the MMI could:
   - Send UDS requests through the V850 to any module
   - Read DTCs (fault codes) from all ECUs
   - Display live measurement blocks
   - Perform basic coding/adaptation
   - Show freeze frame data
   - Clear fault codes

This would essentially be VCDS built into the car's own head unit.
The MMI already has the hardware capability (V850 talks to all buses)
and the software framework (Java application on J9 JVM with
800x480 display and rotary knob/soft key input).

### Required Components for VCDS-Like App
1. V850 firmware mod: Accept UDS request/response relay commands
   from the SH4 via HPIPC/SPI
2. QNX driver/script: Bridge between Java layer and V850
   (could use /dev/shmem or a custom named pipe)
3. Java application: UDS protocol implementation
   - ISO-TP (ISO 15765-2) transport layer
   - UDS services (ReadDTC, ReadDataByID, SecurityAccess, etc.)
   - ODIS-compatible coding value parser
   - Measurement block display with live refresh
4. ECU database: Module addresses, DTC definitions, measurement
   block definitions (could be sourced from VCDS label files
   or ODIS ODX data)

### Security Considerations
- Our application is READ-ONLY for diagnostics display
- CAN message SENDING should require explicit user confirmation
- Coding/adaptation changes should have a confirmation step
- The V850 firmware mod should be reversible via standard
  firmware update (just reflash stock V850app.bin)
- No remote attack surface — all interaction is local via
  the MMI's physical buttons

## Architecture Comparison

| Component      | Jeep Uconnect | Audi MMI3G    |
|---------------|---------------|---------------|
| Main CPU      | TI OMAP       | Renesas SH4   |
| RTOS          | QNX 6.5       | QNX 6.3       |
| CAN Gateway   | Renesas V850  | Renesas V850  |
| CPU↔V850 Bus  | SPI           | HPIPC (shmem) |
| Application   | Native C/C++  | Java on J9    |
| Display       | 8.4" touch    | 7" 800x480    |
| Manufacturer  | Harman Kardon | Harman Becker |
| CAN Buses     | 2 (C-CAN, IHS)| 3+ (see arch) |

## Next Steps

1. Compare the Jeep's SPI command protocol with the MMI3G's
   HPIPC protocol (both serve the same purpose)
2. Identify the MMI3G's V850 firmware update mechanism
   (the MuIOC update in metainfo2.txt documents this)
3. Determine if the V850 can be reflashed via SD card script
   (safer than SPI-level access)
4. Design the UDS relay protocol for V850↔SH4 communication
5. Build the Java UDS stack for the diagnostic application
