#!/bin/ksh
# ============================================================
# MMI3G-Toolkit — Google Earth Restoration
# EXPERIMENTAL — Based on binary analysis, NOT yet car-tested
#
# What this does:
#   1. Probes current GEMMI/Google Earth state
#   2. Checks if GEMMI binaries are present
#   3. Adds disableAuthKey to drivers.ini
#   4. Optionally sets up /etc/hosts DNS redirect
#   5. Dumps diagnostic info for community analysis
#
# Requirements:
#   - Active internet connection (USB ethernet + LTE router)
#   - MMI3G+ with firmware K0900 or newer
#   - GEM enabled (CAR + BACK)
#
# Based on research from:
#   - Binary analysis of gemmi_final + libembeddedearth.so
#   - Live server testing (kh.google.com still responds!)
#   - Congo/audi-mib.bg protocol reverse engineering
#   - DrGER2 GEMMI Monitor research
#
# Part of MMI3G-Toolkit: github.com/dspl1236/MMI3G-Toolkit
# ============================================================

# --- platform.sh ---
_SDPATH_GUESS="${SDPATH:-${0%/*}}"
if [ -f "${_SDPATH_GUESS}/scripts/common/platform.sh" ]; then
    . "${_SDPATH_GUESS}/scripts/common/platform.sh"
elif [ -f "/mnt/efs-system/scripts/common/platform.sh" ]; then
    . "/mnt/efs-system/scripts/common/platform.sh"
fi

SDPATH="${_SDPATH_GUESS}"
TS=$(date +%H%M%S 2>/dev/null || echo "000000")
if command -v getTime >/dev/null 2>&1; then TS="epoch-$(getTime)"; fi

OUTDIR="${SDPATH}/var/google-earth"
REPORT="${OUTDIR}/ge-probe-${TS}.txt"
mkdir -p "${OUTDIR}" 2>/dev/null

# Show status
if [ -x "${SDPATH}/bin/showScreen" ] && [ -f "${SDPATH}/lib/running.png" ]; then
    "${SDPATH}/bin/showScreen" "${SDPATH}/lib/running.png" 2>/dev/null &
    SHOW_PID=$!
fi

exec > "${REPORT}" 2>&1

echo "################################################################"
echo "#  MMI3G-Toolkit — Google Earth Restoration Probe"
echo "#  Generated: $(date)"
echo "#  Train: $(cat /dev/shmem/sw_trainname.txt 2>/dev/null || echo 'n/a')"
echo "#  EXPERIMENTAL — NOT YET CAR-TESTED"
echo "################################################################"
echo ""

# ============================================================
# SECTION 1: GEMMI Binary Inventory
# ============================================================
echo "================================================================"
echo "  GEMMI Binary Inventory"
echo "================================================================"
echo ""

GEMMI_FOUND=0

# Check standard GEMMI locations
for dir in /mnt/nav/gemmi /mnt/efs-system/gemmi /HBpersistence/gemmi \
           /mnt/efs-system/lsd/gemmi /mnt/persistence/gemmi; do
    if [ -d "$dir" ]; then
        echo "[FOUND] GEMMI directory: $dir"
        ls -la "$dir" 2>/dev/null
        GEMMI_FOUND=1
        echo ""
    fi
done

# Check for gemmi_final binary
for path in /mnt/nav/gemmi/gemmi_final /mnt/efs-system/gemmi/gemmi_final \
            /mnt/nav/gemmi/gemmi_final \
            /HBpersistence/gemmi_final \
            /usr/apps/gemmi_final; do
    if [ -f "$path" ]; then
        echo "[FOUND] gemmi_final: $path ($(ls -la "$path" | awk '{print $5}') bytes)"
        GEMMI_FOUND=1
    fi
done

# Check for libembeddedearth.so
for path in /mnt/efs-system/gemmi/libembeddedearth.so \
            /mnt/nav/gemmi/libembeddedearth.so \
            /usr/lib/libembeddedearth.so; do
    if [ -f "$path" ]; then
        echo "[FOUND] libembeddedearth.so: $path ($(ls -la "$path" | awk '{print $5}') bytes)"
    fi
done

# Check for run_gemmi.sh
for path in /mnt/efs-system/gemmi/run_gemmi.sh \
            /mnt/nav/gemmi/run_gemmi.sh; do
    if [ -f "$path" ]; then
        echo "[FOUND] run_gemmi.sh: $path"
        cat "$path" 2>/dev/null
    fi
done

if [ $GEMMI_FOUND -eq 0 ]; then
    echo "[WARN] No GEMMI binaries found on this system"
    echo "[INFO] GEMMI may need to be deployed from EU firmware"
fi
echo ""

# ============================================================
# SECTION 2: Current drivers.ini State
# ============================================================
echo "================================================================"
echo "  drivers.ini — Connection Settings"
echo "================================================================"
echo ""

DRIVERS_INI="/mnt/efs-system/lsd/drivers.ini"
DRIVERS_INI_GEMMI="/mnt/nav/gemmi/drivers.ini"

