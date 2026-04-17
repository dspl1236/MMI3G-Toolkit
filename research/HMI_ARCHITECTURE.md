# MMI3G+ HMI architecture — boot, processes, and IPC

This document is the map: how an MMI3G+ head unit goes from power-on to
a running HMI. It describes the boot sequence, the 101-process service
graph, the DSI IPC bus, and the hook points where custom work is
possible. Everything here is derived from the extracted `ifs-root.ifs`
of MU9411 K0942_4 variant 41 — the same firmware that ships on C7
Audi A6/A7/A8 and D4 Q7 with HN+ navigation.

See also:
- `IFS_FORMAT.md` — how to extract `ifs-root.ifs`
- `F3S_FORMAT.md` — how to extract `efs-system.efs`
- `PER3_READER.md` — the DSI persistence read mechanism
- `PER3_ADDRESS_MAP.md` — per3 address space

## Platform facts

```
QNX version        6.3.2 (RL_qnx_os_632_PSP3_08041A)
CPU                Renesas SH4 (EM_SH, 32-bit LE)
Header board ID   10EE / 9411 (vendor 0x10EE = Xilinx, device 0x9411)
Firmware banner    Harman/Becker MMI3GP Build 9411 C1 D1-15515A
HMI mountpoint     /
HDD mountpoint     /mnt/mediadisk
Nav mountpoint     /mnt/nav
```

Relevant flash partitions:

| Partition | Mount | Contains |
|-----------|-------|----------|
| `/dev/fs0p1` | `/mnt/ifs-root` | Static read-only copy of IFS contents |
| `/dev/fs1p3` | `/HBpersistence` | Adaptation data, DSI persistence (user writable) |
| `/dev/fs4p1` | `/mnt/efs-system` | Scripts, JARs, GEM screens |
| `/mnt/hd0t77` | `/mnt/nav` | Navigation database |

## Boot sequence

```
[ROM bootloader]
        │
        ▼
[startup_header JMP]  — decompresses LZO ifs-root.ifs payload into RAM
        │
        ▼
[procnto-instr]  — QNX kernel, from /proc/boot/procnto-instr
        │
        ▼
[/proc/boot/.script]  — QNX boot script, binary-encoded
        │  ├─ sets LD_LIBRARY_PATH, MMEDB_PATH, FPGA_CSS_ENABLE=1, etc.
        │  ├─ spawns dev-sysregs, dev-nvram, dev-ipc, devb-eide-hbfpga
        │  ├─ mounts filesystems (fs0p1 → /mnt/ifs-root, etc.)
        │  └─ starts srv-starterClientQNX /etc/mmi3g-srv-starter.cfg
        │
        ▼
[srv-starterClientQNX]  — the MMI's init/systemd equivalent
        │  ├─ reads 101 <Process> entries from mmi3g-srv-starter.cfg
        │  ├─ respects <RequiresInterface>/<ProvidesInterface> graph
        │  ├─ starts processes when their dependencies are ready
        │  └─ restarts processes per <MaxProcessRestarts>
        │
        ▼
[MMI3GApplication]  — the main HMI binary (SH4 ELF, 10.7 MB)
        │  ├─ uses J9 JVM (/j9/bin/j9) through /lsd/lsd.sh
        │  ├─ registers DSI interfaces (audio, sound, nav, persistence)
        │  └─ renders UI via /usr/sbin/io-display → NVIDIA Tegra GPU
        │
        ▼
[HMI running]  — the "Audi MMI" screen
```

## The 101 processes

The full service graph lives in `/etc/mmi3g-srv-starter.cfg`, with:

- **101** `<Process>` entries, numbered 0-100
- **105** `<Interface>` IPC endpoints  
- **17** `<Environment>` sets (env-var bundles)
- **30** `<Package>` dependency groups
- All run in a single APS partition: `System`

Extracting the key ones by role:

### Device drivers (kernel mode / QNX resource managers)

