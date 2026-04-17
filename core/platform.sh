#!/bin/ksh
# ============================================================
# MMI3G-Toolkit — platform detection helper
# Source this from any module script:  . /scripts/common/platform.sh
# (or from SD:  . ${SDPATH}/scripts/common/platform.sh)
# ============================================================
#
# Provides these variables / functions to the sourcing script:
#
#   $MMI_VARIANT      "MMI3G_BASIC" | "MMI3G_HIGH" | "MMI3GP" | "RNS850" | "UNKNOWN"
#   $MMI_VARIANT_ID   "9304" | "9308" | "9411" | "9436" | "9478" | ""
#   $MMI_TRAIN        the train name string (e.g. "HN+R_EU_AU_K0942_4"), or "n/a"
#   $MMI_SW_VERSION   main unit software version string, or "n/a"
#   $MMI_HW_SAMPLE    /etc/hwSample contents, or "n/a"
#
# Known variant IDs:
#     9304  MMI 3G Basic
#     9308  MMI 3G High
#     9411  MMI 3G Plus (A4/A5/A6/A7/A8/Q5/Q7 etc)
#     9436  MMI 3G Plus, Audi A1 8X variant  (per DrGER2)
#     9478  MMI 3G Plus, RNS-850 / VW
#
#   mmi_getTime       wall-clock timestamp (seconds since epoch) —
#                     prefers Harman-Becker getTime over QNX date
#                     because `date` on a just-booted MMI returns
#                     elapsed-since-boot until the CAN gateway
#                     pushes a real time.
#   mmi_logstamp      YYYYMMDD-HHMMSS string suitable for filenames,
#                     using the same getTime-preferred source.
#
# Corrections from DrGER2 review (2026-04):
#   * /etc/pci-3g_XXXX.cfg is the authoritative variant identifier
#     on ALL three platforms (Basic/High/Plus). sw_trainname.txt
#     is only populated on 3G+.
#   * RNS-850 is identified by "_VW_" appearing in the train name
#     (e.g. HN+_US_VW_K0711), not by a literal "RNS" string.
#   * Use getTime not date for real wall-clock timestamps.
# ============================================================

# -------- Variant detection (authoritative: /etc/pci-3g_*.cfg) --------
MMI_VARIANT="UNKNOWN"
MMI_VARIANT_ID=""
if [ -f /etc/pci-3g_9304.cfg ]; then
    MMI_VARIANT="MMI3G_BASIC"
    MMI_VARIANT_ID="9304"
elif [ -f /etc/pci-3g_9308.cfg ]; then
    MMI_VARIANT="MMI3G_HIGH"
    MMI_VARIANT_ID="9308"
elif [ -f /etc/pci-3g_9411.cfg ]; then
    MMI_VARIANT="MMI3GP"
    MMI_VARIANT_ID="9411"
elif [ -f /etc/pci-3g_9436.cfg ]; then
    # DrGER2 2026-04: Audi A1 8X uses a distinct variant ID.
    MMI_VARIANT="MMI3GP"
    MMI_VARIANT_ID="9436"
elif [ -f /etc/pci-3g_9478.cfg ]; then
    MMI_VARIANT="MMI3GP"
    MMI_VARIANT_ID="9478"
else
    # Fallback if the pci-3g_*.cfg pattern is missing for some reason —
    # try globbing. New variant IDs can be slotted into the case below.
    for f in /etc/pci-3g_*.cfg; do
        [ -f "$f" ] || continue
        MMI_VARIANT_ID="$(echo "$f" | sed -n 's,^/etc/pci-3g_\([0-9]*\)\.cfg$,\1,p')"
        case "$MMI_VARIANT_ID" in
            9304)           MMI_VARIANT="MMI3G_BASIC" ;;
            9308)           MMI_VARIANT="MMI3G_HIGH" ;;
            9411|9436|9478) MMI_VARIANT="MMI3GP" ;;
            *)              MMI_VARIANT="UNKNOWN" ;;
        esac
        break
    done
fi

