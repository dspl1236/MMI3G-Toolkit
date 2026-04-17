# Reading per3 / DSI persistence values from outside Java

## The short version

The MMI3G per3 / keyValue namespace — where the car-device list, CAN
assignments, feature enable bits, version strings, and adaptation values
all live — is **DSI-only**. It is reachable from inside the J9 Java VM via
`org.dsi.ifc.persistence.DSIPersistence`, and not reachable from a shell
script.

There is no `per3_read` CLI binary. Early drafts of this toolkit's
`variant-dump` and `long-coding` shell scripts referenced one as if it
existed; that was incorrect and has since been removed. Anyone who checked
the scripts out before audit pass 2 (commit `f488ab7`) would have seen
them dutifully return `n/a` for every address — the fallback branch of a
path that never resolved.

This document captures what's actually required, which path we chose, and
what remains to validate on real hardware.

## What per3 / DSI actually is

From the decompiled `de.audi.tghu.development.eis.PersistenceAccessor`
class (see `research/decompiled/`):

```java
public class PersistenceAccessor {
    protected DSIPersistence persistence;
    protected DSIPersistence fakePersistence;

    protected void _poll_fp(int n, int n2, long[] lArray)
            throws DSINonFatalException, DSIFatalException {
        for (int i = 0; i < lArray.length; ++i) {
            switch (n) {
                case 0: this.fakePersistence.readInt(n2, lArray[i], false);    continue;
                case 3: this.fakePersistence.readString(n2, lArray[i], false); continue;
                // ...
            }
        }
    }
}
```

The interface comes from `org.dsi.ifc.persistence.DSIPersistence`, backed
by a native QNX IPC channel served by Harman-Becker's persistence daemon.
The Java client resolves a service reference, issues typed reads
(`readInt`, `readString`, `readTable`), and gets back the value stored at
a given `(namespace, address)` pair.

**Namespaces seen in the ESD files** (from `research/PER3_ADDRESS_MAP.md`):
- `0` = keyValue poll / int (live sensor data)
- `3` = string data (version strings, part numbers)
- `4` = table (structured data like firmware version tuples)

Addresses within per3 are 32-bit. Well-known ranges:

| Range                        | Purpose                                  |
|------------------------------|------------------------------------------|
| `0x00000000` – `0x000FFFFF`  | System / live sensor data                |
| `0x00100000` – `0x0010FFFF`  | Car-device list (installed feature bits) |
| `0x00110000` – `0x001100FF`  | Spare-part / identification strings      |
| `0x00120000` – `0x001200FF`  | Version / counters                       |
| `0x00140000` – `0x001400FF`  | CAN-bus assignment (Komfort vs Dash)     |
| `0x00150000` – `0x001500FF`  | Telephony / feature settings             |

## What you CANNOT do

- **Shell out to a per3 binary.** There isn't one.
- **Read persistence files directly off the filesystem.** The per3
  namespace is mediated by the DSI daemon, which owns the
  representation on disk (it's not plain files; the persistence layer
  handles encoding, locking, and caching).
- **Use sloginfo to fish values out.** sloginfo only has what processes
  chose to log. Adaptation values aren't emitted to syslog.

## What you CAN do — three paths

### Path A: native C binary that speaks DSI IPC

**Status:** not built. Research project.

Requires:

1. DSI header files (`dsi/ifc/persistence.h`, etc.) — **not publicly
   shipped.** Part of the Harman-Becker SDK.
2. Reverse-engineer the IPC protocol from the DSI native library that
   the Java side calls into (`strings` + Ghidra on whatever `.so`
   exports `Java_org_dsi_ifc_persistence_*` symbols).
3. Identify the dispatch channel name the persistence daemon registers
   under (a path like `_PATH_DSI_PERSISTENCE` or similar).
4. Cross-compile against QNX 6.3 SH4. A QNX 6.5 SP1 VM will get you
   close; target libraries can be pulled from the firmware image.

Output would be a ~10 KB binary that runs instantly, callable from any
shell script like:

```bash
per3_read 0x00100015    # returns an integer
per3_read --string 0x00120004    # returns the train name
```

That's the nicest solution. It is also weeks of RE work.

### Path B: Java CLI running on the existing J9 VM

**Status:** not built. Low effort — the pieces are already in
`research/decompiled/`.

The MMI's `lsd.sh` script starts J9 with `dsi.jar` on the classpath. A
small Java main class can use the same APIs our GEM screens use:

