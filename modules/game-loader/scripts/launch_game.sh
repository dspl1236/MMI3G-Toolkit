#!/bin/ksh
# ============================================================
# MMI3G Game Launcher
# Launches a specific game JAR on the J9 JVM
#
# Usage: launch_game.sh <game_dir_name>
#
# Called from GEM script buttons. The game takes over the
# display. When the game exits, the GEM console returns.
#
# The J9 process runs in the foreground so the GEM console
# shows any stdout/stderr output from the game.
# ============================================================

GAMENAME="$1"

# Find SD card
SDCARD=""
for d in /mnt/sdcard10t12 /mnt/sdcard20t12 /mnt/sdcard10t11 /mnt/sdcard20t11; do
    [ -d "$d/games/$GAMENAME" ] && SDCARD="$d" && break
done
[ -z "$SDCARD" ] && echo "Game not found: $GAMENAME" && exit 1

GAMEPATH="${SDCARD}/games/${GAMENAME}"
JARFILE="${GAMEPATH}/game.jar"
MANIFEST="${GAMEPATH}/game.manifest"

# J9 JVM
J9="/j9/bin/j9"
JXE="/mnt/ifs-root/lsd/lsd.jxe"
[ ! -x "$J9" ] && J9="/mnt/ifs-root/j9/bin/j9"

# Read manifest
MAINCLASS=""
EXTRA_ARGS=""
EXTRA_CP=""
VMARGS=""

if [ -f "$MANIFEST" ]; then
    MAINCLASS=$(grep "^main=" "$MANIFEST" | cut -d= -f2)
    EXTRA_ARGS=$(grep "^args=" "$MANIFEST" | cut -d= -f2)
    EXTRA_CP=$(grep "^classpath=" "$MANIFEST" | cut -d= -f2)
    VMARGS=$(grep "^vmargs=" "$MANIFEST" | cut -d= -f2)
fi

# If no main class specified, try to read from JAR manifest
if [ -z "$MAINCLASS" ]; then
    echo "Error: No main class specified in game.manifest"
    echo "Add: main=com.example.GameMain"
    exit 1
fi

# Build classpath
CP="${JARFILE}"
if [ -n "$EXTRA_CP" ]; then
    CP="${CP}:${GAMEPATH}/${EXTRA_CP}"
fi

# Set library path (for any native libs the game might use)
export LD_LIBRARY_PATH="${GAMEPATH}:/j9/bin:/lib:/usr/lib"

echo "============================================"
echo " Launching: $GAMENAME"
echo " Main: $MAINCLASS"
echo " JAR: $JARFILE"
echo "============================================"
echo ""
echo " Controls:"
echo "   Rotary knob = navigate/select"
echo "   Soft keys = action buttons"
echo "   BACK = exit game"
echo ""
echo " Starting in 2 seconds..."
sleep 2

# Launch the game
# -Xbootclasspath provides the Java runtime from lsd.jxe
# -cp provides the game JAR
# Working directory is set to the game folder for data files
cd "${GAMEPATH}"
$J9 \
    -Xbootclasspath:${JXE} \
    -cp ${CP} \
    -Xmx8192k \
    ${VMARGS} \
    ${MAINCLASS} ${EXTRA_ARGS}

EXITCODE=$?
echo ""
echo "============================================"
echo " Game exited with code: $EXITCODE"
echo " Returning to GEM..."
echo "============================================"
