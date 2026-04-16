#!/bin/ksh
# ============================================================
# per3-reader installer
# ============================================================
# Installs per3-reader.jar into /mnt/efs-system/lsd/ as DSITracer.jar,
# which lsd.sh scans for and prepends to the bootclasspath on MMI boot.
#
# Effect: on next MMI reboot, the OSGi framework finds our
# Bundle-Activator (de.dspl.per3reader.Activator), which:
#   1. Opens a ServiceTracker on org.dsi.ifc.persistence.DSIPersistence
#   2. Waits for the live DSIPersistence service to register
#   3. Spins up the TriggerLoop watching /fs/sda1/per3req/
#
# Use per3_read.sh from an SD card or script to issue reads.
#
# Backup: any existing DSITracer.jar is preserved as DSITracer.jar.bak.
# Restore: run per3_restore.sh to reverse this.
# ============================================================

# --- platform.sh (shared variant detection + getTime helper) ---
_SDPATH_GUESS="${SDPATH:-$(dirname $0)}"
if [ -f "${_SDPATH_GUESS}/scripts/common/platform.sh" ]; then
    . "${_SDPATH_GUESS}/scripts/common/platform.sh"
elif [ -f "/mnt/efs-system/scripts/common/platform.sh" ]; then
    . "/mnt/efs-system/scripts/common/platform.sh"
else
    MMI_VARIANT="UNKNOWN"; MMI_VARIANT_ID=""
    for _f in /etc/pci-3g_*.cfg; do
        [ -f "$_f" ] || continue
        MMI_VARIANT_ID="$(echo "$_f" | sed -n 's,^/etc/pci-3g_\([0-9]*\)\.cfg$,\1,p')"
        case "$MMI_VARIANT_ID" in
            9304) MMI_VARIANT="MMI3G_BASIC" ;;
            9308) MMI_VARIANT="MMI3G_HIGH" ;;
            9411|9436|9478) MMI_VARIANT="MMI3GP" ;;
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
fi
# --- end platform.sh source ---

SDPATH="${1:-$(dirname $0)}"
EFSDIR="/mnt/efs-system"
LSDDIR="${EFSDIR}/lsd"
TARGET_NAME="DSITracer.jar"
TARGET="${LSDDIR}/${TARGET_NAME}"
SOURCE_JAR=""

LOGFILE="${SDPATH}/var/per3-install-$(mmi_logstamp).log"
mkdir -p "$(dirname ${LOGFILE})" 2>/dev/null
exec > ${LOGFILE} 2>&1

echo "============================================"
echo " per3-reader Installer"
echo " $(date) [QNX date]"
echo " Variant: ${MMI_VARIANT}"
echo " Train:   ${MMI_TRAIN:-n/a}"
echo "============================================"
echo ""

# --- Locate source JAR ---
for candidate in \
    "${SDPATH}/modules/per3-reader/per3-reader.jar" \
    "${SDPATH}/per3-reader.jar" \
    "${SDPATH}/scripts/per3-reader.jar"; do
    if [ -f "$candidate" ]; then
        SOURCE_JAR="$candidate"
        break
    fi
done

if [ -z "$SOURCE_JAR" ]; then
    echo "[ERROR] per3-reader.jar not found on SD card"
    echo "[ERROR] Looked in:"
    echo "[ERROR]   ${SDPATH}/modules/per3-reader/"
    echo "[ERROR]   ${SDPATH}/"
    echo "[ERROR]   ${SDPATH}/scripts/"
    echo "[ERROR] Build the JAR locally with: cd modules/per3-reader && bash build.sh"
    echo "[ERROR] Then copy per3-reader.jar onto the SD card before running this installer."
    exit 1
fi

echo "[INFO]  Source: ${SOURCE_JAR} ($(ls -la $SOURCE_JAR | awk '{print $5}') bytes)"
echo ""

# --- Remount efs-system rw ---
mount -uw ${EFSDIR}
if [ $? -ne 0 ]; then
    echo "[ERROR] Failed to remount ${EFSDIR} rw"
    exit 1
fi
echo "[OK]    ${EFSDIR} remounted rw"
echo ""

# --- Backup existing DSITracer.jar if present ---
if [ -f "${TARGET}" ]; then
    if [ ! -f "${TARGET}.bak" ]; then
        cp -p "${TARGET}" "${TARGET}.bak"
        echo "[OK]    Backed up existing DSITracer.jar as DSITracer.jar.bak"
    else
        echo "[INFO]  DSITracer.jar.bak already exists — preserving original backup"
    fi
fi

# --- Install the JAR ---
cp "${SOURCE_JAR}" "${TARGET}"
chmod 0644 "${TARGET}"
touch "${TARGET}"
echo "[OK]    Installed ${TARGET}"
echo ""

# --- Create trigger directory on SD card so scripts can find it ---
mkdir -p "${SDPATH}/per3req" 2>/dev/null
echo "[OK]    Created ${SDPATH}/per3req/ (trigger directory)"
echo ""

sync
mount -ur ${EFSDIR} 2>/dev/null

echo "============================================"
echo " per3-reader installed"
echo ""
echo " Next steps:"
echo "   1. Remove this SD card"
echo "   2. Reboot the MMI:"
echo "        Hold MENU + rotary knob + upper-right soft key"
echo "        Wait for full reboot (~2 minutes)"
echo "   3. Insert the SD card again with per3_read.sh on it"
echo "   4. Use the shell to issue reads:"
echo "        ksh ./per3_read.sh int 0x00100015"
echo ""
echo " The bundle's Activator logs to QNX syslog. Check with:"
echo "        sloginfo | grep per3-reader"
echo ""
echo " To uninstall: run per3_restore.sh (or drop a fresh firmware"
echo " update — re-installing MU9411 efs-system replaces DSITracer.jar)."
echo "============================================"
