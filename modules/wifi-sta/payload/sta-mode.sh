#!/bin/ksh
# Phase 7.3: the mode switch. Replaces the factory access point with the
# station on the owner's phone hotspot until the next restart, in the factory
# LAN mode, with SSH from the hotspot as the way in. Everything it writes lives
# in RAM (/fs/tmpfs) except what the factory dhcp-up writes for every lease
# (/etc/resolv.conf); nothing is installed and nothing starts at start-up.
# See docs/wifi-client/wifi-client-mode.md, "The mode switch (7.3)".
#
#   start [-n] [-r dir] [-c config]
#         check, then detach uap0 and bring the station up in the background;
#         follow its log until it reports OK, PARTIAL or FAIL. -n checks
#         only. dir holds the station files (default: this script's
#         directory); config is the hotspot's wpa_supplicant configuration
#         (root, mode 600; default dir/wpa-hotspot.conf). A second start
#         only reports the status.
#   status
#         what is up, and OK, PARTIAL or FAIL.
#   stop  take the station down and re-mount the factory driver. The access
#         point has no SSID after that: a restart is what brings it back.
#
# After the start, a keeper stays in the background until the restart (or a
# stop). Every 10 s it restarts wpa_supplicant or dhcp.client if one has
# exited, and keeps an sshd and the en6 SSH rule bound to the current lease.
# The sshd is the OpenSSH installation's (qnx632-openssh) and runs only while
# that installation is running; without it the station has no SSH. The
# supplicant's random source, jitter-egd, is that installation's when it
# runs; otherwise the start runs the copy beside the station files, which
# stays until the restart.
# It never touches uap0: there is no restore watchdog, and a failure after
# the detach leaves no access point until the restart.
#
# start and stop run their work detached from the session (HUP ignored), so
# a session that arrives on uap0 (start) or on en6 (stop) may drop midway
# while the work goes on; read the outcome with status from a new session.
# Exit: 0 OK (status: also "not started"), 1 usage, 2 refused or FAIL,
# 3 PARTIAL.
set -u
umask 077
PATH=/bin:/sbin:/usr/bin:/usr/sbin
export PATH
# The factory boot environment preloads libmc.so, which creates a second
# thread; QNX 6.3.2 cannot fork a multithreaded sshd. Keep it out of
# everything this script starts.
unset LD_PRELOAD || :
LD_LIBRARY_PATH=/lib:/lib/dll:/usr/lib:/usr/lib/dll:/proc/boot
export LD_LIBRARY_PATH

shell=/bin/ksh
state=/fs/tmpfs/mmi-sta
lock=$state/lock
log_file=$state/log
driver=/lib/dll/devnp-mv8688uap.so
driver_sum='1022510863 93538'
mount_base='irq=13,dma=0x104,clock=25M'
firmware_path=/lib/dll
ap_address=192.168.1.1
ap_netmask=255.255.255.0
sta_if=en6
sta_lan=6
pf_label=mmi_sta_en6
ssh_label=mmi_sta_ssh
ssh_port=2222
sshd=/mnt/ssh/sbin/sshd
sshd_template=/mnt/ssh/etc/sshd_config
passwd_file=/etc/passwd
# The EGD port wpa_supplicant reads its random bytes from, and how long a
# jitter-egd may take to report ready (as the OpenSSH start-up allows).
egd_port=708
egd_limit=65
dhcp_client=/usr/sbin/dhcp.client
dhcp_client_sum='263280565 57048'
dhcp_up=/etc/dhcp/dhcp-up
dhcp_up_sum='3046797907 6292'
resolv_conf=/etc/resolv.conf
dlink_marker=/HBpersistence/DLinkReplacesPPP
rse_marker=/mnt/efs-system/RSE
# dhcp-up's fallback when a lease names one server or none.
fallback_dns=134.60.1.111
nat_rule="nat on $sta_if from <natRangeTable> to any -> ($sta_if) round-robin"
# The keeper's tick, and how many ticks the start waits for a full result.
tick=10
start_ticks=12
follow_limit=300

case $0 in
    /*) self=$0;;
    *) self=$(pwd)/$0;;
esac

usage() {
    echo "usage: ${self##*/} start [-n] [-r dir] [-c config] | status | stop" >&2
    exit 1
}

# --- shared helpers -------------------------------------------------------------
# The unit has no calendar time: its clock counts from the epoch at start-up.
log() {
    echo "$(date '+%H:%M:%S') sta: $*" >> "$log_file"
    return 0
}
say() {
    echo "sta: $*"
}
refuse() {
    echo "sta: $*" >&2
    exit 2
}

# Diagnostics on this unit can hang (pidin on some processes does).
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
            sleep 3
            kill -9 "$bounded_pid" 2>/dev/null
            echo "TIMEOUT after ${bounded_limit}s: $*" >> "$bounded_out"
            return 1
        fi
        sleep 1
        bounded_waited=$((bounded_waited + 1))
    done
    wait "$bounded_pid"
}

interface_present() {
    ifconfig "$1" > /dev/null 2>&1
}
wait_gone() {
    waited=0
    while interface_present "$2"; do
        [ "$waited" -lt "$1" ] || return 1
        sleep 1
        waited=$((waited + 1))
    done
    return 0
}
wait_present() {
    waited=0
    until interface_present "$2"; do
        [ "$waited" -lt "$1" ] || return 1
        sleep 1
        waited=$((waited + 1))
    done
    return 0
}
sum_of() {
    set -- $(cksum "$1" 2>/dev/null)
    echo "${1-} ${2-}"
}
# A pid file's process is still running.
alive() {
    alive_pid=$(cat "$1" 2>/dev/null)
    [ -n "$alive_pid" ] && kill -0 "$alive_pid" 2>/dev/null
}

