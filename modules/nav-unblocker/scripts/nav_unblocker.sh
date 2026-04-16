#!/bin/ksh
# ============================================================
# MMI3G Navigation Database Unblocker
# Patches QNX to disable Harman-Becker nav database activation
# ============================================================
#
# HOW IT WORKS:
#
# The MMI3G system uses process vdev-logvolmgr to create
# /mnt/lvm/acios_db.ini, which MMI3GApplication then uses to
# authenticate the nav database against an FSC activation file.
# Without a valid FSC file for the installed nav database
# release, navigation access is blocked.
#
# Keldo discovered (2015/2016) that terminating vdev-logvolmgr
# shortly after it creates acios_db.ini completely disables
# the activation check. This patch appends that logic to
# manage_cd.sh, which runs at boot via srv-starter-QNX.
#
# APPROACH:
# DrGER2's improved method (Dec 2022) - appends the unblocker
# command to /usr/bin/manage_cd.sh rather than wrapping
# mme-becker via mmelauncher.cfg. This is cleaner, works on
# both MMI3G High and 3G+ without needing sed on HNav systems,
# and doesn't interfere with other mme-becker modifications
# (like the LTE/DLINK setup).
#
# PERSISTENCE:
# The patch persists across reboots. It is overwritten if the
# efs-system firmware component is reinstalled. In that case,
# simply re-run this script.
#
# CREDITS:
# - Keldo (2015/2016): Discovery of vdev-logvolmgr termination
# - Vlasoff (2016): First public activator script
# - DarkDll: Keldo activator improvements
# - DrGER2 (2022): manage_cd.sh approach, GitHub implementation
#
# ============================================================

SDPATH="${1:-$(dirname $0)}"
EFSDIR="/mnt/efs-system"

# Source shared platform helper (with inline fallback)
if [ -f "${SDPATH}/scripts/common/platform.sh" ]; then
    . "${SDPATH}/scripts/common/platform.sh"
else
    MMI_VARIANT="UNKNOWN"
    for f in /etc/pci-3g_*.cfg; do
        [ -f "$f" ] || continue
        VID="$(echo "$f" | sed -n 's,^/etc/pci-3g_\([0-9]*\)\.cfg$,\1,p')"
        case "$VID" in
            9304) MMI_VARIANT="MMI3G_BASIC" ;;
            9308) MMI_VARIANT="MMI3G_HIGH" ;;
            9411|9478) MMI_VARIANT="MMI3GP" ;;
        esac
        break
    done
    MMI_TRAIN="$(cat /dev/shmem/sw_trainname.txt 2>/dev/null)"
    [ -z "$MMI_TRAIN" ] && MMI_TRAIN="$(sloginfo -m 10000 -s 5 2>/dev/null | sed -n 's/^.* +++ Train //p' | sed -n 1p)"
    if [ "$MMI_VARIANT" = "MMI3GP" ] && echo "$MMI_TRAIN" | grep -q "_VW_"; then
        MMI_VARIANT="RNS850"
    fi
    mmi_logstamp() {
        if command -v getTime >/dev/null 2>&1; then
            T="$(getTime 2>/dev/null)"
            [ -n "$T" ] && { date -r "$T" +%Y%m%d-%H%M%S 2>/dev/null || echo "epoch-$T"; return 0; }
        fi
        date +%Y%m%d-%H%M%S 2>/dev/null
    }
fi

LOGFILE="${SDPATH}/var/navunblocker-$(mmi_logstamp).log"

exec > ${LOGFILE} 2>&1

echo "============================================"
echo " MMI3G Nav Database Unblocker"
echo " $(date) [QNX date — may be since-boot]"
echo " Variant: ${MMI_VARIANT}"
echo " Train:   ${MMI_TRAIN:-n/a}"
echo "============================================"
echo ""

# --- The patch command ---
# This is the core of Keldo's discovery:
# Wait up to 180 seconds for acios_db.ini to appear,
# then wait 10 more seconds for it to be fully written,
# then terminate vdev-logvolmgr to prevent activation check.
PATCH_CMD='(waitfor /mnt/lvm/acios_db.ini 180 && sleep 10 && slay vdev-logvolmgr) &'
PATCH_MARKER="acios_db.ini"
MANAGE_CD="${EFSDIR}/usr/bin/manage_cd.sh"

# --- Detect variant (info only — patch is the same on all variants) ---
case "$MMI_VARIANT" in
    MMI3G_HIGH)  echo "[INFO]  MMI 3G High (HNav) detected" ;;
    MMI3G_BASIC) echo "[INFO]  MMI 3G Basic detected" ;;
    MMI3GP)      echo "[INFO]  MMI 3G+ (HN+) detected" ;;
    RNS850)      echo "[INFO]  VW RNS-850 detected" ;;
    *)           echo "[INFO]  Variant: UNKNOWN (train: ${MMI_TRAIN:-n/a})" ;;
