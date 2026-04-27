#!/bin/ksh
# ============================================================
# MMI3G Game Loader - Installer
# Installs game launcher scripts and GEM menu to flash
# Games themselves stay on the SD card
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

SDPATH="${1:-${0%/*}}"
LOGFILE="${SDPATH}/var/game-install-$(mmi_logstamp).log"
EFSDIR="/mnt/efs-system"
ENGDEFS="${EFSDIR}/engdefs"
SCRIPTDIR="${EFSDIR}/scripts/Games"

exec > ${LOGFILE} 2>&1

echo "============================================"
echo " MMI3G Game Loader - Installer"
echo " $(date)"
echo "============================================"
echo ""

if [ ! -d "${ENGDEFS}" ]; then
    echo "[ERROR] engdefs not found. Enable GEM first!"
    exit 1
fi

# Hold F3S reclaim for the duration of this script (see research/F3S_FORMAT.md)
# Guarded: if platform.sh provided it, use it; otherwise inline the minimum.
if command -v mmi_reclaim_hold >/dev/null 2>&1; then
    mmi_reclaim_hold
else
    touch /tmp/disableReclaim 2>/dev/null
    trap 'rm -f /tmp/disableReclaim 2>/dev/null' EXIT INT TERM
fi

mount -uw ${EFSDIR}
mkdir -p ${SCRIPTDIR}

# Install launcher script to flash
cp -v "${SDPATH}/scripts/launch_game.sh" "${SCRIPTDIR}/launch_game.sh"
chmod +x "${SCRIPTDIR}/launch_game.sh"
echo "[INST]  launch_game.sh"

# Install game list scanner
cp -v "${SDPATH}/scripts/game_loader.sh" "${SCRIPTDIR}/game_loader.sh"
chmod +x "${SCRIPTDIR}/game_loader.sh"
echo "[INST]  game_loader.sh"

# Install GEM screen
if [ -d "${SDPATH}/engdefs" ]; then
    for esd in ${SDPATH}/engdefs/Games*.esd; do
        if [ -f "$esd" ]; then
            BASENAME=$(basename $esd)
            cp -v "$esd" "${ENGDEFS}/${BASENAME}"
            echo "[INST]  $BASENAME"
        fi
    done
fi

sync

# Scan for games on all SD cards
GAME_COUNT=0
for d in /mnt/sdcard10t12 /mnt/sdcard20t12 /mnt/sdcard10t11 /mnt/sdcard20t11; do
    if [ -d "$d/games" ]; then
        for g in $d/games/*/game.jar; do
            [ -f "$g" ] && GAME_COUNT=$((GAME_COUNT + 1))
        done
    fi
done

echo ""
echo "============================================"
echo " Game Loader Installed!"
echo ""
echo " Games found on SD cards: $GAME_COUNT"
echo ""
echo " HOW TO ADD GAMES:"
echo "   1. Create /games/<name>/ on your SD card"
echo "   2. Put game.jar in that folder"
echo "   3. Create game.manifest with:"
echo "      main=com.example.MainClass"
echo "      name=My Game"
echo "   4. Open GEM > /games > select your game"
echo ""
echo " SD Slot 1: toolkit & modules"
echo " SD Slot 2: games library!"
echo ""
echo " COMPATIBLE GAMES:"
echo "   - Java 1.4/1.5 console games"
echo "   - Text adventures, roguelikes"
echo "   - Simple graphical games using stdout"
echo "   - Custom J9-compatible games"
echo "============================================"
