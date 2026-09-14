#!/bin/ksh
# ============================================================
# MMI-Toolkit — Comprehensive System Diagnostic
# Single-pass data gathering: system state, activations,
# backups, credentials, variant ID, and CAN/persistence state
#
# Runs entirely from SD card. No flash writes.
# Part of MMI-Toolkit: github.com/dspl1236/MMI-Toolkit
# ============================================================

SDPATH="${1:-${0%/*}}"

# Source platform.sh for QNX compatibility shims
if [ -f "${SDPATH}/scripts/common/platform.sh" ]; then
    . "${SDPATH}/scripts/common/platform.sh"
elif [ -f "/mnt/efs-system/scripts/common/platform.sh" ]; then
    . "/mnt/efs-system/scripts/common/platform.sh"
fi
TS=$(date +%H%M%S 2>/dev/null || echo "000000")

# Use getTime if available (QNX epoch timestamp)
if command -v getTime >/dev/null 2>&1; then
    EPOCH=$(getTime 2>/dev/null)
    TS="epoch-${EPOCH}"
fi

OUTDIR="${SDPATH}/var/sysinfo/${TS}"
REPORT="${SDPATH}/var/sysinfo/sysinfo-${TS}.txt"
BACKUP="${SDPATH}/var/backup"

# Create directories one level at a time (QNX mkdir -p can be flaky)
mkdir "${SDPATH}/var" 2>/dev/null
mkdir "${SDPATH}/var/sysinfo" 2>/dev/null
mkdir "${SDPATH}/var/sysinfo/${TS}" 2>/dev/null
mkdir "${SDPATH}/var/backup" 2>/dev/null
mkdir "${SDPATH}/var/backup/HBpersistence" 2>/dev/null
mkdir "${SDPATH}/var/backup/FSC" 2>/dev/null

# Verify output directory exists
if [ ! -d "${OUTDIR}" ]; then
    # Fallback: write everything to var/ directly
    OUTDIR="${SDPATH}/var"
    REPORT="${SDPATH}/var/sysinfo-${TS}.txt"
fi

# ------------------------------------------------------------
# Robustness (issues #12 / #13): a hung QNX utility must never
# leave the unit stuck on running.png with no completion screen.
# ------------------------------------------------------------
# Per-heavy-command and whole-run time budgets (seconds). Overridable
# for host tests; the defaults are generous for a healthy unit.
: "${MMI_CMD_BUDGET:=20}"
: "${MMI_RUN_BUDGET:=300}"

show_screen() {
    # $1 = png basename under lib/. Best-effort, backgrounded.
    if [ -x "${SDPATH}/bin/showScreen" ] && [ -f "${SDPATH}/lib/$1" ]; then
        "${SDPATH}/bin/showScreen" "${SDPATH}/lib/$1" 2>/dev/null &
    fi
}

# Run a command under a hard time budget so a hung utility (notably
# `pidin fd`, which walks every process's fd table and wedges some
# units) cannot stall the diagnostic. Same background+sleep+kill idiom
# proven by the IPC capture (section 16). Redirect at the call site;
# the command inherits this function's stdout/stderr.
run_bounded() {
    _rb_budget="$1"; shift
    "$@" &
    _rb_pid=$!
    # Redirect the watchdog to /dev/null: if it is cancelled, its orphaned
    # `sleep` child must NOT keep an inherited stdout pipe open (that would
    # stall a piped caller for the whole budget — the #12/#13 symptom).
    ( sleep "${_rb_budget}"; kill -15 "${_rb_pid}" 2>/dev/null
      sleep 2; kill -9 "${_rb_pid}" 2>/dev/null ) >/dev/null 2>&1 &
    _rb_wd=$!
    wait "${_rb_pid}" 2>/dev/null
    _rb_rc=$?
    kill -9 "${_rb_wd}" 2>/dev/null    # cancel watchdog if the command finished in time
    wait "${_rb_wd}" 2>/dev/null
    return ${_rb_rc}
}

# Always advance the screen off running.png on exit, however we exit — the
# keystone fix for #12/#13. EXIT covers normal end and any `exit`; INT/TERM/
# HUP (session reap, launcher signal) re-exit so the EXIT handler still runs.
_finished() { show_screen done.png; }
trap _finished EXIT
trap 'exit' INT TERM HUP

