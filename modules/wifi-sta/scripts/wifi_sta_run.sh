#!/bin/ksh
# ============================================================
# Wi-Fi client (station mode) - install, upgrade or remove
#
# Turns the MMI 3G+ 88W8688 from the car's access point into a client
# that joins a phone hotspot (WPA2-PSK), using the files in wifi-sta/ on
# this card: the station driver, wpa_supplicant, jitter-egd and their
# scripts from https://github.com/chundla/mmi3g-wifi-sta, and Marvell's
# linux-firmware station firmware.
#
# Install (default):
#   1. check the card's files and that this unit has the factory files the
#      station was validated with; nothing is changed otherwise
#   2. set the factory LAN-mode flag (/HBpersistence/DLinkReplacesPPP) if
#      it is not set
#   3. install the station files on the HDD (/mnt/persistence/wifi-sta)
#   4. store wifi-sta/hotspot.conf from the card (root, mode 600), then
#      delete it from the card
#   5. add the WifiClient GEM screen
#   6. add the start-up block to /mnt/efs-system/lsd/lsd.sh
#   7. if wifi-sta/options is on the card, apply it (see below)
#   An earlier install is upgraded in place; its hotspot configuration,
#   its GEM start-up choice and its inbound list stay unless the options
#   change them.
# wifi-sta/options (optional; the web builder writes it), one per line:
#   start-up=client      join the networks at every start-up (or: ap)
#   allow=icmp           admit ping from the station's own network
#   allow=tcp 23         admit a TCP (or udp) port from it; 23 is the
#                        factory telnet, a root login with no password
#   allow=none           admit nothing but DHCP replies
#   Any allow= line replaces the unit's inbound list (and the older
#   telnet-on-hotspot marker); with none, the list stays as it is.
# Remove: put an empty file wifi-sta/REMOVE on the card. The LAN-mode
#   flag stays (wifi-sta/lan-mode.sh disable removes it).
#
# Every step is one of the bundled scripts, each with its own checks,
# rollback and status. This file runs them in order, each under a time
# limit, and stops at the first that refuses. The output goes to the
# toolkit's install log in var/ on the card.
#
# Nothing starts the station here. After a restart, the GEM screen
# WifiClient starts it, or chooses to join the hotspot at every start-up.
# ============================================================

SDPATH="${1:-${0%/*}/..}"
umask 077
PATH=/bin:/sbin:/usr/bin:/usr/sbin
export PATH
# The factory environment preloads libmc.so; the station's scripts clear it
# too.
unset LD_PRELOAD

ksh=/bin/ksh
pay="${SDPATH}/wifi-sta"
card_conf="${pay}/hotspot.conf"
card_options="${pay}/options"
remove_flag="${pay}/REMOVE"
sums="${pay}/CKSUMS"
run=/fs/tmpfs
persistence=/mnt/persistence
efs_system=/mnt/efs-system
marker=/mnt/efs-persist/wifi-sta/gem/client-at-start-up
gem_dir=/mnt/efs-persist/wifi-sta/gem
inbound_file=$gem_dir/inbound
telnet_marker=$gem_dir/telnet-on-hotspot
inbound_max=16
flag=/HBpersistence/DLinkReplacesPPP
# The factory files the station was validated with, on one unit (9411,
# HN+R_US_AU_K0942_3, MU 1038). sta-mode.sh refuses to start without them.
driver=/lib/dll/devnp-mv8688uap.so
driver_sum='1022510863 93538'
dhcp_client=/usr/sbin/dhcp.client
dhcp_client_sum='263280565 57048'
dhcp_up=/etc/dhcp/dhcp-up
dhcp_up_sum='3046797907 6292'
# DrGER's LTE dhcp-up (20230218), which many 3G+ units run instead; it gives a
# lease's name servers to resolv.conf as the station needs (see sta-mode.sh).
dhcp_up_drger_sum='1601281849 792'
# Seconds per step; every step finishes well inside this on a healthy unit.
budget=300

