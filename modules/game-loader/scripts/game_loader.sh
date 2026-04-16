#!/bin/ksh
# ============================================================
# MMI3G Game Loader
# Launches Java games from SD card on the J9 JVM
# ============================================================
#
# HOW IT WORKS:
# The MMI's J9 JVM can run arbitrary Java classes using
# lsd.jxe as the bootclasspath (contains the full Java runtime).
# Credit: romangarms (Java-on-Audi-MMI-3G) for discovering this.
#
# Games are stored as JAR files in /games/ on the SD card.
# Each game has a .manifest file that specifies:
#   - Main class name
#   - Display name (shown in GEM menu)
#   - Input mapping (knob, softkeys)
#
# The GEM screen lists available games. Selecting one launches
# j9 with the game JAR on the classpath. The game takes over
# the display until it exits, then the GEM returns.
#
# GAME REQUIREMENTS:
# - Java 1.4/1.5 compatible (no generics, no annotations)
# - No AWT/Swing (not available on J9)
# - Display: Use stdout for GEM console, or use HB display
#   framework from lsd.jxe bootclasspath
# - Input: Read from stdin or use the HB input framework
# - Max heap: ~13MB (-Xmx13312k)
#
# SD CARD LAYOUT:
# /games/
#   doom/
#     game.jar          - The game JAR
#     game.manifest     - Config (main class, name, args)
#     *.wad             - Game data files (if needed)
#   snake/
#     game.jar
#     game.manifest
#   tetris/
#     game.jar
#     game.manifest
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

SDPATH="${1:-$(dirname $0)/..}"
GAME_DIR="${SDPATH}/games"
LOGFILE="${SDPATH}/var/game-loader-$(mmi_logstamp).log"

# J9 JVM location
J9="/j9/bin/j9"
JXE="/mnt/ifs-root/lsd/lsd.jxe"

# Alternate J9 locations (some firmware versions differ)
[ ! -x "$J9" ] && J9="/mnt/ifs-root/j9/bin/j9"

mkdir -p "${SDPATH}/var"

exec > ${LOGFILE} 2>&1

echo "============================================"
echo " MMI3G Game Loader"
echo " $(date)"
echo "============================================"
echo ""

# Verify J9 is available
if [ ! -x "$J9" ]; then
    echo "[ERROR] J9 JVM not found at $J9"
    echo "[ERROR] Trying to locate j9..."
    J9=$(find /j9 /mnt/ifs-root -name "j9" -type f 2>/dev/null | head -1)
    if [ -z "$J9" ]; then
        echo "[ERROR] J9 JVM not found anywhere!"
        exit 1
    fi
    echo "[INFO]  Found J9 at: $J9"
fi

# Verify lsd.jxe is available
if [ ! -f "$JXE" ]; then
    JXE="/lsd/lsd.jxe"
    [ ! -f "$JXE" ] && JXE=$(find /mnt -name "lsd.jxe" -type f 2>/dev/null | head -1)
    if [ -z "$JXE" ]; then
        echo "[ERROR] lsd.jxe not found!"
        exit 1
    fi
fi

echo "[INFO]  J9: $J9"
echo "[INFO]  JXE: $JXE"
echo ""

# Check what games are available
if [ ! -d "$GAME_DIR" ]; then
    echo "[ERROR] No games directory found at $GAME_DIR"
    exit 1
fi

echo "[INFO]  Scanning for games in $GAME_DIR..."
GAME_COUNT=0

for GAMEPATH in ${GAME_DIR}/*/; do
    GAMENAME=$(basename $GAMEPATH)
    MANIFEST="${GAMEPATH}/game.manifest"
    JARFILE="${GAMEPATH}/game.jar"
    
    if [ -f "$JARFILE" ]; then
        GAME_COUNT=$((GAME_COUNT + 1))
        
        # Read manifest if present
        MAINCLASS=""
        DISPLAYNAME="$GAMENAME"
        EXTRA_ARGS=""
        
        if [ -f "$MANIFEST" ]; then
            MAINCLASS=$(grep "^main=" "$MANIFEST" | cut -d= -f2)
            DISPLAYNAME=$(grep "^name=" "$MANIFEST" | cut -d= -f2)
            EXTRA_ARGS=$(grep "^args=" "$MANIFEST" | cut -d= -f2)
        fi
        
        echo "[GAME]  $GAME_COUNT: $DISPLAYNAME ($GAMENAME)"
        echo "        JAR: $JARFILE"
        echo "        Main: ${MAINCLASS:-auto-detect}"
        echo "        Args: ${EXTRA_ARGS:-none}"
    fi
done

echo ""
echo "[INFO]  Found $GAME_COUNT games"
echo "============================================"
