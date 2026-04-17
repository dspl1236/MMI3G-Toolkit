# per3-writer — Write DSI Persistence Values from Shell Scripts

## The Missing Piece

The per3-reader module reads DSI persistence values. This module
**writes** them — enabling coding changes, GEM activation, and
feature configuration entirely from the SD card. No VCDS needed.

## Architecture

Same pattern as per3-reader: a Java OSGi bundle that hooks into
the DSI framework, with a file-based trigger for shell scripts.

```
Shell script → write request file → per3-writer bundle → DSI → IOC
```

### Write Flow
1. Shell script writes request to `/fs/sda1/per3write/request`
2. Bundle reads the request, calls DSIPersistence.writeInt/writeString
3. IOC receives the value via IPC channel
4. CIOCPresCtrlPersistence stores it in IOC flash
5. Value persists across reboots

## Potential Uses

### GEM Enable (eliminating VCDS dependency)
```bash
# Enable GEM — adaptation 5F channel 6 = 1
per3_write.sh int <GEM_ADDRESS> 1

# After reboot: CAR + BACK/SETUP opens GEM
```
Note: The exact DSI address for the GEM flag needs to be
determined by live testing (dump before/after VCDS change).

### Coding Changes
```bash
# Set active nav database region
per3_write.sh int 0x00100000 2    # 2 = North America

# Set cluster variant coding
per3_write.sh int <CLUSTER_ADDR> <VALUE>
```

### Feature Activation
```bash
# Write coding bytes that control feature availability
# Same values VCDS/ODIS writes to adaptation channels
```

## Finding the GEM Address

To determine which DSI address controls the GEM flag:

1. Install per3-reader bundle
2. Dump all per3 namespace 3 values: `per3_dump.sh 3`
3. Enable GEM via VCDS (5F channel 6 = 1)
4. Dump again: `per3_dump.sh 3`
5. Diff the two dumps — the changed address is the GEM flag

## DSI Write API

The Java bundle calls:
```java
DSIPersistence persistence = tracker.getService();
persistence.requestWriteInt(namespace, key, value);
persistence.requestWriteString(namespace, key, buffer);
persistence.requestWriteBuffer(namespace, key, data, size);
```

These map to the C++ functions:
- CIOCPresCtrlPersistence::processWriteInt
- CIOCPresCtrlPersistence::processWriteString
- CIOCPresCtrlPersistence::processWriteBuffer

## Status

**Design phase** — the architecture mirrors per3-reader (proven
working pattern). Implementation requires:
1. Java bundle with DSIPersistence write calls
2. Shell script client (per3_write.sh)
3. Live testing to map coding addresses

## Risk Assessment

Writing incorrect values to DSI persistence can:
- Change vehicle coding (reversible via VCDS)
- Alter instrument cluster configuration
- Modify telephone/WLAN settings

All changes are reversible — the IOC persistence can always be
reset via VCDS/ODIS or firmware reinstall. No hardware risk.
