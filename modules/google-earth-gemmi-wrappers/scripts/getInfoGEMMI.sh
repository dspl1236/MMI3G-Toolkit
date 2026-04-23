#!/bin/ksh

TARGET="/mnt/nav/gemmi/gemmi_final"

if [ -x "${TARGET}" ]; then
    echo "Get Info GEMMI"
    if command -v use >/dev/null 2>&1; then
        use "${TARGET}"
    else
        ls -la "${TARGET}"
    fi
    echo "done."
else
    echo "GEMMI not installed!"
    echo "doing nothing."
fi

echo "---------------------------------------"
echo "Connectivity Status:"
echo "---------------------------------------"
echo "Content of _CS_RESOLVE"
getconf _CS_RESOLVE 2>/dev/null

if [ -f /etc/resolv.conf ]; then
    echo "Content of /etc/resolv.conf:"
    cat /etc/resolv.conf
else
    echo "/etc/resolv.conf is not set"
fi