# Show status on screen if showScreen available
show_screen running.png

{
# Backgrounded subshell: disarm the inherited completion trap so only the
# parent ever shows done.png (guards any ksh that fires inherited EXIT traps).
trap - EXIT INT TERM HUP
echo "################################################################"
echo "#  MMI-Toolkit System Information Report"
echo "#  Generated: $(date 2>/dev/null)"
echo "#  Host: $(hostname 2>/dev/null || echo unknown)"
echo "################################################################"

# ============================================================
# 1. SYSTEM IDENTITY
# ============================================================
echo ""
echo "================================================================"
echo "  1. SYSTEM IDENTITY"
echo "================================================================"

echo ""
echo "--- Software Train ---"
TRAIN=$(cat /dev/shmem/sw_trainname.txt 2>/dev/null)
echo "Train: ${TRAIN:-unknown}"
cp /dev/shmem/sw_trainname.txt "${OUTDIR}/sw_train.txt" 2>/dev/null

echo ""
echo "--- MMI Variant Detection ---"
for f in /etc/pci-3g_*.cfg; do
    [ -f "$f" ] || continue
    VID=$(echo "$f" | sed -n 's|.*/pci-3g_\([0-9]*\)\.cfg|\1|p')
    case "$VID" in
        9304) echo "Variant: MMI 3G Basic ($VID)" ;;
        9308) echo "Variant: MMI 3G High ($VID)" ;;
        9411) echo "Variant: MMI 3G+ ($VID)" ;;
        9436) echo "Variant: MMI 3G+ Gen2 ($VID)" ;;
        9478) echo "Variant: MMI 3G+ Gen3 ($VID)" ;;
        *)    echo "Variant: Unknown ($VID)" ;;
    esac
done
# Check for RSE (rear seat entertainment)
echo "$TRAIN" | grep -q "HN+R" && echo "  RSE: Yes (HN+R train)" || echo "  RSE: No"
# Check for VW/Porsche
echo "$TRAIN" | grep -q "_VW_" && echo "  Platform: VW (RNS-850)"
echo "$TRAIN" | grep -q "_AU_" && echo "  Platform: Audi"

echo ""
echo "--- QNX Version ---"
uname -a 2>/dev/null

echo ""
echo "--- System Uptime / pidin info ---"
pidin info 2>/dev/null
pidin info > "${OUTDIR}/pidin_info.txt" 2>/dev/null

# ============================================================
# 2. GEM & ENGINEERING STATUS
# ============================================================
echo ""
echo "================================================================"
echo "  2. GEM & ENGINEERING STATUS"
echo "================================================================"

echo ""
echo "--- DBGModeActive (GEM file marker) ---"
if [ -f /HBpersistence/DBGModeActive ]; then
    echo "STATUS: ENABLED (/HBpersistence/DBGModeActive exists)"
    ls -la /HBpersistence/DBGModeActive
else
    echo "STATUS: DISABLED (file not present)"
fi

