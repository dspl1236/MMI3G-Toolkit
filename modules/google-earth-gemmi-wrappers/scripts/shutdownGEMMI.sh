#!/bin/ksh

if [ `pidin arg 2>/dev/null | grep -c gemmi_final` -gt 1 ]; then
    echo "Shutdown GEMMI (volatile)"
    slay gemmi_final
    echo "done."
else
    echo "GEMMI not running!"
    echo "doing nothing."
fi
