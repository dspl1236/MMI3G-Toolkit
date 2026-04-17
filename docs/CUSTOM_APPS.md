# Building custom apps for MMI3G+

This is a practical guide for developers who want to run their own code
on an MMI3G+ head unit. It covers the five extension mechanisms the
platform supports, when to pick each one, and what tooling you need.

> Status: Mechanisms 1-3 are proven and used by existing toolkit modules.
> Mechanism 4 (native code injection) is demonstrated but no shipping
> module uses it yet. Mechanism 5 (firmware replacement) requires work
> on an IFS repacker that has not been built.

If any of this is new, start with [research/HMI_ARCHITECTURE.md](../research/HMI_ARCHITECTURE.md)
to understand what you're hooking into.

## Picking a mechanism

| Mechanism | Language | Persistence | Effort | Example |
|-----------|----------|-------------|--------|---------|
| 1. SD script | shell | Per-insertion | Easy | `system-info`, `variant-dump` |
| 2. Flash-persistent script | shell | Across reboots | Easy | `nav-unblocker` |
| 3. GEM screen | Java + XML | Across reboots | Medium | `gauges-dashboard`, `long-coding` |
| 4. OSGi bundle | Java | Across reboots | Hard | `per3-reader` |
| 5. Native binary | C/C++ | Across reboots | Hard (need toolchain) | none yet |

## Mechanism 1: SD-card scripts

The lowest-effort option. Write a shell script, put it on an SD card,
insert the card. The MMI's `proc_scriptlauncher` finds it, XOR-decodes
it, and runs it as root.

**When to use:** one-shot diagnostics, reading files off flash, dumping
state to the SD card, any operation that doesn't need to survive reboot.

**How:**

1. Write your logic in `core/copie_scr_plain.sh`-compatible shell (ksh
   on QNX 6.3.2, POSIX subset).
2. Package as a toolkit module (see [CONTRIBUTING.md](../docs/CONTRIBUTING.md)).
3. The builder runs the XOR encoder on `copie_scr_plain.sh` to produce
   the magic `copie_scr.sh` the MMI looks for.
4. User inserts the SD card, script runs within 30-60 seconds.

**Gotchas:**

- Scripts are stateless; each SD insertion starts a new ksh
- No persistent filesystem writes unless you target `/mnt/efs-system/...`
- Log everything to the SD card for post-mortem debugging
- The `platform.sh` helper in `core/` gives you variant detection,
  timestamped logging, and safe fallbacks for missing binaries

## Mechanism 2: Flash-persistent scripts

If you want something to run on every boot, drop a script (or a patch
to an existing script) into `/mnt/efs-system/` from an SD session. The
MMI runs scripts from there during its startup sequence.

**When to use:** patches to existing shell scripts
(like `nav-unblocker` adding a line to `manage_cd.sh`), one-shot
initialization at boot time.

**How:**

1. Use the SD-script mechanism to copy your `.sh` into
   `/mnt/efs-system/scripts/common/` (or wherever appropriate).
2. If you need it invoked automatically, either patch an existing
   startup script or add a symlink in a directory that the
   `srv-starter.cfg` entries scan.
3. Test your uninstall path: every toolkit module must have one.

**Gotchas:**

- `/mnt/efs-system` is overwritten by firmware updates (MU updates)
- Anything you install here will need to be reinstalled after any
  firmware flash

## Mechanism 3: GEM screens

The Green Engineering Menu is a built-in HMI debug menu the MMI draws
when you hold CAR+BACK (or CAR+SETUP on older models). It renders
XML-defined screens (`.esd` files) with Java-backed data-binding.

**When to use:** anything that wants a UI visible on the MMI screen
itself — live gauges, coding editors, status displays.

**How:**

1. Set the GEM enable bit via VCDS (address 5F, adaptation channel 6 = 1)
   — this is a one-time setup, not per-module.
2. Write your screen as an `.esd` file (see `modules/gauges-dashboard/`
   for a worked example).
3. Reference key-value bindings to any DSI property (per3 adaptation,
   live sensor data, etc.).
4. Install the `.esd` into `/mnt/efs-system/engdefs/` from an SD script.
5. Users see your screen in the GEM menu on next boot.

**Gotchas:**

