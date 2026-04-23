#!/bin/ksh
# ============================================================
# MMI3G-Toolkit — Combined Installer + Persistent Shell
# ============================================================

SDPATH="${1:-$(dirname $0)}"
export SDPATH

# Source platform.sh for QNX compatibility shims
if [ -f "${SDPATH}/scripts/common/platform.sh" ]; then
    . "${SDPATH}/scripts/common/platform.sh"
fi

# Show "running" status on MMI display
if [ -f "${SDPATH}/bin/showScreen" ] && [ -f "${SDPATH}/lib/running.png" ]; then
    cp "${SDPATH}/bin/showScreen" /tmp/showScreen 2>/dev/null
    chmod +x /tmp/showScreen 2>/dev/null
    /tmp/showScreen "${SDPATH}/lib/running.png" &
    SHOWSCREEN_PID=$!
fi

LOGFILE="${SDPATH}/var/install-$(date +%Y%m%d-%H%M%S 2>/dev/null || echo install).log"
EFSDIR="/mnt/efs-system"
EFSPERSIST="/mnt/efs-persist"

exec > ${LOGFILE} 2>&1

echo "============================================"
echo " MMI3G-Toolkit Installer"
echo " $(date 2>/dev/null)"
echo " Train: $(cat /dev/shmem/sw_trainname.txt 2>/dev/null)"
echo "============================================"
echo ""

# Safety checks
if [ ! -d "${EFSDIR}" ]; then
    echo "[ERROR] /mnt/efs-system not found!"
    exit 1
fi

# Remount read-write
mount -uw ${EFSDIR} 2>/dev/null
echo "[OK] efs-system remounted rw"

mount -uw ${EFSPERSIST} 2>/dev/null
echo "[OK] efs-persist remounted rw"
echo ""

# ============================================================
# STEP 1: Immediate backdoor (same-session, like before)
# ============================================================
echo "[STEP 1] Starting immediate root shell on port 2323..."
TMPCONF="/tmp/inetd_backdoor.conf"
echo "2323 stream tcp nowait root /bin/ksh ksh -i" > "$TMPCONF"
/usr/sbin/inetd "$TMPCONF" 2>/dev/null &
echo "[OK] Shell listener on port 2323 (this session)"
echo ""

# ============================================================
# STEP 2: PERSISTENT backdoor — survives reboot
# ============================================================
echo "[STEP 2] Making shell PERSISTENT across reboots..."

# Method A: Add to system inetd.conf (writable on EFS)
INETD_CONF="/etc/inetd.conf"
INETD_EFS="${EFSDIR}/etc/inetd.conf"

# Check if inetd.conf is on writable EFS or read-only IFS
if [ -f "${INETD_EFS}" ]; then
    INETD_TARGET="${INETD_EFS}"
    echo "  [INFO] inetd.conf found on EFS (writable)"
elif [ -f "${INETD_CONF}" ]; then
    INETD_TARGET="${INETD_CONF}"
    echo "  [INFO] inetd.conf found at ${INETD_CONF}"
else
    INETD_TARGET=""
    echo "  [WARN] No inetd.conf found"
fi

if [ -n "$INETD_TARGET" ]; then
    if grep -q "2323" "$INETD_TARGET" 2>/dev/null; then
        echo "  [OK] Port 2323 already in inetd.conf"
    else
        # Backup first
        cp "$INETD_TARGET" "${SDPATH}/var/inetd.conf.bak" 2>/dev/null
        echo "" >> "$INETD_TARGET"
        echo "# MMI3G-Toolkit root shell (persistent)" >> "$INETD_TARGET"
        echo "2323 stream tcp nowait root /bin/ksh ksh -i" >> "$INETD_TARGET"
        echo "  [OK] Added port 2323 to ${INETD_TARGET}"
        echo "  [OK] Backup at ${SDPATH}/var/inetd.conf.bak"
        
        # Signal inetd to reload config
        INETD_PID=$(pidin -F "%a %N" 2>/dev/null | grep inetd | sed 's/[^0-9].*//;s/^ *//' | grep -v '^$')
        if [ -n "$INETD_PID" ]; then
            # Can't easily send SIGHUP without kill -HUP, try slay
            kill -1 $INETD_PID 2>/dev/null
            echo "  [OK] Sent HUP to inetd (PID $INETD_PID)"
        fi
    fi