# en6's address and the prefix length of its netmask ("addr bits"), or
# nothing while it has none. QNX ifconfig prints the mask in hex; while the
# client negotiates, it holds 0.0.0.0.
mask_bits() {
    mb_hex=${1#0x}
    [ "${#mb_hex}" = 8 ] || return 1
    mb_bits=0
    while [ -n "$mb_hex" ]; do
        case $mb_hex in
            [fF]*) mb_bits=$((mb_bits + 4));;
            [eE]*) mb_bits=$((mb_bits + 3));;
            [cC]*) mb_bits=$((mb_bits + 2));;
            8*) mb_bits=$((mb_bits + 1));;
            0*) ;;
            *) return 1;;
        esac
        mb_hex=${mb_hex#?}
    done
    echo "$mb_bits"
}
lease_of() {
    bounded 10 "$state/en6.txt" ifconfig "$sta_if" || return 1
    set -- $(sed -n 's/^[ 	]*inet \([0-9.]*\) netmask \(0x[0-9a-fA-F]*\).*/\1 \2/p' \
        "$state/en6.txt" | grep -v '^0\.0\.0\.0 ' | sed -e '1!d')
    [ $# = 2 ] || return 1
    lo_bits=$(mask_bits "$2") || return 1
    echo "$1 $lo_bits"
}
# The network address of "addr bits".
network_of() {
    no_bits=$2
    no_rest=$1.
    no_out=
    for no_i in 1 2 3 4; do
        no_oct=${no_rest%%.*}
        no_rest=${no_rest#*.}
        if [ "$no_bits" -ge 8 ]; then
            no_mask=255
            no_bits=$((no_bits - 8))
        else
            case $no_bits in
                0) no_mask=0;; 1) no_mask=128;; 2) no_mask=192;; 3) no_mask=224;;
                4) no_mask=240;; 5) no_mask=248;; 6) no_mask=252;; *) no_mask=254;;
            esac
            no_bits=0
        fi
        no_out=$no_out${no_out:+.}$((no_oct & no_mask))
    done
    echo "$no_out"
}

# Destination, gateway and interface of each route, without the host entries
# the stack clones or learns by ARP (flags c and L).
routes_now() {
    bounded 10 "$state/routes.txt" netstat -rn || return 1
    grep -q '^Destination' "$state/routes.txt" || return 1
    while read -r r_dest r_gw r_flags r_refs r_use r_mtu r_if r_rest; do
        [ -n "$r_if" ] && [ "$r_dest" != Destination ] || continue
        case $r_flags in *[cL]*) continue;; esac
        echo "$r_dest $r_gw $r_if"
    done < "$state/routes.txt" > "$state/routes.keys"
}
default_routes() {
    grep '^default ' "$state/routes.keys"
}
# Exactly one default route, and it is en6's.
station_default_only() {
    [ "$(default_routes | sed -n '$=')" = 1 ] && default_routes | grep -q " $sta_if\$"
}

# The filter rules carry one of two labels. $pf_label: on en6, the DHCP
# server's replies in and everything else blocked, loaded before the
# interface exists. $ssh_label: SSH from the lease's subnet to its address,
# replaced whenever the lease changes. Filter rules only, loaded and checked
# as radio-reattach.sh does, so NAT and states are untouched. Each returns
# non-zero, with the rules as they were, on any failure; pf.err says why.
pf_load() {
    pfctl -n -R -f "$state/pf.next" >> "$state/pf.err" 2>&1 || return 1
    if pfctl -R -f "$state/pf.next" >> "$state/pf.err" 2>&1 &&
            pfctl -sr > "$state/pf.verified" 2>> "$state/pf.err" &&
            [ "$(grep -c "label \"$pf_label\"" "$state/pf.verified")" = "$1" ] &&
            [ "$(grep -c "label \"$ssh_label\"" "$state/pf.verified")" = "$2" ]; then
        return 0
    fi
    echo "loaded rules did not verify; restoring the previous set" >> "$state/pf.err"
    pfctl -R -f "$state/pf.current" >> "$state/pf.err" 2>&1
    return 1
}
sta_pf_enable() {
    : > "$state/pf.err"
    pfctl -sr > "$state/pf.current" 2>> "$state/pf.err" || return 1
    [ "$(grep -c -e "label \"$pf_label\"" -e "label \"$ssh_label\"" "$state/pf.current")" = 0 ] ||
        { echo "rules already present" >> "$state/pf.err"; return 1; }
    [ "$(grep -c '^pass out ' "$state/pf.current")" = 1 ] ||
        { echo "no single 'pass out' rule to insert before" >> "$state/pf.err"; return 1; }
    while IFS= read -r pf_line; do
        case $pf_line in
            'pass out '*)
                echo "pass in quick on $sta_if inet proto udp from any port 67 to any port 68 keep state label \"$pf_label\""
                echo "block drop in quick on $sta_if all label \"$pf_label\"";;
        esac
        echo "$pf_line"
    done < "$state/pf.current" > "$state/pf.next"
    pf_load 2 0
}
# ssh_pf "addr bits" puts the SSH rule before en6's first rule; ssh_pf off
# takes it out.
ssh_pf() {
    : > "$state/pf.err"
    pfctl -sr > "$state/pf.current" 2>> "$state/pf.err" || return 1
    [ "$(grep -c "label \"$pf_label\"" "$state/pf.current")" = 2 ] ||
        { echo "the $sta_if rules are not in place" >> "$state/pf.err"; return 1; }
    sp_want=0
    sp_rule=
    if [ "$1" != off ]; then
        set -- $1
        sp_rule="pass in quick on $sta_if inet proto tcp from $(network_of "$1" "$2")/$2 to $1 port = $ssh_port flags S/SA keep state label \"$ssh_label\""
        sp_want=1
    fi
    sp_first=yes
    while IFS= read -r pf_line; do
        case $pf_line in *"label \"$ssh_label\""*) continue;; esac
        case $pf_line in
            *"label \"$pf_label\""*)
                [ "$sp_first" = yes ] && [ -n "$sp_rule" ] && echo "$sp_rule"
                sp_first=no;;
        esac
        echo "$pf_line"
    done < "$state/pf.current" > "$state/pf.next"
    pf_load 2 "$sp_want"
}
# Both labels out, whatever is there.
sta_pf_disable() {
    : > "$state/pf.err"
    pfctl -sr > "$state/pf.current" 2>> "$state/pf.err" || return 1
    [ "$(grep -c -e "label \"$pf_label\"" -e "label \"$ssh_label\"" "$state/pf.current")" != 0 ] ||
        return 0
    grep -v -e "label \"$pf_label\"" -e "label \"$ssh_label\"" "$state/pf.current" > "$state/pf.next"
    pf_load 0 0
}

