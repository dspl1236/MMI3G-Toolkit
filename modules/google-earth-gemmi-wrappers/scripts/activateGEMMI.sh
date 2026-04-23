#!/bin/ksh

TARGET="/mnt/nav/gemmi"
if [ -x "${TARGET}/run_gemmi.sh" ]; then
    echo "GEMMI already active!"
    echo "doing nothing."
elif [ -x "${TARGET}/run_gemmi.stop" ]; then
    echo "Activate GEMMI (persistent)"
    mount -uw /mnt/nav 2>/dev/null
    mv "${TARGET}/run_gemmi.stop" "${TARGET}/run_gemmi.sh"
    chmod +x "${TARGET}/run_gemmi.sh" 2>/dev/null
    echo "done."
else
    echo "GEMMI not installed!"
    echo "doing nothing."
fi