say() {
    echo "[wifi-sta] $*"
}

# The card's status screen: this step's line, under the module's share of the
# bar (run.sh exports FORGE_PROGRESS and FORGE_MOD_RANGE; alone, nothing).
progress() {
    [ -n "${FORGE_PROGRESS:-}" ] || return 0
    echo "${FORGE_MOD_RANGE:+${FORGE_MOD_RANGE} }Wi-Fi: $*" > "$FORGE_PROGRESS" 2>/dev/null
    return 0
}

fail() {
    say "FAILED: $*"
    say "RESULT: FAILED. Steps before this one stay done; each has its own status and rollback."
    exit 2
}

sum_of() {
    cksum "$1" 2>/dev/null | { read -r a b rest && echo "$a $b"; }
}

# bounded <input> <command...>: run it with stdin from <input>, stopped
# after $budget seconds.
bounded() {
    b_in=$1
    shift
    "$@" < "$b_in" &
    b_pid=$!
    ( sleep "$budget"; kill -15 "$b_pid" 2>/dev/null; sleep 5; kill -9 "$b_pid" 2>/dev/null ) \
        > /dev/null 2>&1 &
    b_wd=$!
    wait "$b_pid"
    b_rc=$?
    kill -9 "$b_wd" 2>/dev/null
    wait "$b_wd" 2>/dev/null
    return "$b_rc"
}

# step <script> <args...>: one bundled script, logged; its exit status.
step() {
    s_name=$1
    shift
    say "\$ $s_name $*"
    bounded /dev/null "$ksh" "${pay}/${s_name}" "$@"
}

# status_of <script>: its status output, logged and kept in $status_out.
status_of() {
    say "\$ $1 status"
    status_out=$(bounded /dev/null "$ksh" "${pay}/$1" status 2>&1)
    echo "$status_out"
}

# The card's files, against the sums written when the module was built.
check_card() {
    [ -d "$pay" ] || fail "${pay} is not on the card"
    [ -f "$sums" ] || fail "${sums} is missing"
    cc_bad=0
    while read -r c_sum c_size c_name; do
        [ -n "$c_name" ] || continue
        if [ "$(sum_of "${pay}/${c_name}")" != "$c_sum $c_size" ]; then
            say "${c_name} does not match its sum ($c_sum $c_size): $(sum_of "${pay}/${c_name}")"
            cc_bad=1
        fi
    done < "$sums"
    [ "$cc_bad" = 0 ] || fail "the card's files are damaged or not this build's; copy them again"
    say "the card's files match ${sums}"
}

check_unit() {
    [ "$(uname -s)" = QNX ] || fail "run this on the MMI"
    for f in "$driver $driver_sum" "$dhcp_client $dhcp_client_sum"; do
        set -- $f
        if [ "$(sum_of "$1")" != "$2 $3" ]; then
            fail "$1 is $(sum_of "$1"), not the $2 $3 the station was validated with; this firmware is not supported, nothing was changed"
        fi
    done
    case "$(sum_of "$dhcp_up")" in
        "$dhcp_up_sum") say "the factory driver, dhcp.client and dhcp-up are the validated ones" ;;
        "$dhcp_up_drger_sum") say "the factory driver and dhcp.client are the validated ones; dhcp-up is DrGER's LTE one (accepted)" ;;
        *) fail "$dhcp_up is $(sum_of "$dhcp_up"), neither the factory $dhcp_up_sum nor DrGER's LTE $dhcp_up_drger_sum; nothing was changed" ;;
    esac
    [ -d "$persistence" ] || fail "${persistence} is absent (no HDD); nothing was changed"
}

