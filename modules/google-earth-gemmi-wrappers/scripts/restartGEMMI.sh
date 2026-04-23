#!/bin/ksh

TARGET="/mnt/nav/gemmi"
RUN="${TARGET}/run_gemmi.sh"

if [ `pidin arg 2>/dev/null | grep -c gemmi_final` -gt 1 ]; then
    echo "Restart GEMMI (volatile)"
    slay -s KILL gemmi_final
    sleep 1
    if [ -x "${RUN}" ]; then
        ksh "${RUN}" > /dev/ser1 2> /dev/ser1 &
    fi
    echo "done."
else
    if [ -x "${RUN}" ]; then
        echo "GEMMI not running, starting it instead"
        ksh "${RUN}" > /dev/ser1 2> /dev/ser1 &
        echo "done."
    else
        echo "GEMMI not running!"
        echo "doing nothing."
    fi
fi
