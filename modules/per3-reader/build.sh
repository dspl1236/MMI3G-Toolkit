#!/bin/bash
# ============================================================
# per3-reader build script
# ============================================================
# Compiles the bundle against offline stubs and packages it as
# per3-reader.jar suitable for dropping into /mnt/efs-system/lsd/
# on the MMI (takes the DSITracer.jar slot in lsd.sh).
#
# Requires: JDK 1.5+ with javac on PATH. We target -source 1.4
# / -target 1.4 because the MMI's IBM J9 VM (for QNX 6.3) is a
# J2ME-class runtime — 1.4 is the safe floor.
#
# On the MMI, the real org.osgi.* and org.dsi.* classes are
# provided by the bootclasspath (osgi.jar + dsi.jar). The stubs
# under src/stubs/ are ONLY used at compile time; we don't
# include them in the output JAR.
# ============================================================
set -e

HERE="$(cd "${0%/*}" && pwd)"
cd "$HERE"

SRC_MAIN=src/de/dspl/per3reader
SRC_STUBS=src/stubs
OUT=build
JAR=per3-reader.jar

# Target 1.7 is the floor modern JDKs can emit (JDK 17 won't do <7).
# The MMI's IBM J9 VM (QNX 6.3) is a J2ME-class runtime — DrGER2's notes
# indicate 1.5 - 1.6 class files are normally what it sees. 1.7 bytecode
# *should* load (we use no 1.7-only language features) but this is the
# #1 on-device risk to verify. If the bundle fails to load with an
# UnsupportedClassVersionError, install an older JDK (1.7) and rebuild.
JAVAC_OPTS="-source 1.7 -target 1.7 -encoding UTF-8 -Xlint:-options"

echo "[build] clean"
rm -rf "$OUT" "$JAR"
mkdir -p "$OUT"

echo "[build] collect sources"
SOURCES="$(find $SRC_MAIN $SRC_STUBS -name '*.java' | tr '\n' ' ')"
SRC_COUNT="$(echo $SOURCES | wc -w)"
echo "       $SRC_COUNT .java files"

echo "[build] javac"
javac $JAVAC_OPTS -d "$OUT" $SOURCES

# Verify Activator + Per3Reader + TriggerLoop compiled
for CLASS in de/dspl/per3reader/Activator.class \
             de/dspl/per3reader/Per3Reader.class \
             de/dspl/per3reader/TriggerLoop.class; do
    if [ ! -f "$OUT/$CLASS" ]; then
        echo "[build] FAIL: $CLASS not produced"
        exit 1
    fi
done

echo "[build] jar (only de/dspl/per3reader/, NOT stubs, NOT test/)"
# Strip the stub packages from the output — at runtime, the real OSGi
# and DSI classes come from the bootclasspath.
# Also strip the test/ subpackage — not needed at runtime, only in dev.
rm -rf "$OUT-jar"
mkdir -p "$OUT-jar/de/dspl/per3reader"
# Copy only the .class files directly under de/dspl/per3reader/ (NOT subdirs)
find "$OUT/de/dspl/per3reader" -maxdepth 1 -name '*.class' -exec cp {} "$OUT-jar/de/dspl/per3reader/" \;
jar cfm "$JAR" MANIFEST.MF -C "$OUT-jar" de/dspl/per3reader

echo "[build] verify jar contents"
jar tf "$JAR" | sort

echo "[build] done: $JAR ($(du -b "$JAR" | cut -f1) bytes)"

# -----------------------------------------------------------------
# Run the offline test harness. Uses FakePersistence/MockDSIPersistence
# so no MMI hardware needed. Exits non-zero if any test fails.
# -----------------------------------------------------------------
echo ""
echo "[test] running offline tests"
if java -cp "$OUT" de.dspl.per3reader.test.TestMain; then
    echo "[test] PASS"
else
    echo "[test] FAIL"
    exit 1
fi
