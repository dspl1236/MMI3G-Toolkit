# CAN Bus Access Scope — What Can We Reach?

## Porsche Cayenne 958 CAN Topology

The Cayenne 958 has **three main CAN buses** plus a diagnostic bus,
all connected through a **Central Gateway Module (7PP907530)**.

```
                    ┌─────────────────────────┐
                    │   Gateway Module        │
                    │   (7PP907530)           │
                    │                         │
        ┌───────── │  Infotainment CAN ◄──── │ ◄── PCM 3.1 (us!)
        │          │                         │
        │  ┌────── │  Comfort CAN            │ ◄── Cluster, HVAC, Doors
        │  │       │                         │        Seats, KESSY, Wipers
        │  │  ┌─── │  Powertrain CAN         │ ◄── DME, Transmission, ABS
        │  │  │    │                         │        ESP, Steering
        │  │  │    │  Diagnostic CAN (OBD)   │ ◄── OBD-II port
        │  │  │    └─────────────────────────┘
        │  │  │
        ▼  ▼  ▼
    The Gateway controls routing between buses
```

## Which Bus Does the PCM Sit On?

The PCM 3.1 head unit sits on the **Infotainment CAN bus**. But through
the IOC (V850) and the gateway, it has access to modules on OTHER buses:

### Directly on Infotainment CAN (no gateway needed)
- **Instrument Cluster** (Kombi) — CAN ID 0x0717 for UDS
- **BOSE/Burmester amplifier**
- **CD changer / media**
- **Rear entertainment** (if equipped)
- **TV tuner** (if equipped)
- **Telematics module** (3G/4G)

### Via Gateway → Comfort CAN
- **HVAC / Climate control** — temperature, fan, AC
- **Seat modules** — memory positions, heating, ventilation
- **Door modules** — locks, windows, mirrors
- **KESSY** — keyless entry, start/stop
- **Parking sensors / camera**
- **Rear module** — tailgate, cargo lights
- **Tow module** (if equipped)
- **Front-end electronics** — headlights, DRL, wipers

### Via Gateway → Powertrain CAN
- **DME (Engine ECU)** — engine data, fault codes, adaptations
- **Transmission** — gear position, fluid temp, adaptations
- **ABS/ESP** — wheel speeds, brake pressure
- **Transfer case** — AWD mode, fluid info
- **Steering** — EPAS calibration
- **E-Hybrid components** (if equipped) — battery, motor, charging

### Via Gateway → Diagnostic CAN
- **OBD-II standardized data** — all J1979 modes
- **Freeze frame data**
- **Emissions monitors**

## What Can uds_send Access?

### UDS Addressing (ISO 14229)
UDS uses two addressing schemes on Porsche:
- **Physical addressing**: Direct to one ECU (e.g., 0x0717 = cluster)
- **Functional addressing**: Broadcast to all ECUs (0x07DF)

### Common Porsche UDS Module Addresses
| Module | UDS Physical | CAN TX ID | CAN RX ID |
|--------|-------------|-----------|-----------|
| Instrument Cluster | 0x17 | 0x0717 | 0x077D |
| PCM (self) | 0x56 | 0x0756 | 0x07BC |
| DME (Engine) | 0x01 | 0x0701 | 0x0781 |
| Transmission | 0x02 | 0x0702 | 0x0782 |
| ABS/ESP | 0x03 | 0x0703 | 0x0783 |
| Airbag/SRS | 0x15 | 0x0715 | 0x077B |
| Gateway | 0x19 | 0x0719 | 0x077F |
| HVAC | 0x08 | 0x0708 | 0x0788 |
| Seat Module L | 0x36 | 0x0736 | 0x079C |
| Seat Module R | 0x37 | 0x0737 | 0x079D |
| Door FL | 0x44 | 0x0744 | 0x07A4 |
| Door FR | 0x45 | 0x0745 | 0x07A5 |
| Door RL | 0x46 | 0x0746 | 0x07A6 |
| Door RR | 0x47 | 0x0747 | 0x07A7 |
| KESSY | 0x2E | 0x072E | 0x0794 |
| Parking Aid | 0x76 | 0x0776 | 0x07DC |
| Rear Camera | 0x6C | 0x076C | 0x07D2 |
| Front Electronics | 0x09 | 0x0709 | 0x0789 |
| Tow Module | 0x69 | 0x0769 | 0x07CF |
| Hybrid Battery | 0x8C | 0x078C | TBD |