# Check both locations — EFS copy and GEMMI copy
FOUND_INI=""
for _ini in "$DRIVERS_INI" "$DRIVERS_INI_GEMMI"; do
    if [ -f "$_ini" ]; then
        FOUND_INI="$_ini"
        echo "[FOUND] $_ini"
        cat "$_ini"
        echo ""

        # Check for disableAuthKey
        if grep -q "disableAuthKey" "$_ini" 2>/dev/null; then
            echo "[INFO] disableAuthKey PRESENT in $_ini"
        else
            echo "[INFO] disableAuthKey NOT in $_ini"
        fi
        echo ""
    fi
done

if [ -z "$FOUND_INI" ]; then
    echo "[WARN] drivers.ini not found at either:"
    echo "       $DRIVERS_INI"
    echo "       $DRIVERS_INI_GEMMI"
    FOUND_INI="MISSING"
fi
echo ""

# ============================================================
# SECTION 3: Network Connectivity
# ============================================================
echo "================================================================"
echo "  Network Status"
echo "================================================================"
echo ""

echo "--- Interfaces ---"
ifconfig 2>/dev/null | grep -A2 "en5\|ppp0\|mam0"

echo ""
echo "--- DNS Configuration ---"
cat /etc/resolv.conf 2>/dev/null || echo "No resolv.conf"
echo ""

echo "--- /etc/hosts ---"
cat /etc/hosts 2>/dev/null || echo "No hosts file (normal for QNX)"
echo ""

echo "--- Route Table ---"
route -n show 2>/dev/null | grep default
echo ""

echo "--- Connectivity Test ---"
# Try to ping Google's tile server
if command -v ping >/dev/null 2>&1; then
    echo "Ping kh.google.com:"
    ping -c 1 -w 3 kh.google.com 2>&1 | head -3
else
    echo "ping not available"
fi
echo ""

echo "--- Google Earth Server Tests ---"
# Test the 4 key endpoints we need for Google Earth
# kh.google.com/dbRoot.v5 = tile config (MUST return data)
# kh.google.com/geauth = auth endpoint (DEAD, should 404)
# auth.keyhole.com = legacy auth (DEAD)

# Try wget first (most likely on QNX), then curl, then raw TCP
HTTP_TOOL=""
if command -v wget >/dev/null 2>&1; then
    HTTP_TOOL="wget"
elif command -v curl >/dev/null 2>&1; then
    HTTP_TOOL="curl"
fi

if [ -n "$HTTP_TOOL" ]; then
    echo "HTTP tool: $HTTP_TOOL"
    echo ""

    # Test 1: Tile server (dbRoot.v5) — CRITICAL
    echo "  [TEST] kh.google.com/dbRoot.v5 (tile config):"
    if [ "$HTTP_TOOL" = "wget" ]; then
        RESULT=$(wget -q -O /dev/null --spider -S "http://kh.google.com/dbRoot.v5" 2>&1 | head -5)
    else
        RESULT=$(curl -s -o /dev/null -w "HTTP %{http_code} (%{size_download} bytes)" "http://kh.google.com/dbRoot.v5" 2>&1)
    fi
    echo "    $RESULT"
    echo ""

    # Test 2: Auth endpoint (should be 404/dead)
    echo "  [TEST] kh.google.com/geauth (auth, should be dead):"
    if [ "$HTTP_TOOL" = "wget" ]; then
        RESULT=$(wget -q -O /dev/null --spider -S "http://kh.google.com/geauth" 2>&1 | head -3)
    else
        RESULT=$(curl -s -o /dev/null -w "HTTP %{http_code}" "http://kh.google.com/geauth" 2>&1)
    fi
    echo "    $RESULT"
    echo ""

    # Test 3: Legacy auth (should be dead)
    echo "  [TEST] auth.keyhole.com (legacy auth):"
    if [ "$HTTP_TOOL" = "wget" ]; then
        RESULT=$(wget -q -O /dev/null --spider -S -T 5 "http://auth.keyhole.com/" 2>&1 | head -3)
    else
        RESULT=$(curl -s -o /dev/null -w "HTTP %{http_code}" --connect-timeout 5 "http://auth.keyhole.com/" 2>&1)
    fi
    echo "    $RESULT"
    echo ""

    # Test 4: Download dbRoot.v5 to SD card for analysis
    echo "  [TEST] Downloading dbRoot.v5 to SD card..."
    if [ "$HTTP_TOOL" = "wget" ]; then
        wget -q -O "${OUTDIR}/dbRoot.v5" "http://kh.google.com/dbRoot.v5" 2>&1
    else
        curl -s -o "${OUTDIR}/dbRoot.v5" "http://kh.google.com/dbRoot.v5" 2>&1
    fi
    if [ -f "${OUTDIR}/dbRoot.v5" ] && [ -s "${OUTDIR}/dbRoot.v5" ]; then
        DBSIZE=$(ls -la "${OUTDIR}/dbRoot.v5" | awk '{print $5}')
        echo "    [OK] Downloaded ${DBSIZE} bytes → ${OUTDIR}/dbRoot.v5"
        echo "    [OK] Google tile server is ALIVE and responding!"
    else
        echo "    [FAIL] Could not download dbRoot.v5"
        echo "    [INFO] Server may be unreachable or internet is not connected"
    fi
