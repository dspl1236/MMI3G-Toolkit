#!/bin/ksh
# Phases 7.4a, 7.4b and 7.6: the engineering-screen (GEM) buttons of the
# Wi-Fi client. The action is this file's name: gem-install.sh links
# "status", "client", "ap", "start" and "check" to it, and WifiClient.esd
# names those links. See docs/wifi-client/wifi-client-mode.md, "The GEM
# screen (7.4a), prepared offline", "The start button and persistent files
# (7.4b, 7.5)" and "Station mode at start-up (7.6)".
#
#   status  the start-up mode, the last start-up's lines, then sta-mode.sh
#           status if a copy is on the unit; otherwise which of uap0 and
#           en6 are present.
#   client  from the next start-up on, join the hotspot (sta-boot.sh reads
#           the marker this leaves).
#   ap      from the next start-up on, keep the car's access point (the
#           marker goes). Only a restart brings the access point back.
#   check   what the GEM's runner gives a script: user, parent, environment,
#           open files, the FIFO, how wide a line the console shows and
#           whether lines appear as they are written.
#   start   sta-mode.sh start from the installed station files (7.5), if
#           this press is fresh, the start is not disabled and the files
#           match their sums. The access point is gone until the restart.
#
# The GEM's JVM runs "/bin/ksh -c '<path> >/scripts/script.fifo'" and its
# console shows each line until every writer has closed the FIFO; until then
# no other script button works. So everything here is bounded, and nothing
# started from here may keep this script's output open. stderr is not
# redirected by the GEM, hence the exec below. Every line also goes to
# gem.log beside this file, which is what to read afterwards over SSH.
exec 2>&1
set -u
umask 022
preload=${LD_PRELOAD-unset}
inherited_path=${PATH-unset}
inherited_libs=${LD_LIBRARY_PATH-unset}
# The factory boot environment preloads libmc.so; see sta-mode.sh.
unset LD_PRELOAD || :
PATH=/bin:/sbin:/usr/bin:/usr/sbin
export PATH