# -------- Train name (3G+ only populates sw_trainname.txt) --------
MMI_TRAIN="n/a"
if [ -f /dev/shmem/sw_trainname.txt ]; then
    T="$(cat /dev/shmem/sw_trainname.txt 2>/dev/null)"
    [ -n "$T" ] && MMI_TRAIN="$T"
fi
# Basic/High fallback — DrGER2's sloginfo method
if [ "$MMI_TRAIN" = "n/a" ]; then
    T="$(sloginfo -m 10000 -s 5 2>/dev/null | sed -n 's/^.* +++ Train //p' | sed -n 1p)"
    [ -n "$T" ] && MMI_TRAIN="$T"
fi

# -------- RNS-850 disambiguation --------
# RNS-850 has the "_VW_" infix (e.g. HN+_US_VW_K0711).
# A 9411 unit without _VW_ is a regular A4/A5/A6/A7/A8/Q5/Q7 MMI 3G+;
# 9436 is the A1 8X variant (smaller/cheaper hardware, same MMI 3G+ class);
# 9478 is the VW RNS-850 variant.
if [ "$MMI_VARIANT" = "MMI3GP" ] && echo "$MMI_TRAIN" | grep -q "_VW_"; then
    MMI_VARIANT="RNS850"
fi

# -------- Other identification sources --------
MMI_SW_VERSION="n/a"
if [ -f /etc/version/MainUnit-version.txt ]; then
    V="$(sed -n 's/^version = //p' /etc/version/MainUnit-version.txt 2>/dev/null | head -1)"
    [ -n "$V" ] && MMI_SW_VERSION="$V"
fi

MMI_HW_SAMPLE="n/a"
if [ -f /etc/hwSample ]; then
    H="$(cat /etc/hwSample 2>/dev/null)"
    [ -n "$H" ] && MMI_HW_SAMPLE="$H"
fi

# -------- Time helpers --------
# DrGER2: QNX `date` returns time-since-boot until the CAN gateway
# delivers wall-clock. `getTime` (Harman-Becker binary) returns the
# real current time provided by the vehicle.
mmi_getTime() {
    if command -v getTime >/dev/null 2>&1; then
        getTime 2>/dev/null
    else
        date +%s 2>/dev/null
    fi
}

# Filename-safe timestamp. Uses getTime when available, falling back
# to date-formatted output. Format is always YYYYMMDD-HHMMSS so log
# filenames sort correctly regardless of source.
mmi_logstamp() {
    # Prefer getTime (epoch seconds) and format with date -r if possible
    if command -v getTime >/dev/null 2>&1; then
        T="$(getTime 2>/dev/null)"
        if [ -n "$T" ]; then
            # Try date -r (BSD/QNX) to format the epoch value
            if date -r "$T" +%Y%m%d-%H%M%S 2>/dev/null; then
                return 0
            fi
            # Last resort: emit the raw epoch seconds (still uniquely sortable)
            echo "epoch-$T"
            return 0
        fi
    fi
    # Fall through: QNX date (may be since-boot on a cold MMI)
    date +%Y%m%d-%H%M%S 2>/dev/null
}

# Reclaim interlock helpers. mmi3g-flashctl runs F3S garbage collection
# every 5 min against /HBpersistence; the /tmp/disableReclaim flag file
# blocks it. Toolkit scripts that do multi-write operations against
# /HBpersistence or /mnt/efs-system should call mmi_reclaim_hold at the
# start of their critical section and rely on the EXIT trap to release
# it. See research/F3S_FORMAT.md for details.
#
# Usage:
#   mmi_reclaim_hold          # set flag + install trap
#   ... critical writes ...
#   mmi_reclaim_release       # optional early release before exit
#
# The trap handles the normal exit path, Ctrl-C, and SIGTERM. If a
# script forgets to call release explicitly, the flag is still cleared
# on script exit.
mmi_reclaim_hold() {
    touch /tmp/disableReclaim 2>/dev/null
    trap 'rm -f /tmp/disableReclaim 2>/dev/null' EXIT INT TERM
}

mmi_reclaim_release() {
    rm -f /tmp/disableReclaim 2>/dev/null
}
