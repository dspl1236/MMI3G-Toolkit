#!/bin/ksh
# MMI3G-Toolkit Uninstaller
# Removes GEM screens and script directories installed by any toolkit module.
# Safe to run even if only some modules were installed — missing items are skipped.

EFSDIR="/mnt/efs-system"
ENGDEFS="${EFSDIR}/engdefs"
SCRIPTS="${EFSDIR}/scripts"

echo "============================================"
echo " MMI3G-Toolkit Uninstaller"
echo " $(date)"
echo "============================================"
echo ""

if [ ! -d "${EFSDIR}" ]; then
    echo "[ERROR] ${EFSDIR} not found. Not running on MMI?"
    exit 1
fi

mount -uw ${EFSDIR}
if [ $? -ne 0 ]; then
    echo "[ERROR] Failed to remount ${EFSDIR} read-write"
    exit 1
fi
echo "[OK] ${EFSDIR} remounted rw"
echo ""

# -----------------------------------------------------------
# GEM screens (.esd files in /mnt/efs-system/engdefs)
# Each glob below matches one module's screen prefix.
# Keep this list in sync with modules/*/engdefs/*.esd filenames.
# -----------------------------------------------------------
echo "--- Removing GEM screens ---"
REMOVED_COUNT=0
for pattern in \
    "Gauges*.esd" \
    "SystemInfo*.esd" \
    "Scanner*.esd" \
    "Coding*.esd" \
    "GamesMenu*.esd" \
    "MapParser*.esd" \
    "NavUnblocker*.esd" \
    "PasswordFinder*.esd" \
    "Splash*.esd" \
    "VariantDump*.esd" \
    "LTE*.esd" \
    "GEM*.esd" \
    "JVMExtract*.esd" \
    "DiagTool*.esd"
do
    for f in ${ENGDEFS}/${pattern}; do
        if [ -f "${f}" ]; then
            rm -v "${f}"
            REMOVED_COUNT=$((REMOVED_COUNT + 1))
        fi
    done
done
echo "  ${REMOVED_COUNT} screen file(s) removed"
echo ""

# -----------------------------------------------------------
# Script directories under /mnt/efs-system/scripts/
# These match the script_dir values from each module's module.json.
# -----------------------------------------------------------
echo "--- Removing script directories ---"
REMOVED_DIRS=0
for d in \
    Gauges \
    SystemInfo \
    Scanner \
    Coding \
    Games \
    MapParser \
    NavUnblocker \
    PasswordFinder \
    Splash \
    VariantDump \
    LTE \
    GEM \
    JVMExtract \
    DiagTool
do
    if [ -d "${SCRIPTS}/${d}" ]; then
        rm -rf "${SCRIPTS}/${d}"
        echo "  Removed ${SCRIPTS}/${d}"
        REMOVED_DIRS=$((REMOVED_DIRS + 1))
    fi
done
echo "  ${REMOVED_DIRS} script dir(s) removed"
echo ""

# -----------------------------------------------------------
# Modules that install into locations outside engdefs/scripts
# (splash-screen replaces boot images, lte-setup writes netcfg files).
# We do NOT auto-revert those here — users should run the module's own
# restore script (splash_restore.sh, lte_restore.sh, nav_restore.sh).
# -----------------------------------------------------------
echo "--- Modules with separate restore scripts ---"
echo "  splash-screen:  run splash_restore.sh to revert boot image"
echo "  lte-setup:      run lte_restore.sh to revert network config"
echo "  nav-unblocker:  run nav_restore.sh to restore manage_cd.sh"
echo "  (These are NOT undone automatically — they touch files outside engdefs/scripts)"
echo ""

sync
mount -ur ${EFSDIR} 2>/dev/null

echo "============================================"
echo " Uninstall complete."
echo " Reboot MMI: hold MENU + knob + upper-right soft key"
echo "============================================"
