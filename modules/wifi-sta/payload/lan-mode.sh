#!/bin/ksh
# Phase 7.1: the factory LAN mode. The empty file
# /HBpersistence/DLinkReplacesPPP makes the HMI's online applications treat
# the connection as established (read once, at start-up) and makes the
# factory dhcp-up keep a lease's default route and point the internal DNS at
# its name servers. See docs/wifi-client/wifi-client-mode.md, "Phase 7 plan".
#
#   status           the flag, who set it, the default route, resolv.conf
#   snapshot <dir>   read-only capture of routes, NAT and DNS-redirect
#                    anchors, resolver, DHCP processes and interfaces
#   enable           set the flag; refuses a flag this script did not set
#   disable          remove the flag it set, and a resolv.conf that was not
#                    there before (or put the earlier one back)
#
# enable and disable change persistent storage: the flag, and this script's
# own record in /mnt/efs-persist/lan-mode. Neither takes effect for the HMI
# until the unit restarts; routes and pf anchors already set stay until then.
# Exit: 0 done, 1 usage, 2 refused or failed.
set -u
umask 077
PATH=/bin:/sbin:/usr/bin:/usr/sbin
export PATH
unset LD_PRELOAD || :

flag=/HBpersistence/DLinkReplacesPPP
flag_dir=/HBpersistence
rse_marker=/mnt/efs-system/RSE
dhcp_up=/etc/dhcp/dhcp-up
dhcp_up_sum='3046797907 6292'
resolv_conf=/etc/resolv.conf
state=/mnt/efs-persist/lan-mode
owner=$state/owner
min_free_kb=64

usage() {
    echo "usage: lan-mode.sh status | snapshot <dir> | enable | disable" >&2
    exit 1
}

say() {
    echo "lan-mode: $*"
    [ -d "$state" ] && echo "$(date) $*" >> "$state/log" 2>/dev/null
    return 0
}

fail() {
    say "FAIL: $*"
    exit 2
}

# bounded <seconds> <output> <command...>: run it, stop it at the limit.
bounded() {
    bounded_limit=$1
    bounded_out=$2
    shift 2
    "$@" > "$bounded_out" 2>&1 &
    bounded_pid=$!
    bounded_waited=0
    while kill -0 "$bounded_pid" 2>/dev/null; do
        if [ "$bounded_waited" -ge "$bounded_limit" ]; then
            kill "$bounded_pid" 2>/dev/null
            sleep 1
            kill -9 "$bounded_pid" 2>/dev/null
            echo "TIMEOUT after ${bounded_limit}s: $*" >> "$bounded_out"
            return 1
        fi
        sleep 1
        bounded_waited=$((bounded_waited + 1))
    done
    wait "$bounded_pid"
}

sum_of() {
    cksum "$1" 2>/dev/null | { read -r a b rest && echo "$a $b"; }
}

# Free kilobytes on the filesystem holding directory $1. QNX df -k prints the
# one filesystem without a header; the fourth field is what is available.
# /HBpersistence is a symlink to /mnt/efs-persist/: given the link, df says
# "Block device required"; given "link/", it prints the filesystem's line and
# then that error, so take the device line.
free_kb() {
    df -k "$1/" 2>/dev/null | grep '^/dev/' | sed -n 1p |
        { read -r fs total used avail rest && echo "$avail"; }
}

default_route() {
    netstat -rn 2>/dev/null | grep '^default' || echo "no default route"
}

status() {
    if [ -f "$flag" ]; then
        if [ -f "$owner" ]; then
            say "flag present, set by this script: $(sed -n 1p "$owner")"
        else
            say "flag present, NOT set by this script"
        fi
    else
        say "flag absent"
    fi
    say "default route: $(default_route)"
    if [ -f "$resolv_conf" ]; then
        say "resolv.conf: $(sum_of "$resolv_conf")"
        sed 's/^/lan-mode:   /' "$resolv_conf"
    else
        say "resolv.conf: absent"
    fi
}

