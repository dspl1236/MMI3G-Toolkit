#!/bin/ksh
# Experimental MMI3G+ boot helper. See docs/PERSISTENT_TELNET.md before use.
# Despite the name, port 2323 is raw TCP, not a TELNET protocol server.
if [ "$#" -ne 1 ] || [ "$1" != --allow-unauthenticated-root ]; then
    echo 'Usage: persistent_telnet.sh --allow-unauthenticated-root' >&2
    echo 'WARNING: exposes a passwordless root shell on all network interfaces.' >&2
    exit 2
fi

PATH=/proc/boot:/bin:/sbin:/usr/bin:/usr/sbin
export PATH
unset ENV BASH_ENV LD_PRELOAD
LD_LIBRARY_PATH=/lib:/lib/dll:/usr/lib:/usr/lib/dll:/proc/boot:/j9/bin
export LD_LIBRARY_PATH
cd / || exit 1
trap '' HUP
umask 077

# Deliberately narrow: the startup pattern was exercised on QNX 6.3.2/SH7785.
[ "$(uname -s)" = QNX ] && [ "$(uname -r)" = 6.3.2 ] &&
    [ "$(uname -m)" = SH7785 ] || {
        echo 'UNSUPPORTED_PLATFORM: expected QNX 6.3.2 SH7785' >&2
        exit 1
    }
[ -x /usr/sbin/inetd ] && [ -x /bin/ksh ] || exit 1

# QNX /dev/shmem is flat: do not use mkdir here.
LOCK=/dev/shmem/mmi-persistent-telnet.lock
LOG=/dev/shmem/mmi-persistent-telnet.log
PROCESSES=/dev/shmem/mmi-persistent-telnet.processes
CONF=/dev/shmem/inetd_2323.conf
LINE='2323 stream tcp nowait root /bin/ksh ksh -i'
if ! (set -C; echo "$$" > "$LOCK") 2>/dev/null; then
    echo 'BUSY: lock exists; inspect it or reboot, do not start another helper.' >&2
    exit 1
fi
trap 'rm -f "$LOCK"' 0
trap 'exit 1' INT TERM
for file in "$LOG" "$PROCESSES" "$CONF"; do
    if [ -L "$file" ] || { [ -e "$file" ] && [ ! -f "$file" ]; }; then
        echo "UNSAFE_PATH: $file" >&2
        exit 1
    fi
done
exec < /dev/null > "$LOG" 2>&1
echo MMI_PERSISTENT_TELNET_START

# No watchdog and no service kills. A bounded wait avoids holding up boot;
# the boot hook MUST still launch this helper in the background.
n=0
while [ "$n" -lt 30 ]; do
    PTY_READY=0
    SYSTEM_INETD_READY=0
    pidin ar > "$PROCESSES" || exit 1
    while read -r P EXE ARG REST; do
        [ "$EXE" != /sbin/devc-pty ] || PTY_READY=1
        if [ "$EXE" = /usr/sbin/inetd ]; then
            if [ -z "$ARG$REST" ]; then
                SYSTEM_INETD_READY=1
            elif [ "$ARG" = "$CONF" ] || [ "$ARG $REST" = "-d $CONF" ]; then
                echo "EXISTING_INSTANCE=$P SHELL_NOT_TESTED"
                exit 0
            fi
        fi
    done < "$PROCESSES"
    # Readiness only, NOT a bind address or an access-control rule.
    if [ "$PTY_READY" -eq 1 ] && [ "$SYSTEM_INETD_READY" -eq 1 ] &&
       ifconfig 2>/dev/null | grep -Eq 'inet[[:space:]]+172\.16\.42\.1([[:space:]]|$)'; then
        break
    fi
    sleep 3
    n=$((n+1))
done
if [ "$n" -eq 30 ]; then
    echo "READINESS_TIMEOUT PTY=$PTY_READY SYSTEM_INETD=$SYSTEM_INETD_READY"
    exit 1
fi

# Refuse an unrelated configuration; never overwrite another console setup.
if [ -e "$CONF" ]; then
    [ "$(cat "$CONF")" = "$LINE" ] || {
        echo CONFIG_CONFLICT
        exit 1
    }
else
    (set -C; echo "$LINE" > "$CONF") || exit 1
fi
(trap '' HUP; exec /usr/sbin/inetd "$CONF" < /dev/null >> "$LOG" 2>&1) &
echo "START_REQUESTED PID=$! WAIT_TICKS=$n SHELL_NOT_TESTED"
exit 0
