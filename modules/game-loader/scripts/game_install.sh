#!/bin/ksh
# ============================================================
# MMI3G Game Loader - Installer
# Installs game launcher scripts and GEM menu to flash
# Games themselves stay on the SD card
# ============================================================

SDPATH="${1:-$(dirname $0)}"
LOGFILE="${SDPATH}/var/game-install-$(date +%Y%m%d-%H%M%S).log"
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
