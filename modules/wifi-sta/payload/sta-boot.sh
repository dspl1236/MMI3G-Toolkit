#!/bin/ksh
# Phase 7.6: start station mode at start-up, when the engineering screen
# (GEM) has chosen it. Installed by sta-install.sh beside sta-mode.sh on the
# HDD, and run in the background by boot-launch.sh, which the start-up block
# that sta-install.sh hook adds to the factory lsd.sh starts. When the
# OpenSSH installation (qnx632-openssh) is there, it waits for that to start
# its jitter-egd and the access point's sshd first, as it did when the OpenSSH
# start-up ran it. See docs/wifi-client/wifi-client-mode.md, "Station mode at
# start-up (7.6)".
#
# It does nothing (the access point stays) unless the GEM's "Start-up:
# hotspot client" button has left its marker, and nothing while the GEM's
# kill switch exists or en5 (the wired adapter, at home) is present. Every
# refusal comes before sta-mode.sh detaches uap0, so it leaves the access
# point. Each run appends to boot.log beside this file, which the GEM's
# "Station status" shows.
set -u
umask 077
PATH=/bin:/sbin:/usr/bin:/usr/sbin
export PATH
unset LD_PRELOAD || :

home=/mnt/persistence/wifi-sta
sums=$home/SUMS
gem=/mnt/efs-persist/wifi-sta/gem
marker=$gem/client-at-start-up
kill_switch=$gem/start.disabled
log_file=$home/boot.log
log_max=32768
run=/fs/tmpfs
# The OpenSSH installation, its kill switch and its RAM state, and how long
# to wait for it: its own launcher gives up within about 215 s of start-up.
openssh=/mnt/persistence/openssh
openssh_disabled=/mnt/efs-persist/openssh.disabled
openssh_run=$run/mmi-openssh
openssh_limit=300
# The factory networking service, the en5 hook and the HMI are still
# starting when the access point and the OpenSSH start-up are up; with this
# wait the detach comes when it did in 7.6, about 2.5 minutes after
# power-on.
settle=60
# How long to wait for the access point's factory address.
uap0_limit=300
ap_address=192.168.1.1

log() {
    echo "$(date '+%H:%M:%S') boot: $*" >> "$log_file" 2>/dev/null
    echo "boot: $*"
    return 0
}

rotate() {
    [ -f "$log_file" ] || return 0
    set -- $(ls -l "$log_file" 2>/dev/null)
    [ "${5:-0}" -le "$log_max" ] 2>/dev/null && return 0
    mv -f "$log_file" "$log_file.old" 2>/dev/null
    return 0
}

sums_ok() {
    [ -s "$sums" ] || { log "no $sums: the station files are not installed"; return 1; }
    sums_bad=0
    while read -r s_sum s_size s_name; do
        [ -n "$s_name" ] || continue
        set -- $(cksum "$home/$s_name" 2>/dev/null) x x
        [ "$1 $2" = "$s_sum $s_size" ] && continue
        log "$s_name does not match its sum"
        sums_bad=1
    done < "$sums"
    [ "$sums_bad" = 0 ]
}

# Both of its services run and its start-up has finished.
openssh_up() {
    for ou_f in sshd.pid entropy.pid; do
        ou_pid=$(cat "$openssh_run/$ou_f" 2>/dev/null)
        [ -n "$ou_pid" ] && kill -0 "$ou_pid" 2>/dev/null || return 1
    done
    [ ! -d "$openssh_run/start.lock" ]
}

trap '' 1
rotate
log "start-up, unit clock $(date '+%H:%M:%S') (uptime)"
if [ ! -f "$marker" ]; then
    log "mode: car access point (no $marker); nothing to do."
    exit 0
fi
if [ -e "$kill_switch" ]; then
    log "the start is disabled ($kill_switch); keeping the access point."
    exit 0
fi
log "mode: hotspot client."
waited=0
until ifconfig uap0 2>/dev/null | grep -q "inet $ap_address "; do
    if [ "$waited" -ge "$uap0_limit" ]; then
        log "uap0 has no $ap_address after ${uap0_limit}s; not starting."
        exit 0
    fi
    sleep 5
    waited=$((waited + 5))
done
if [ -f "$openssh/INSTALL_READY" ] && [ ! -e "$openssh_disabled" ]; then
    waited=0
    until openssh_up; do
        if [ "$waited" -ge "$openssh_limit" ]; then
            log "OpenSSH is not up after ${openssh_limit}s; starting without it."
            break
        fi
        sleep 5
        waited=$((waited + 5))
    done
    [ "$waited" -ge "$openssh_limit" ] || log "OpenSSH is up (waited ${waited}s)."
fi
log "waiting ${settle}s for the start-up to settle."
sleep "$settle"
if ifconfig en5 > /dev/null 2>&1; then
    log "en5 is present (wired, at home); keeping the access point."
    exit 0
fi
[ ! -e "$kill_switch" ] && [ -f "$marker" ] ||
    { log "the mode changed while waiting; not starting."; exit 0; }
sums_ok || { log "not starting."; exit 0; }
out=$run/wifi-sta-boot.start
log "starting the station (sta-mode.sh start)."
/bin/ksh "$home/sta-mode.sh" start < /dev/null > "$out" 2>&1
rc=$?
sed -e 's/^/    /' "$out" >> "$log_file" 2>/dev/null
log "sta-mode.sh start exit $rc (0 OK, 2 refused or FAIL, 3 PARTIAL)."
exit 0