else
    echo "  No HTTP tools available (wget/curl)"
    echo "  DNS resolution test:"
    nslookup kh.google.com 2>&1 | head -5
fi
echo ""

# ============================================================
# SECTION 4: EOL Flag State (from GEM if accessible)
# ============================================================
echo "================================================================"
echo "  EOL Flag State"
echo "================================================================"
echo ""

echo "--- HU Variant ---"
# Try to determine variant from firmware files
for cfg in /etc/pci-3g_9304.cfg /etc/pci-3g_9308.cfg \
           /etc/pci-3g_9411.cfg /etc/pci-3g_9478.cfg; do
    if [ -f "$cfg" ]; then
        echo "[FOUND] Variant config: $cfg"
    fi
done
echo "MMI_VARIANT: ${MMI_VARIANT:-unknown}"
echo "MMI_VARIANT_ID: ${MMI_VARIANT_ID:-unknown}"
echo ""

echo "--- DataPST.db ---"
for db in /HBpersistence/DataPST.db /mnt/hmisql/DataPST.db; do
    if [ -f "$db" ]; then
        echo "[FOUND] $db ($(ls -la "$db" | awk '{print $5}') bytes)"
    fi
done
echo ""

echo "--- lsd.jxe location ---"
for jxe in /mnt/efs-system/lsd/lsd.jxe /mnt/ifs-root/lsd/lsd.jxe \
           /lsd/lsd.jxe; do
    if [ -f "$jxe" ]; then
        echo "[FOUND] lsd.jxe: $jxe ($(ls -la "$jxe" | awk '{print $5}') bytes)"
        echo "[INFO] Location determines if EOL flags are modifiable:"
        case "$jxe" in
            */efs-system/*) echo "        EFS (writable) — flags CAN be modified" ;;
            */ifs-root/*)   echo "        IFS (read-only) — flags need IFS mod" ;;
        esac
    fi
done
echo ""

# ============================================================
# SECTION 5: gemmi_final Process Check
# ============================================================
echo "================================================================"
echo "  GEMMI Process Status"  
echo "================================================================"
echo ""

GEMMI_PID=$(pidin -F "%a %N" 2>/dev/null | grep gemmi_final | awk '{print $1}')
if [ -n "$GEMMI_PID" ]; then
    echo "[RUNNING] gemmi_final is active (PID: $GEMMI_PID)"
    pidin -p "$GEMMI_PID" -F "%a %b %N %A" 2>/dev/null
else
    echo "[STOPPED] gemmi_final is NOT running"
fi
echo ""

# ============================================================
# SECTION 6: GEMMI GEM Screen Info
# ============================================================
echo "================================================================"
echo "  GEM /googleearth Console Info"
echo "================================================================"
echo ""

# Check if GEMMI ESD screen exists
for esd in /mnt/efs-system/engdefs/*gemmi* /mnt/efs-system/engdefs/*google* \
           /mnt/efs-system/engdefs/*earth*; do
    if [ -f "$esd" ]; then
        echo "[FOUND] ESD: $esd"
    fi
done
echo ""

# ============================================================
# SUMMARY
# ============================================================
echo "################################################################"
echo "#  Summary"
echo "################################################################"
echo ""
echo "GEMMI binaries:     $([ $GEMMI_FOUND -eq 1 ] && echo 'PRESENT' || echo 'NOT FOUND')"
echo "drivers.ini:        $([ -n "$FOUND_INI" ] && [ "$FOUND_INI" != "MISSING" ] && echo "PRESENT ($FOUND_INI)" || echo 'MISSING')"
echo "disableAuthKey:     $(grep -q disableAuthKey "$FOUND_INI" 2>/dev/null && echo 'SET' || echo 'NOT SET')"
echo "Internet (en5):     $(ifconfig en5 2>/dev/null | grep -q inet && echo 'CONNECTED' || echo 'NOT CONNECTED')"
echo "gemmi_final:        $([ -n "$GEMMI_PID" ] && echo 'RUNNING' || echo 'STOPPED')"
echo "Variant:            ${MMI_VARIANT:-unknown} (${MMI_VARIANT_ID:-?})"
echo ""
echo "Report saved to: ${REPORT}"
echo ""
echo "################################################################"
echo "#  NEXT STEPS"
echo "#"
echo "#  Share this report on the MMI3G-Toolkit GitHub or"
echo "#  ClubTouareg GEMMI thread for community analysis."
echo "#"
echo "#  DO NOT run the enabler script until this probe"
echo "#  has been reviewed by the community."
echo "################################################################"

# Show done
if [ -n "$SHOW_PID" ]; then
    kill $SHOW_PID 2>/dev/null
    sleep 1
    if [ -f "${SDPATH}/lib/done.png" ]; then
        "${SDPATH}/bin/showScreen" "${SDPATH}/lib/done.png" 2>/dev/null &
    fi
fi