| # | Binary | Args (abbreviated) |
|---|--------|--------------------|
| 3 | `/usr/bin/dev-ipc` | `-I38 -c10 -A0xB0000 -V10EE -D9411 -vvv` |
| 5 | `/usr/bin/dev-nvram` | `-d -V0x10ee -D0x9411 -B0 ...` |
| 6 | `/usr/bin/dev-sysregs` | `-r -A 0x00001000,2k -c /etc/sysregs-mmi3g-9411.cfg` |
| 7 | `/usr/bin/dev-videoctrl` | `-c /etc/videoctrl-Audi3G.cfg` |
| 2 | `/usr/bin/dev-adjmanager` | `-f0x8000000 -s0x40000 -d0x20 -m0` (TCON / display adjustment) |
| 8 | `/usr/bin/devb-eide-hbfpga` | EIDE over the FPGA bus (HDD controller) |
| 9-10 | `/usr/bin/devb-sdc-hbfpga` | SD card controllers (slot 1 and slot 2) |
| 11 | `/usr/bin/devc-ser8250hb` | Serial console |
| 12 | `/usr/sbin/devf-generic` | Internal flash filesystem |
| 14 | `/usr/bin/devg-NVMiniRM` | NVIDIA graphics mini resource manager |
| 18 | `/usr/sbin/io-audio` | QNX audio manager |
| 19 | `/usr/sbin/io-display` | `-dvid=0x10de,did=0x187` — NVIDIA Tegra display |
| 20 | `/sbin/io-pkt-v4-hc` | IPv4 + IPv6 networking |
| 22 | `/sbin/io-usb` | USB host controller (EHCI + OHCI) |

### Navigation subsystem

| # | Binary |
|---|--------|
| 53 | `/usr/bin/ndr` — navigation data router, HFS-backed |
| 59 | `/usr/bin/vdev-flexgps` — GPS device virtualizer |
| 90 | `/usr/apps/NavCore` — navigation engine (7.1 MB SH4 ELF) |
| 93 | `/usr/bin/vdev-logvolmgr` — volume manager (target of `nav-unblocker` module) |

### Media / audio stack

| # | Binary |
|---|--------|
| 21 | `/sbin/io-media-nvidia` — NVIDIA-backed media decoder |
| 23-26, 88, 96 | `/sbin/io-fs-media` — mount handlers for tmp/iPod/extdrive/pfs/BT/upnp media |
| 42 | `mmelauncher` — media manager launcher |
| 43 | `/usr/bin/mme-update` — media DB updater (tag scanner) |
| 91 | `/usr/sbin/gracenote_srvr` — Gracenote music recognition server |

### HMI / Java stack

| # | Binary |
|---|--------|
| 28 | `/usr/bin/layermanagerV2` — compositor, renders the HMI layers |
| 48 | `/bin/proc_scriptlauncher` — the SD-card script executor we hook into! |
| 58 | `/usr/bin/srv-starterClientQNX` — init itself |
| 61 | **`/usr/apps/MMI3GApplication`** — the main HMI (10.7 MB) |
| 62 | `/lsd/lsd.sh` — J9 JVM launcher, starts OSGi container + all Java apps |
| 97 | `/usr/bin/run_gemmi.sh` — starts the Green Engineering Menu subsystem |

### Persistence / adaptation

| # | Binary |
|---|--------|
| 5 | `/usr/bin/dev-nvram` — NVRAM resource manager (backs DSI persistence) |
| 95 | `/usr/bin/servicebroker` — DSI service broker (the IPC hub) |
| 45 | `/usr/bin/multicored` — dumps, monitoring, diagnostic traces |

### Miscellaneous hooks we already target

| # | Binary | What the toolkit does with it |
|---|--------|-------------------------------|
| 37 | `/usr/bin/manage_cd.sh` | `nav-unblocker` module patches this |
| 40 | `mmi3g-flashctl` | Referenced by variant-dump; validates firmware |
| 48 | `/bin/proc_scriptlauncher` | The SD-card XOR-script runner — our entire toolkit's entry point |
| 97 | `/usr/bin/run_gemmi.sh` | Starts GEM; the module we activate |

### Binary availability

All 101 executables (or their shell-script wrappers) are now extractable
via `tools/inflate_ifs.py --extract`. Key ones for reverse engineering:

```
/usr/apps/MMI3GApplication      10,702,848 bytes   SH4 ELF
/usr/apps/MMI3GMedia             8,298,496 bytes   SH4 ELF
/usr/apps/MMI3GNavigation        9,523,200 bytes   SH4 ELF
/usr/apps/MMI3GMisc              3,895,296 bytes   SH4 ELF
/usr/apps/MMI3GTelephone         5,844,992 bytes   SH4 ELF
/usr/apps/NavCore                7,086,080 bytes   SH4 ELF
/proc/boot/procnto-instr           413,696 bytes   SH4 ELF (QNX kernel)
/proc/boot/libc.so.2               425,984 bytes   SH4 ELF (C library)
/j9/bin/libj9jit23.so            ~3 MB               SH4 ELF (IBM J9 JIT)
/lsd/lsd.jxe                      ~5 MB               J9 JXE bundle
```

## IPC: the DSI service broker

