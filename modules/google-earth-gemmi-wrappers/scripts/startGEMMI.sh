#!/bin/ksh

TARGET="/mnt/nav/gemmi"
RUN="${TARGET}/run_gemmi.sh"

if [ `pidin arg 2>/dev/null | grep -c gemmi_final` -gt 1 ]; then
    echo "GEMMI already running!"
    echo "doing nothing."
else
    if [ -x "${RUN}" ]; then
        echo "Start GEMMI (volatile)"
        ksh "${RUN}" > /dev/ser1 2> /dev/ser1 &
        echo "done."
    else
        if [ -x "${TARGET}/run_gemmi.stop" ]; then
            echo "Please activate GEMMI first!"
            echo "doing nothing."
        else
            echo "GEMMI not installed!"
            echo "doing nothing."
        fi
    fi
fi