**Note**: Addresses may vary by model year and equipment. These need
verification on Andrew's 2016 Cayenne S E-Hybrid.

## Potential Capabilities (Beyond Oil Reset)

### Diagnostics (Read-Only — Safe)
- **Read fault codes** from ANY module (Service 0x19)
- **Read live data** — RPM, coolant temp, wheel speeds, battery SOC
- **Read freeze frame** data
- **Read module information** — part numbers, SW versions, VIN
- **Read adaptation values** — coding, configuration

### Service Functions (Write — Use Caution)
- **Oil service reset** (cluster DID 0x0156) ← current project
- **Inspection reset** (cluster DID 0x0D17/0x0D18)
- **Clear fault codes** (Service 0x14)
- **Battery registration** (gateway coding)
- **Brake pad reset** (after brake job)
- **Steering angle calibration** (after alignment)
- **Throttle body adaptation** (DME)
- **Window calibration** (comfort module)
- **Seat memory programming** (seat module)

### Long Coding / Configuration (Write — Advanced)
- **Enable/disable features** (DRL, fold mirrors, one-touch windows)
- **Seatbelt chime** modification
- **Sidemarker** light behavior
- **Lock/unlock** confirmation sounds
- **Coming home / leaving home** light timing
- **Tire pressure** monitor reset

### CAUTION: Gateway Filtering
The CAN gateway may filter certain UDS messages. The PCM may not
be able to reach all modules directly. Testing needed to determine:
1. Which modules respond to UDS requests from the PCM
2. Which services the gateway allows through
3. Whether security access (0x27) is required per-module

## Investigation Plan (from PuTTY)

### Step 1: Scan for responding modules
```bash
# Try each module address
for addr in 01 02 03 08 09 15 17 19 2E 36 37 44 45 46 47 56 69 6C 76; do
    echo "$addr 10 01" > /tmp/uds_cmd
    /tmp/uds_send
    echo "---"
done
```

### Step 2: Read module info from responding modules
```bash
# Service 0x22 ReadDataByIdentifier
echo "17 22 F1 90" > /tmp/uds_cmd  # Read VIN from cluster
/tmp/uds_send
echo "17 22 F1 87" > /tmp/uds_cmd  # Read part number
/tmp/uds_send
```

### Step 3: Read fault codes
```bash
# Service 0x19 ReadDTCInformation
echo "17 19 02 FF FF" > /tmp/uds_cmd  # Read all DTCs from cluster
/tmp/uds_send
```

## Cross-Platform Module Differences

| Function | Porsche 958 | Audi MMI3G+ | VW RNS-850 |
|----------|------------|-------------|------------|
| Cluster addr | 0x17 | 0x17 | 0x17 |
| Gateway addr | 0x19 | 0x19 | 0x19 |
| DME addr | 0x01 | 0x01 | 0x01 |
| Oil reset DID | 0x0156 | TBD | TBD |
| CAN protocol | ISO 15765 | ISO 15765 | ISO 15765 |
| Gateway filter | Model-specific | Model-specific | Model-specific |

## Safety Considerations

### SAFE to try:
- Reading data (Service 0x22, 0x19)
- Default session (Service 0x10 01)
- Extended session (Service 0x10 03)
- Module identification

### USE CAUTION:
- Writing data (Service 0x2E)
- Clearing DTCs (Service 0x14)
- Routine control (Service 0x31)
- Security access (Service 0x27)

### NEVER from the head unit:
- Flash programming (Service 0x34/0x36/0x37)
- ECU reset (Service 0x11)
- Anything on powertrain while engine is running
