#!/bin/ksh
# ============================================================
# shell_fix.sh — Robust root shell on port 2323
# 
# The original "ksh -i" approach doesn't properly pipe I/O
# through inetd sockets on QNX 6.3.2. This script:
#   1. Kills any existing backdoor inetd
#   2. Starts devc-pty if not running (for proper TTY support)
#   3. Launches a new inetd with sh -c wrapper for I/O redirect
#   4. Also tries to enable passwordless login on port 23
#
# Run from root shell or add to copie_scr SD card
# ============================================================

echo "[shell_fix] Starting..."

# Kill any existing backdoor inetd instances
# (the main system inetd PID is high, backdoor ones from /tmp are separate)
for pid in $(pidin -F "%a %N" 2>/dev/null | grep "inetd_backdoor" | sed 's/^ *//' | cut -d' ' -f1); do
    slay -p $pid 2>/dev/null
    echo "[shell_fix] Killed old backdoor inetd PID $pid"
done

# Ensure devc-pty is running (provides /dev/ptyp* devices)
if ! pidin -F "%N" 2>/dev/null | grep -q devc-pty; then
    /sbin/devc-pty &
    sleep 1
    echo "[shell_fix] Started devc-pty"
else
    echo "[shell_fix] devc-pty already running"
fi

# Method 1: Shell with proper I/O redirect (most compatible)
TMPCONF="/tmp/inetd_shell.conf"
echo '2323 stream tcp nowait root /bin/sh sh -c "exec /bin/ksh 2>&1"' > "$TMPCONF"
/usr/sbin/inetd "$TMPCONF" 2>/dev/null &
echo "[shell_fix] Shell listener on port 2323 (sh wrapper)"

# Method 2: Telnetd on port 2324 (proper PTY, but needs login)
TMPCONF2="/tmp/inetd_telnet.conf"
echo "2324 stream tcp nowait root /usr/sbin/telnetd telnetd" > "$TMPCONF2"
/usr/sbin/inetd "$TMPCONF2" 2>/dev/null &
echo "[shell_fix] Telnet on port 2324 (login required)"

# Method 3: Try to make telnet passwordless
# /etc/shadow is in IFS (read-only) but we can try to override
# by creating a writable copy and bind-mounting
if [ -f /etc/shadow ]; then
    SHADOW_ORIG=$(cat /etc/shadow 2>/dev/null)
    echo "[shell_fix] Current shadow: $SHADOW_ORIG"
    
    # Try writing directly (will fail if IFS)
    echo "root::177:0:0" > /etc/shadow 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "[shell_fix] *** PASSWORD CLEARED! telnet port 23 = root, no password ***"
    else
        echo "[shell_fix] /etc/shadow is read-only (IFS)"
        echo "[shell_fix] Port 23 still requires password"
    fi
fi

# Verify
echo ""
echo "[shell_fix] === Status ==="
echo "  Port 2323: $(echo '' | nc.shle -w 1 127.0.0.1 2323 2>/dev/null && echo 'LISTENING' || echo 'check manually')"
echo "  Port 2324: $(echo '' | nc.shle -w 1 127.0.0.1 2324 2>/dev/null && echo 'LISTENING' || echo 'check manually')"  
echo "  Port 23:   $(echo '' | nc.shle -w 1 127.0.0.1 23 2>/dev/null && echo 'LISTENING' || echo 'check manually')"
echo ""
echo "[shell_fix] Connect with:"
echo "  PuTTY → Raw → 192.168.0.154:2323  (type blind, output shows)"
echo "  PuTTY → Telnet → 192.168.0.154:2324 (login prompt)"
echo "  telnet 192.168.0.154 (port 23, login prompt)"
echo ""
echo "[shell_fix] Done."
