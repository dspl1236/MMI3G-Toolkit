#!/bin/ksh
# Phase 7.6: the start-up launcher. sta-install.sh hook installs it as
# /mnt/efs-persist/wifi-sta-boot.sh and adds a marked block to the factory
# /mnt/efs-system/lsd/lsd.sh that runs it in the background, so the HMI's
# start-up never waits for it. It waits for the HDD, then runs sta-boot.sh,
# which decides from the GEM's marker whether to start the station. See
# docs/wifi-client/wifi-client-mode.md, "Station mode at start-up (7.6)".
trap '' 1
umask 077
PATH=/bin:/sbin:/usr/bin:/usr/sbin
export PATH
unset LD_PRELOAD || :

boot=/mnt/persistence/wifi-sta/sta-boot.sh
limit=180

waited=0
until [ -f "$boot" ]; do
    if [ "$waited" -ge "$limit" ]; then
        echo "wifi-sta: no $boot after ${limit}s (no HDD, or the station files are removed)."
        exit 0
    fi
    sleep 5
    waited=$((waited + 5))
done
exec /bin/ksh "$boot"
