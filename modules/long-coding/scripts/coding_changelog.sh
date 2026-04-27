#!/bin/ksh
# ============================================================
# Coding Changelog — compare recent coding snapshots on SD
# Runs from GEM button, reports diffs between last N dumps
# ============================================================

# --- platform.sh (shared variant detection + getTime helper) ---
# Defines MMI_VARIANT / MMI_VARIANT_ID / MMI_TRAIN and mmi_logstamp().
# Must be sourced before any code that calls mmi_logstamp.
_SDPATH_GUESS="${SDPATH:-${0%/*}}"
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

SDPATH="${1:-/fs/sda1}"
for sd in /fs/sda1 /fs/sda0 /fs/sd1 /fs/sd0; do
    if [ -d "$sd" ]; then
        SDPATH=$sd
        break
    fi
done

CODINGDIR="${SDPATH}/var/coding"
if [ ! -d "$CODINGDIR" ]; then
    echo "No coding dumps found at $CODINGDIR."
    echo "Run 'Dump ALL codings to SD' first, make your changes,"
    echo "then run this to see what moved."
    exit 0
fi

# Find last 10 coding dump files
FILES=$(ls -1t ${CODINGDIR}/coding-*.txt 2>/dev/null | head -10)
if [ -z "$FILES" ]; then
    echo "No coding-*.txt dumps found in $CODINGDIR."
    exit 0
fi

echo "=== Last 10 coding snapshots ==="
echo "$FILES"
echo ""

# Compare newest two
NEWEST=$(echo "$FILES" | head -1)
PREV=$(echo "$FILES" | head -2 | tail -1)

if [ "$NEWEST" = "$PREV" ] || [ -z "$PREV" ]; then
    echo "Only one snapshot exists. Take another (make a change first) and run again."
    exit 0
fi

echo ""
echo "=== Diff: $(basename $PREV) -> $(basename $NEWEST) ==="
diff "$PREV" "$NEWEST" | head -100
echo ""
echo "(showing first 100 diff lines — full diff in SD card logs)"

# Save full diff
DIFF_OUT="${CODINGDIR}/changelog-$(mmi_logstamp).diff"
diff "$PREV" "$NEWEST" > "$DIFF_OUT" 2>&1
echo "Full diff saved to: $DIFF_OUT"
sync