echo ""
echo "--- engdefs Directory ---"
if [ -d /mnt/efs-system/engdefs ]; then
    ESDCOUNT=$(ls /mnt/efs-system/engdefs/*.esd 2>/dev/null | wc -l)
    echo "STATUS: EXISTS (${ESDCOUNT} screen files)"
    ls -la /mnt/efs-system/engdefs/*.esd > "${OUTDIR}/engdefs_listing.txt" 2>/dev/null
else
    echo "STATUS: NOT FOUND"
fi

echo ""
echo "--- AppDevelopment.jar ---"
for j in /mnt/efs-system/lsd/AppDevelopment.jar /mnt/efs-system/lsd/development/AppDevelopment.jar; do
    [ -f "$j" ] && echo "FOUND: $j ($(ls -la "$j" | awk '{print $5}') bytes)"
done

# ============================================================
# 3. ACTIVATION & FEATURE STATE
# ============================================================
echo ""
echo "================================================================"
echo "  3. ACTIVATION & FEATURE STATE"
echo "================================================================"

echo ""
echo "--- Feature Activation ---"
if [ -f /mnt/efs-persist/acios_db.ini ]; then
    echo "Nav DB config:"
    cat /mnt/efs-persist/acios_db.ini 2>/dev/null | grep -v "^#" | grep -v "^$"
    cp /mnt/efs-persist/acios_db.ini "${BACKUP}/acios_db.ini" 2>/dev/null
fi

echo ""
echo "--- Nav Unblocker Status ---"
if [ -f /mnt/efs-system/scripts/setdatabase.cfg ]; then
    if grep -q "manage_cd" /mnt/efs-system/scripts/setdatabase.cfg 2>/dev/null; then
        echo "manage_cd.sh: PATCHED (DrGER2 unblocker)"
    else
        echo "manage_cd.sh: Stock"
    fi
fi

echo ""
echo "--- FSC Files (Feature activation codes) ---"
ls -laR /HBpersistence/FSC/ 2>/dev/null || echo "No FSC directory"
# Backup FSC files
if [ -d /HBpersistence/FSC ]; then
    # FSC dir already created above
    cp -R /HBpersistence/FSC/* "${BACKUP}/FSC/" 2>/dev/null
    echo "  (backed up to SD)"
fi

echo ""
echo "--- GEMMI (Google Earth) ---"
if [ -f /mnt/nav/gemmi/gemmi_final ]; then
    echo "INSTALLED: /mnt/nav/gemmi/gemmi_final"
    ls -la /mnt/nav/gemmi/ 2>/dev/null
    # Check if running
    pidin ar 2>/dev/null | grep -q gemmi && echo "RUNNING: Yes" || echo "RUNNING: No"
else
    echo "NOT INSTALLED"
fi

echo ""
echo "--- LAN/Network Flags ---"
[ -f /HBpersistence/usedhcp ] && echo "usedhcp: SET (DrGER LAN mode)" || echo "usedhcp: not set"
[ -f /HBpersistence/DLinkReplacesPPP ] && echo "DLinkReplacesPPP: SET" || echo "DLinkReplacesPPP: not set"

# ============================================================
# 4. CREDENTIALS & PASSWORDS
# ============================================================
echo ""
echo "================================================================"
echo "  4. CREDENTIALS & PASSWORDS"
echo "================================================================"

echo ""
echo "--- WiFi Hotspot Config ---"
for f in /mnt/efs-persist/wlan_*.conf /mnt/efs-system/etc/wpa_supplicant.conf /etc/wpa_supplicant.conf; do
    if [ -f "$f" ]; then
        echo "FOUND: $f"
        cat "$f" 2>/dev/null
        cp "$f" "${BACKUP}/${f##/*}" 2>/dev/null
    fi
done

echo ""
echo "--- Bluetooth Pairing ---"
if [ -f /HBpersistence/bdaddr.txt ]; then
    echo "BT Address: $(cat /HBpersistence/bdaddr.txt 2>/dev/null)"
    cp /HBpersistence/bdaddr.txt "${BACKUP}/bdaddr.txt" 2>/dev/null
fi

echo ""
echo "--- Audi Connect / myaudi ---"
for f in /mnt/efs-system/scripts/Connectivity/common.cfg /lsd/MMI3G_MyAudi.properties; do
    if [ -f "$f" ]; then
        echo "FOUND: $f"
        grep -i "user\|pass\|key\|token\|auth\|ssid\|psk" "$f" 2>/dev/null
        cp "$f" "${BACKUP}/${f##/*}" 2>/dev/null
    fi
done

echo ""
echo "--- VIN ---"
if [ -f /HBpersistence/vin ]; then
    echo "VIN: $(cat /HBpersistence/vin 2>/dev/null)"
fi

echo ""
echo "--- System Login Credentials ---"
echo "/etc/passwd:"
cat /etc/passwd 2>&1
echo ""
echo "/etc/shadow:"
cat /etc/shadow 2>&1
echo ""
echo "passwd file location:"
ls -la /etc/passwd 2>&1
readlink -f /etc/passwd 2>&1
echo ""
echo "shadow file location:"
ls -la /etc/shadow 2>&1
readlink -f /etc/shadow 2>&1
echo ""
echo "/etc/default/login:"
cat /etc/default/login 2>&1
# Backup to SD
cp /etc/passwd "${BACKUP}/passwd" 2>/dev/null
cp /etc/shadow "${BACKUP}/shadow" 2>/dev/null
cp /etc/default/login "${BACKUP}/default_login" 2>/dev/null

# ============================================================
# 5. STORAGE & PARTITIONS
# ============================================================
echo ""
echo "================================================================"
echo "  5. STORAGE & PARTITIONS"
echo "================================================================"

echo ""
echo "--- Mount Points ---"
mount 2>/dev/null | sort
mount > "${OUTDIR}/mounts.txt" 2>/dev/null

echo ""
echo "--- Disk Usage ---"
df -k 2>/dev/null
df -k > "${OUTDIR}/disk_usage.txt" 2>/dev/null

echo ""
echo "--- Flash Partitions ---"
ls -la /dev/fs* 2>/dev/null
ls -la /dev/hd* 2>/dev/null
ls -la /dev/sdcard* 2>/dev/null

# ============================================================
# 6. NETWORK
# ============================================================
echo ""
echo "================================================================"
echo "  6. NETWORK"
echo "================================================================"

echo ""
echo "--- Interfaces ---"
ifconfig -a 2>/dev/null
ifconfig -a > "${OUTDIR}/interfaces.txt" 2>/dev/null

echo ""
echo "--- Routes ---"
netstat -rn 2>/dev/null
netstat -rn > "${OUTDIR}/routes.txt" 2>/dev/null

echo ""
echo "--- DNS ---"
cat /etc/resolv.conf 2>/dev/null
cat /etc/resolv.conf > "${OUTDIR}/dns.txt" 2>/dev/null

# ============================================================
# 7. INSTALLED SCRIPTS & MODIFICATIONS
# ============================================================
echo ""
echo "================================================================"
echo "  7. INSTALLED SCRIPTS & MODIFICATIONS"
echo "================================================================"

echo ""
echo "--- Custom Scripts on EFS ---"
ls -laR /mnt/efs-system/scripts/ 2>/dev/null

echo ""
echo "--- Splash Screens ---"
ls -la /mnt/efs-system/lsd/startup-*.png 2>/dev/null | wc -l
echo " splash screen PNGs found"
if [ -f /mnt/efs-system/lsd/StartupImageConfig.txt ]; then
    cat /mnt/efs-system/lsd/StartupImageConfig.txt 2>/dev/null
fi

# ============================================================
# 8. HBpersistence SNAPSHOT
# ============================================================
echo ""
echo "================================================================"
echo "  8. HBpersistence SNAPSHOT"
echo "================================================================"

echo ""
echo "--- File Listing ---"
ls -laR /HBpersistence/ > "${OUTDIR}/HBpersistence_listing.txt" 2>&1
echo "Full listing saved to: HBpersistence_listing.txt"

# Backup key persistence files
# HBpersistence dir already created above
for f in /HBpersistence/DBGModeActive \
         /HBpersistence/usedhcp \
         /HBpersistence/DLinkReplacesPPP \
         /HBpersistence/vin \
         /HBpersistence/bdaddr.txt \
         /HBpersistence/audiomixer*.txt \
         /HBpersistence/TouchCalib.bin; do
    [ -f "$f" ] && cp "$f" "${BACKUP}/HBpersistence/" 2>/dev/null
done
echo "Key files backed up to SD"

# ============================================================
# 9. PROCESSES
# ============================================================
echo ""
echo "================================================================"
echo "  9. RUNNING PROCESSES"
echo "================================================================"

run_bounded "${MMI_CMD_BUDGET}" pidin ar > "${OUTDIR}/processes.txt" 2>/dev/null
# Show unique process names only (reuse the bounded capture above; no 2nd pidin)
awk '{print $1}' "${OUTDIR}/processes.txt" 2>/dev/null | sort -u | grep -v "^name$" | grep -v "^$"

# ============================================================
# 10. SYSLOG
# ============================================================
echo ""
echo "================================================================"
echo "  10. SYSTEM LOG"
echo "================================================================"

sloginfo 2>/dev/null | sed -n '1,200p' > "${OUTDIR}/syslog.txt" 2>/dev/null
echo "Syslog saved (first 200 lines)"

# ============================================================
# 11. NAVIGATION DATABASE & MAP STATE
# ============================================================
echo ""
echo "================================================================"
echo "  11. NAVIGATION DATABASE & MAP STATE"
echo "================================================================"

echo ""
echo "--- acios_db.ini ---"
ACIOS=""
for candidate in /mnt/nav/db/acios_db.ini /mnt/lvm/acios_db.ini \
                 /mnt/hdd/acios_db.ini /mnt/efs-persist/acios_db.ini; do
    if [ -f "$candidate" ]; then
        ACIOS="$candidate"
        echo "Found: $candidate"
        cat "$candidate" 2>/dev/null
        cp "$candidate" "${BACKUP}/acios_db.ini" 2>/dev/null
        break
    fi
done
[ -z "$ACIOS" ] && echo "acios_db.ini not found"

echo ""
echo "--- DBInfo.txt ---"
DBINFO=/mnt/nav/db/DBInfo.txt
if [ -f "$DBINFO" ]; then
    cat "$DBINFO" 2>/dev/null
    cp "$DBINFO" "${BACKUP}/" 2>/dev/null
else
    echo "DBInfo.txt not found"
fi

echo ""
echo "--- FSC Activation Files ---"
for searchdir in /mnt/efs-persist/FSC /HBpersistence/FSC /mnt/persist/FSC; do
    if [ -d "$searchdir" ]; then
        echo "  $searchdir:"
        ls -la "$searchdir"/*.fsc 2>/dev/null
        mkdir -p "${BACKUP}/FSC" 2>/dev/null
        cp "$searchdir"/*.fsc "${BACKUP}/FSC/" 2>/dev/null
    fi
done

echo ""
echo "--- MAC Address (for FSC lookup) ---"
ifconfig en0 2>/dev/null | grep -i "address"
ifconfig lo0 2>/dev/null | grep -i "address"

echo ""
echo "--- Nav Unblocker State ---"
ls -la /mnt/efs-system/scripts/manage_cd_original.sh 2>/dev/null && echo "Nav unblocker: INSTALLED" || echo "Nav unblocker: not installed"
ls -la /mnt/efs-system/scripts/manage_cd.sh 2>/dev/null

# ============================================================
# 12. CREDENTIAL SWEEP
# ============================================================
echo ""
echo "================================================================"
echo "  12. CREDENTIAL SWEEP"
echo "================================================================"

echo ""
echo "--- Broad string sweep (ssid/psk/password/token) ---"
for searchdir in /mnt/efs-persist /mnt/persist /mnt/efs-system/etc; do
    if [ -d "$searchdir" ]; then
        HITS=$(find "$searchdir" -type f 2>/dev/null | xargs grep -il "ssid\|psk\|passphrase\|password\|token\|apikey" 2>/dev/null)
        if [ -n "$HITS" ]; then
            echo "  Files with credential-like strings in $searchdir:"
            echo "$HITS" | while read f; do
                echo "    $f"
                grep -Ein "ssid=|psk=|passphrase=|password=|token=|apikey=" "$f" 2>/dev/null | head -5 | sed 's/^/      /'
            done
        fi
    fi
done

# ============================================================
# 13. PERSISTENCE FILE BACKUP
# ============================================================
echo ""
echo "================================================================"
echo "  13. PERSISTENCE FILE BACKUP"
echo "================================================================"

echo ""
echo "--- CVALUE Coding Files ---"
for cva in /HBpersistence/CVALUE*.CVA /mnt/efs-persist/CVALUE*.CVA; do
    if [ -f "$cva" ]; then
        cp "$cva" "${BACKUP}/" 2>/dev/null
        echo "  Backed up: ${cva##*/}"
    fi