# The factory translates <natRangeTable> on ppp0 and en5 only; en6 gets the
# same rule after en5's, in RAM. 7.2 showed pfctl -N leaving the anchors and
# the table alone on this unit; it is still checked each time.
nat_extras() {
    for anchor in dnsRedirect1 dnsRedirect2 dnsRedirect3 dnsRedirect4; do
        echo "$anchor:"
        pfctl -a "$anchor" -sn 2>&1
    done > "$state/anchors-nat-$1.txt"
    pfctl -t natRangeTable -T show > "$state/nat-table-$1.txt" 2>&1
}
nat_present() {
    pfctl -sn 2>/dev/null | grep -qxF "$nat_rule"
}
sta_nat() {
    : > "$state/nat.err"
    pfctl -sn > "$state/nat.current" 2>> "$state/nat.err" || return 1
    nat_count=$(grep -cxF "$nat_rule" "$state/nat.current")
    if [ "$1" = enable ]; then
        [ "$nat_count" = 0 ] || return 0
        [ "$(grep -c '^nat on en5 from <natRangeTable> ' "$state/nat.current")" = 1 ] ||
            { echo "no single en5 NAT rule to follow" >> "$state/nat.err"; return 1; }
        while IFS= read -r nat_line; do
            echo "$nat_line"
            case $nat_line in 'nat on en5 from <natRangeTable> '*) echo "$nat_rule";; esac
        done < "$state/nat.current" > "$state/nat.next"
        nat_want=1
    else
        [ "$nat_count" != 0 ] || return 0
        grep -vxF "$nat_rule" "$state/nat.current" > "$state/nat.next"
        nat_want=0
    fi
    nat_extras before
    pfctl -n -N -f "$state/nat.next" >> "$state/nat.err" 2>&1 || return 1
    if pfctl -N -f "$state/nat.next" >> "$state/nat.err" 2>&1 &&
            pfctl -sn > "$state/nat.verified" 2>> "$state/nat.err" &&
            [ "$(grep -cxF "$nat_rule" "$state/nat.verified")" = "$nat_want" ] &&
            nat_extras after &&
            [ "$(cat "$state/anchors-nat-before.txt")" = "$(cat "$state/anchors-nat-after.txt")" ] &&
            [ "$(cat "$state/nat-table-before.txt")" = "$(cat "$state/nat-table-after.txt")" ]; then
        return 0
    fi
    echo "the loaded NAT set did not verify, or an anchor or the table changed; restoring the previous set" >> "$state/nat.err"
    pfctl -N -f "$state/nat.current" >> "$state/nat.err" 2>&1
    return 1
}

# Stops the process in pid file $1 (named $2), TERM first, KILL after $3 s.
stop_pid() {
    sp_pid=$(cat "$1" 2>/dev/null)
    rm -f "$1"
    if [ -z "$sp_pid" ] || ! kill -0 "$sp_pid" 2>/dev/null; then
        log "$2 was not running."
        return 0
    fi
    log "stopping $2 (pid $sp_pid)."
    kill "$sp_pid" 2>/dev/null
    sp_waited=0
    while kill -0 "$sp_pid" 2>/dev/null && [ "$sp_waited" -lt "$3" ]; do
        sleep 1
        sp_waited=$((sp_waited + 1))
    done
    if kill -0 "$sp_pid" 2>/dev/null; then
        kill -9 "$sp_pid" 2>/dev/null
        log "$2 (pid $sp_pid) did not stop on TERM in ${3}s; killed."
        return 1
    fi
    log "$2 (pid $sp_pid) stopped."
}
# The dhcp.client for en6 is the one whose arguments end in "-i en6"; the
# factory's own on en5 (-b -i en5) never matches.
dhcp_pids() {
    bounded 20 "$state/pidin.txt" pidin -f aA || return 1
    sed -n "s/^ *\([0-9][0-9]*\) [^ ]*dhcp\.client .* -i $sta_if *\$/\1/p" "$state/pidin.txt"
}
dhcp_stop() {
    dhcp_found=$(dhcp_pids) || { log "pidin failed or timed out; dhcp.client not stopped."; return 1; }
    [ -n "$dhcp_found" ] || { log "no dhcp.client for $sta_if is running."; return 0; }
    log "stopping dhcp.client for $sta_if, pid" $dhcp_found
    kill $dhcp_found 2>/dev/null
    for dhcp_pid in $dhcp_found; do
        dhcp_waited=0
        while kill -0 "$dhcp_pid" 2>/dev/null && [ "$dhcp_waited" -lt 10 ]; do
            sleep 1
            dhcp_waited=$((dhcp_waited + 1))
        done
        kill -0 "$dhcp_pid" 2>/dev/null && kill -9 "$dhcp_pid" 2>/dev/null
    done
    rm -f "$state/dhcp.pid"
    dhcp_found=$(dhcp_pids) || { log "pidin failed after the stop."; return 1; }
    [ -z "$dhcp_found" ] || { log "dhcp.client still running: pid" $dhcp_found; return 1; }
    log "dhcp.client stopped."
}