dir=/mnt/efs-persist/wifi-sta/gem
log_file=$dir/gem.log
log_max=32768
run=/fs/tmpfs
fifo=/scripts/script.fifo
# The station files on the HDD (7.5), from sta-install.sh; SUMS is written
# last and lists each file with its cksum.
sta_home=/mnt/persistence/wifi-sta
sta_sums=$sta_home/SUMS
# The persistent copy first, then a 7.3-style copy in RAM.
sta_candidates="$sta_home/sta-mode.sh /fs/tmpfs/sta-mode.sh"
# A file here stops the start button and the start at start-up, whatever
# else is installed.
kill_switch=$dir/start.disabled
# Present: sta-boot.sh starts the station at start-up. Absent: the car's
# access point, the factory default.
marker=$dir/client-at-start-up
boot_log=$sta_home/boot.log
# sta-mode.sh start: up to about 60 s of checks, then it follows its own
# log for at most 300 s.
start_limit=420
# A press older than this many minutes is not acted on (see fresh_press).
press_minutes=2
action=${0##*/}

# The unit has no calendar time: its clock counts from the epoch at start-up.
out() {
    echo "$*"
    echo "$(date '+%H:%M:%S') $action: $*" >> "$log_file" 2>/dev/null
    return 0
}
# Into the log only.
note() {
    echo "$(date '+%H:%M:%S') $action: $*" >> "$log_file" 2>/dev/null
    return 0
}
note_file() {
    sed -e "s/^/    /" "$1" >> "$log_file" 2>/dev/null
    return 0
}

# Diagnostics on this unit can hang (pidin on some processes does).
bounded() {
    bounded_limit=$1
    bounded_out=$2
    shift 2
    "$@" > "$bounded_out" 2>&1 < /dev/null &
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

# One older generation is kept; the unit has no wc, so ls gives the size.
rotate() {
    [ -f "$log_file" ] || return 0
    set -- $(ls -l "$log_file" 2>/dev/null)
    [ "${5:-0}" -le "$log_max" ] 2>/dev/null && return 0
    mv -f "$log_file" "$log_file.old" 2>/dev/null
    return 0
}

present() {
    if ifconfig "$1" > /dev/null 2>&1; then echo present; else echo absent; fi
}

mode_now() {
    if [ -f "$marker" ]; then echo "hotspot client"; else echo "car access point"; fi
}

cmd_status() {
    out "start-up mode: $(mode_now)"
    if [ -f "$boot_log" ]; then
        # The last start-up's own lines, without sta-mode.sh's indented ones.
        n=$(sed -n '/ boot: start-up,/=' "$boot_log" | sed -n '$p')
        [ -z "$n" ] || sed -n "$n,\$p" "$boot_log" | grep -v '^    ' |
            while IFS= read -r line; do out "$line"; done
    fi
    sta=
    for f in $sta_candidates; do
        if [ -f "$f" ]; then
            sta=$f
            break
        fi
    done
    if [ -z "$sta" ]; then
        out "sta-mode.sh is not on this unit"
        out "(RAM copies are gone after a restart)"
        out "uap0 $(present uap0), en6 $(present en6)"
        return 0
    fi
    out "$sta"
    tmp=$run/wifi-gem-status.$$
    if bounded 90 "$tmp" /bin/ksh "$sta" status; then
        rc=0
    else
        rc=$?
    fi
    note_file "$tmp"
    # sta-mode.sh prints "sta: " before each line; the console is narrow.
    sed -e 's/^sta: //' "$tmp"
    rm -f "$tmp"
    out "exit $rc (0 OK or not started, 2 FAIL, 3 PARTIAL)"
}

cmd_check() {
    tmp=$run/wifi-gem-check.$$
    out "runner check, unit clock $(date '+%H:%M:%S')"
    out "pid $$, parent $PPID"
    # No id on the unit: a new file's owner is the effective user.
    probe=$dir/.owner.$$
    if ( : > "$probe" ) 2>/dev/null; then
        set -- $(ls -l "$probe" 2>/dev/null)
        out "user ${3:-unknown}, group ${4:-unknown}"
        rm -f "$probe"
    else
        out "cannot write $dir"
    fi
    out "LD_PRELOAD $preload"
    out "PATH $inherited_path"
    note "LD_LIBRARY_PATH $inherited_libs"
    out "cwd $(pwd)"
    out "umask $(umask)"
    set -- $(ls -l "$fifo" 2>/dev/null)
    out "fifo ${1:-absent}"
    # The parent last: its listing is the one read below.
    for p in $$ $PPID; do
        if bounded 10 "$tmp" pidin -p "$p"; then
            note "pidin -p $p:"
        else
            note "pidin -p $p (timed out):"
        fi
        note_file "$tmp"
    done
    # pidin -p: a header, then "pid tid name prio state ..." per thread.
    set -- $(sed -n 2p "$tmp" 2>/dev/null)
    out "parent name ${3:-unknown}"
    # The parent is the GEM's "ksh -c"; family names its parent in turn.
    bounded 10 "$tmp" pidin -p "$PPID" family
    note "pidin -p $PPID family:"
    note_file "$tmp"
    if bounded 10 "$tmp" pidin -p $$ fds; then
        n=$(sed -n '$=' "$tmp")
        out "open files: ${n:-0} lines (see log)"
    else
        out "pidin fds timed out"
    fi
    note "pidin -p $$ fds:"
    note_file "$tmp"
    export > "$tmp" 2>&1
    note "export:"
    note_file "$tmp"
    rm -f "$tmp"
    out "width ruler, 80 characters:"
    out "----+----1----+----2----+----3----+----4----+----5----+----6----+----7----+----8"
    out "A: now; B follows in 3 s"
    sleep 3
    out "B: 3 s after A"
    out "check done"
}

# "Jan 01 00:06" from ls -l, as minutes; the month and day as they stand.
stamp_of() {
    set -- $(ls -l "$1" 2>/dev/null)
    [ $# -ge 8 ] || return 1
    stamp_day="$6 $7"
    case $8 in
        [0-9][0-9]:[0-9][0-9]) ;;
        *) return 1 ;;
    esac
    stamp_time=$8
    stamp_h=${8%:*}
    stamp_m=${8#*:}
    # A leading zero would make ksh read octal.
    stamp_minutes=$(( ${stamp_h#0} * 60 + ${stamp_m#0} ))
}

# Each press recreates the FIFO (rm, mkfifo) just before the script is
# launched, and the launch then waits in its redirect until the console
# opens the FIFO. If the console lost the factory race, nothing opens it
# until someone does so by hand, maybe much later. So the FIFO's time, from
# before this script wrote to it, has to be within a few minutes of now. A
# fresh file in RAM gives "now" in the same format.
fresh_press() {
    now_file=$run/wifi-gem-now.$$
    : > "$now_file"
    stamp_of "$now_file"
    now_rc=$?
    rm -f "$now_file"
    [ "$now_rc" = 0 ] || { press_age="unknown (no clock in $run)"; return 1; }
    now_day=$stamp_day
    now_time=$stamp_time
    now_minutes=$stamp_minutes
    if [ ! -p "$fifo" ] || ! stamp_of "$fifo"; then
        press_age="unknown ($(ls -l "$fifo" 2>&1))"
        return 1
    fi
    press_age="$stamp_day $stamp_time, now $now_day $now_time"
    [ "$stamp_day" = "$now_day" ] || return 1
    [ $((now_minutes - stamp_minutes)) -le "$press_minutes" ] &&
        [ "$now_minutes" -ge "$stamp_minutes" ]
}

# Every file sta-install.sh listed, against its cksum.
sums_ok() {
    [ -s "$sta_sums" ] || { out "no $sta_sums: the station files are not installed"; return 1; }
    sums_bad=0
    while read -r s_sum s_size s_name; do
        [ -n "$s_name" ] || continue
        if bounded 60 "$tmp" cksum "$sta_home/$s_name"; then
            set -- $(cat "$tmp")
            [ "$1 $2" = "$s_sum $s_size" ] && continue
        fi
        out "$s_name does not match its sum: $(sed -e '1!d' "$tmp")"
        sums_bad=1
    done < "$sta_sums"
    [ "$sums_bad" = 0 ]
}

# The start's new lines since the last call. sta-mode.sh begins each line
# with "sta: ", after the time in its log lines; the console is narrow.
start_show() {
    start_lines=$(sed -n '$=' "$tmp")
    start_lines=${start_lines:-0}
    [ "$start_lines" -gt "$start_seen" ] || return 0
    sed -n "$((start_seen + 1)),${start_lines}p" "$tmp" |
        sed -e 's/^sta: //' -e 's/^\([0-9:]* \)sta: /\1/' |
        while IFS= read -r line; do out "$line"; done
    start_seen=$start_lines
}

cmd_start() {
    # First, before anything goes to the console: a write may change the
    # FIFO's time.
    if ! fresh_press; then
        out "not started: this press is not recent (pressed $press_age)."
        out "Restart the unit, wait a few minutes, then press again."
        return 0
    fi
    note "press $press_age"
    if [ -e "$kill_switch" ]; then
        out "not started: the start is disabled ($kill_switch)."
        return 0
    fi
    sta=$sta_home/sta-mode.sh
    tmp=$run/wifi-gem-start.$$
    sums_ok || { rm -f "$tmp"; out "not started: run sta-install.sh status over SSH."; return 0; }
    out "files match SUMS; sta-mode.sh start follows."
    out "If it starts, the access point is off until the restart."
    : > "$tmp"
    # Its own output goes to a file, never to the FIFO, so a start that
    # outlives this script cannot hold the console.
    ( trap '' 1; exec /bin/ksh "$sta" start ) < /dev/null > "$tmp" 2>&1 &
    start_pid=$!
    start_seen=0
    start_waited=0
    while :; do
        start_show
        kill -0 "$start_pid" 2>/dev/null || break
        if [ "$start_waited" -ge "$start_limit" ]; then
            out "still running after ${start_limit}s; press Station status later."
            note "left $tmp in place"
            return 0
        fi
        sleep 1
        start_waited=$((start_waited + 1))
    done
    if wait "$start_pid"; then rc=0; else rc=$?; fi
    start_show
    rm -f "$tmp"
    out "exit $rc (0 OK, 2 refused or FAIL, 3 PARTIAL)"
}

# Sets the start-up mode. Like start, a held-up press is not acted on.
cmd_mode() {
    if ! fresh_press; then
        out "not changed: this press is not recent (pressed $press_age)."
        out "start-up mode: $(mode_now)"
        return 0
    fi
    case $1 in
        client)
            : > "$marker.new.$$" && mv -f "$marker.new.$$" "$marker" ||
                { rm -f "$marker.new.$$"; out "could not write $marker"; }
            [ ! -e "$kill_switch" ] || out "but the start is disabled ($kill_switch)."
            out "start-up mode: $(mode_now)"
            out "From the next start-up, the unit joins the hotspot."
            out "Press Start station now to join it without a restart." ;;
        ap)
            rm -f "$marker"
            out "start-up mode: $(mode_now)"
            out "Restart the unit to get the car's access point back."
            out "(Stopping the station by hand leaves it without a network name.)" ;;
    esac
}

rotate
note "start (LD_PRELOAD $preload)"
case $action in
    status) cmd_status ;;
    check) cmd_check ;;
    start) cmd_start ;;
    client|ap) cmd_mode "$action" ;;
    *) out "unknown action $action: run as status, client, ap, start or check" ;;
esac
note "end"
exit 0
