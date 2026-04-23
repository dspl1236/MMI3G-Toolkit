#!/bin/ksh

TARGET="/mnt/nav/gemmi"
if [ -x "${TARGET}/run_gemmi.sh" ]; then
    echo "Deactivate GEMMI (persistent)"
    mount -uw /mnt/nav 2>/dev/null
    mv "${TARGET}/run_gemmi.sh" "${TARGET}/run_gemmi.stop"
    echo "done."
elif [ -x "${TARGET}/run_gemmi.stop" ]; then
    echo "GEMMI already deactivated!"
    echo "doing nothing."
else
    echo "GEMMI not installed!"
    echo "doing nothing."
fi