# --- start: preflight (in the session) ---------------------------------------------
preflight() {
    [ "$(uname -s)" = QNX ] || refuse "run this on the MMI."
    for f in "$sta_driver" "$helper" "$image"; do
        [ -f "$f" ] && [ -s "$f" ] || refuse "$f is missing or empty."
    done
    for f in "$ctl" "$probe" "$wpa_bin" "$dhcp_client"; do
        [ -f "$f" ] && [ -x "$f" ] || refuse "$f is missing or not executable."
    done
    # SSH over the hotspot needs the OpenSSH installation running: its sshd,
    # its configuration and the sshd account its start-up maps into
    # /etc/passwd.
    if [ -x "$sshd" ] && [ -s "$sshd_template" ] && grep -q '^sshd:' "$passwd_file" 2>/dev/null; then
        ssh=yes
    else
        ssh=no
    fi
    [ "$(sum_of "$driver")" = "$driver_sum" ] ||
        refuse "$driver is not the reviewed factory object ($(sum_of "$driver"))."
    [ "$(sum_of "$dhcp_client")" = "$dhcp_client_sum" ] ||
        refuse "$dhcp_client is not the reviewed factory binary ($(sum_of "$dhcp_client"))."
    [ "$(sum_of "$dhcp_up")" = "$dhcp_up_sum" ] ||
        refuse "$dhcp_up is not the reviewed factory script ($(sum_of "$dhcp_up"))."
    [ ! -e "$rse_marker" ] || refuse "$rse_marker exists; dhcp-up would take a branch not reviewed."
    # Only the LAN-mode branch of dhcp-up gives the HMI the route; it was
    # reviewed with lan-mode.sh's empty flag.
    [ -f "$dlink_marker" ] && [ ! -s "$dlink_marker" ] ||
        refuse "station mode needs the empty flag $dlink_marker (lan-mode.sh enable, then a restart)."
    # The key: root's alone, one WPA-PSK network. Read through pipes, never
    # copied or logged.
    [ -f "$conf" ] && [ -s "$conf" ] || refuse "configuration $conf is missing or empty."
    set -- $(ls -l "$conf")
    [ "$1" = "-rw-------" ] && [ "$3" = root ] ||
        refuse "$conf must be owned by root with mode 600 (is $1 $3)."
    conf_lines() { sed -e 's/^[ 	]*//' -e 's/[ 	]*$//' "$conf"; }
    [ "$(conf_lines | grep -c '^network={')" = 1 ] &&
        [ "$(conf_lines | grep -c '^ssid=')" = 1 ] &&
        [ "$(conf_lines | grep -Fxc 'key_mgmt=WPA-PSK')" = 1 ] ||
        refuse "$conf must hold exactly one network, with one ssid= and key_mgmt=WPA-PSK."

    [ -d "$state" ] || mkdir -p "$state" || refuse "cannot create $state."
    chmod 700 "$state"
    if interface_present "$sta_if"; then
        refuse "$sta_if already exists; stop it (sta-mode.sh stop) or restart the unit first."
    fi
    # The station takes the access point's factory MAC. Only the factory
    # mount programs it: a uap0 mounted by hand shows all zeros.
    bounded 10 "$state/uap0.txt" ifconfig uap0 ||
        refuse "uap0 is absent or ifconfig timed out; restart the unit first."
    ap_mac=$(sed -n 's/^[ 	]*address: *//p' "$state/uap0.txt" | sed -e '1!d')
    hex='[0-9a-fA-F]'
    case $ap_mac in
        00:00:00:00:00:00|[aA][aA]:[bB][bB]:[cC][cC]:[dD][dD]:[eE][eE]:[fF][fF]) ap_mac=;;
        $hex[02468aAcCeE]:$hex$hex:$hex$hex:$hex$hex:$hex$hex:$hex$hex) ;;
        *) ap_mac=;;
    esac
    [ -n "$ap_mac" ] || refuse "uap0 has no usable factory MAC; restart the unit first."
    # A second lease would compete for the default route (en5's, at home).
    routes_now || refuse "the routing table could not be read."
    if default_routes > /dev/null; then
        refuse "a default route exists ($(default_routes | sed -e '1!d')); the station's lease would compete with it. Delete it first (route delete default)."
    fi
    bounded 20 "$state/pidin.txt" pidin -f aA ||
        refuse "pidin did not answer; cannot check jitter-egd or dhcp.client."
    if grep -q 'jitter-egd' "$state/pidin.txt"; then
        egd=running
    elif [ -f "$egd_bin" ] && [ -x "$egd_bin" ]; then
        egd=start
    else
        refuse "jitter-egd is not running and $egd_bin is missing; wpa_supplicant would have no random bytes."
    fi
    ! sed -n 's/^ *[0-9][0-9]* //p' "$state/pidin.txt" | grep -q "dhcp\.client .* -i $sta_if *\$" ||
        refuse "a dhcp.client for $sta_if is already running."
    pfctl -sr > "$state/pf.check" 2>&1 || refuse "pfctl -sr failed: $(cat "$state/pf.check")"
    [ "$(grep -c -e "label \"$pf_label\"" -e "label \"$ssh_label\"" "$state/pf.check")" = 0 ] ||
        refuse "rules labelled $pf_label or $ssh_label are loaded; run sta-mode.sh stop first."
    [ "$(grep -c '^pass out ' "$state/pf.check")" = 1 ] ||
        refuse "the filter rules have no single 'pass out' rule to insert before."
    pfctl -sn > "$state/nat.check" 2>&1 || refuse "pfctl -sn failed."
    [ "$(grep -c '^nat on en5 from <natRangeTable> ' "$state/nat.check")" = 1 ] ||
        refuse "the NAT rules have no single en5 rule to follow."
    ! grep -qxF "$nat_rule" "$state/nat.check" ||
        refuse "the $sta_if NAT rule is already loaded; run sta-mode.sh stop first."
    # The probe's guard must refuse while the factory driver holds the module,
    # or it cannot be trusted to pass for the right reason after the detach.
    bounded 30 "$state/guard.txt" "$probe" -n
    guard_rc=$?
    [ "$guard_rc" = 1 ] && grep -q 'verdict=REFUSED the module is in use' "$state/guard.txt" ||
        refuse "the probe guard did not refuse the attached module (exit $guard_rc); nothing was changed."
}

session_client() {
    sc=${SSH_CONNECTION-}
    [ -n "$sc" ] || sc=${SSH_CLIENT-}
    echo "${sc%% *}"
}

# Prints the log from line $1 on until $2 appears, the worker in pid file $3
# ends, or the limit passes.
follow() {
    fl_seen=$1
    fl_waited=0
    while :; do
        fl_lines=$(sed -n '$=' "$log_file" 2>/dev/null)
        fl_lines=${fl_lines:-0}
        if [ "$fl_lines" -gt "$fl_seen" ]; then
            sed -n "$((fl_seen + 1)),${fl_lines}p" "$log_file"
            fl_seen=$fl_lines
        fi
        [ ! -f "$2" ] || break
        if ! alive "$3"; then
            # One more look: the verdict may land as the worker exits.
            sleep 1
            [ ! -f "$2" ] || continue
            say "the worker (pid $(cat "$3" 2>/dev/null)) ended without a verdict; see $log_file and $state/worker.out."
            return 2
        fi
        if [ "$fl_waited" -ge "$follow_limit" ]; then
            say "no verdict after ${follow_limit}s; it is still running. Read sta-mode.sh status later."
            return 3
        fi
        sleep 1
        fl_waited=$((fl_waited + 1))
    done
    fl_verdict=$(cat "$2")
    say "verdict $fl_verdict"
    case $fl_verdict in
        OK) return 0;;
        PARTIAL*) return 3;;
        *) return 2;;
    esac
}