esac
echo ""

# --- Remount efs-system read-write ---
echo "[ACTI]  Remounting efs-system rw..."
mount -uw ${EFSDIR}
if [ $? -ne 0 ]; then
    echo "[ERROR] Failed to remount efs-system!"
    exit 1
fi
echo "[OK]    Remounted"
echo ""

# --- Check if already patched ---
echo "[CHECK] Checking for existing patch..."

# Check manage_cd.sh (DrGER2 method)
if [ -f "${MANAGE_CD}" ]; then
    if grep -q "${PATCH_MARKER}" "${MANAGE_CD}" 2>/dev/null; then
        echo "[INFO]  manage_cd.sh is ALREADY patched!"
        echo "[INFO]  The unblocker is already installed."
        echo "[INFO]  No changes made."
        echo ""
        echo "  If nav is still blocked, reboot the MMI:"
        echo "  Hold MENU + rotary knob + upper-right soft key"
        exit 0
    fi
fi

# Check for legacy Keldo/Vlasoff mme-becker.sh patch
LEGACY_PATCH=0
if [ -f "${EFSDIR}/sbin/mme-becker.sh" ]; then
    if grep -q "${PATCH_MARKER}" "${EFSDIR}/sbin/mme-becker.sh" 2>/dev/null; then
        echo "[INFO]  Legacy mme-becker.sh patch detected"
        LEGACY_PATCH=1
    fi
fi
if [ -f "${EFSDIR}/etc/mmelauncher.cfg.pre-navdb.bak" ]; then
    echo "[INFO]  Legacy mmelauncher.cfg backup detected"
    LEGACY_PATCH=1
fi

if [ $LEGACY_PATCH -eq 1 ]; then
    echo "[INFO]  A legacy activator (Keldo/Vlasoff/DarkDll) was"
    echo "[INFO]  previously installed. Our patch uses the improved"
    echo "[INFO]  manage_cd.sh method and will coexist safely."
    echo "[INFO]  The legacy patch is harmless but redundant."
    echo ""
fi

# --- Backup manage_cd.sh ---
BACKUPDIR="${SDPATH}/var/navunblocker-backup"
mkdir -p ${BACKUPDIR}

if [ -f "${MANAGE_CD}" ]; then
    cp -v "${MANAGE_CD}" "${BACKUPDIR}/manage_cd.sh.original"
    echo "[BACK]  Original manage_cd.sh backed up to SD card"
else
    echo "[ERROR] manage_cd.sh not found at ${MANAGE_CD}"
    echo "[ERROR] This is unexpected — file should exist on all"
    echo "[ERROR] MMI3G High and 3G+ systems."
    exit 1
fi
echo ""

# --- Apply patch ---
# This follows DrGER2's canonical approach (navunblocker-230308):
#   1. mv -> .sh-ORIG, then cp -p back (preserves perms/timestamps)
#   2. Append TimeLogger marker line (also makes the patch visible to
#      DrGER2's mmi3ginfo3 detection via grep)
#   3. Append the waitfor/slay patch line
#   4. chmod 0777
#   5. touch -r to copy the original mtime (avoids tripping any
#      file-integrity / change-detection heuristics)
echo "[ACTI]  Applying nav database unblocker patch..."
mv -v "${MANAGE_CD}" "${MANAGE_CD}-ORIG"
cp -v "${MANAGE_CD}-ORIG" "${MANAGE_CD}"
echo '/usr/apps/bench/TimeLogger "Starting MMI3G NavUnblocker patch"' >> "${MANAGE_CD}"
echo "${PATCH_CMD}" >> "${MANAGE_CD}"
chmod 0777 "${MANAGE_CD}"
touch -r "${MANAGE_CD}-ORIG" "${MANAGE_CD}"

# Verify
if grep -q "${PATCH_MARKER}" "${MANAGE_CD}" 2>/dev/null; then
    echo "[OK]    Patch applied successfully to manage_cd.sh"
else
    echo "[ERROR] Patch verification failed!"
    echo "[ERROR] Restoring from -ORIG backup..."
    cp -v "${MANAGE_CD}-ORIG" "${MANAGE_CD}"
    exit 1
fi
echo ""

# --- Sync ---
sync

echo "============================================"
echo " Nav Database Unblocker Installed!"
echo ""
echo " IMPORTANT: You must reboot the MMI for the"
echo " patch to take effect:"
echo ""
echo "   Hold MENU + rotary knob + upper-right soft key"
echo "   Wait for full reboot (~2 minutes)"
echo ""
echo " After reboot, navigation should initialize"
echo " normally without an FSC activation file."
echo ""
echo " This patch persists across reboots. It will"
echo " be overwritten if you reinstall the efs-system"
echo " firmware component — just re-run this script."
echo ""
echo " To uninstall: run nav_restore.sh"
echo ""
echo " Log: ${LOGFILE}"
echo "============================================"
