# MMI3G UI Framework — Decompiled Architecture Analysis

## Source
Extracted from `efs-system.efs` in firmware `HN+R_EU_AU_K0942_4` (MU9411 variant 61).
Decompiled with CFR 0.152. 152 Java source files recovered from `AppDevelopment.jar`.

## Overview

The MMI3G user interface runs on an IBM J9 JVM (Java 1.5 / J2SE 5.0 equivalent) on
QNX 6.3.x RTOS (Renesas SH4 CPU). The UI framework uses a proprietary OSGi-like
bundle system built by Harman Becker.

## Plugin Architecture

### Bundle Registration
The JVM loads bundles defined in `bundles.properties` inside `lsd.jxe`. Each bundle has:
- A name (`Bundle.Name.XX`)
- An activator class (`Bundle.Activator.XX`)
- A startup priority

The GEM is bundle 53: `AppDevelopment` with activator `de.audi.tghu.development.Activator`

### Activator Pattern
Every plugin implements `org.osgi.framework.BundleActivator`:

```java
public class Activator implements BundleActivator {
    private BundleActivator appActivator = new AppActivator();
    private BundleActivator smActivator = new SMActivator();
    private BundleActivator hmiActivator = new HMIActivator();

    public void start(BundleContext ctx) throws Exception {
        appActivator.start(ctx);   // App logic
        smActivator.start(ctx);    // State machine
        hmiActivator.start(ctx);   // UI rendering
    }
    public void stop(BundleContext ctx) throws Exception { ... }
}
```

Three sub-activators handle different concerns:
- **AppActivator** — Registers the development app, loads ESD screen definitions
- **SMActivator** — Registers with the state machine framework
- **HMIActivator** — Registers HMI widgets for rendering

### JVM Startup (lsd.sh)
The bootclasspath is built dynamically:
```
BOOTCLASSPATH=-Xbootclasspath
BOOTCLASSPATH="$BOOTCLASSPATH:/lsd/DSITracer.jar"    # Optional tracing
BOOTCLASSPATH="$BOOTCLASSPATH:/lsd/AppDevelopment.jar" # GEM plugin
BOOTCLASSPATH="$BOOTCLASSPATH:/lsd/texts.jar"         # Localization
BOOTCLASSPATH="$BOOTCLASSPATH:/lsd/lsd.jxe"           # Main application
```

**To add a custom plugin:** Add a JAR to `/mnt/efs-system/lsd/` and add it to the
bootclasspath in `lsd.sh` before the JXE line.

### Key JVM Parameters
- Resolution: 800x480 LVDS display
- Heap: 13312KB max (`-Xmx13312k`)
- JIT: 2048KB code cache
- DSI channel: QNX message passing (`-Ddsi.channel=msgpassing`)
- GEM screens dir: `/HBpersistence/engdefs` (also `/mnt/efs-system/engdefs`)

## Data Access Layer

### Two Data Sources
The `EngineeringInfoService` uses two data sources:
- **DATASOURCE_PERSISTENCE (0)** — DSI persistence (per 1/3/7 namespace data)
- **DATASOURCE_SYSTEM (1)** — JVM system data (free memory, GC, script exec)

### PersistenceAccessor (CAN Bus / Vehicle Data)
Reads data via `org.dsi.ifc.persistence.DSIPersistence`:
```java
persistence.readInt(namespace, key, false);    // per X 0xKEY int
persistence.readString(namespace, key, false); // per X 0xKEY String
persistence.readBuffer(namespace, key, false); // per X 0xKEY raw bytes
persistence.readArray(namespace, key, false);  // per X 0xKEY int array
```

Where `namespace` is the "per" number from the ESD file:
- **per 1** = MMI system data (namespace 1)
- **per 3** = CAN bus / vehicle data (namespace 3)
- **per 7** = GPS / navigation data (namespace 7)

The DSIPersistence interface is a native bridge — the actual data retrieval
happens in QNX native code, not Java. The namespace/key addressing maps
to Harman Becker's internal CAN gateway configuration.

### SystemAccessor (JVM Internal Data)
Only handles namespace 1 with three fixed keys:
- Key 1 = JVM free memory (int)
- Key 2 = JVM total memory (int)
- Key 3 = Trigger garbage collection
- Key 256 (0x100) = Execute shell script (string = script path)

**Key finding:** The `script` element in ESD files uses `sys 1 0x0100` which
maps to SystemAccessor key 256, which calls `Runtime.exec()` to run a shell
script. Output is piped through `/scripts/script.fifo` (a QNX named pipe)
back to the GEM console display.

### Polling Mechanism
When an ESD element has a `poll XXXX` line, the `EngineeringInfoService` creates
a `Timer` that fires at that interval and calls `pollModel()` on the
`ScreenElementModel`. This triggers `PersistenceAccessor._poll_hb()` which
calls the DSI persistence read methods.

## ESD Screen Model

