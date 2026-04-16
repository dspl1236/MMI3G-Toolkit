#!/bin/ksh
# ============================================================
# MMI3G JVM / UI Framework Extractor
# Pulls Java runtime, UI framework, and config files to SD
# for offline reverse engineering and decompilation
# ============================================================
#
# PURPOSE:
# The MMI3G UI is implemented in an IBM J9 JVM running a
# Harman Becker Java application. To add custom menu items
# to the normal MMI interface (CAR tab, etc.), we need to
# understand the plugin/bundle architecture.
#
# This script copies everything needed for offline analysis:
# - lsd.jxe (main UI application blob)
# - AppDevelopment.jar (GEM plugin — working example of
#   how to hook into the UI framework)
# - All JARs on the classpath
# - lsd.sh (JVM startup script with classpath and args)
# - J9 runtime binaries and libraries
# - Bundle/plugin configuration files
# - DSI (Display Service Interface) config
# - UI resource files (images, properties, texts)
#
# WHAT TO DO WITH THE OUTPUT:
# 1. Decompile AppDevelopment.jar with JD-GUI, CFR, or
#    Procyon to understand the Activator pattern
# 2. Extract bundles.properties from lsd.jxe to see how
#    bundles are registered and auto-started
# 3. Inspect lsd.sh for classpath order and JVM flags
# 4. Study the J9 JVM version to find compatible SDK
# 5. Look at DSI config for display/input interfaces
#
# This script is READ-ONLY — copies files, changes nothing.
#
# ============================================================

# --- platform.sh (shared variant detection + getTime helper) ---
# Defines MMI_VARIANT / MMI_VARIANT_ID / MMI_TRAIN and mmi_logstamp().
# Must be sourced before any code that calls mmi_logstamp.
_SDPATH_GUESS="${SDPATH:-$(dirname $0)}"
if [ -f "${_SDPATH_GUESS}/scripts/common/platform.sh" ]; then
    . "${_SDPATH_GUESS}/scripts/common/platform.sh"
elif [ -f "/mnt/efs-system/scripts/common/platform.sh" ]; then
    . "/mnt/efs-system/scripts/common/platform.sh"
else
    # Inline minimal fallback (DrGER2 review corrections applied)
    MMI_VARIANT="UNKNOWN"; MMI_VARIANT_ID=""
    for _f in /etc/pci-3g_*.cfg; do
        [ -f "$_f" ] || continue
        MMI_VARIANT_ID="$(echo "$_f" | sed -n 's,^/etc/pci-3g_\([0-9]*\)\.cfg$,\1,p')"
        case "$MMI_VARIANT_ID" in
            9304) MMI_VARIANT="MMI3G_BASIC" ;;
            9308) MMI_VARIANT="MMI3G_HIGH" ;;
            9411|9478) MMI_VARIANT="MMI3GP" ;;
        esac
        break
    done
    MMI_TRAIN="$(cat /dev/shmem/sw_trainname.txt 2>/dev/null)"
    [ -z "$MMI_TRAIN" ] && MMI_TRAIN="$(sloginfo -m 10000 -s 5 2>/dev/null | sed -n 's/^.* +++ Train //p' | sed -n 1p)"
    [ -z "$MMI_TRAIN" ] && MMI_TRAIN="n/a"
    if [ "$MMI_VARIANT" = "MMI3GP" ] && echo "$MMI_TRAIN" | grep -q "_VW_"; then
        MMI_VARIANT="RNS850"
    fi
    mmi_logstamp() {
        if command -v getTime >/dev/null 2>&1; then
            _T="$(getTime 2>/dev/null)"
            [ -n "$_T" ] && { date -r "$_T" +%Y%m%d-%H%M%S 2>/dev/null || echo "epoch-$_T"; return 0; }
        fi
        date +%Y%m%d-%H%M%S 2>/dev/null
    }
    mmi_getTime() {
        if command -v getTime >/dev/null 2>&1; then getTime 2>/dev/null; else date +%s 2>/dev/null; fi
    }
fi
# --- end platform.sh source ---

SDPATH="${1:-$(dirname $0)}"
TIMESTAMP=$(mmi_logstamp)
LOGFILE="${SDPATH}/var/jvm-extract-${TIMESTAMP}.log"
OUTDIR="${SDPATH}/var/jvm-extract/${TIMESTAMP}"

mkdir -p ${OUTDIR}

exec > ${LOGFILE} 2>&1

echo "============================================"
echo " MMI3G JVM / UI Framework Extractor"
echo " $(date)"
echo " Train: $(cat /dev/shmem/sw_trainname.txt 2>/dev/null)"
echo "============================================"
echo ""

