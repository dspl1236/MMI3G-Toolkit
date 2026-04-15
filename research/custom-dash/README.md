# Custom Digital Dashboard — Development Guide

## Overview

This is a replacement `AppDevelopment.jar` that transforms the GEM button
combo (CAR+BACK) into a live digital dashboard with gauges for RPM, boost,
coolant, and other CAN bus data. The original GEM remains accessible via
the top-left soft key.

## Architecture

```
CAR + BACK (hold 5 sec)
    │
    ▼
┌──────────────────────────────────────────┐
│  DIGITAL DASH            14.4V  6/9 GPS  │
├───────────────────┬──────────────────────┤
│                   │                      │
│      BOOST        │        RPM           │
│     12.4 PSI      │       3,250          │
│                   │                      │
├───────────────────┼──────────────────────┤
│                   │                      │
│     COOLANT       │      OIL TEMP        │
│      195°F        │       220°F          │
│                   │                      │
├───────────────────┴──────────────────────┤
│  [GEM]     [DIAG]     [PAGE]     [BACK]  │
└──────────────────────────────────────────┘

Soft keys:
  Top-left:     GEM  → Open original Green Engineering Menu
  Top-right:    DIAG → Toggle diagnostic overlay
  Bottom-left:  PAGE → Cycle gauge pages (3 pages)
  Bottom-right: BACK → Return to normal MMI

Gauge pages:
  Page 1 (Performance): Boost / RPM / Coolant / Oil Temp
  Page 2 (Driving):     Speed / RPM / Volts / Intake Temp
  Page 3 (System):      GPS Alt / GPS Sats / Volts / USB
```

## Prerequisites

Before building the custom dash, you MUST:

1. **Run the CAN scanner module** on your specific car to discover
   which per 3 addresses carry engine data (RPM, boost, etc.)
2. **Update DashEngine.java** with the discovered addresses
3. **Test on the car** with the scanner screens first to verify
   the addresses return live, changing data

## Build Requirements

- JDK that can target Java 1.5 (e.g., JDK 8 with `-source 1.5 -target 1.5`)
- The following interface JARs from the MMI (available at runtime on car,
  needed at compile time only — extract from lsd.jxe or use stubs):
  - `org.osgi.framework.BundleActivator`
  - `org.osgi.framework.BundleContext`
  - `org.dsi.ifc.persistence.DSIPersistence`
  - `org.dsi.ifc.base.DSIListener`
  - `de.audi.atip.timer.Timer`
  - `de.audi.atip.timer.TimerListener`

## Build Process (once stubs are created)

```bash
# Compile
javac -source 1.5 -target 1.5 \
  -cp stubs/osgi.jar:stubs/dsi.jar:stubs/atip.jar \
  -d build/ \
  src/de/audi/tghu/development/Activator.java \
  src/de/audi/tghu/development/dash/*.java

# Package
cd build
jar cf ../AppDevelopment.jar de/
cd ..
```

## Installation

```bash
# Via toolkit SD card:
# 1. Backup original
mount -uw /mnt/efs-system
cp /mnt/efs-system/lsd/AppDevelopment.jar \
   /mnt/efs-system/lsd/AppDevelopment.jar.ORIG

# 2. Install custom
cp /sdcard/AppDevelopment.jar /mnt/efs-system/lsd/

# 3. Reboot MMI
```

## Recovery

If the custom JAR causes issues (JVM crash, blank screen):

**Method 1: SD card script**
Build an SD card with a run.sh that restores the backup:
```bash
mount -uw /mnt/efs-system
cp /mnt/efs-system/lsd/AppDevelopment.jar.ORIG \
   /mnt/efs-system/lsd/AppDevelopment.jar
```

**Method 2: Firmware reinstall**
Reinstall just the efs-system component via User Defined Mode
in the Red Engineering Menu. This restores all factory files.

**Method 3: Emergency Update**
Use the firmware SD card in Emergency Update mode (accessible
even without a working JVM).

## Status

**Phase: Scaffolding / Pre-scanner**

The Java source structure is ready but the CAN bus addresses
for engine data (RPM, boost, coolant, speed) are unknown.

Next steps:
1. Run can-scanner module on the car
2. Identify live per 3 addresses for engine data
3. Update DashEngine.java with real addresses
4. Create OSGi/DSI/ATIP stub JARs for compilation
5. Compile, test on car
6. Iterate on rendering (may need to study the HMI drawing
   API from decompiled ScreenRenderer/Widget classes)

## CAN Address Reference

Known working addresses (all platforms):
| Per | Address    | Data                  | Format       |
|-----|------------|-----------------------|--------------|
| 3   | 0x00000023 | Battery voltage       | int, x100 mV |
| 3   | 0x00120004 | SW train name         | String       |
| 3   | 0x00110006 | VW spare part number  | String       |
| 7   | 0x000200bb | GPS satellites used   | int          |
| 7   | 0x000200bc | GPS satellites visible| int          |
| 1   | 0x00030019 | GPS altitude          | int, meters  |
| 1   | 0x0000100d | MU software version   | String       |
| 1   | 0x0003001a | Nav database version  | String       |
| 1   | 0x00180000 | USB device count      | int          |

Addresses to discover (via CAN scanner):
| Data           | Expected Per | Notes                    |
|----------------|-------------|--------------------------|
| Engine RPM     | per 3       | Probably in 0x0001xxxx   |
| Vehicle speed  | per 3       | May be km/h raw          |
| Coolant temp   | per 3       | Probably Celsius raw     |
| Boost pressure | per 3       | May need offset/scale    |
| Oil temperature| per 3       | Probably Celsius raw     |
| Intake air temp| per 3       | Probably Celsius raw     |
| Throttle pos   | per 3       | 0-100% or 0-1000        |
| Fuel level     | per 3       | Percentage or liters     |