done

echo ""
echo "--- Shared Memory State ---"
ls /dev/shmem/ 2>/dev/null

echo ""
echo "--- efs-persist listing ---"
ls -la /mnt/efs-persist/ 2>/dev/null | head -30

# ============================================================
# 14. QNX KERNEL & BUS TOPOLOGY
# ============================================================
echo ""
echo "================================================================"
echo "  14. QNX KERNEL & BUS TOPOLOGY"
echo "================================================================"

echo ""
echo "--- QNX Kernel ---"
uname -a 2>/dev/null

echo ""
echo "--- IPC / IOC Devices ---"
ls -laR /dev/ipc/ 2>/dev/null
ls -laR /dev/dspipc/ 2>/dev/null

echo ""
echo "--- MOST / CAN / Serial ---"
ls -la /dev/most* /dev/can* /dev/ser* 2>/dev/null

echo ""
echo "--- FPGA Sysregs ---"
ls /dev/sysregs/ 2>/dev/null

echo ""
echo "--- Service Broker ---"
ls -la /srv/ 2>/dev/null

echo ""
echo "--- hbsystem ---"
ls -laR /hbsystem/ 2>/dev/null

# ============================================================
# ============================================================
# 15. DEEP BINARY BACKUP
# ============================================================
echo ""
echo "================================================================"
echo "  15. DEEP BINARY BACKUP"
echo "================================================================"