# === LSD (Layered Service Display) Directory ===
echo "[SECT]  1/8 — LSD Application Files"
echo "-------------------------------------------"

LSDDIR="/mnt/efs-system/lsd"
LSDOUT="${OUTDIR}/lsd"
mkdir -p ${LSDOUT}

if [ -d "${LSDDIR}" ]; then
    echo "[INFO]  Listing ${LSDDIR}/:"
    ls -la ${LSDDIR}/ 2>/dev/null
    echo ""

    # Copy all JARs
    for f in ${LSDDIR}/*.jar; do
        if [ -f "$f" ]; then
            FNAME=$(basename $f)
            SIZE=$(ls -l "$f" | awk '{print $5}')
            cp "$f" "${LSDOUT}/${FNAME}" 2>/dev/null
            echo "[COPY]  ${FNAME} (${SIZE} bytes)"
        fi
    done

    # Copy lsd.jxe (this is the big one ~25MB)
    if [ -f "${LSDDIR}/lsd.jxe" ]; then
        SIZE=$(ls -l "${LSDDIR}/lsd.jxe" | awk '{print $5}')
        echo "[COPY]  lsd.jxe (${SIZE} bytes) — this may take a moment..."
        cp "${LSDDIR}/lsd.jxe" "${LSDOUT}/lsd.jxe" 2>/dev/null
        echo "[OK]    lsd.jxe copied"
    else
        echo "[WARN]  lsd.jxe not found!"
    fi

    # Copy startup script
    if [ -f "${LSDDIR}/lsd.sh" ]; then
        cp "${LSDDIR}/lsd.sh" "${LSDOUT}/lsd.sh" 2>/dev/null
        echo "[COPY]  lsd.sh"
    fi

    # Copy all properties and config files
    for f in ${LSDDIR}/*.properties ${LSDDIR}/*.cfg ${LSDDIR}/*.txt ${LSDDIR}/*.dat ${LSDDIR}/*.xml; do
        if [ -f "$f" ]; then
            FNAME=$(basename $f)
            cp "$f" "${LSDOUT}/${FNAME}" 2>/dev/null
            echo "[COPY]  ${FNAME}"
        fi
    done

    # Copy images subdirectory if present
    if [ -d "${LSDDIR}/images" ]; then
        mkdir -p ${LSDOUT}/images
        cp -r ${LSDDIR}/images/* ${LSDOUT}/images/ 2>/dev/null
        IMGCOUNT=$(ls ${LSDOUT}/images/ 2>/dev/null | wc -l)
        echo "[COPY]  images/ (${IMGCOUNT} files)"
    fi
else
    echo "[ERROR] ${LSDDIR} not found!"
fi
echo ""

# === J9 JVM Runtime ===
echo "[SECT]  2/8 — J9 JVM Runtime"
echo "-------------------------------------------"

J9OUT="${OUTDIR}/j9"
mkdir -p ${J9OUT}

# J9 binary and libraries
for d in /j9 /mnt/ifs-root/j9; do
    if [ -d "$d" ]; then
        echo "[INFO]  Found J9 at: $d"
        ls -laR $d 2>/dev/null > ${J9OUT}/j9_listing.txt
        echo "[COPY]  j9_listing.txt"

        # Copy the J9 binary
        if [ -f "$d/bin/j9" ]; then
            cp "$d/bin/j9" ${J9OUT}/ 2>/dev/null
            echo "[COPY]  j9 binary"
        fi

        # Copy java.properties
        if [ -f "$d/bin/java.properties" ]; then
            cp "$d/bin/java.properties" ${J9OUT}/ 2>/dev/null
            echo "[COPY]  java.properties"
        fi

        # List all shared libs
        ls -la $d/bin/lib*.so 2>/dev/null > ${J9OUT}/j9_libs.txt
        echo "[COPY]  j9_libs.txt (shared library list)"
        break
    fi
done

# Capture the running J9 process command line
pidin -fNA 2>/dev/null | grep j9 > ${J9OUT}/j9_process.txt
echo "[COPY]  j9_process.txt (running process args)"
echo ""

# === JVM Startup Configuration ===
echo "[SECT]  3/8 — JVM Startup Configuration"
echo "-------------------------------------------"

CFGOUT="${OUTDIR}/config"
mkdir -p ${CFGOUT}

# lsd.sh is the master startup script
for f in /mnt/efs-system/lsd/lsd.sh /mnt/ifs-root/lsd/lsd.sh; do
    if [ -f "$f" ]; then
        cp "$f" ${CFGOUT}/lsd.sh 2>/dev/null
        echo "[COPY]  lsd.sh from $f"
        break
    fi
done

# mmelauncher config — controls how mme-becker and the JVM are started
for f in /mnt/efs-system/etc/mmelauncher.cfg /etc/mmelauncher.cfg; do
    if [ -f "$f" ]; then
        cp "$f" ${CFGOUT}/mmelauncher.cfg 2>/dev/null
        echo "[COPY]  mmelauncher.cfg"
    fi
done

# srv-starter config — QNX process startup order
if [ -f "/etc/mmi3g-srv-starter.cfg" ]; then
    cp /etc/mmi3g-srv-starter.cfg ${CFGOUT}/ 2>/dev/null
    echo "[COPY]  mmi3g-srv-starter.cfg"
fi

# DefaultScope — HB trace config referenced in MMI3GApplication args
if [ -f "/etc/DefaultScope.hbtc" ]; then
    cp /etc/DefaultScope.hbtc ${CFGOUT}/ 2>/dev/null
    echo "[COPY]  DefaultScope.hbtc"
fi
echo ""

# === DSI (Display Service Interface) ===
echo "[SECT]  4/8 — DSI Configuration"
echo "-------------------------------------------"

DSIOUT="${OUTDIR}/dsi"
mkdir -p ${DSIOUT}

# DSI-related files
for f in /etc/dsi*.cfg /etc/dsi*.conf /mnt/efs-system/etc/dsi*; do
    if [ -f "$f" ]; then
        FNAME=$(basename $f)
        cp "$f" ${DSIOUT}/${FNAME} 2>/dev/null
        echo "[COPY]  ${FNAME}"
    fi
done

# USB launcher config (controls device detection including D-Link)
for f in /etc/usblauncher.cfg /mnt/efs-system/etc/usblauncher.cfg; do
    if [ -f "$f" ]; then
        cp "$f" ${DSIOUT}/usblauncher.cfg 2>/dev/null
        echo "[COPY]  usblauncher.cfg"
        break
    fi
done
echo ""

# === GEM Plugin Architecture (reference) ===
echo "[SECT]  5/8 — GEM Plugin Architecture"
echo "-------------------------------------------"

GEMOUT="${OUTDIR}/gem"
mkdir -p ${GEMOUT}

# All ESD screen definitions
if [ -d "/mnt/efs-system/engdefs" ]; then
    cp -r /mnt/efs-system/engdefs/* ${GEMOUT}/ 2>/dev/null
    ESDCOUNT=$(ls ${GEMOUT}/*.esd 2>/dev/null | wc -l)
    echo "[COPY]  ${ESDCOUNT} .esd screen definitions"
fi

# HBpersistence engdefs (alternate location)
if [ -d "/HBpersistence/engdefs" ]; then
    mkdir -p ${GEMOUT}/HBpersistence
    cp -r /HBpersistence/engdefs/* ${GEMOUT}/HBpersistence/ 2>/dev/null
    echo "[COPY]  HBpersistence/engdefs/"
fi
echo ""

# === IFS-Root System Binaries ===
echo "[SECT]  6/8 — Key System Binaries"
echo "-------------------------------------------"

BINOUT="${OUTDIR}/bin"
mkdir -p ${BINOUT}

# List all binaries (don't copy — too large, just list for reference)
ls -la /mnt/ifs-root/usr/bin/ 2>/dev/null > ${BINOUT}/usr_bin_listing.txt
ls -la /mnt/ifs-root/usr/apps/ 2>/dev/null > ${BINOUT}/usr_apps_listing.txt
ls -la /mnt/ifs-root/usr/lib/ 2>/dev/null > ${BINOUT}/usr_lib_listing.txt
ls -la /mnt/ifs-root/sbin/ 2>/dev/null > ${BINOUT}/sbin_listing.txt
echo "[COPY]  Binary/library directory listings"

# Extract strings from key binaries for analysis hints
if [ -x "/usr/bin/strings" ] || [ -x "/mnt/ifs-root/usr/bin/strings" ]; then
    echo "[ACTI]  Extracting strings from MMI3GApplication..."
    strings /mnt/ifs-root/usr/apps/MMI3GApplication 2>/dev/null | head -500 > ${BINOUT}/MMI3GApplication_strings.txt
    echo "[COPY]  MMI3GApplication_strings.txt (first 500 lines)"
else
    echo "[INFO]  strings binary not available — skipping"
fi

# Capture the ifs-root build info
if [ -f "/etc/build" ]; then
    cp /etc/build ${BINOUT}/ 2>/dev/null
    echo "[COPY]  /etc/build"
fi
echo ""

# === EFS-System Directory Tree ===
echo "[SECT]  7/8 — EFS-System Directory Tree"
echo "-------------------------------------------"

ls -laR /mnt/efs-system/ 2>/dev/null > ${OUTDIR}/efs-system-tree.txt
echo "[COPY]  efs-system-tree.txt (full directory listing)"
echo ""

# === JXE Internal Structure (attempt extraction) ===
echo "[SECT]  8/8 — JXE Internal Analysis"
echo "-------------------------------------------"

JXEOUT="${OUTDIR}/jxe-analysis"
mkdir -p ${JXEOUT}

if [ -f "${LSDOUT}/lsd.jxe" ]; then
    # JXE files are essentially ZIP-like archives
    # Try to extract with common tools
    SIZE=$(ls -l "${LSDOUT}/lsd.jxe" | awk '{print $5}')
    echo "[INFO]  lsd.jxe size: ${SIZE} bytes"

    # Check for ZIP signature (PK header)
    HEADER=$(dd if="${LSDOUT}/lsd.jxe" bs=2 count=1 2>/dev/null | od -A n -t x1 | tr -d ' ')
    echo "[INFO]  File header bytes: ${HEADER}"

    # Try strings to find bundles.properties and class names
    echo "[ACTI]  Extracting text from lsd.jxe..."
    strings "${LSDOUT}/lsd.jxe" 2>/dev/null | grep -i "bundle\|activator\|plugin\|menu\|screen\|car\|navigation\|media" | sort -u > ${JXEOUT}/jxe_bundle_strings.txt
    BCOUNT=$(wc -l < ${JXEOUT}/jxe_bundle_strings.txt)
    echo "[COPY]  jxe_bundle_strings.txt (${BCOUNT} lines)"

    # Extract all class/package names
    strings "${LSDOUT}/lsd.jxe" 2>/dev/null | grep "^de\.\|^com\.\|^org\.\|^java\." | sort -u > ${JXEOUT}/jxe_class_names.txt
    CCOUNT=$(wc -l < ${JXEOUT}/jxe_class_names.txt)
    echo "[COPY]  jxe_class_names.txt (${CCOUNT} class/package refs)"

    # Extract anything that looks like properties
    strings "${LSDOUT}/lsd.jxe" 2>/dev/null | grep "=" | grep -v "^[[:space:]]" | head -200 > ${JXEOUT}/jxe_properties.txt
    echo "[COPY]  jxe_properties.txt (key=value pairs)"

    # Look for the bundles.properties specifically
    strings "${LSDOUT}/lsd.jxe" 2>/dev/null | grep -A5 "Bundle\." > ${JXEOUT}/jxe_bundles_config.txt
    echo "[COPY]  jxe_bundles_config.txt"

    # Extract anything mentioning CAN, per, or key-value namespace
    strings "${LSDOUT}/lsd.jxe" 2>/dev/null | grep -i "can\|personality\|namespace\|keyvalue\|per_\|per3\|gateway\|vehicle" | sort -u > ${JXEOUT}/jxe_can_refs.txt
    echo "[COPY]  jxe_can_refs.txt (CAN/vehicle data references)"

    # Look for menu/screen structure
    strings "${LSDOUT}/lsd.jxe" 2>/dev/null | grep -i "menuitem\|addmenu\|carmenu\|mainmenu\|screenmgr\|screenmanager\|navigationmenu" | sort -u > ${JXEOUT}/jxe_menu_refs.txt
    echo "[COPY]  jxe_menu_refs.txt (menu/screen references)"
else
    echo "[WARN]  lsd.jxe not available for analysis"
fi
echo ""

# --- Summary ---
sync

TOTALSIZE=$(du -sh ${OUTDIR} 2>/dev/null | awk '{print $1}')
TOTALFILES=$(find ${OUTDIR} -type f 2>/dev/null | wc -l)

echo "============================================"
echo " JVM / UI Framework Extraction Complete"
echo ""
echo " Output: var/jvm-extract/${TIMESTAMP}/"
echo " Size:   ${TOTALSIZE}"
echo " Files:  ${TOTALFILES}"
echo ""
echo " Key files for reverse engineering:"
echo "   lsd/AppDevelopment.jar — Decompile with JD-GUI"
echo "     (this is the GEM plugin — shows how to hook"
echo "      into the UI framework)"
echo "   lsd/lsd.jxe — Main UI application blob"
echo "   lsd/lsd.sh — JVM startup with classpath"
echo "   config/mmi3g-srv-starter.cfg — Boot process"
echo "   jxe-analysis/ — Strings extracted from JXE"
echo ""
echo " NEXT STEPS:"
echo "   1. Copy output to your PC"
echo "   2. Open AppDevelopment.jar in JD-GUI or CFR"
echo "   3. Look at de.audi.tghu.development.Activator"
echo "   4. Review jxe_bundles_config.txt for plugin IDs"
echo "   5. Check jxe_menu_refs.txt for UI structure"
echo "   6. Check jxe_can_refs.txt for CAN data hooks"
echo "============================================"
