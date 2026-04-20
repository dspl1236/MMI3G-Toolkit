# GEM Activation Deep Dive — Ghidra + Java Decompilation Results
# Date: 2026-04-20
# Part of MMI-Toolkit research

## SUMMARY

DBGModeActive enables GEM on both Audi MMI3G+ and Porsche PCM 3.1,
but the mechanisms are DIFFERENT:

- **Porsche PCM3Root**: Has `checkDBGModeFile()` in the native binary
- **Audi MMI3GApplication**: Does NOT contain DBGModeActive — the check
  is elsewhere (likely HDD-loaded binary or runtime process)

## PORSCHE MECHANISM (PCM3Root — fully traced)

```
Boot → CGSystemReactControl (0x1f3200) reads:
  - /HBpersistence/DBGModeActive
  - /HBpersistence/MonitorRootReloadHeaps

Step2 function (0x226e00):
  - Checks "Engineeringmenu_step2" value
  - Creates OR deletes /HBpersistence/DBGModeActive
  - Opens file with mode "w" (write)
  - Logs: "DBG_MODE_ACTIVE File sucessfully created" [sic]
  - Nearby: requestSetPersistence, PersMapperConsumer

No direct per3 addresses in the literal pools — the persistence
write happens through function pointers (indirect call):
  - 0x08180bac (code function)
  - 0x083f1a5c (code function)
  - 0x083f1ac0 (code function)
```

## AUDI MECHANISM (MMI3GApplication + AppDevelopment.jar)

### Native Layer (MMI3GApplication)

The native binary has engineering FSM but NO DBGModeActive reference:
```
GEngineeringFSM states:
  EngineeringOff_10
  EngineeringOn_11
  Working_2

Key functions:
  userEnableEngineering(enable)  — triggers state transition
  setEngineering(%d)             — writes the value
  requestEnableDebugMode         — debug mode request
  DEBUG_ENABLE_DBG_MODE          — devctl command to hddmgr

UPD_ID messages:
  UPD_ID_requestEnterEngineeringSession
  UPD_ID_requestExitEngineeringSession
  UPD_ID_engineering
  UPD_ID_engineeringMenuState
  UPD_ID_isEngineeringMode
```

### Java Layer (AppDevelopment.jar)

The GEM engine is a Java OSGi application:

```
de.audi.tghu.development.eis.EngineeringInfoService
  - setPersistence()
  - storeInt(namespace, address, value)  ← writes per3
  - storeString()
  - pollModel()

de.audi.tghu.sim.persistence.FakePersistence
  implements org.dsi.ifc.persistence.DSIPersistence
  - enterGreenEngineeringMenu
  - leaveGreenEngineeringMenu
  - enterEngineeringSession
  - exitEngineeringSession
  - writeInt(int namespace, long address, int value)
  - readInt(int namespace, long address)

de.audi.tghu.development.eis.PersistenceAccessor
  - USEHBPERSISTENCE (boolean flag)
  - persistence (DSIPersistence instance)
  - fakePersistence (DSIPersistence instance)
```

### KEY SYSTEM PROPERTIES

```java
de.audi.tghu.engineering.base_dir
  = Path to ESD screen files
  = Default: /mnt/efs-system/engdefs/ (probable)
  = POTENTIAL OVERRIDE: /mnt/sdcard10t12/engdefs/
  → If overrideable, ESD files load from SD card!

de.audi.tghu.engineering.dsi_regmode
  = DSI registration mode
  = Values: "new" or "classic"
```

### DSI PERSISTENCE API

The per3 read/write interface:
```java
interface org.dsi.ifc.persistence.DSIPersistence {
    void writeInt(int namespace, long address, int value)
    void readInt(int namespace, long address)
    void writeString(int namespace, long address, String value)
    void readString(int namespace, long address)
    void writeArray(int namespace, long address, int[] value)
    void readArray(int namespace, long address)
    void writeBuffer(int namespace, long address, byte[] value)
    void readBuffer(int namespace, long address)
    void setNotification(short[], DSIListener)
}

// For GEM enable, the call would be:
// persistence.writeInt(3, <address>, 1)
// where namespace=3 is per3
```

## OPEN QUESTIONS

1. WHERE is DBGModeActive checked on Audi?
   - Not in MMI3GApplication
   - Not in any IFS binary
   - Must be in HDD-loaded binary or runtime process
   - Andrew confirmed it WORKS on his A6

2. What per3 address stores the GEM enable state?
   - VCDS reads it as module 5F, adaptation channel 6
   - The actual per3 address is still unknown
   - Before/after persistence dump will reveal it

3. Can de.audi.tghu.engineering.base_dir be overridden?
   - Set via Java System.getProperty()
   - If settable via OSGi bundle properties or startup config,
     ESD files could load directly from SD card
   - Would eliminate the need to copy ESDs to flash

## NEXT STEPS

1. VCDS capture of 5F adaptation channels (all values)
2. Before/after persistence dump to find exact per3 address
3. Test if engineering.base_dir can point to SD card
4. Find the HDD binary that checks DBGModeActive on Audi