mkdir "${BACKUP}/Keys" 2>/dev/null
mkdir "${BACKUP}/Keys/DataKey" 2>/dev/null
mkdir "${BACKUP}/Keys/FSCKey" 2>/dev/null
mkdir "${BACKUP}/Keys/MetainfoKey" 2>/dev/null

cp /HBpersistence/DataPST.db "${BACKUP}/DataPST.db" 2>/dev/null && echo "  DataPST.db backed up" || echo "  DataPST.db not found"
cp /HBpersistence/DataPST.crc "${BACKUP}/DataPST.crc" 2>/dev/null
cp /HBpersistence/Keys/DataKey/DK_public_signiert.bin "${BACKUP}/Keys/DataKey/" 2>/dev/null && echo "  DataKey backed up"
cp /HBpersistence/Keys/FSCKey/FSC_public_signiert.bin "${BACKUP}/Keys/FSCKey/" 2>/dev/null && echo "  FSCKey backed up"
cp /HBpersistence/Keys/MetainfoKey/MI_public_signiert.bin "${BACKUP}/Keys/MetainfoKey/" 2>/dev/null && echo "  MetainfoKey backed up"
cp /HBpersistence/FSC/Logs/Security_Exceptions.log "${BACKUP}/FSC/Security_Exceptions.log" 2>/dev/null && echo "  Security_Exceptions.log backed up"
cp /HBpersistence/oadb_simuCS.dbf "${BACKUP}/oadb_simuCS.dbf" 2>/dev/null && echo "  oadb_simuCS.dbf backed up"
cp /HBpersistence/PDL.dat "${BACKUP}/PDL.dat" 2>/dev/null
cp /HBpersistence/addressbook.db "${BACKUP}/addressbook.db" 2>/dev/null && echo "  addressbook.db backed up"

