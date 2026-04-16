#!/bin/ksh
# ============================================================
# Long-Coding Module Installer
# Installs ESD screens to MMI GEM menu
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
    mmi_getTime() {
        if command -v getTime >/dev/null 2>&1; then getTime 2>/dev/null; else date +%s 2>/dev/null; fi
    }
fi
# --- end platform.sh source ---

SDPATH="${1:-$(dirname $0)}"
LOGFILE="${SDPATH}/var/coding-install-$(mmi_logstamp).log"
EFSDIR="/mnt/efs-system"
MODULEDIR=$(dirname "$0")/..

exec > ${LOGFILE} 2>&1

echo "============================================"
echo " Long-Coding Module Installer"
echo " $(date)"
echo " Train: $(cat /dev/shmem/sw_trainname.txt 2>/dev/null)"
echo "============================================"
echo ""

# Remount efs-system rw
echo "[ACTI] Remounting efs-system rw..."
mount -uw ${EFSDIR} 2>&1
if [ $? -ne 0 ]; then
    echo "[ERROR] Failed to remount efs-system. Is it locked?"
    exit 1
fi

# Ensure engdefs dir exists (should be created by gem-activator)
if [ ! -d "${EFSDIR}/engdefs" ]; then
    mkdir -p ${EFSDIR}/engdefs
    echo "[INST] Created ${EFSDIR}/engdefs/"
fi

# Ensure scripts dir exists
mkdir -p ${EFSDIR}/scripts/Coding 2>/dev/null

# Copy ESD files
echo "[ACTI] Installing ESD screens..."
for esd in CodingMain.esd CodingCarConfig.esd CodingBusRouting.esd; do
    SRC="${MODULEDIR}/engdefs/${esd}"
    DST="${EFSDIR}/engdefs/${esd}"
    if [ -f "$SRC" ]; then
        cp "$SRC" "$DST"
        chmod 644 "$DST"
        echo "[OK]   Installed $esd"
    else
        echo "[WARN] Source not found: $SRC"
    fi
done

# Copy helper scripts
echo "[ACTI] Installing helper scripts..."
for script in coding_dump.sh coding_changelog.sh; do
    SRC="${MODULEDIR}/scripts/${script}"
    DST="${EFSDIR}/scripts/Coding/${script}"
    if [ -f "$SRC" ]; then
        cp "$SRC" "$DST"
        chmod 755 "$DST"
        echo "[OK]   Installed ${script}"
    else
        echo "[WARN] Source not found: $SRC"
    fi
done

# Remount ro
mount -ur ${EFSDIR}
sync

echo ""
echo "============================================"
echo " Long-Coding module installed!"
echo ""
echo " Access via Green Engineering Menu:"
echo "   CAR + BACK (C7) or CAR + SETUP (older)"
echo "   Navigate to: /coding"
echo ""
echo " Screens:"
echo "   CodingMain       - overview"
echo "   CodingCarConfig  - car device flags"
echo "   CodingBusRouting - CAN bus assignments"
echo ""
echo " Actions:"
echo "   Dump ALL codings to SD"
echo "   Show last 10 changes"
echo ""
echo " IMPORTANT: This is a READ-ONLY module."
echo " To CHANGE adaptation values, use VCDS"
echo " or ODIS. This module shows current state."
echo "============================================"