### Screen Element Types (from model/ package)
- **KeyValueModel** — Displays a polled value (int, string, buffer, array)
- **ChoiceModel** — Selection control
- **SliderModel** — Slider control (min/max range)
- **ButtonModel** — Action button
- **ScriptModel** — Shell script execution button
- **ExportModel** — Data export control
- **LinkModel** — Navigation link to sub-screen
- **TableModel** — Tabular data display
- **BIOSCtrlModel** — Low-level BIOS control
- **LabelModel** — Static text label

### Widget Rendering (from widget/ package)
Each model type has a corresponding widget renderer. The rendering framework
uses Harman Becker's proprietary display layer, not standard Java AWT/Swing.

## Key Findings for Custom Development

### Adding a Custom JAR Plugin
1. Write a Java 1.5 compatible JAR with an OSGi `BundleActivator`
2. Copy to `/mnt/efs-system/lsd/`
3. Modify `lsd.sh` to add it to the bootclasspath
4. The JAR can use `EngineeringInfoService` to poll CAN bus data
5. The JAR can use `SystemAccessor.execScript()` to run QNX shell commands

### Adding to the CAR Menu (Advanced)
The normal MMI menus are defined inside `lsd.jxe`, not in the GEM framework.
Adding a CAR menu entry requires either:
1. Modifying `lsd.jxe` (needs J9 JXE tools — high risk)
2. Hooking into the HMI framework's menu registration from a custom bundle
   (needs decompilation of `lsd.jxe` to find the registration API)
3. Hijacking an unused menu slot via adaptation coding

### CAN Bus Address Discovery
The per 3 namespace addresses are defined in native QNX code, not Java.
The Java layer just passes through namespace + key to the DSI persistence
layer. A systematic scan of address ranges from GEM screens is the most
practical approach to discovering available vehicle data.

### Available Data Types
The DSI persistence supports:
- `readInt()` — 32-bit integer (e.g., voltage in centimillivolts)
- `readString()` — Text string (e.g., software version)
- `readBuffer()` — Raw byte array
- `readArray()` — Integer array

All four types can be polled at configurable intervals via ESD screen definitions.

## Package Structure

```
de.audi.tghu.development/
├── Activator.java                    # Bundle entry point (OSGi)
├── EngineeringException.java
├── app/
│   ├── AppActivator.java             # App registration
│   ├── ATIPServices.java             # ATIP framework services
│   ├── DevelopmentApp.java           # Main app controller
│   ├── DevelopmentScreenFactory.java # ESD file parser
│   └── Logger.java
├── config/
│   ├── RendererConfigBasic.java      # 400x240 layout
│   ├── RendererConfigHigh.java       # 800x480 layout
│   └── RendererConfigFactory.java
├── eis/                              # Engineering Info Service
│   ├── EngineeringInfoService.java   # Core data polling engine
│   ├── Namespace.java                # Namespace container
│   ├── PersistenceAccessor.java      # DSI → CAN bus bridge
│   ├── SystemAccessor.java           # JVM internals + script exec
│   ├── PersistenceListener.java      # Async data callbacks
│   └── EISListener.java              # Listener interface
├── model/                            # Data models for ESD elements
│   ├── KeyValueModel.java
│   ├── ScreenModel.java
│   ├── ScriptModel.java
│   ├── SliderModel.java
│   └── ... (15 model classes)
├── renderer/                         # UI rendering
│   ├── ScreenRenderer.java           # Main screen renderer
│   ├── ConsoleScreen.java            # Script output console
│   └── ... (10 renderer classes)
├── sm/
│   └── DevelopmentSMM.java           # State machine module
├── widget/                           # UI widget implementations
│   ├── KeyValueWidget.java
│   ├── ScriptWidget.java
│   ├── SliderWidget.java
│   └── ... (18 widget classes)
└── util/
    └── HashtableOfLong.java          # Long-keyed hashtable
```

## Credits
- Firmware: Audi `HN+R_EU_AU_K0942_4` (8R0906961FB)
- Decompilation: CFR 0.152
- EFS extraction: Custom Python parser
- Research context: DrGER2's MMI3G documentation, Audizine/VWVortex community


## V850 IOC (I/O Controller) Firmware Analysis

### What the IOC Does
The V850 microcontroller is the CAN bus interface chip on the MMI3G board.
It sits between the physical CAN buses and the SH4 main CPU (which runs QNX + Java).
All CAN data passes through the IOC before reaching the Java layer.

### Firmware: V850app.bin (589,760 bytes)
- Build: `AUDI-3G-9411-C0-Version:-T01` (2015-12-07)
- Compiled with Renesas V850 C/C++ compiler

### CAN Bus Architecture (from IOC firmware strings)
The IOC manages these CAN buses:

| Bus ID | Name           | Purpose                          |
|--------|----------------|----------------------------------|
| 1      | Antrieb        | Powertrain (Engine, TCU, ABS)    |
| 2      | Flexray        | FlexRay bus                      |
| 3      | Clamp15        | Ignition-switched power          |
| 5      | Dashboard      | Instrument cluster CAN           |
| 6      | Infotainment   | MMI head unit CAN                |
| 7      | Extended       | Extended CAN                     |
| 8      | Fahrwerk       | Chassis/Suspension               |

