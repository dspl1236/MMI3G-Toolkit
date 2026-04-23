#!/bin/sh

if [[ -f /tmp/run_gemmi_count ]]
then
    echo "[DEBUG GEMMI] Removing /tmp/run_gemmi_count"
    rm /tmp/run_gemmi_count
fi

./run_gemmi.sh