# ============================================================
# 16. IPC CHANNEL CAPTURE
# ============================================================
echo ""
echo "================================================================"
echo "  16. IPC CHANNEL CAPTURE (CAN/BAP data)"
echo "================================================================"

mkdir "${OUTDIR}/ipc" 2>/dev/null
for ch in 2 3 4 5 6 7 8 9 10 11; do
    CHPATH=""
    if [ -e "/dev/ipc/ch${ch}" ]; then
        CHPATH="/dev/ipc/ch${ch}"
    elif [ -e "/dev/ipc/ioc/ch${ch}" ]; then
        CHPATH="/dev/ipc/ioc/ch${ch}"
    fi
    if [ -n "$CHPATH" ]; then
        cat "$CHPATH" > "/tmp/ipc_ch${ch}.bin" &
        CATPID=$!
        sleep 3
        kill $CATPID 2>/dev/null
        wait $CATPID 2>/dev/null
        if [ -s "/tmp/ipc_ch${ch}.bin" ]; then
            SIZE=$(ls -la "/tmp/ipc_ch${ch}.bin" | awk '{print $5}')
            cp "/tmp/ipc_ch${ch}.bin" "${OUTDIR}/ipc/ch${ch}.bin" 2>/dev/null
            echo "  ch${ch}: ${SIZE} bytes captured"
        else
            echo "  ch${ch}: blocked (0 bytes)"
            rm -f "/tmp/ipc_ch${ch}.bin"
        fi
    fi