cmd_start() {
    dry=no
    root=${self%/*}
    conf=
    while getopts ':nr:c:' option; do
        case $option in
            n) dry=yes;;
            r) root=$OPTARG;;
            c) conf=$OPTARG;;
            *) usage;;
        esac
    done
    shift $((OPTIND - 1))
    [ $# = 0 ] || usage
    [ -n "$conf" ] || conf=$root/wpa-hotspot.conf
    if [ -d "$lock" ]; then
        say "station mode was already started (phase $(cat "$state/phase" 2>/dev/null)); not starting again."
        cmd_status
        exit $?
    fi
    sta_driver=$root/devn-mv8688sta.so
    ctl=$root/mv8688-ctl
    probe=$root/mv8688-probe
    helper=$root/sd8688_helper.bin
    image=$root/sd8688.bin
    wpa_bin=$root/wpa_supplicant
    egd_bin=$root/jitter-egd
    preflight
    for f in "$sta_driver" "$ctl" "$probe" "$helper" "$image" "$wpa_bin"; do
        say "$f cksum $(sum_of "$f")"
    done
    if [ "$egd" = running ]; then
        say "uap0 factory MAC $ap_mac goes to the station; no default route; jitter-egd is running."
    else
        say "uap0 factory MAC $ap_mac goes to the station; no default route; jitter-egd starts from $egd_bin."
    fi
    [ "$ssh" = yes ] ||
        say "the OpenSSH installation is not running: the station will have no SSH."
    client=$(session_client)
    case $client in
        192.168.1.*) say "this session arrives on uap0 ($client): it will drop at the detach. Reconnect over the hotspot (port $ssh_port on the lease address) and run status.";;
        '') say "no SSH_CONNECTION; cannot tell which interface this session uses.";;
        *) say "session client $client.";;
    esac
    if [ "$dry" = yes ]; then
        say "dry run: nothing was changed."
        exit 0
    fi
    # mkdir is atomic: of two starts, one gets the lock.
    mkdir "$lock" 2>/dev/null || { say "another start holds $lock."; exit 2; }
    for f in sta_driver ctl probe helper image wpa_bin conf ap_mac ssh egd egd_bin; do
        eval "echo \"\$$f\"" > "$lock/$f"
    done
    echo starting > "$state/phase"
    rm -f "$state/verdict" "$state/stop.verdict" "$state/bound" "$state/sshd.pid" \
        "$state/dhcp.pid" "$state/wpa.pid" "$state/keeper.pid"
    : >> "$log_file"
    seen=$(sed -n '$=' "$log_file")
    ( trap '' 1; exec "$shell" "$self" __start ) < /dev/null >> "$state/worker.out" 2>&1 &
    echo $! > "$lock/pid"
    say "started in the background (pid $!); following its log."
    follow "${seen:-0}" "$state/verdict" "$lock/pid"
    exit $?
}

# --- start: the work (detached) -------------------------------------------------
load_lock() {
    for f in sta_driver ctl probe helper image wpa_bin conf ap_mac ssh egd egd_bin; do
        eval "$f=\$(cat \"\$lock/\$f\" 2>/dev/null)"
    done
}
verdict() {
    echo "$1" > "$state/verdict"
    log "verdict $1"
}
fail_start() {
    log "FAILED: $*"
    echo failed > "$state/phase"
    verdict FAIL
    exit 2
}

wpa_start() {
    rm -f "$state/wpa.log"      # -f appends
    # Without -d: the log carries the INFO events (connections, handshakes,
    # rekeys) and no debug detail, so it grows slowly over a long session.
    "$wpa_bin" -i "$sta_if" -D mv8688 -c "$conf" -t -f "$state/wpa.log" \
        < /dev/null > "$state/wpa.out" 2>&1 &
    echo $! > "$state/wpa.pid"
    log "wpa_supplicant started on $sta_if (pid $!) with $conf (not logged)."
}

# The station's own random source, when the OpenSSH installation's is not
# running, started as that installation's start-up starts it. It is left
# running after a stop, until the restart.
egd_start() {
    rm -f "$state/egd.log"
    ( trap '' 1; exec "$egd_bin" "$egd_port" ) < /dev/null > "$state/egd.log" 2>&1 &
    echo $! > "$state/egd.pid"
    eg_waited=0
    until grep -q '^JITTER_EGD_READY ' "$state/egd.log" 2>/dev/null; do
        if ! alive "$state/egd.pid"; then
            log "jitter-egd from $egd_bin exited: $(sed -n '$p' "$state/egd.log" 2>/dev/null)"
            return 1
        fi
        if [ "$eg_waited" -ge "$egd_limit" ]; then
            log "jitter-egd from $egd_bin was not ready after ${egd_limit}s."
            stop_pid "$state/egd.pid" jitter-egd 5
            return 1
        fi
        sleep 1
        eg_waited=$((eg_waited + 1))
    done
    log "jitter-egd: started from $egd_bin on port $egd_port (pid $(cat "$state/egd.pid"))."
}

worker_start() {
    load_lock
    log "start: uap0 factory MAC $ap_mac; unit clock $(date '+%Y-%m-%dT%H:%M:%S') (uptime, not calendar time)."
    log "state volume: $(df -k "$state" 2>/dev/null | sed -n '$p')"
    # What the stop puts back. LAN-mode leases rewrite resolv.conf on the
    # system flash.
    rm -f "$state/resolv.conf.baseline"
    if [ -f "$resolv_conf" ]; then
        cp "$resolv_conf" "$state/resolv.conf.baseline" ||
            fail_start "cannot keep a copy of $resolv_conf."
        log "resolv.conf before the start: $(sum_of "$resolv_conf") (copy kept)."
    else
        : > "$state/resolv.conf.absent"
        log "resolv.conf before the start: absent."
    fi
    if [ "$egd" = start ] && ! egd_start; then
        rm -rf "$lock"
        rm -f "$state/phase"
        log "no random source for wpa_supplicant; nothing was changed."
        verdict FAIL
        exit 2
    fi
    if sta_pf_enable; then
        log "pf: $sta_if admits only DHCP replies until a lease (label $pf_label)."
    else
        rm -rf "$lock"
        rm -f "$state/phase"
        log "pf rules could not be loaded: $(cat "$state/pf.err")"
        verdict FAIL
        exit 2
    fi
    log "detaching uap0 (the stack quiesces; expect a stall). The access point is gone until the restart."
    bounded 60 "$state/destroy.txt" ifconfig uap0 destroy ||
        log "destroy did not return cleanly: $(cat "$state/destroy.txt")"
    if ! wait_gone 30 uap0; then
        sta_pf_disable || log "the $sta_if rules could not be removed: $(cat "$state/pf.err")"
        rm -rf "$lock"
        rm -f "$state/phase"
        log "uap0 is still present after the destroy; nothing else was changed."
        verdict FAIL
        exit 2
    fi
    log "uap0 is gone."
    bounded 30 "$state/guard-detached.txt" "$probe" -n ||
        fail_start "the probe guard still refuses after the detach; no station. Restart the unit."
    log "mounting the station driver as $sta_if (the stack stalls during the download)."
    if ! bounded 60 "$state/sta-mount.txt" mount -T io-pkt -o \
            "lan=$sta_lan,mac=$ap_mac,helper=$helper,firmware=$image" "$sta_driver" ||
            ! wait_present 20 "$sta_if"; then
        fail_start "the station driver did not attach ($(cat "$state/sta-mount.txt")); no access point and no station. Restart the unit, or run stop to re-mount the factory driver."
    fi
    bounded 10 "$state/en6.txt" ifconfig "$sta_if"
    log "$sta_if $(sed -n -e 's/^[^ ]*: *//' -e '1p' "$state/en6.txt")"
    sed -n '1p' "$state/en6.txt" | grep -q 'BROADCAST' ||
        fail_start "$sta_if lacks BROADCAST, so dhcp.client cannot send. Run stop, or restart."
    bounded 10 "$state/en6-up.txt" ifconfig "$sta_if" up ||
        fail_start "$sta_if could not be brought up. Run stop, or restart."
    wpa_start
    echo keeping > "$state/phase"
    keeper
}

# --- the keeper ----------------------------------------------------------------
# Logs a line only when the value under $1 changes, so a long session does
# not fill the RAM disk.
changed() {
    ch_old=$(cat "$state/seen.$1" 2>/dev/null)
    [ "$ch_old" != "$2" ] || return 1
    echo "$2" > "$state/seen.$1"
    return 0
}

sshd_bind() {
    sb_addr=${1%% *}
    sed -e "s|^ListenAddress .*|ListenAddress $sb_addr|" \
        -e "s|^PidFile .*|PidFile $state/sshd.pidfile|" \
        "$sshd_template" > "$state/sshd_config"
    chmod 600 "$state/sshd_config"
    if ! bounded 20 "$state/sshd-test.txt" "$sshd" -t -f "$state/sshd_config"; then
        log "sshd: the configuration for $sb_addr did not test: $(cat "$state/sshd-test.txt")"
        return 1
    fi
    ( trap '' 1; exec "$sshd" -D -e -f "$state/sshd_config" ) < /dev/null \
        >> "$state/sshd.log" 2>&1 &
    echo $! > "$state/sshd.pid"
    sleep 2
    if alive "$state/sshd.pid"; then
        log "sshd: listening on $sb_addr:$ssh_port (pid $(cat "$state/sshd.pid"))."
        return 0
    fi
    log "sshd: exited at once; see sshd.log."
    return 1
}

# One pass: bring everything back in line with the current state.
converge() {
    if ! interface_present "$sta_if"; then
        log "FAILED: $sta_if is gone; the keeper stops. Restart the unit."
        echo failed > "$state/phase"
        [ -f "$state/verdict" ] || verdict FAIL
        exit 2
    fi
    # The supplicant reconnects on its own (6.2); it is restarted only if it
    # has exited, at most once a minute.
    if ! alive "$state/wpa.pid"; then
        if [ $((ticks - wpa_restarted)) -ge 6 ]; then
            log "wpa_supplicant has exited ($(sed -n '$p' "$state/wpa.out" 2>/dev/null)); restarting it."
            wpa_restarted=$ticks
            wpa_start
        fi
    fi
    bounded 10 "$state/ctl.txt" "$ctl" -i "$sta_if" status
    link=$(sed -n 's/^state=\([a-z_]*\) .*/\1/p' "$state/ctl.txt")
    counts=$(sed -n 's/.*\(connects=[0-9]* link_losses=[0-9]*\).*/\1/p' "$state/ctl.txt")
    changed link "$link $counts" && log "link: ${link:-unknown} ${counts}"
    # The client is started once associated, and again (at most once a
    # minute) if it exits. Without -T it keeps asking; -b asks the server to
    # broadcast its replies.
    if [ "$link" = associated ] && ! alive "$state/dhcp.pid" &&
            [ $((ticks - dhcp_started)) -ge 6 ]; then
        dhcp_started=$ticks
        "$dhcp_client" -b -i "$sta_if" < /dev/null >> "$state/dhcp.out" 2>&1 &
        echo $! > "$state/dhcp.pid"
        log "started $dhcp_client -b -i $sta_if (pid $!)."
    fi
    lease=$(lease_of) || lease=
    changed lease "$lease" && log "lease: ${lease:-none}"
    if [ -n "$lease" ]; then
        bound=$(cat "$state/bound" 2>/dev/null)
        if [ "$ssh" = yes ] && { [ "$bound" != "$lease" ] || ! alive "$state/sshd.pid"; }; then
            if [ "$bound" != "$lease" ] && [ "$(cat "$state/bind.failed" 2>/dev/null)" = "$lease" ] &&
                    [ $((ticks - bind_tried)) -lt 6 ]; then
                :
            else
                bind_tried=$ticks
                stop_pid "$state/sshd.pid" sshd 5
                rm -f "$state/bound"
                if ssh_pf "$lease"; then
                    log "pf: SSH to ${lease%% *}:$ssh_port from its /${lease#* } admitted (label $ssh_label)."
                    if sshd_bind "$lease"; then
                        echo "$lease" > "$state/bound"
                        rm -f "$state/bind.failed"
                    else
                        echo "$lease" > "$state/bind.failed"
                    fi
                else
                    log "pf: the SSH rule could not be loaded: $(cat "$state/pf.err")"
                    echo "$lease" > "$state/bind.failed"
                fi
            fi
        fi
        if ! nat_present; then
            if sta_nat enable; then
                log "pf: $sta_if translates <natRangeTable> as en5 does (RAM only)."
            else
                changed nat "$(cat "$state/nat.err")" &&
                    log "pf: NAT on $sta_if could not be added: $(cat "$state/nat.err")"
            fi
        fi
    fi
    # Another lease (en5's, at home) would take the route; recorded, not fought.
    if routes_now; then
        changed defaults "$(default_routes | sed -e 's/$/;/')" &&
            log "default routes: $(echo $(default_routes | sed -e 's/^default //' -e 's/$/;/'))"
    fi
}

# What the start reports, once: OK when everything the purpose needs is up.
start_checks() {
    missing=
    grep -q '^state=associated' "$state/ctl.txt" || missing="$missing not associated;"
    grep -q '^rsn=1 ' "$state/ctl.txt" || missing="$missing no RSN join;"
    grep -q 'Key negotiation completed with .*PTK=CCMP GTK=CCMP' "$state/wpa.log" 2>/dev/null ||
        missing="$missing no CCMP handshake;"
    [ -n "$lease" ] || missing="$missing no lease;"
    if [ -n "$lease" ]; then
        station_default_only ||
            missing="$missing the default route is not the lease's alone ($(echo $(default_routes)));"
        sc_servers=$(sed -n 's/^nameserver[ 	]*//p' "$resolv_conf" 2>/dev/null)
        echo "$sc_servers" | grep -v "^$(echo "$fallback_dns" | sed 's/\./\\./g')\$" | grep -q . ||
            missing="$missing resolv.conf names no server of the lease's;"
        bounded 5 "$state/getconf.txt" getconf _CS_RESOLVE
        ! grep -q 'nameserver' "$state/getconf.txt" || missing="$missing _CS_RESOLVE not cleared;"
        nat_present || missing="$missing no NAT on $sta_if;"
        if [ "$ssh" = yes ]; then
            [ "$(cat "$state/bound" 2>/dev/null)" = "$lease" ] && alive "$state/sshd.pid" ||
                missing="$missing no sshd on the lease;"
        fi
    fi
}

keeper() {
    echo $$ > "$state/keeper.pid"
    trap 'log "keeper: stopping on request."; exit 0' 15
    ticks=0
    wpa_restarted=0
    dhcp_started=-6
    bind_tried=-6
    log "keeper: running (pid $$), every ${tick}s until the restart or a stop."
    while :; do
        converge
        if [ ! -f "$state/verdict" ]; then
            start_checks
            if [ -z "$missing" ]; then
                if [ "$ssh" = yes ]; then
                    sshd_note="and sshd listens on ${lease%% *}:$ssh_port"
                else
                    sshd_note="with no SSH (the OpenSSH installation is not running)"
                fi
                log "RESULT: $sta_if joined the hotspot with WPA2-PSK, leased ${lease%% *} as the only default route with resolv.conf naming $(echo $sc_servers), translates <natRangeTable>, $sshd_note."
                verdict OK
            elif [ "$ticks" -ge "$start_ticks" ]; then
                log "PARTIAL after $((ticks * tick))s:$missing the keeper keeps trying."
                verdict "PARTIAL:$missing"
            fi
        fi
        sleep "$tick"
        ticks=$((ticks + 1))
    done
}

# --- stop ---------------------------------------------------------------------
cmd_stop() {
    [ $# = 0 ] || usage
    if [ ! -d "$lock" ] && ! interface_present "$sta_if"; then
        say "station mode is not started; nothing to stop."
        exit 0
    fi
    if [ "$(cat "$state/phase" 2>/dev/null)" = starting ] && alive "$lock/pid"; then
        say "a start is still bringing the station up; run stop again when it reports."
        exit 2
    fi
    if [ "$(cat "$state/phase" 2>/dev/null)" = stopping ] && alive "$state/stop.pid"; then
        say "a stop is already running."
        exit 2
    fi
    client=$(session_client)
    lease=$(lease_of) || lease=
    if [ -n "$lease" ] && [ -n "$client" ] &&
            [ "$(network_of "$client" "${lease#* }")" = "$(network_of "${lease%% *}" "${lease#* }")" ]; then
        say "this session arrives on $sta_if ($client): it will drop when the station leaves. The stop goes on."
    fi
    echo stopping > "$state/phase"
    rm -f "$state/stop.verdict"
    : >> "$log_file"
    seen=$(sed -n '$=' "$log_file")
    ( trap '' 1; exec "$shell" "$self" __stop ) < /dev/null >> "$state/worker.out" 2>&1 &
    echo $! > "$state/stop.pid"
    say "stopping in the background (pid $!); following its log."
    follow "${seen:-0}" "$state/stop.verdict" "$state/stop.pid"
    exit $?
}

worker_stop() {
    load_lock
    stop_verdict=OK
    degrade() {
        [ "$stop_verdict" = FAIL ] || stop_verdict=PARTIAL
        log "PARTIAL: $*"
    }
    log "stop: started."
    # The 7.3 run's first stop died silently after the supplicant's TERM.
    # Name a caught signal (KILL cannot be); HUP stays ignored from the spawn.
    for stop_sig in 2 3 13 15; do
        trap "log \"stop: signal $stop_sig received; the steps after the last line are not done. Run stop again.\"; exit 4" $stop_sig
    done
    stop_pid "$state/keeper.pid" keeper 20 || :
    stop_pid "$state/sshd.pid" sshd 5 || degrade "sshd had to be killed."
    dhcp_stop || degrade "the dhcp.client for $sta_if could not be stopped; a restart ends it."
    stop_pid "$state/wpa.pid" wpa_supplicant 10 || degrade "wpa_supplicant had to be killed."
    if interface_present "$sta_if"; then
        if [ -n "$ctl" ]; then
            bounded 30 "$state/disconnect.txt" "$ctl" -i "$sta_if" -w 15 disconnect ||
                log "the disconnect request failed: $(cat "$state/disconnect.txt")"
            sleep 2
        fi
        bounded 60 "$state/sta-destroy.txt" ifconfig "$sta_if" destroy ||
            log "the destroy did not return cleanly: $(cat "$state/sta-destroy.txt")"
        if ! wait_gone 30 "$sta_if"; then
            log "FAILED: $sta_if is still present; the factory driver stays out and the rules stay in. Restart the unit."
            echo failed > "$state/phase"
            echo FAIL > "$state/stop.verdict"
            exit 2
        fi
        log "$sta_if is gone."
    fi
    if sta_pf_disable; then
        log "pf: the $sta_if rules are out."
    else
        degrade "the $sta_if filter rules could not be removed: $(cat "$state/pf.err")"
    fi
    if sta_nat disable; then
        log "pf: the $sta_if NAT rule is out."
    else
        degrade "the $sta_if NAT rule could not be removed: $(cat "$state/nat.err")"
    fi
    # resolv.conf as it was before the start; the run's copy is kept.
    n=1
    while [ -e "$state/resolv.conf.run.$n" ]; do n=$((n + 1)); done
    if [ -f "$state/resolv.conf.absent" ]; then
        if [ -f "$resolv_conf" ]; then
            cp "$resolv_conf" "$state/resolv.conf.run.$n" 2>/dev/null
            if rm -f "$resolv_conf" && [ ! -f "$resolv_conf" ]; then
                log "resolver: removed $resolv_conf, absent before the start (copy resolv.conf.run.$n)."
            else
                degrade "resolver: $resolv_conf could not be removed."
            fi
        fi
    elif [ -f "$state/resolv.conf.baseline" ] &&
            [ "$(cat "$state/resolv.conf.baseline")" != "$(cat "$resolv_conf" 2>/dev/null)" ]; then
        [ ! -f "$resolv_conf" ] || cp "$resolv_conf" "$state/resolv.conf.run.$n" 2>/dev/null
        if (umask 0; cat "$state/resolv.conf.baseline" > "$resolv_conf") &&
                [ "$(cat "$state/resolv.conf.baseline")" = "$(cat "$resolv_conf")" ]; then
            log "resolver: put back $resolv_conf from before the start (copy resolv.conf.run.$n)."
        else
            degrade "resolver: $resolv_conf from before the start could not be put back."
        fi
    fi
    rm -f "$state/resolv.conf.absent" "$state/resolv.conf.baseline"
    if routes_now && default_routes > /dev/null; then
        log "routes: a default route remains ($(default_routes | sed -e '1!d'))."
    fi
    stop_factory
    rm -f "$state/bound" "$state/bind.failed" "$state"/seen.*
    rm -rf "$lock"
    rm -f "$state/phase"
    echo "$stop_verdict" > "$state/stop.verdict"
    log "stop: verdict $stop_verdict"
    [ "$stop_verdict" = OK ] || exit 3
    exit 0
}

# The factory driver goes back only once the module is idle and no
# firmware answers: its attach skips the download when it finds the ready
# magic and would drive the station image.
stop_factory() {
    if interface_present uap0; then
        log "uap0 is present; not mounting a second copy."
        return
    fi
    if [ -z "$probe" ] || [ ! -x "$probe" ]; then
        degrade "no probe to check the module with; the factory driver stays out. Restart the unit."
        return
    fi
    if ! bounded 30 "$state/guard-after.txt" "$probe" -n; then
        degrade "the module is still in use; the factory driver stays out. Restart the unit."
        return
    fi
    bounded 60 "$state/firmware-check.txt" "$probe" -c
    check_rc=$?
    if [ "$check_rc" != 0 ]; then
        stop_verdict=FAIL
        log "FAILED: the firmware check did not pass (exit $check_rc); the factory driver stays out. A full power-off is the recovery."
        return
    fi
    log "the module is idle and no firmware answers; mounting the factory driver."
    for params in "$mount_base,fwpath=$firmware_path,resetmask=0" \
            "$mount_base,fwpath=$firmware_path,resetmask=4"; do
        if bounded 60 "$state/factory-mount.txt" mount -T io-pkt -o "$params" "$driver" &&
                wait_present 30 uap0; then
            log "factory driver mounted with $params."
            if ifconfig uap0 inet "$ap_address" netmask "$ap_netmask" up; then
                log "uap0 holds $ap_address. It has no SSID or key after a manual mount: restart the unit for the access point."
            else
                degrade "uap0 is up but $ap_address could not be set."
            fi
            return
        fi
        log "the factory mount with $params did not attach."
    done
    stop_verdict=FAIL
    log "FAILED: the factory driver could not be mounted. Restart the unit."
}

# --- status -------------------------------------------------------------------
cmd_status() {
    phase=$(cat "$state/phase" 2>/dev/null)
    if [ ! -d "$lock" ] && ! interface_present "$sta_if"; then
        if interface_present uap0; then
            say "station mode is not started; uap0 is present."
        else
            say "station mode is not started, and uap0 is absent (a stop leaves it unconfigured)."
        fi
        [ ! -f "$state/stop.verdict" ] || say "last stop: $(cat "$state/stop.verdict")"
        return 0
    fi
    st=OK
    why=
    bad() { [ "$st" = FAIL ] || st=$1; why="$why $2;"; }
    say "phase ${phase:-unknown}; start verdict $(cat "$state/verdict" 2>/dev/null || echo none)"
    if alive "$state/keeper.pid"; then
        say "keeper: running (pid $(cat "$state/keeper.pid"))"
    else
        bad PARTIAL "the keeper is not running"
    fi
    [ "$phase" != failed ] || bad FAIL "the start or stop failed"
    if interface_present "$sta_if"; then
        if [ -n "${ctl:=$(cat "$lock/ctl" 2>/dev/null)}" ] &&
                bounded 10 "$state/status-ctl.txt" "$ctl" -i "$sta_if" status; then
            sed -n -e '/^state=/p' -e '/connects=/p' -e '/^rsn=/p' "$state/status-ctl.txt" |
                sed -e 's/^/sta:   /'
            grep -q '^state=associated' "$state/status-ctl.txt" || bad PARTIAL "not associated"
        else
            bad PARTIAL "the control tool did not answer"
        fi
        lease=$(lease_of) || lease=
        if [ -n "$lease" ]; then
            say "lease: ${lease%% *}/${lease#* }"
        else
            bad PARTIAL "no lease"
        fi
    else
        bad FAIL "$sta_if is absent"
    fi
    alive "$state/wpa.pid" && say "wpa_supplicant: running (pid $(cat "$state/wpa.pid"))" ||
        bad PARTIAL "wpa_supplicant is not running"
    alive "$state/dhcp.pid" && say "dhcp.client: running (pid $(cat "$state/dhcp.pid"))" ||
        bad PARTIAL "dhcp.client is not running"
    if [ "$(cat "$lock/ssh" 2>/dev/null)" = no ]; then
        say "sshd: none (the OpenSSH installation was not running at the start)"
    elif alive "$state/sshd.pid"; then
        say "sshd: pid $(cat "$state/sshd.pid") on $(cat "$state/bound" 2>/dev/null | sed -e 's/ .*//'):$ssh_port"
        [ "$(cat "$state/bound" 2>/dev/null)" = "${lease:-}" ] || bad PARTIAL "sshd is not on the current lease"
    else
        bad PARTIAL "no sshd on the lease"
    fi
    if routes_now; then
        say "default routes: $(echo $(default_routes | sed -e 's/^default //' -e 's/$/;/'))"
        station_default_only || bad PARTIAL "the default route is not the station's alone"
    else
        bad PARTIAL "netstat did not answer"
    fi
    say "resolv.conf: $(echo $(sed -n 's/^nameserver[ 	]*//p' "$resolv_conf" 2>/dev/null))"
    nat_present || bad PARTIAL "no NAT on $sta_if"
    if bounded 20 "$state/status-pidin.txt" pidin -f aA; then
        grep -q 'jitter-egd' "$state/status-pidin.txt" ||
            bad PARTIAL "jitter-egd is not running (rekeys and reconnects need it)"
    fi
    say "recent log:"
    sl_lines=$(sed -n '$=' "$log_file" 2>/dev/null)
    sl_lines=${sl_lines:-0}
    sl_from=$((sl_lines - 9))
    [ "$sl_from" -ge 1 ] || sl_from=1
    sed -n "${sl_from},\$p" "$log_file" 2>/dev/null | sed -e 's/^/  /'
    if [ "$st" = OK ]; then
        say "status OK"
        return 0
    fi
    say "status $st:$why"
    [ "$st" = PARTIAL ] && return 3
    return 2
}

[ $# -ge 1 ] || usage
command=$1
shift
case $command in
    start) cmd_start ${1+"$@"};;
    status) [ $# = 0 ] || usage; cmd_status; exit $?;;
    stop) cmd_stop ${1+"$@"};;
    __start) worker_start;;
    __stop) worker_stop;;
    *) usage;;
esac
