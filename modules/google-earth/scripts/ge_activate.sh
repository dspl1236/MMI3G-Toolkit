#!/bin/ksh
# ============================================================
# MMI3G-Toolkit — Google Earth Enable + Deploy
# Combined script: deploys GEMMI binaries (if needed) AND
# adds disableAuthKey to drivers.ini
#
# Safe order of operations:
#   1. Check variant compatibility
#   2. Deploy GEMMI binaries from SD card (skips if already present)
#   3. Set up GEMMI cache directories
#   4. Backup drivers.ini
#   5. Add disableAuthKey to drivers.ini
#   6. Check network connectivity
#   7. Report results
#
# Revert with ge_restore.sh
# Part of MMI3G-Toolkit: github.com/dspl1236/MMI3G-Toolkit
# ============================================================

# --- platform.sh ---
_SDPATH_GUESS="${SDPATH:-$(dirname $0)}"
if [ -f "${_SDPATH_GUESS}/scripts/common/platform.sh" ]; then
    . "${_SDPATH_GUESS}/scripts/common/platform.sh"
elif [ -f "/mnt/efs-system/scripts/common/platform.sh" ]; then
    . "/mnt/efs-system/scripts/common/platform.sh"
fi

SDPATH="${_SDPATH_GUESS}"
TS=$(date +%H%M%S 2>/dev/null || echo "000000")
if command -v getTime >/dev/null 2>&1; then TS="epoch-$(getTime)"; fi

OUTDIR="${SDPATH}/var/google-earth"
LOG="${OUTDIR}/ge-activate-${TS}.log"
BACKUP="${SDPATH}/var/backup/google-earth"
mkdir -p "${OUTDIR}" 2>/dev/null
mkdir -p "${BACKUP}" 2>/dev/null

EFSDIR="/mnt/efs-system"
DRIVERS_INI="${EFSDIR}/lsd/drivers.ini"
GEMMI_TARGET="/mnt/nav/gemmi"

# Show status
if [ -x "${SDPATH}/bin/showScreen" ] && [ -f "${SDPATH}/lib/running.png" ]; then
    "${SDPATH}/bin/showScreen" "${SDPATH}/lib/running.png" 2>/dev/null &
    SHOW_PID=$!
fi

exec > "${LOG}" 2>&1

echo "============================================"
echo " Google Earth Enable + Deploy"
echo " $(date)"
echo " Train: $(cat /dev/shmem/sw_trainname.txt 2>/dev/null)"
echo "============================================"
echo ""

CHANGES=0

# ============================================================
# Step 1: Variant check
# ============================================================
echo "[STEP 1] Variant compatibility..."

case "${MMI_VARIANT_ID}" in
    9304|9308|9411)
        echo "  Audi variant — no RANGE_ block on GE"
        ;;
    9478)
        echo "  VW/RNS-850 — RANGE_ may block UI menu"
        echo "  gemmi_final can still run independently"
        ;;
    *)
        echo "  Unknown variant (${MMI_VARIANT_ID}) — proceeding"
        ;;
esac
echo ""

# ============================================================
# Step 2: Remount EFS + NAV read-write
# ============================================================
echo "[STEP 2] Remounting partitions rw..."
mount -uw ${EFSDIR} 2>/dev/null
mount -uw /mnt/nav 2>/dev/null
echo "  [OK] Partitions remounted"
echo ""

# ============================================================
# Step 3: Deploy GEMMI binaries (if not already present)
# ============================================================
echo "[STEP 3] GEMMI binary deployment..."

if [ -f "${GEMMI_TARGET}/gemmi_final" ]; then
    SIZE=$(ls -la "${GEMMI_TARGET}/gemmi_final" | awk '{print $5}')
    echo "  [OK] GEMMI already installed at ${GEMMI_TARGET}"
    echo "  gemmi_final: ${SIZE} bytes — skipping deployment"