snapshot() {
    dir=$1
    [ -d "$dir" ] || mkdir "$dir" || fail "cannot create $dir"
    {
        echo "date: $(date)"
        if [ -f "$flag" ]; then ls -l "$flag"; else echo "flag: absent"; fi
        if [ -f "$owner" ]; then echo "owner: $(sed -n 1p "$owner")"; else echo "owner: none"; fi
        echo "dhcp-up: $(sum_of "$dhcp_up")"
        if [ -f "$resolv_conf" ]; then
            echo "resolv.conf: $(sum_of "$resolv_conf")"
            cat "$resolv_conf"
        else
            echo "resolv.conf: absent"
        fi
    } > "$dir/summary.txt" 2>&1
    rc=0
    bounded 10 "$dir/pidin-info.txt" pidin info || rc=2
    bounded 10 "$dir/routes.txt" netstat -rn || rc=2
    bounded 10 "$dir/nat.txt" pfctl -sn || rc=2
    for n in 1 2 3 4; do
        bounded 10 "$dir/anchor-dnsRedirect$n.txt" pfctl -a "dnsRedirect$n" -sn || rc=2
    done
    bounded 10 "$dir/cs-resolve.txt" getconf _CS_RESOLVE || rc=2
    bounded 10 "$dir/ifconfig.txt" ifconfig -a || rc=2
    if bounded 20 "$dir/pidin-args.txt" pidin -f aA; then
        grep -e dhcp -e ifwatchd "$dir/pidin-args.txt" > "$dir/dhcp-procs.txt"
    else
        rc=2
    fi
    rm -f "$dir/pidin-args.txt"
    if [ "$rc" = 0 ]; then
        say "snapshot in $dir: complete"
    else
        say "snapshot in $dir: PARTIAL (a read failed or timed out; see its file)"
    fi
    return "$rc"
}

enable() {
    if [ -f "$flag" ]; then
        [ -f "$owner" ] || fail "$flag exists and was not set by this script; leaving it"
        say "already enabled by this script: $(sed -n 1p "$owner")"
        return 0
    fi
    [ -d "$flag_dir" ] || fail "$flag_dir is missing"
    [ "$(sum_of "$dhcp_up")" = "$dhcp_up_sum" ] ||
        fail "dhcp-up is not the reviewed copy ($dhcp_up_sum): $(sum_of "$dhcp_up")"
    [ -e "$rse_marker" ] && fail "$rse_marker exists: dhcp-up would take its RSE branch"
    free=$(free_kb "$flag_dir")
    case $free in
        ''|*[!0-9]*) fail "cannot read the free space of $flag_dir" ;;
    esac
    [ "$free" -ge "$min_free_kb" ] || fail "$flag_dir has only ${free} KB free"
    [ -d "$state" ] || mkdir "$state" || fail "cannot create $state"
    rm -f "$state/resolv.baseline" "$state/resolv.state"
    if [ -f "$resolv_conf" ]; then
        cp "$resolv_conf" "$state/resolv.baseline" &&
            [ "$(sum_of "$state/resolv.baseline")" = "$(sum_of "$resolv_conf")" ] ||
            fail "cannot keep a copy of $resolv_conf"
        echo present > "$state/resolv.state"
    else
        echo absent > "$state/resolv.state"
    fi
    echo "set $(date)" > "$owner" || fail "cannot write $owner"
    if ! touch "$flag" || [ ! -f "$flag" ] || [ -s "$flag" ]; then
        rm -f "$owner"
        [ -f "$flag" ] && [ ! -s "$flag" ] && rm -f "$flag"
        fail "could not create an empty $flag"
    fi
    say "flag set; resolv.conf was $(cat "$state/resolv.state") before. Restart the unit for the HMI to read it."
}

disable() {
    if [ ! -f "$owner" ]; then
        [ -f "$flag" ] && fail "$flag was not set by this script; leaving it"
        say "not enabled"
        return 0
    fi
    rm -f "$flag"
    [ -f "$flag" ] && fail "could not remove $flag"
    case $(cat "$state/resolv.state" 2>/dev/null) in
        absent)
            if [ -f "$resolv_conf" ]; then
                # QNX date has no +%s; number the copies instead.
                n=1
                while [ -e "$state/resolv.lan-mode.$n" ]; do n=$((n + 1)); done
                kept=$state/resolv.lan-mode.$n
                cp "$resolv_conf" "$kept" 2>/dev/null
                rm -f "$resolv_conf"
                [ -f "$resolv_conf" ] && fail "could not remove $resolv_conf"
                say "removed $resolv_conf, absent before (copy: $kept)"
            fi ;;
        present)
            if [ "$(sum_of "$resolv_conf")" != "$(sum_of "$state/resolv.baseline")" ]; then
                cp "$state/resolv.baseline" "$resolv_conf" &&
                    [ "$(sum_of "$resolv_conf")" = "$(sum_of "$state/resolv.baseline")" ] ||
                    fail "could not put the earlier $resolv_conf back"
                say "put the earlier $resolv_conf back"
            fi ;;
        *)
            say "no record of resolv.conf before; left it as it is" ;;
    esac
    rm -f "$owner"
    say "flag removed. Restart the unit; routes and pf anchors set in LAN mode stay until then."
}

[ $# -ge 1 ] || usage
case $1 in
    status) [ $# = 1 ] || usage; status ;;
    snapshot) [ $# = 2 ] || usage; snapshot "$2" ;;
    enable) [ $# = 1 ] || usage; enable ;;
    disable) [ $# = 1 ] || usage; disable ;;
    *) usage ;;
esac
