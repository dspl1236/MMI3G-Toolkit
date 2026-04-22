# Custom Driver Injection — Loading Drivers Without IFS Reflash

## Overview

QNX 6.3 on the MMI3G loads `.so` drivers dynamically at runtime.
Custom or patched drivers can be loaded from writable storage without
modifying the read-only IFS firmware image.

## Three Injection Methods

### Method 1: LD_LIBRARY_PATH (Recommended)

Harman-Becker already planned for this — `dhcp-up` contains:
```sh
#export LD_LIBRARY_PATH=/mnt/persistence/nws:$LD_LIBRARY_PATH
```

Uncomment (or add to a startup script) to load libraries from
writable storage BEFORE the IFS versions:

```sh
# In copie_scr.sh or a boot script:
export LD_LIBRARY_PATH=/mnt/persistence/nws:$LD_LIBRARY_PATH

# QNX checks /mnt/persistence/nws/ FIRST, then /lib/dll/
# A patched devn-asix.so here overrides the IFS version
```

### Method 2: io-pkt Explicit Mount

Load a specific driver by full path:
```sh
mount -T io-pkt /mnt/efs-system/drivers/devn-custom-lte.so
```

### Method 3: SD Card (Testing Only)

Load drivers from removable media — ideal for development:
```sh
for drv in /mnt/sdcard10t12/drivers/*.so; do
    mount -T io-pkt "$drv"
done
```

## Writable Storage for Drivers

| Path | Type | Size | Persists? | Best For |
|------|------|------|-----------|----------|
| /mnt/efs-system/ | NOR flash | 38MB | ✅ Yes | Production drivers |
| /mnt/persistence/ | NOR flash | 30MB | ✅ Yes | LD_LIBRARY_PATH |
| /mnt/nav/ | HDD | 28GB | ✅ Yes | Large files |
| /mnt/sdcard*/ | SD card | varies | ❌ Removable | Testing |
| /tmp/ | tmpfs/RAM | limited | ❌ Lost on reboot | Quick tests |

## Current Network Drivers in IFS

```
/lib/dll/devn-asix.so        — USB ethernet (ASIX AX88172/772/772B)
/lib/dll/devnp-mv8688uap.so  — WiFi AP mode (Marvell 88W8688)
/lib/dll/devnp-shim.so       — Network shim
/usr/lib/dll/devnp-mlb.so    — MOST/MLB bus
```

## Use Case: AX88772D Support

The existing `devn-asix.so` (75KB, SH4 ELF) supports AX88172/A,
AX88178, AX88772, and AX88772B — but NOT the AX88772D revision.

The D revision uses a different USB product ID that the driver
doesn't recognize. Fix options:

**Option A: Hex-patch USB product ID table**
1. Extract `devn-asix.so` from IFS (75KB)
2. Find the USB vendor/product ID table
3. Add AX88772D's IDs (vendor 0x0B95, product 0x772D or 0x0074)
4. Place at `/mnt/persistence/nws/devn-asix.so`
5. Set LD_LIBRARY_PATH → patched driver loads first

**Option B: Cross-compile from source**
1. Set up QNX 6.5 eval VM (`qnx650sp1-vm.zip` in Flashdaten)
2. Use SH4 cross-compiler: `qcc -Vgcc_ntosh`
3. Compile patched ASIX driver with AX88772D support
4. Deploy to writable storage

## Use Case: LTE Modem Driver

For native LTE modem support (replacing USB ethernet + router):

1. Identify LTE modem's USB interface (most present as USB serial)
2. Compile or port a USB serial/NCM/MBIM driver for QNX SH4
3. Deploy to writable storage
4. Modify `libmodemservice.so` (already on writable EFS) for LTE AT commands
5. No IFS reflash needed — entire cellular stack is on writable partitions

## Use Case: WiFi Client Mode

The current `devnp-mv8688uap.so` runs in AP mode only (creates
a hotspot). For client mode (connecting to phone hotspot):

1. The Marvell 88W8688 chip supports both AP and STA modes
2. A client-mode driver would need QNX SH4 compilation
3. Deploy via LD_LIBRARY_PATH
4. Would eliminate the need for USB ethernet entirely

## Building Drivers

The QNX 6.5 SP1 evaluation VM (`qnx650sp1-vm.zip` in Flashdaten)
contains the complete SH4 cross-compilation toolchain:

```sh
# On QNX eval VM:
source /opt/qnx650/qnx650-env.sh
qcc -Vgcc_ntosh -shared -o devn-custom.so driver_source.c
# Copy devn-custom.so to MMI's writable storage
```

The eval VM is the key to building ANY native QNX tool or driver
for the MMI — including `curl`, `ssh`, `netcat`, custom network
drivers, and even a local tile proxy server for Google Earth.

## Security Considerations

- No code signing on QNX drivers — any valid SH4 ELF .so will load
- Root access via copie_scr.sh allows unrestricted driver loading
- LD_LIBRARY_PATH overrides affect ALL processes (including system)
- Test thoroughly on SD card before deploying to flash

## References

- `research/DATA_CONNECTIVITY_OPTIONS.md` — USB ethernet, LTE options
- `research/HMI_ARCHITECTURE.md` — QNX process model
- `research/SWDL_UPDATE_SYSTEM.md` — Firmware update system
- `research/EOL_FLAGS_AND_GOOGLE_EARTH.md` — GEMMI server protocol

## Update: Device ID Override (No Patching Required)

QNX documentation reveals that `devn-asix.so` supports explicit
USB device ID override via command-line parameters. This eliminates
the need for hex-patching to add AX88772D support:

```sh
io-pkt-v4-hc -d asix did=0x772D,vid=0x0B95 &
```

The `did` and `vid` options force the driver to bind to any USB
device regardless of its product ID. As long as the register
layout is compatible (which it is for all AX88772 revisions),
the driver works normally.

This is simpler than all three injection methods documented above
and requires no custom driver binary at all — just a command-line
argument change in the network startup script.

Source: qnx.com/developers/docs/6.4.0/neutrino/utilities/d/devn-asix.so.html