else
    echo "  [INFO] GEMMI not installed — looking for source files..."

    SOURCE=""
    # Check SD card /gemmi/ directory
    if [ -f "${SDPATH}/gemmi/gemmi_final" ] && \
       [ -f "${SDPATH}/gemmi/libembeddedearth.so" ]; then
        SOURCE="${SDPATH}/gemmi"
        echo "  [FOUND] SD card: ${SOURCE}"
    fi

    # Check gemmi-dump output on SD
    if [ -z "$SOURCE" ]; then
        for dump in ${SDPATH}/var/gemmi_dump; do
            if [ -f "${dump}/gemmi_final" ] && \
               [ -f "${dump}/libembeddedearth.so" ]; then
                SOURCE="${dump}"
                echo "  [FOUND] gemmi-dump output: ${SOURCE}"
            fi
        done
    fi

    if [ -n "$SOURCE" ]; then
        mkdir -p "${GEMMI_TARGET}" 2>/dev/null
        mkdir -p "${GEMMI_TARGET}/scripts" 2>/dev/null
        mkdir -p "${GEMMI_TARGET}/models" 2>/dev/null
        mkdir -p "${GEMMI_TARGET}/res" 2>/dev/null

        DEPLOYED=0
        for file in gemmi_final libembeddedearth.so libmessaging.so \
                    libthirdparty_icu_3_5.so mapStylesWrite \
                    drivers.ini run_gemmi.sh pg.sh \
                    debug_gemmi.sh debug_memcpu.sh; do
            if [ -f "${SOURCE}/${file}" ]; then
                cp "${SOURCE}/${file}" "${GEMMI_TARGET}/${file}"
                chmod +x "${GEMMI_TARGET}/${file}"
                echo "  [COPY] ${file}"
                DEPLOYED=$((DEPLOYED + 1))
            fi
        done

        # Control scripts
        if [ -d "${SOURCE}/scripts" ]; then
            for script in ${SOURCE}/scripts/*.sh; do
                if [ -f "$script" ]; then
                    name=$(basename "$script")
                    cp "$script" "${GEMMI_TARGET}/scripts/${name}"
                    chmod +x "${GEMMI_TARGET}/scripts/${name}"
                    echo "  [COPY] scripts/${name}"
                    DEPLOYED=$((DEPLOYED + 1))
                fi
            done
        fi

        # Models and resources
        for subdir in models res; do
            if [ -d "${SOURCE}/${subdir}" ]; then
                cp -r "${SOURCE}/${subdir}" "${GEMMI_TARGET}/"
                echo "  [COPY] ${subdir}/"
                DEPLOYED=$((DEPLOYED + 1))
            fi
        done

        echo "  [OK] Deployed ${DEPLOYED} files"
        CHANGES=$((CHANGES + DEPLOYED))
    else
        echo "  [WARN] No GEMMI source files found on SD card"
        echo "  [INFO] If your car already had GE, binaries may"
        echo "         self-provision when internet is connected"
    fi
fi
echo ""

# ============================================================
# Step 4: Set up GEMMI cache
# ============================================================
echo "[STEP 4] GEMMI cache directories..."
for cachedir in /mnt/img-cache/gemmi /mnt/img-cache/gemmi/.config \
                /mnt/img-cache/gemmi/cache /mnt/img-cache/gemmi/scache \
                /mnt/img-cache/gemmi/temp; do
    if [ ! -d "$cachedir" ]; then
        mkdir -p "$cachedir" 2>/dev/null
        echo "  [MKDIR] $cachedir"
    fi
done
echo "  [OK] Cache ready"
echo ""

# ============================================================
# Step 5: Backup + modify drivers.ini
# ============================================================
echo "[STEP 5] drivers.ini modification..."
if [ -f "$DRIVERS_INI" ]; then
    cp "$DRIVERS_INI" "${BACKUP}/drivers.ini.bak-${TS}"
    echo "  [OK] Backed up to ${BACKUP}/drivers.ini.bak-${TS}"

    if grep -q "disableAuthKey" "$DRIVERS_INI" 2>/dev/null; then
        echo "  [OK] disableAuthKey already present"
    else
        echo "" >> "$DRIVERS_INI"
        echo "    ; Google Earth auth bypass (MMI3G-Toolkit)" >> "$DRIVERS_INI"
        echo "    Connection/disableAuthKey = true" >> "$DRIVERS_INI"
        CHANGES=$((CHANGES + 1))
        echo "  [MOD] Added disableAuthKey = true"
    fi
else
    echo "  [WARN] drivers.ini not found at $DRIVERS_INI"
fi
echo ""

# ============================================================
# Step 6: Network check
# ============================================================
echo "[STEP 6] Network connectivity..."
HAS_NET=0
if ifconfig en5 2>/dev/null | grep -q "inet"; then
    echo "  [OK] en5 interface has IP address"
    HAS_NET=1
elif ifconfig ppp0 2>/dev/null | grep -q "inet"; then
    echo "  [OK] ppp0 interface has IP address"
    HAS_NET=1
else
    echo "  [INFO] No active internet interface"
    echo "  [INFO] Connect USB ethernet + LTE router for Google Earth"
fi
echo ""

# ============================================================
# Summary
# ============================================================
echo "============================================"
echo " Summary"
echo "============================================"
echo ""
echo " Changes made:     $CHANGES"
echo " GEMMI binaries:   $([ -f "${GEMMI_TARGET}/gemmi_final" ] && echo 'PRESENT' || echo 'NOT FOUND')"
echo " disableAuthKey:   $(grep -q disableAuthKey "$DRIVERS_INI" 2>/dev/null && echo 'SET' || echo 'NOT SET')"
echo " Internet:         $([ $HAS_NET -eq 1 ] && echo 'CONNECTED' || echo 'NOT CONNECTED')"
echo " Backup:           ${BACKUP}/"
echo ""

if [ $CHANGES -gt 0 ]; then
    echo " REBOOT REQUIRED for changes to take effect"
    echo ""
    echo " After reboot:"
    echo "   1. Ensure internet is connected"
    echo "   2. Open NAV > Map Settings > check for Google Earth"
    echo "   3. If GE option appears, enable it"
    echo "   4. If not, run ge_probe.sh and share results"
    echo ""
    echo " To revert: run ge_restore.sh from SD card"
fi

echo ""
echo " Log: ${LOG}"
echo "============================================"

# Show done
if [ -n "$SHOW_PID" ]; then
    kill $SHOW_PID 2>/dev/null
    sleep 1
    if [ -f "${SDPATH}/lib/done.png" ]; then
        "${SDPATH}/bin/showScreen" "${SDPATH}/lib/done.png" 2>/dev/null &
    fi
fi