fi

# Method B: Startup script in persistent location (fallback)
STARTUP_SCRIPT="${EFSDIR}/scripts/start_shell.sh"
mkdir -p "${EFSDIR}/scripts" 2>/dev/null
cat > "$STARTUP_SCRIPT" << 'SHELLEOF'
#!/bin/ksh
# Persistent root shell on port 2323
# Installed by MMI3G-Toolkit
CONF="/tmp/inetd_shell.conf"
echo "2323 stream tcp nowait root /bin/ksh ksh -i" > "$CONF"
/usr/sbin/inetd "$CONF" &
SHELLEOF
chmod +x "$STARTUP_SCRIPT" 2>/dev/null
echo "  [OK] Fallback startup script at ${STARTUP_SCRIPT}"
echo ""

# ============================================================
# STEP 3: System info dump
# ============================================================
echo "[STEP 3] Running system info dump..."
if [ -f "${SDPATH}/scripts/sysinfo_dump.sh" ]; then
    ksh "${SDPATH}/scripts/sysinfo_dump.sh" "${SDPATH}"
    echo "[OK] System info collected"
else
    echo "[SKIP] sysinfo_dump.sh not found"
fi

# Install sysinfo script to EFS for future runs
SCRIPTDIR="${EFSDIR}/scripts/SystemInfo"
mkdir -p ${SCRIPTDIR} 2>/dev/null
if [ -f "${SDPATH}/scripts/sysinfo_dump.sh" ]; then
    cp "${SDPATH}/scripts/sysinfo_dump.sh" "${SCRIPTDIR}/sysinfo_dump.sh" 2>/dev/null
    chmod +x "${SCRIPTDIR}/sysinfo_dump.sh" 2>/dev/null
fi

# Install platform.sh
if [ -f "${SDPATH}/scripts/common/platform.sh" ]; then
    mkdir -p "${EFSDIR}/scripts/common" 2>/dev/null
    cp "${SDPATH}/scripts/common/platform.sh" "${EFSDIR}/scripts/common/platform.sh" 2>/dev/null
fi
echo ""

# ============================================================
# STEP 4: Dump credentials
# ============================================================
echo "[STEP 4] Dumping login credentials..."
mkdir -p "${SDPATH}/var" 2>/dev/null
{
    echo "=== /etc/passwd ==="
    cat /etc/passwd 2>&1
    echo ""
    echo "=== /etc/shadow ==="
    cat /etc/shadow 2>&1
} > "${SDPATH}/var/passwd_dump.txt" 2>&1
echo "[OK] Credentials dumped"
echo ""

# ============================================================
# STEP 5: Google Earth — probe and prep
# ============================================================
echo "[STEP 5] Google Earth probe..."

# Check GEMMI status
GEMMI_RUNNING=0
if pidin 2>/dev/null | grep -q gemmi_final; then
    GEMMI_RUNNING=1
    echo "  [OK] gemmi_final is RUNNING"
else
    echo "  [INFO] gemmi_final not running"
fi

# Check where /lsd/ actually lives
echo "  --- /lsd/ mapping ---"
ls -la /lsd/ 2>&1 | sed 's/^/  /'
echo "  --- /lsd/lsd.jxe ---"
ls -la /lsd/lsd.jxe 2>&1 | sed 's/^/  /'
cksum /lsd/lsd.jxe 2>&1 | sed 's/^/  /'

# Check if modified lsd.jxe is on SD card
if [ -f "${SDPATH}/lsd_ge_enabled.jxe" ]; then
    echo ""
    echo "  [FOUND] Modified lsd.jxe on SD card!"
    echo "  Size: $(ls -la "${SDPATH}/lsd_ge_enabled.jxe" | sed 's/  */ /g' | cut -d' ' -f5) bytes"
    cksum "${SDPATH}/lsd_ge_enabled.jxe" 2>&1 | sed 's/^/  /'
    
    # Try to deploy — copy to nav HDD (writable, large)
    DEPLOY_DIR="/mnt/nav/gemmi"
    mkdir -p "$DEPLOY_DIR" 2>/dev/null
    if [ -d "$DEPLOY_DIR" ]; then
        cp "${SDPATH}/lsd_ge_enabled.jxe" "${DEPLOY_DIR}/lsd_patched.jxe" 2>/dev/null
        echo "  [OK] Copied to ${DEPLOY_DIR}/lsd_patched.jxe"
        echo "  [INFO] To activate: need to redirect /lsd/lsd.jxe → this file"
        echo "  [INFO] Or repack IFS with patched lsd.jxe and reflash"
    fi