- The Java code that backs GEM screens runs in the HMI's JVM. You don't
  write it; you declare bindings.
- The set of available data sources is fixed unless you also install an
  OSGi bundle (mechanism 4) that exposes new DSIPersistence keys.

## Mechanism 4: OSGi bundles

The MMI runs an OSGi container (IBM J9) via `/lsd/lsd.sh`. The container
loads bundles from `/mnt/efs-system/lsd/` at startup. Our `per3-reader`
module is the reference implementation: it replaces the existing
`DSITracer.jar` extension-point slot with a custom bundle that bridges
DSI reads to shell scripts.

**When to use:** any Java logic that needs to stay resident in the JVM,
access DSIPersistence or other DSI services, or communicate with shell
scripts over IPC.

**How:**

1. Compile your bundle as a J2ME-compatible JAR (Java 1.7 bytecode,
   class file version 51 — see `modules/per3-reader/build.sh`).
2. Use stub interfaces under `src/stubs/` that match the
   on-device `dsi.jar` exactly (use `tools/verify_stubs_vs_dsi.py`
   after extracting JARs from a real firmware).
3. Your bundle's Activator runs `start()` on container boot. Register
   services with `BundleContext.registerService(...)`.
4. Install the JAR by replacing `DSITracer.jar` in
   `/mnt/efs-system/lsd/` (backup the original first — per3-reader's
   install script does this).

**Gotchas:**

- J9 on QNX 6.3.2 is a J2ME-class runtime: no generics, no concurrent
  collections, limited reflection. Test offline with `MockDSIPersistence`
  before deploying.
- Harman's DSITracer.jar might register listeners via direct
  `addListener()` calls rather than OSGi service registry. If your
  events don't fire, check both paths.
- Breaking lsd.jar = no HMI. Always have an uninstall SD card ready.

## Mechanism 5: Native code (the new frontier)

Now that `tools/inflate_ifs.py --extract` gives you every SH4 binary
on the system, building and running custom native code becomes
feasible. No one has shipped a toolkit module that does this yet, so
this section is a plan more than a recipe.

### Building

**Toolchain.** You need a QNX 6.3-ish cross-compiler targeting
Renesas SH4, plus a sysroot built from extracted libraries.

Option A — Official SDK: QNX Software Development Platform 6.3.2 was
commercially distributed 2007-2009. Archives still circulate on
community sites. Target: `sh-unknown-nto-qnx6.3.2`.

Option B — Build from openqnx: the leaked QNX 6.4.1 source
(`github.com/vocho/openqnx`) has enough to bootstrap a working
toolchain. Binary compatibility between QNX 6.3 and 6.4 userland is
good enough for most utilities (same syscall ABI, compatible libc).

**Sysroot.** After `inflate_ifs.py --extract`, copy into your sysroot:

```
<extracted>/proc/boot/libc.so.2         →  sysroot/usr/lib/libc.so.2
<extracted>/proc/boot/libc.so           →  sysroot/usr/lib/libc.so
<extracted>/lib/*                       →  sysroot/lib/
<extracted>/usr/lib/*                   →  sysroot/usr/lib/
<extracted>/usr/include/*               →  sysroot/usr/include/
```

Link with `-B<sysroot>/usr/lib -Wl,--dynamic-linker=/usr/lib/ldqnx.so.2`.
Test your binary with `file` — should show:

```
ELF 32-bit LSB executable, Renesas SH, version 1 (SYSV), dynamically
linked, interpreter /usr/lib/ldqnx.so.2
```

### Deploying

You have four rough options for getting your binary running:

**A. Drop into `/mnt/efs-system/bin/` and exec from an SD script.** The
simplest path. Your binary lives with the other persistent files and
runs when triggered. Good for utilities with a clear start and stop.