The MMI's RPC bus is called **DSI** (Distributed Service Infrastructure).
Process #95 `servicebroker` is the central registry; every HMI service
registers its interfaces there and consumers look them up by name.

In `srv-starter.cfg` the `<Interface>` entries enumerate the 105 IPC
endpoints. Examples seen: `/database`, `/dev/adjmanager`, `/dev/cam0`,
`/dev/cd0`, `/dev/flexgps`, `/dev/hd0`, `/dev/hd0t77` (nav partition),
`/dev/hd0t78`. The `<ProvidesInterface>` and `<RequiresInterface>`
fields in each Process block form a dependency DAG that
`srv-starterClientQNX` uses to order startup.

From Java the DSI bus is accessed via `org.dsi.ifc.persistence.DSIPersistence`
(and its siblings). From C++ the same bus is reached via native DSI
libraries (`libdsiservice.so`, `libdsiClient.so`) exposed by classes
like `CSoundRSUAdapter`, `CAudioManagementRSUAdapter`,
`CRSUDevicePersistence`, `CIOCPresCtrlPersistence`, `CTVTunerPersistence`
— all symbols visible in `MMI3GApplication`.

## Where custom work can plug in

### 1. SD-card script injection (what the toolkit already does)

`/bin/proc_scriptlauncher` (process #48) polls SD card slots and
executes `copie_scr.sh` when it sees one. That's our entry point for
every current module. **Anything that can be done as a shell script
runs from here.**

### 2. GEM screens (Java, runs inside MMI3GApplication's JVM)

Custom `.esd` screen descriptors placed in `/mnt/efs-system/engdefs/`
get loaded by the GEM subsystem. `gauges-dashboard`, `long-coding`,
and friends all use this path. Requires the GEM enable bit set via
VCDS (adaptation 5F channel 6 = 1).

### 3. OSGi bundles (Java, runs inside lsd.sh's JVM)

The extension-point pattern pioneered by `per3-reader`: replace
`/mnt/efs-system/lsd/DSITracer.jar` with a custom OSGi bundle. This
runs in the same JVM as the HMI with full access to DSI services,
zero JVM-startup cost per call. Current alpha module uses this to
expose per3 reads to shell.

### 4. Native binary injection (NEW — enabled by this extraction)

Because we can now extract every SH4 ELF in the firmware, future work
could:

- Drop a custom binary into `/mnt/efs-system/bin/` from an SD script
- Register it as a new entry in the running `srv-starterClientQNX`
  (via `dev-ipc` IPC)
- Or hook into an existing process via `LD_PRELOAD` on a library the
  target loads
- Or patch one of the 30 packages in `srv-starter.cfg` to launch our
  binary alongside a legit one

This is the path to "custom apps" — native code that runs at HMI level,
not just the Java GEM sandbox.

### 5. Firmware replacement (FUTURE — requires IFS repack)

Decompression works. Repacking an IFS (writing new file data + regenerating
LZO1X streams in Harman's exact format) is not yet implemented. When it is,
you could ship modified `ifs-root.ifs` via an MU update. Note that
Harman's flasher does firmware signature verification — you'd need to
bypass or re-sign that too.

## Cross-compilation

To build native SH4 ELF binaries for the MMI, you need:

- **QNX Software Development Platform 6.3.2** (Momentics, with SH4 target)
- **minilzo / libucl** if you want to read Harman file formats from your tool
- **libc.so.2** from the extracted `/proc/boot/libc.so.2` as the sysroot

The SDK is commercially licensed but was distributed broadly in 2008-era
QNX 6.4 betas. An alternative is the leaked `openqnx` source tree
(`github.com/vocho/openqnx`) which contains everything needed to build
a working QNX 6.4.1 cross-toolchain, close enough to 6.3.2 for most
userland binaries.

A future toolkit module could:

1. Ship a pre-built Docker image with SH4 cross-gcc and the libc
   sysroot already set up
2. Accept a user's C source via SD card (or better, build off-device
   and upload the binary)
3. Install it via the existing `proc_scriptlauncher` hook

## References

- `/etc/mmi3g-srv-starter.cfg` — authoritative service config (extracted from IFS)
- `/proc/boot/.script` — kernel boot script (binary format, not yet fully parsed)
- `openqnx/trunk/services/system/public/sys/image.h` — IFS on-disk format
- `openqnx/trunk/utils/m/mkxfs/dumpifs/dumpifs.c` — reference reader
- `github.com/unbe/mmi-ifs` — prior art on decompressing MMI3G IFS
- DrGER2's audizine threads — extensive community documentation of MMI3G internals