fi

# Check drivers.ini for disableAuthKey
DRIVERS_INI="${EFSDIR}/lsd/drivers.ini"
if [ -f "$DRIVERS_INI" ]; then
    if grep -q "disableAuthKey" "$DRIVERS_INI" 2>/dev/null; then
        echo "  [OK] disableAuthKey already set in drivers.ini"
    else
        cp "$DRIVERS_INI" "${SDPATH}/var/drivers.ini.bak" 2>/dev/null
        echo "" >> "$DRIVERS_INI"
        echo "    ; Google Earth auth bypass (MMI3G-Toolkit)" >> "$DRIVERS_INI"
        echo "    Connection/disableAuthKey = true" >> "$DRIVERS_INI"
        echo "  [OK] Added disableAuthKey to drivers.ini"
    fi
fi

# Probe network for GE servers
echo ""
echo "  --- Google Earth server check ---"
ping -c 1 -w 2 kh.google.com 2>&1 | sed 's/^/  /' | grep -v "^$"
echo ""

# ============================================================
# STEP 6: Filesystem mapping (for research)
# ============================================================
echo "[STEP 6] Filesystem mapping for /lsd/..."
{
    echo "=== /lsd/ directory ==="
    ls -la /lsd/ 2>&1
    echo ""
    echo "=== mount points ==="
    mount 2>&1
    echo ""
    echo "=== /lsd/lsd.jxe file type ==="
    ls -la /lsd/lsd.jxe 2>&1
    cksum /lsd/lsd.jxe 2>&1
    echo ""
    echo "=== Can we write to /lsd/? ==="
    touch /lsd/.test_write 2>&1
    if [ -f /lsd/.test_write ]; then
        echo "YES - /lsd/ is WRITABLE!"
        rm /lsd/.test_write 2>/dev/null
    else
        echo "NO - /lsd/ is READ-ONLY (IFS)"
    fi
    echo ""
    echo "=== Writable locations ==="
    echo "HBpersistence: $(df /HBpersistence 2>/dev/null | grep -v Filesystem)"
    echo "efs-system:    $(df /mnt/efs-system 2>/dev/null | grep -v Filesystem)"
    echo "efs-persist:   $(df /mnt/efs-persist 2>/dev/null | grep -v Filesystem)"
    echo "nav HDD:       $(df /mnt/nav 2>/dev/null | grep -v Filesystem)"
    echo "persistence:   $(df /mnt/persistence 2>/dev/null | grep -v Filesystem)"
} > "${SDPATH}/var/lsd_mapping.txt" 2>&1
echo "[OK] /lsd/ mapping saved to var/lsd_mapping.txt"
echo ""

# ============================================================
# Summary
# ============================================================
echo "============================================"
echo " Installation Complete"
echo "============================================"
echo ""
echo " Backdoor:    port 2323 (immediate + persistent)"
echo " GEMMI:       $([ $GEMMI_RUNNING -eq 1 ] && echo 'RUNNING' || echo 'not running')"
echo " Sysinfo:     var/sysinfo/"
echo " Credentials: var/passwd_dump.txt"
echo " LSD mapping: var/lsd_mapping.txt"
echo " Log:         ${LOGFILE}"
echo ""
echo " Connect: telnet 192.168.0.154 2323"
echo "============================================"

# Show "done" status on MMI display
if [ -x /tmp/showScreen ] && [ -f "${SDPATH}/lib/done.png" ]; then
    kill ${SHOWSCREEN_PID} 2>/dev/null
    sleep 1
    /tmp/showScreen "${SDPATH}/lib/done.png" &
fi