done

# ============================================================
# 17. QDB DATABASE DUMP
# ============================================================
echo ""
echo "================================================================"
echo "  17. QDB DATABASE DUMP"
echo "================================================================"

echo "--- Registered QDB databases ---"
ls /dev/qdb/ 2>/dev/null
if [ -e "/dev/qdb/mme" ]; then
    echo ""
    echo "--- mme database tables ---"
    run_bounded "${MMI_CMD_BUDGET}" qdbc -d mme "SELECT name FROM sqlite_master WHERE type='table'" > "${OUTDIR}/qdb_mme_tables.txt" 2>/dev/null
    cat "${OUTDIR}/qdb_mme_tables.txt" 2>/dev/null
fi

# ============================================================
# 18. EXTENDED PROCESS DUMP
# ============================================================
echo ""
echo "================================================================"
echo "  18. EXTENDED PROCESS DUMP"
echo "================================================================"

run_bounded "${MMI_CMD_BUDGET}" pidin -F "%H %p %N %a" > "${OUTDIR}/pidin_full.txt" 2>/dev/null
echo "  Full pidin saved"
run_bounded "${MMI_CMD_BUDGET}" pidin mem > "${OUTDIR}/pidin_mem.txt" 2>/dev/null
echo "  Memory map saved"
# `pidin fd` walks every process's fd table and hangs/destabilises some
# units — the exact point issues #12/#13 stalled. Time-bounded so a hang
# only loses this one dump instead of wedging the whole run.
run_bounded "${MMI_CMD_BUDGET}" pidin fd > "${OUTDIR}/pidin_fd.txt" 2>/dev/null
echo "  File descriptors saved"

# ============================================================
# 19. FULL SYSLOG
# ============================================================
echo ""
echo "================================================================"
echo "  19. FULL SYSLOG DUMP"
echo "================================================================"

run_bounded "${MMI_CMD_BUDGET}" sloginfo > "${OUTDIR}/syslog_full.txt" 2>/dev/null
echo "  Full syslog saved"

# ============================================================
# 20. SYSTEM CONFIG FILES
# ============================================================
echo ""
echo "================================================================"
echo "  20. SYSTEM CONFIG FILES"
echo "================================================================"

mkdir "${BACKUP}/etc" 2>/dev/null
for f in /etc/inetd.conf /etc/shadow /etc/passwd /etc/hosts /etc/resolv.conf /etc/qdb.cfg /etc/hmi_country.txt; do
    if [ -f "$f" ] || [ -L "$f" ]; then
        BNAME=$(echo "$f" | sed 's|/|_|g')
        cp "$f" "${BACKUP}/etc/${BNAME}" 2>/dev/null
        echo "  Backed up: $f"
    fi
done


echo ""
echo "################################################################"
echo "#  End of System Information Report"
echo "#  Data:    ${OUTDIR}/"
echo "#  Backups: ${BACKUP}/"
echo "#  Report:  ${REPORT}"
echo "################################################################"

} > "${REPORT}" 2>&1 &
_report_pid=$!
# Global safety net: even if an unwrapped command hangs (an unknown stall
# point, e.g. issue #12), guarantee the run ends so the EXIT trap advances
# the screen. Redirected to /dev/null so an orphaned watchdog `sleep` can
# never hold a captured stdout pipe open past the run.
( trap - EXIT INT TERM HUP
  sleep "${MMI_RUN_BUDGET}"; kill -15 "${_report_pid}" 2>/dev/null
  sleep 3; kill -9 "${_report_pid}" 2>/dev/null ) >/dev/null 2>&1 &
_report_wd=$!
wait "${_report_pid}" 2>/dev/null
kill -9 "${_report_wd}" 2>/dev/null
wait "${_report_wd}" 2>/dev/null

# Copy report to the data dir too — bounded, in case the SD/mount is wedged
# (a failing card is exactly the population that runs a diagnostic).
run_bounded "${MMI_CMD_BUDGET}" cp "${REPORT}" "${OUTDIR}/" 2>/dev/null

# done.png is shown by the EXIT trap (_finished) — covering normal end,
# early crash, and a watchdog kill alike.
