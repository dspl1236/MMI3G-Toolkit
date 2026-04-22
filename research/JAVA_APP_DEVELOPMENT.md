# Java Application Development for MMI3G/RNS-850

## JVM Environment

The MMI3G runs **IBM J9** — a compact Java runtime designed for embedded
systems. This is **NOT** Java ME (MIDP/CLDC for phones). It is:

- **CDC 1.1** (Connected Device Configuration)
- **Foundation Profile 1.1**
- Essentially Java SE minus GUI classes

### What's Available

| Package | Status | Notes |
|---------|--------|-------|
| java.lang | ✅ Full | String, Math, Runtime, System, Thread |
| java.io | ✅ Full | File, InputStream/OutputStream, Reader/Writer |
| java.util | ✅ Most | Collections, Random, Date, Properties |
| java.net | ✅ Full | Socket, URL, HttpURLConnection |
| java.security | ✅ Basic | MessageDigest, Signature, KeyStore |
| java.text | ✅ Basic | DateFormat, NumberFormat |
| javax.microedition | ❌ None | This is NOT Java ME |
| java.awt | ❌ None | No AWT — no Frame, Canvas, Graphics |
| javax.swing | ❌ None | No Swing |
| org.osgi.framework | ✅ Full | OSGi R3 — bundle lifecycle, services |
| org.dsi.ifc | ✅ Full | DSI persistence, admin, base interfaces |

### JVM Location

```
/j9/bin/j9                          — J9 executable (SH4 ELF)
/j9/bin/libj9jit23.so               — JIT compiler (~3 MB)
/j9/lib/                            — Core J9 libraries
/mnt/ifs-root/lsd/lsd.jxe           — Main UI app (27 MB JXE bundle)
/mnt/efs-system/lsd/lsd.sh          — JVM launch script
/mnt/efs-system/lsd/AppDevelopment.jar  — GEM plugin API (247 KB)
/mnt/efs-system/lsd/DSITracer.jar   — Extension slot (599 KB)
```

### Class File Version

**Critical:** AppDevelopment.jar uses Java 1.2 class files (version 46.0).

| Version | Class Format | J9 Support |
|---------|-------------|------------|
| Java 1.2 | 46.0 | ✅ Confirmed (AppDevelopment.jar) |
| Java 1.4 | 48.0 | ✅ Expected |
| Java 5 | 49.0 | ✅ Safe target for custom code |
| Java 6 | 50.0 | ⚠️ Untested |
| Java 7 | 51.0 | ❌ Likely rejected |
| Java 8+ | 52.0+ | ❌ UnsupportedClassVersionError |

**Target Java 5 (version 49.0)** for all custom code.

### Compiling for MMI J9

Modern javac (Java 21) doesn't support `--release` below 8. Workaround:
compile with `--release 8`, then patch the class file header:

```python
# Patch class version from 52 (Java 8) → 49 (Java 5)
import struct
with open('MyClass.class', 'r+b') as f:
    f.seek(6)  # Major version offset
    f.write(struct.pack('>H', 49))
```

This is safe when code only uses APIs available in Java 5 (no lambdas,
no streams, no try-with-resources, no diamond operator).

### JVM Memory Limits

From car testing (SH7785 SH4A @ 792MHz, 476MB total RAM):

```
Java Free Memory:   2,854 KB
Java Total Memory: 11,776 KB (~11.5 MB)
```

The J9 JVM is allocated ~12MB heap. Games should target under 8MB to
leave headroom for the GEM and other Java processes.

## Display Options

### Option 1: GEM Console (Text Output)

Games print to stdout, which appears in the GEM console (green text on
black background). This is the simplest approach — no graphics library
needed.

**Pros:** Zero setup, works immediately, reliable
**Cons:** Text only, no real-time updates, limited to ~20 rows

Best for: Benchmarks, fortune cookies, text adventures, diagnostics

### Option 2: showScreen Framebuffer (PNG Display)

Use the `showScreen` binary (already in our toolkit) to display images
on the MMI screen. Render frames to PNG, call showScreen to display.

```
/tmp/showScreen /path/to/frame.png
```

**Pros:** Full 800x480 color display, pixel-perfect rendering
**Cons:** ~1-2 FPS (PNG encode + display overhead), one-way (no input)

Best for: Static displays, dashboards, splash screens

### Option 3: Layermanager Framebuffer (Native C)

Direct framebuffer access via QNX layermanager — same path showScreen
uses internally. Requires a native QNX SH4 binary.

```c
// From showScreen reverse engineering:
open("/dev/layermanager")
RegisterDisplayable()
GetVfb()            // get virtual framebuffer pointer
memcpy(vfb, pixels) // write pixel data
UpdateVfb()         // push to display
```

