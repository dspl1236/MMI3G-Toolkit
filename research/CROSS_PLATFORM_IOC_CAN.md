# Cross-Platform IOC/CAN Architecture — Harman HN+ Family

## Applies To
All three Harman HN+/HN+R head unit platforms share the same fundamental
IOC/CAN architecture:

| Platform | Vehicle | Head Unit | Tested By |
|----------|---------|-----------|-----------|
| **MMI3G+** | 2010-2018 Audi A6/A7/A8/Q7 | HN+R K0942 | Andrew (2013 C7 A6 3.0T) |
| **RNS-850** | 2010-2018 VW Touareg/Phaeton | HN+R K0821 | daredoole (EU VW) |
| **PCM 3.1** | 2010-2016 Porsche Cayenne/Panamera/911 | PCME02XX | Andrew (2016 958 S E-Hybrid) |

## Shared Hardware Architecture

### Main CPU: Renesas SH7786 (SH4A)
- 32-bit SuperH RISC processor
- Runs QNX 6.3.2 / 6.5.0
- Hosts all application software (PCM3Root/MMI3GApplication)

### IO Controller: Renesas V850ES/SJ3
- 32-bit V850 RISC microcontroller (μPD70F3344-3368 series)
- On-chip CAN controller (1-2 channels)
- 32 message buffers per CAN channel
- Standard (11-bit) and Extended (29-bit) CAN ID support
- On-chip IEBus controller (automotive LAN)
- Connected to SH4 via Xilinx FPGA (PCI bridge)
- Reference: Renesas V850ES/SJ3 User's Manual Rev.5.00 (Chapter 19)

### FPGA Bridge: Xilinx (PCI ID 0x10EE:0x9411)
- PCI device connecting SH4 bus to V850 IOC
- Handles interrupt routing (IRQ 30-54)
- Memory-mapped I/O regions for IPC

### CAN Bus Transceiver
- Physical layer: CAN-H / CAN-L (ISO 11898)
- Connected to V850's CTXD/CRXD pins

## Shared Software Stack

```
┌─────────────────────────────────────────────────┐
│  Application Layer (SH4, QNX)                   │
│  ┌──────────────────┐  ┌──────────────────┐     │
│  │ PCM3Root (Porsche)│  │MMI3GApp (Audi/VW)│     │
│  │ oil reset, nav    │  │ GE, nav, diag    │     │
│  └────────┬─────────┘  └────────┬─────────┘     │
│           │                      │               │
│  ┌────────▼──────────────────────▼─────────┐     │
│  │  NDR Resource Manager (/dev/ndr/cmd)    │     │
│  │  CLibResMgr → devctl(class=5, cmd=7/8) │     │
│  │  CTransTel telegram framing             │     │
│  └────────────────┬────────────────────────┘     │
│                   │                              │
│  ┌────────────────▼────────────────────────┐     │
│  │  dev-ipc (/dev/ipc/ioc/ch2-ch10)       │     │
│  │  CHBIpcProtocol (0xFADE magic)          │     │
│  │  19 IOC service types                   │     │
│  └────────────────┬────────────────────────┘     │
└───────────────────┼──────────────────────────────┘
                    │ PCI Bus (Xilinx FPGA)
┌───────────────────▼──────────────────────────────┐
│  V850ES/SJ3 IO Controller                       │
│  ┌─────────────────────────────────────────┐     │
│  │  CAN Controller (Chapter 19)            │     │
│  │  - CnGMCTRL: Global control             │     │
│  │  - CnCTRL: Module control               │     │
│  │  - CnMDATA0-7: Message data bytes       │     │
│  │  - CnMDLC: Data length code (0-8)       │     │
│  │  - CnMID: Message identifier (11/29-bit)│     │
│  │  - CnMCTRL: Message control (TX/RX)     │     │
│  │  - CnMASK1-4: Acceptance masks          │     │
│  │  - CnERC: Error counter                 │     │
│  │  - CnBRP/CnBTR: Baud rate              │     │
│  │  - 32 message buffers (m=00-31)         │     │
│  └─────────────────────────────────────────┘     │
│  ┌─────────────────────────────────────────┐     │
│  │  IEBus Controller (IEB)                 │     │
│  │  Automotive LAN for audio/media control │     │
│  └─────────────────────────────────────────┘     │
└───────────────────┬──────────────────────────────┘
                    │ CAN Transceiver (CTXD/CRXD)
                    ▼
            CAN Bus (CAN-H / CAN-L)
                    │
    ┌───────────────┼───────────────┐
    ▼               ▼               ▼
 Cluster       Gateway         Body Control
 (0x0717)      (0x07DF)        Module
```

## NDR devctl Interface (Discovered via Disassembly)

### devctl Command Codes
From NavigationNdrInfo (PCM 3.1, NOT STRIPPED, has debug symbols):

```c
#define NDR_WRITE  0xC0040507   // DIOTF, size=4, class=0x05, cmd=0x07
#define NDR_READ   0xC0040508   // DIOTF, size=4, class=0x05, cmd=0x08
```