```java
public class Per3Read {
    public static void main(String[] args) {
        int ns = Integer.parseInt(args[0], 16);
        int addr = Integer.parseInt(args[1], 16);
        DSIPersistence p = /* resolve via OSGi service registry */;
        long[] out = new long[1];
        p.readInt(ns, addr, out, false);
        System.out.println(out[0]);
    }
}
```

Wrapper shell script:

```bash
#!/bin/ksh
exec /usr/apps/j9/bin/j9 \
    -cp /mnt/efs-system/lsd/dsi.jar:/mnt/efs-system/scripts/common/per3_read.jar \
    com.dspl.Per3Read "$@"
```

Trade-off: JVM startup is ~5 seconds per invocation. Fine for batch
dumps, painful for interactive scripts. The right fix for that is
Path C (keep the JVM warm).

### Path C: OSGi bundle alongside the HMI Java services

**Status: IMPLEMENTED (alpha, awaiting on-device validation).** See
`modules/per3-reader/`.

A resident bundle that installs into Harman-Becker's OSGi
extension-point slot (the `DSITracer.jar` location), registered as a
`DSIPersistence` client at startup. Queries arrive via an atomic
file-trigger mechanism — a shell script drops a request file into a
known directory, the bundle picks it up, performs the DSI read, and
writes a result file the shell script reads back.

Zero JVM startup cost per query since the bundle is always resident.
Architecturally heavier than Path B (bundle lifecycle, service
registration, file-trigger protocol), but worth it because most
callers want per3 values interactively, not batch-only.

## Current toolkit position

- `long-coding` module ships GEM screens (`CodingMain.esd`,
  `CodingCarConfig.esd`, `CodingBusRouting.esd`) that render per3
  values live. These run inside the Java VM and Just Work.
- `variant-dump` captures what a shell CAN see directly: train name,
  variants, hwSample, kernel info, storage, nav DB state, FSC status,
  unblocker state. It deliberately does not invent a per3 reader.
- `per3-reader` module (alpha) ships Path C — an OSGi bundle that
  bridges DSI reads to shell scripts via file triggers. Offline tests
  pass; on-device validation still pending.
- Other modules can call `per3_read <namespace> <address>` once
  per3-reader is installed and running. Scripts should still handle
  the "not installed" case gracefully.

## What we built

The per3-reader module in this repo implements Path C. At a glance:

- **Bundle:** `modules/per3-reader/per3-reader.jar` (~9 KB, 5 classes)
  - `Activator` — OSGi lifecycle
  - `Per3Reader` — `DSIPersistence` service client
  - `TriggerLoop` — file-trigger request/response handler
- **Scripts:** `per3_install.sh`, `per3_restore.sh`, `per3_read.sh`
- **Bytecode target:** Java 1.7 (class file version 51) to match the
  J9 runtime shipped in MMI3G+ firmware
- **Interface compatibility:** stubs under `modules/per3-reader/src/stubs/`
  verified against `DSIPersistence` (42/42 methods) and
  `DSIPersistenceListener` (18/18 methods) from extracted firmware.
  No `AbstractMethodError` risk at install time.

### What still needs on-device validation

Offline: 9/9 tests pass with `MockDSIPersistence`. On-device behavior
depends on two things we can't verify from the extracted firmware
alone:

1. **J9 bytecode version acceptance.** We compile to Java 7. If the
   J9 runtime rejects this, the fallback is to recompile
   `-source 1.6 -target 1.6`. No code changes required.
2. **Listener registration mechanism.** We register through the OSGi
   service registry. The real `DSITracer.jar` may register by calling
   `addListener()` directly on the persistence service. If our events
   don't fire, that's the thing to check.

### How other modules should call it

Modules that want per3 values should use the conditional pattern so
they stay useful even when per3-reader isn't installed:

```bash
if [ -x /mnt/efs-system/scripts/common/per3_read ]; then
    VAL="$(/mnt/efs-system/scripts/common/per3_read 0 0x00100015)"
else
    VAL="n/a — install per3-reader module"
fi
```

The modules stay useful without the reader, get better with it, and
never pretend a missing tool exists.

## Credits

- `research/decompiled/de/audi/tghu/development/eis/PersistenceAccessor.java`
  and `SystemAccessor.java` — the Java API surface.
- `research/PER3_ADDRESS_MAP.md` — the address map extracted from the
  factory ESD files.
- Ground-truth interface signatures (`DSIPersistence`,
  `DSIPersistenceListener`) extracted from the MU9411 K0942_4 firmware
  dump, verified against our stubs via `tools/verify_stubs_vs_dsi.py`.