**B. Add to the `srv-starter.cfg` graph.** Dangerous — the cfg is
consumed at boot and any parsing error prevents HMI startup. Feasible
in principle (add a new `<Process>` entry with your binary's path)
but needs very careful testing. A safer variant: add your binary as
a dependent of an existing non-critical process.

**C. LD_PRELOAD into an existing HMI process.** Build a shared library,
install it, and set an env var that points to it. Then your code runs
in the address space of a target process (e.g. `MMI3GApplication`)
with full access to its symbols. Most powerful, most dangerous.

**D. Native helper called from a GEM screen.** Build a small QNX utility
that the Java HMI can `exec()` to do work Java can't. A good middle
ground when mechanism 3 is the UI but you need native speed or C APIs
the JVM lacks.

### What to target first

If you're designing a new native module, reasonable starting points:

- **DSI native client** — the proper answer to `per3-reader` Path A.
  Reverse-engineer the DSI IPC protocol from `libdsiservice.so` (visible
  in the extract), implement a 10 KB binary that speaks it, expose a
  `per3_read` CLI. Faster than the Java bundle for batch dumps. See
  [research/DSI_ARCHITECTURE.md](../research/DSI_ARCHITECTURE.md) for
  the complete class map and the open questions that need answering
  first.
- **USB storage bridge** — read/write to USB mass-storage devices from
  user scripts. The driver is already there (`/sbin/io-usb`,
  `/sbin/io-fs-media`), you'd just need a small tool that wraps their
  API.
- **Backlight/fan/temperature monitor** — real-time SoC monitoring
  via `/dev/sysregs`. The driver exposes raw FPGA registers; a small
  C helper makes them legible.

### Deployment path E: inflator-overlay injection

A deployment mechanism worth mentioning explicitly because it's
elegant and non-destructive. The running MMI launches `inflator` at
boot with the invocation `inflator /mnt/efs-system/bin /mnt/efs-extended`
— it's a QNX resource manager that decompresses iwlyfmbp files on
demand.

Because inflator is a standard resmgr, **you can run a second
instance with a different overlay mapping**. If your second inflator
mounts earlier in the path-lookup order, a process opening
`/mnt/efs-extended/some-binary` would hit YOUR overlay first. Your
overlay could:

- Serve a patched/replacement binary from a different source (SD
  card, `/HBpersistence`, tmpfs)
- Leave unpatched paths passing through to the stock inflator
- Unmount itself cleanly when the SD card is removed

This is mechanism 5 territory (native code) rather than stock
mechanism 4 (OSGi), but worth building only once the DSI native
client works so the replacement binary has something to talk to.

Critical caveat: QNX resmgr ordering depends on mount order, and
mount order depends on where your startup hook runs relative to the
stock inflator's invocation in `.script`. That constrains your
options — you'd realistically need a helper shell script that the
MMI auto-executes early enough, which means either patching
`srv-starter.cfg` (dangerous) or exploiting an existing early-hook
script.

### What NOT to do

- Do not patch `procnto-instr` or `libc.so.2`. The kernel is signature-
  verified on newer firmware; replacing it reliably bricks the unit.
- Do not touch `mmi3g-flashctl` behaviour. That's what validates
  legitimate firmware updates from a real Audi service center.
- Do not ship binaries that disable the HMI's safety-critical paths
  (backup camera, parking sensors, engine data feeds). People drive
  these cars.

## Toolkit integration

When your custom app is ready, wrap it as a module:

1. `modules/<your-module>/module.json` — metadata (see other modules)
2. `modules/<your-module>/scripts/*.sh` — install/restore/runtime scripts
3. `modules/<your-module>/bundle/` — JARs, ESDs, or ELF binaries
4. `modules/<your-module>/README.md` — explain what it does, how to
   install, how to uninstall, what it depends on
5. Submit a PR. See [CONTRIBUTING.md](../docs/CONTRIBUTING.md) for the
   full module format.

## Further reading

- [research/HMI_ARCHITECTURE.md](../research/HMI_ARCHITECTURE.md) — the
  101-process service graph
- [research/DSI_ARCHITECTURE.md](../research/DSI_ARCHITECTURE.md) — the
  DSI IPC class map (Proxy/Stub/Event pattern, RSU adapters, native
  persistence API)
- [research/PER3_READER.md](../research/PER3_READER.md) — case study of
  an OSGi bundle
- [research/IFS_FORMAT.md](../research/IFS_FORMAT.md) — how to extract
  the binaries you'll link against
- [research/PER3_ADDRESS_MAP.md](../research/PER3_ADDRESS_MAP.md) — the
  per3 namespace you'll probably want to read from
- [modules/per3-reader/](../modules/per3-reader/) — reference module
  that exercises OSGi + shell-script bridging