# read_options: checks wifi-sta/options and sets opt_startup (client, ap or
# empty) and opt_allow (the inbound lines, "none", or empty). Changes
# nothing; fails on any line it does not know.
read_options() {
    opt_startup=
    opt_allow=
    opt_n=0
    [ -f "$card_options" ] || return 0
    while IFS= read -r o_line; do
        o_line=${o_line%%#*}
        set -- $o_line
        [ $# -gt 0 ] || continue
        o_line="$*"
        case $o_line in
            start-up=client|start-up=ap)
                opt_startup=${o_line#start-up=} ;;
            allow=none)
                opt_allow=none ;;
            allow=icmp)
                o_entry=icmp ;;
            "allow=tcp "*|"allow=udp "*)
                set -- ${o_line#allow=}
                [ $# = 2 ] || fail "options: \"$o_line\" needs one port; nothing was changed by the options"
                case $2 in
                    [1-9]|[1-9][0-9]|[1-9][0-9][0-9]|[1-9][0-9][0-9][0-9]|[1-9][0-9][0-9][0-9][0-9]) ;;
                    *) fail "options: \"$o_line\": the port must be 1-65535; nothing was changed by the options" ;;
                esac
                [ "$2" -le 65535 ] || fail "options: \"$o_line\": the port must be 1-65535; nothing was changed by the options"
                o_entry="$1 $2" ;;
            *) fail "options: unknown line \"$o_line\" in ${card_options}; nothing was changed by the options" ;;
        esac
        case $o_line in
            allow=icmp|"allow=tcp "*|"allow=udp "*)
                [ "$opt_allow" != none ] || continue
                opt_n=$((opt_n + 1))
                [ "$opt_n" -le "$inbound_max" ] || fail "options: more than $inbound_max allow= lines; nothing was changed by the options"
                opt_allow="${opt_allow:+$opt_allow
}$o_entry" ;;
        esac
    done < "$card_options"
    # allow=none anywhere wins over the other allow= lines.
    grep -q '^[ 	]*allow=none[ 	]*\(#.*\)*$' "$card_options" && opt_allow=none
    return 0
}

apply_options() {
    [ -f "$card_options" ] || return 0
    say "options from ${card_options}"
    case $opt_startup in
        client) : > "$marker" || fail "could not write $marker"
            say "start-up: join the networks at every start-up" ;;
        ap) rm -f "$marker"
            say "start-up: the car's access point" ;;
    esac
    case $opt_allow in
        '') say "inbound: unchanged" ;;
        none)
            rm -f "$inbound_file" "$telnet_marker"
            say "inbound: nothing admitted but DHCP replies" ;;
        *)
            echo "$opt_allow" > "$inbound_file.new.$$" && chmod 644 "$inbound_file.new.$$" &&
                mv -f "$inbound_file.new.$$" "$inbound_file" ||
                { rm -f "$inbound_file.new.$$"; fail "could not write $inbound_file"; }
            rm -f "$telnet_marker"
            say "inbound: $(echo $opt_allow | sed -e 's/icmp/ping/' -e 's/ \([a-z]\)/, \1/g') admitted from the station's own network"
            case "
$opt_allow
" in
                *"
tcp 23
"*) say "WARNING: telnet (tcp 23) is a root login with no password for everyone on that network" ;;
            esac ;;
    esac
    say "these take effect at the next station start"
}