**Pros:** 30+ FPS possible, direct pixel access, real-time
**Cons:** Requires QNX SH4 cross-compiler, native code

Best for: Doom, real-time games, video playback

### Option 4: HB Display Framework (Java, from lsd.jxe)

The Harman-Becker UI framework inside `lsd.jxe` provides Java display
classes. Undocumented — requires reverse engineering `rom.classes`.

**Pros:** Native Java, integrates with MMI UI, supports input events
**Cons:** Completely undocumented, requires lsd.jxe decompilation

Best for: Future research — full MMI-integrated apps

## Game Development

### Game Structure

```
games/
  mygame/
    game.jar          — Compiled game (Java 5 class files)
    game.manifest     — Config file
    *.dat             — Optional data files
```

### game.manifest Format

```properties
main=com.example.MyGame
name=My Cool Game
description=A game for the MMI
```

### Minimal Game Template

```java
public class MyGame {
    public static void main(String[] args) {
        System.out.println("============================================");
        System.out.println("  My Game on MMI3G!");
        System.out.println("============================================");

        Runtime rt = Runtime.getRuntime();
        System.out.println("Free Memory: " + (rt.freeMemory() / 1024) + " KB");

        // Game logic here...
        // Output goes to GEM console

        System.out.println("Game Over!");
    }
}
```

### Build & Deploy

```bash
# 1. Compile
javac --release 8 MyGame.java

# 2. Package
jar cfe game.jar MyGame MyGame.class

# 3. Patch class version to Java 5
python3 -c "
import struct
with open('MyGame.class', 'r+b') as f:
    f.seek(6)
    f.write(struct.pack('>H', 49))
"
# Re-package after patching
jar cfe game.jar MyGame MyGame.class

# 4. Create manifest
echo 'main=MyGame' > game.manifest
echo 'name=My Game' >> game.manifest

# 5. Place on SD card
mkdir -p /sdcard/games/mygame/
cp game.jar game.manifest /sdcard/games/mygame/
```

### Input Handling

The GEM console is **output-only** — no stdin for interactive input.
For games that need input:

1. **Touchscreen:** Read from `/dev/devi/touch0` (native code only)
2. **Rotary controller:** Read via CAN bus or per3 namespace
3. **File-based triggers:** Watch a trigger file (like per3-reader does)
4. **No input needed:** Self-running benchmarks, demos, animations

### Available Games

| Game | Type | Status |
|------|------|--------|
| J9 Benchmark | CPU/memory/string test | Ready (Java 5) |
| Fortune Cookie | Random Audi-themed fortunes | Ready (Java 5) |
| Snake | Text-based snake game | Ready (Java 5) |
| Quattro Quest | Text adventure | Ready (Java 5) |

## OSGi Bundle Development

For deeper MMI integration, deploy as an OSGi bundle via the
DSITracer.jar extension slot:

1. Create a `BundleActivator` that registers services
2. Package as a JAR with `Bundle-Activator` in MANIFEST.MF
3. Install to `/mnt/efs-system/lsd/DSITracer.jar`
4. Reboot — J9 loads the bundle via bootclasspath

See `modules/per3-reader/` for a complete OSGi bundle example.

### DSI Persistence API

```java
import org.dsi.ifc.persistence.DSIPersistence;

// Read a per3 value
int batteryVoltage = persistence.requestReadInt(3, 0x00000023);

// Write a per3 value (CAREFUL — can change car config)
persistence.requestWriteInt(3, address, value);
```

## lsd.jxe Structure

The main UI application is a 27MB J9 JXE bundle (ZIP format):

```
lsd.jxe (342 files)
├── rom.classes                    — Compiled class archive
├── resources/
│   ├── sysconst/
│   │   ├── sysconst.properties    — 1617 EOL feature flags
│   │   └── variants/             — Market-specific overrides
│   ├── bundles.properties         — OSGi bundle list
│   └── [HMI resources]
├── META-INF/
│   ├── certs/                     — VW root CA, T-Systems
│   └── properties/                — MyAudi, POI configs
└── org/dsi/info/DSIInfo.bin
```

Key for feature unlocking: modify `sysconst.properties` inside lsd.jxe
to enable hidden features (Google Earth, online services, etc.).

See `research/EOL_FLAGS_AND_GOOGLE_EARTH.md` for details.

## References

- **romangarms** — [Java-on-Audi-MMI-3G](https://github.com/romangarms) — original J9 research
- **DrGER2** — GEM screen customization, GEMMI monitor scripts
- **IBM J9 docs** — CDC/Foundation Profile specification
- **research/HMI_ARCHITECTURE.md** — Full MMI software stack
- **research/DSI_ARCHITECTURE.md** — DSI persistence interface
- **research/PER3_READER.md** — OSGi bundle development guide
