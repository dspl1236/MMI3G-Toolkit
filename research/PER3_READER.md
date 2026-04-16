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

This document captures what's actually required, so the next time someone
wants per3 values in a shell pipeline, they don't have to rediscover
everything.

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

- **Shell out to a per3 binary.** There isn't one. DrGER2 (who wrote
  `mmi3ginfo3`, the canonical MMI3G info-dump script) explicitly
  confirmed this during review.
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

This is the answer DrGER2 was hoping for. It is also weeks of RE work.

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

### Path C: OSGi bundle alongside AppDevelopment.jar

Permanent resident bundle. Queried via a Unix-domain socket or a
FIFO. Zero startup cost per query.

Architecturally much heavier than B — bundle lifecycle, service
registration, IPC protocol design. Worth considering only after B proves
the Java-side reads work correctly in practice.

## Current toolkit position

- `long-coding` module ships GEM screens (`CodingMain.esd`,
  `CodingCarConfig.esd`, `CodingBusRouting.esd`) that render per3
  values live. These run inside the Java VM and Just Work.
- `variant-dump` captures what a shell CAN see: train name, variants,
  hwSample, kernel info, storage, nav DB state, FSC status, unblocker
  state. It explicitly does NOT try to dump per3 values and directs
  users at VCDS/ODIS or the long-coding screens.
- **Nothing in the toolkit currently reads per3 from outside Java.**
  That's accurate to what's actually possible today.

## If we build something

If someone (maintainer or contributor) wants to take Path B, the first
deliverable is a single Java class under `modules/per3-reader/src/` that:

1. Resolves a `DSIPersistence` reference through the OSGi
   `ServiceRegistry`.
2. Accepts `(namespace, address, type)` from command line.
3. Calls the appropriate read method.
4. Prints the value to stdout.

Then a wrapper shell script in `modules/per3-reader/scripts/` that
invokes J9 with the right classpath. Then the `variant-dump` and
`long-coding` dump scripts can be upgraded from "direction" to
"actual values" with a conditional:

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

- DrGER2 for the review that caught the invented `per3_read`
  references and for the specific feedback on how the DSI layer
  actually works in practice.
- `research/decompiled/de/audi/tghu/development/eis/PersistenceAccessor.java`
  and `SystemAccessor.java` — the Java API surface.
- `research/PER3_ADDRESS_MAP.md` — the address map extracted from the
  factory ESD files.