### Key Classes (from NavigationNdrInfo symbols)
| Class | Purpose |
|-------|---------|
| CLibResMgr | NDR resource manager client library |
| CTransTel | Transport Telegram — message framing |
| CTransTelBuffer | Telegram buffer management |
| CNdrServiceClientProxy | High-level NDR service client |
| CHBIpcProtocol | IPC protocol (0xFADE magic) |

### Platform Variations
| Feature | MMI3G+ | RNS-850 | PCM 3.1 |
|---------|--------|---------|---------|
| NDR path | /dev/ndr/cmd | /dev/ndr/cmd | /dev/ndr/cmd |
| NDR devctl class | TBD (may differ) | TBD | 0x05 (confirmed) |
| IOC channels | ch2-ch10 | ch2-ch10 | ch2-ch10 |
| /etc/ writable | YES (confirmed) | Unknown | NO (IFS read-only) |
| Cluster CAN ID | 0x0717 | 0x0717 | 0x0717 |
| UDS address | 0x17 | 0x17 | 0x17 |

### IMPORTANT: The class=0x20, cmd=8 from our Audi research was WRONG
This was the hypothesized format from PCM3Root Ghidra analysis but
returned ENOTTY(25) on the actual PCM hardware. The CORRECT codes
(class=5, cmd=7/8) were discovered by disassembling NavigationNdrInfo
from the car's own /mnt/data/tools/ directory.

The same codes likely apply to MMI3G+ and RNS-850 since they share
the same NDR driver codebase (CLibResMgr). To confirm:
1. Grab NavigationNdrInfo from each platform
2. Run ndr_probe to verify class=5,cmd=7/8 work

## V850 CAN Controller Key Details (from Datasheet)

### Register Map (CAN0 at base 0x03FEC000)
| Register | Address | Purpose |
|----------|---------|---------|
| C0GMCTRL | +0x000 | Global control (init/operate/sleep) |
| C0CTRL | +0x050 | Module control (mode, error clear) |
| C0INFO | +0x053 | Status (bus-off, error state) |
| C0ERC | +0x054 | Error counter (TX/RX) |
| C0IE | +0x056 | Interrupt enable |
| C0BRP | +0x05A | Baud rate prescaler |
| C0BTR | +0x05C | Bit timing (TSEG1, TSEG2, SJW) |
| C0MDATA0-7[m] | +0x100+m*0x20 | Message data bytes (m=0-31) |
| C0MDLC[m] | +0x108+m*0x20 | Data length code |
| C0MCONF[m] | +0x109+m*0x20 | Message config |
| C0MID[m] | +0x10A+m*0x20 | Message ID (11/29-bit) |
| C0MCTRL[m] | +0x10E+m*0x20 | Message control (TX request, RX ready) |

### CAN Frame Format
- SOF (1 bit) → Arbitration (ID + RTR) → Control (DLC) → Data (0-8 bytes)
  → CRC (15 bits) → ACK → EOF (7 bits)
- Standard format: 11-bit ID
- Extended format: 29-bit ID (SRR + IDE bits)
- DLC supports 0-8 data bytes

### Error Handling
- Error Active → Error Passive → Bus-Off states
- TX error counter: increments by 8 on error, decrements on success
- RX error counter: increments by 1-8 depending on error type
- Bus-off recovery: 128 × 11 consecutive recessive bits

## Implications for UDS Oil Service Reset

### The Same Binary Could Work on All Three Platforms
Since all three platforms share:
- Same NDR resource manager (CLibResMgr)
- Same devctl interface (likely class=5, cmd=7/8 everywhere)
- Same IOC channel architecture (ch2-ch10)
- Same V850 CAN controller hardware
- Same CAN bus protocol (ISO 11898)

A single `uds_send` binary (cross-compiled for QNX SH4) could reset
the oil service on Audi, VW, AND Porsche head units.

### Per-Platform Testing Needed
1. **PCM 3.1** (in progress): v3 binary with class=5,cmd=7
2. **MMI3G+**: Run ndr_probe to confirm same devctl codes
3. **RNS-850**: daredoole can test same probe + binary

### Universal Oil Reset Sequence
```
1. devctl(ndr_fd, 0xC0040507, telegram[0x10, 0x03])  → Extended session
2. devctl(ndr_fd, 0xC0040507, telegram[0x2E, DID...]) → Write oil reset
3. devctl(ndr_fd, 0xC0040508, response_buf)           → Read response
```

Where DID varies per manufacturer:
| OEM | Oil Reset DID | Inspection Distance | Inspection Time |
|-----|--------------|--------------------|-----------------| 
| Porsche | 0x0156 | 0x0D17 | 0x0D18 |
| Audi/VW | TBD | TBD | TBD |

## References
- Renesas V850ES/SJ3 User's Manual: Hardware (Rev.5.00, Feb 2012)
  Chapter 19: CAN Controller (pages 728-886)
- NavigationNdrInfo disassembly (PCM 3.1, with debug symbols)
- reddit.com/r/QNX/comments/1h4l09k/ (overlay root paths)
