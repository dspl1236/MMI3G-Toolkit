#!/bin/ksh
# MMI3G-Toolkit Uninstaller
# Removes all toolkit-installed GEM screens and scripts

EFSDIR="/mnt/efs-system"
ENGDEFS="${EFSDIR}/engdefs"

echo "MMI3G-Toolkit Uninstaller"
echo "========================="

mount -uw ${EFSDIR}

echo "Removing toolkit GEM screens..."
for f in Gauges*.esd SystemInfo*.esd; do
    if [ -f "${ENGDEFS}/${f}" ]; then
        rm -v "${ENGDEFS}/${f}"
    fi
done

echo "Removing toolkit scripts..."
for d in Gauges SystemInfo; do
    if [ -d "${EFSDIR}/scripts/${d}" ]; then
        rm -rf "${EFSDIR}/scripts/${d}"
        echo "  Removed /scripts/${d}"
    fi
done

sync
echo ""
echo "Done. Reboot MMI (MENU + knob + upper-right soft key)"