install_all() {
    progress "checking the card"
    check_card
    progress "checking the unit"
    check_unit
    read_options
    say "train: $(cat /dev/shmem/sw_trainname.txt 2>/dev/null)"
    # gem-install.sh does not remount; the factory start-up mounts it
    # read-write, so this only makes sure.
    mount -uw "$efs_system" 2>/dev/null
    marker_was=absent
    [ -f "$marker" ] && marker_was=present
    say "GEM start-up choice before: hotspot client marker ${marker_was}"
    status_of sta-install.sh
    sta_before=$status_out
    status_of gem-install.sh
    gem_before=$status_out

    restart_for_flag=no
    if [ -f "$flag" ] && [ ! -s "$flag" ]; then
        say "the LAN-mode flag ${flag} is already set"
    else
        progress "setting LAN mode"
        step lan-mode.sh enable || fail "lan-mode.sh enable"
        restart_for_flag=yes
    fi

    # An earlier build's start-up line in the OpenSSH start-up comes out
    # first; its rollback also clears the marker, which is put back below.
    case $sta_before in
        *'an older build'*) step sta-install.sh unhook || fail "sta-install.sh unhook" ;;
    esac
    progress "installing station files"
    step sta-install.sh install "$pay" || fail "sta-install.sh install"

    if [ -f "$card_conf" ]; then
        progress "storing networks"
        # The passphrase line wpa_passphrase leaves as a comment is dropped:
        # the unit keeps only the derived key.
        tmp="${run}/wifi-sta-conf.$$"
        rm -f "$tmp"
        sed -e '/^[ 	]*#[ 	]*psk=/d' "$card_conf" > "$tmp" || { rm -f "$tmp"; fail "could not read ${card_conf}"; }
        say "\$ sta-install.sh conf < ${card_conf}"
        if bounded "$tmp" "$ksh" "${pay}/sta-install.sh" conf; then
            rm -f "$tmp" "$card_conf"
            if [ -f "$card_conf" ]; then
                say "WARNING: could not delete ${card_conf}; delete it from the card yourself"
            else
                say "${card_conf} stored on the unit and deleted from the card"
            fi
        else
            rm -f "$tmp"
            fail "sta-install.sh conf refused ${card_conf} (it stays on the card); see the README for its format"
        fi
    else
        status_of sta-install.sh > /dev/null
        case $status_out in
            *'wpa-hotspot.conf: present'*)
                say "no hotspot.conf on the card; the installed configuration stays" ;;
            *)
                say "WARNING: no hotspot configured. Put wifi-sta/hotspot.conf on the card and run it again." ;;
        esac
    fi

    case $gem_before in
        *'state: older'*) step gem-install.sh remove || fail "gem-install.sh remove" ;;
    esac
    progress "adding the GEM screen"
    step gem-install.sh install "$pay" || fail "gem-install.sh install"
    progress "adding the start-up hook"
    step sta-install.sh hook || fail "sta-install.sh hook"

    if [ "$marker_was" = present ] && [ ! -f "$marker" ] && [ -d "$gem_dir" ]; then
        : > "$marker" && say "GEM start-up choice kept: hotspot client"
    fi
    progress "applying options"
    apply_options

    step sta-install.sh status
    step gem-install.sh status
    step lan-mode.sh status
    say "RESULT: OK, installed."
    [ -z "${FORGE_NOTE:-}" ] || echo "Wi-Fi client installed: restart the MMI" > "$FORGE_NOTE" 2>/dev/null
    if [ "$restart_for_flag" = yes ]; then
        say "Restart the unit: the LAN-mode flag and the GEM screen take effect at the next start-up."
    else
        say "Restart the unit for the GEM to read the WifiClient screen (if it is new)."
    fi
    say "Then, in the GEM: WifiClient > \"Start station now\", or \"Start-up: join the hotspot\"."
}

remove_all() {
    progress "removing"
    [ "$(uname -s)" = QNX ] || fail "run this on the MMI"
    mount -uw "$efs_system" 2>/dev/null
    step sta-install.sh unhook || fail "sta-install.sh unhook"
    step sta-install.sh remove || fail "sta-install.sh remove"
    # The owner's inbound choices first, so the GEM removal can take the
    # directory.
    rm -f "$inbound_file" "$telnet_marker"
    step gem-install.sh remove || fail "gem-install.sh remove"
    step lan-mode.sh status
    say "RESULT: OK, removed. The LAN-mode flag stays; restart the unit."
}

say "card ${SDPATH}; unit clock $(date) (may count from start-up)"
if [ -f "$remove_flag" ]; then
    say "mode: remove (${remove_flag} is on the card)"
    remove_all
else
    say "mode: install"
    install_all
fi
exit 0