### Key IOC Subsystems
- `cfappgateway` — CAN Application Gateway (routes messages between buses)
- `PERS` — Personality/Persistence (maps CAN data → per 3 namespace)
- `GATW` — Gateway configuration
- `HPIPC` — High Performance IPC (V850 ↔ SH4 shared memory)
- `TP20` — VAG Transport Protocol 2.0 (diagnostics)

### CAN Message IDs Found in IOC Firmware
All major VAG drivetrain CAN IDs are present in the V850 binary:

| CAN ID | LE matches | BE matches | Message      |
|--------|-----------|-----------|--------------|
| 0x280  | 18        | 68        | Motor_1 (RPM)|
| 0x288  | 23        | 19        | Motor_2 (CLT)|
| 0x320  | 9         | 57        | Speed/Fuel   |
| 0x380  | 110       | 59        | Intake temp  |
| 0x480  | 54        | 69        | Motor extra  |
| 0x1A0  | 28        | 2         | Wheel speed  |
| 0x621  | 1         | 2         | Tank/fuel    |

### Implications
The IOC firmware PROCESSES all engine CAN messages. The `cfappgateway`
function decides which messages get routed to the Infotainment bus (bus 6)
and which get mapped to PERS (per 3 namespace) addresses.

The fact that `FOT temperature` appears at per 3 `0x00000004` proves that
SOME sensor data crosses from the IOC to the per 3 namespace. The IOC
firmware is where the address mapping lives — it's in compiled V850 machine
code, not in configurable tables.

### V850 Disassembly
The V850 can be disassembled with:
- GCC V850 binutils: `v850-elf-objdump -m v850 -b binary -D V850app.bin`
- Ghidra with `ghidra_v850` plugin (github.com/esaulenka/ghidra_v850)
- IDA Pro with V850 processor module

Full disassembly and function-level analysis of the `cfappgateway` routing
logic would reveal the exact CAN ID → per 3 address mapping table.


## V850 IOC Ghidra Decompilation Results

### Analysis Setup
- Ghidra 11.3 with esaulenka/ghidra_v850 plugin (V850E2M variant)
- 754 functions discovered by auto-analysis
- Key functions decompiled with Ghidra's built-in decompiler

### Per 3 Internal Index System

The IOC uses an internal index system (0x00-0xE7) for per 3 data slots.
`FUN_000449ae` maps `(bus_type, signal_id)` pairs to per 3 indices:

```
Formula: switch(param_2 & 0xff | (param_1 & 0xff) << 4)

bus=0 sig=7 (case 0x07) -> per3[0x24] = Cable code
bus=2 sig=0 (case 0x20) -> per3[0x23] = Battery voltage
```

The per 3 address visible from Java (e.g., `per 3 0x00000023`) maps directly
to the internal index (0x23). The IOC manages up to 232 slots (max 0xE7).

### Per 3 Data Storage

Three lookup tables define per 3 slot properties:

| Table | Address | Purpose |
|-------|---------|---------|
| `DAT_00015f00` | Size table | Bytes per slot (1-253 bytes) |
| `DAT_00015aac` | Attribute flags | Read/write permissions, change notification |
| `DAT_00015e8c` | Data offsets | RAM addresses for slot data |

Data is stored in V850 RAM (0x00220xxx range) and shared with the SH4
via HPIPC (High Performance IPC) shared memory.

### Read/Write Handlers

- `FUN_00039222` (per3_write_handler): Writes data to per 3 slots with
  rate limiting via timestamp comparison. Queues write requests at
  `0x204df8 + 0x1b74`.

- `FUN_0003946c` (per3_read_handler): Reads data from per 3 slots with
  similar rate limiting. Triggers HPIPC notification to SH4.

### CAN Message Processing

The IOC firmware references all major VAG CAN IDs but the mapping from
raw CAN messages to per 3 slots happens in the CAN reception handler code.
The `cfappgateway` function routes messages between the physical CAN buses.

### Key Finding

The per 3 data is populated by the V850 firmware's CAN message handlers.
Adding new per 3 data (e.g., RPM from CAN ID 0x280) would require:

1. Identifying the CAN reception handler for the Infotainment bus
2. Adding code to extract RPM from Motor_1 (0x280) byte 2-3
3. Writing the extracted value to a per 3 slot
4. Registering the new slot in the size, flags, and offset tables

This is a V850 firmware modification — not a simple configuration change.
The IOC firmware (V850app.bin) would need to be patched and re-flashed
via the MMI firmware update mechanism.

Alternative: Gateway re-parameterization via ODIS to forward Motor_1/Motor_2
to the Infotainment CAN bus, where existing IOC handlers might pick them up
if there are unused reception slots in the firmware.
