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
# Step 5: Patch lsd.jxe — Enable Google Earth EOL flag
# ============================================================
echo "[STEP 5] lsd.jxe EOL flag patch..."

# Find lsd.jxe — check writable EFS first, then read-only IFS
LSD=""
LSD_WRITABLE=0
if [ -f "${EFSDIR}/lsd/lsd.jxe" ]; then
    LSD="${EFSDIR}/lsd/lsd.jxe"
    LSD_WRITABLE=1
    echo "  [OK] lsd.jxe on writable EFS: $LSD"
elif [ -f "/mnt/ifs-root/lsd/lsd.jxe" ]; then
    LSD="/mnt/ifs-root/lsd/lsd.jxe"
    LSD_WRITABLE=0
    echo "  [WARN] lsd.jxe on read-only IFS: $LSD"
    echo "  [WARN] Cannot patch from SD card — needs IFS reflash"
fi

if [ -n "$LSD" ] && [ $LSD_WRITABLE -eq 1 ]; then
    # Backup lsd.jxe
    cp "$LSD" "${BACKUP}/lsd.jxe.bak-${TS}"
    echo "  [OK] Backed up to ${BACKUP}/lsd.jxe.bak-${TS}"

    # Check current state — is GOOGLE_EARTH already =1?
    # The flag is STORED (uncompressed) in the JAR, so grep works
    CURRENT=$(strings "$LSD" 2>/dev/null | grep "^EOLFLAG_GOOGLE_EARTH=" | head -1)

    if [ "$CURRENT" = "EOLFLAG_GOOGLE_EARTH=1" ]; then
        echo "  [OK] EOLFLAG_GOOGLE_EARTH already set to 1 (enabled)"
    elif [ "$CURRENT" = "EOLFLAG_GOOGLE_EARTH=0" ]; then
        echo "  [MOD] Patching EOLFLAG_GOOGLE_EARTH=0 → =1"

        # Find the byte offset of the '0' in EOLFLAG_GOOGLE_EARTH=0
        # Strategy: search for all occurrences, skip RANGE_ entries
        #
        # The flag in sysconst.properties is preceded by "available\n"
        # The RANGE_ entries are preceded by "RANGE_"
        # We patch the FIRST non-RANGE_ occurrence

        PATCHED=0
        # Use dd to scan for the pattern in 64KB blocks
        FILESIZE=$(ls -la "$LSD" | awk '{print $5}')
        BLOCK=65536
        OFF=0
        TARGET="EOLFLAG_GOOGLE_EARTH=0"

        while [ $OFF -lt $FILESIZE ] && [ $PATCHED -eq 0 ]; do
            # Read a chunk and check for the target
            CHUNK=$(dd if="$LSD" bs=1 skip=$OFF count=$((BLOCK + 40)) 2>/dev/null)
            case "$CHUNK" in
                *"$TARGET"*)
                    # Found the target in this chunk — now find exact offset
                    # Read byte-by-byte within this block to find it
                    INNER=0
                    while [ $INNER -lt $BLOCK ]; do
                        SAMPLE=$(dd if="$LSD" bs=1 skip=$((OFF + INNER)) count=22 2>/dev/null)
                        if [ "$SAMPLE" = "$TARGET" ]; then
                            # Check if preceded by RANGE_ (6 bytes before)
                            PRE=""
                            if [ $((OFF + INNER)) -ge 6 ]; then
                                PRE=$(dd if="$LSD" bs=1 skip=$((OFF + INNER - 6)) count=6 2>/dev/null)
                            fi
                            if [ "$PRE" != "RANGE_" ]; then
                                # This is the actual flag value — patch it!
                                BYTE_OFF=$((OFF + INNER + 21))
                                # Verify the byte is actually '0' (0x30)
                                OLD=$(dd if="$LSD" bs=1 skip=$BYTE_OFF count=1 2>/dev/null)
                                if [ "$OLD" = "0" ]; then
                                    printf '1' | dd of="$LSD" bs=1 seek=$BYTE_OFF conv=notrunc 2>/dev/null
                                    PATCHED=1
                                    CHANGES=$((CHANGES + 1))
                                    echo "  [OK] Patched '0' → '1' at byte offset $BYTE_OFF"
                                    echo "  [OK] Google Earth EOL flag enabled"
                                else
                                    echo "  [WARN] Unexpected byte at offset $BYTE_OFF: '$OLD'"
                                fi
                                break
                            fi
                        fi
                        INNER=$((INNER + 1))
                    done
                    ;;
            esac
            OFF=$((OFF + BLOCK))
        done

        if [ $PATCHED -eq 0 ]; then
            echo "  [WARN] Could not find EOLFLAG_GOOGLE_EARTH=0 in lsd.jxe"
            echo "  [INFO] Flag may already be set, or file format is unexpected"
            echo "  [INFO] Use eol_modifier.py on PC as fallback"
        fi
    else
        echo "  [WARN] Unexpected flag state: '$CURRENT'"
    fi

    # Check for RANGE_ block (VW/RNS-850 variants)
    HAS_RANGE=$(strings "$LSD" 2>/dev/null | grep "^RANGE_EOLFLAG_GOOGLE_EARTH=0$" | head -1)
    if [ -n "$HAS_RANGE" ]; then
        echo ""
        echo "  [WARN] RANGE_EOLFLAG_GOOGLE_EARTH=0 detected!"
        echo "  [INFO] This variant has a range lock on Google Earth"
        echo "  [INFO] The flag was set to 1 but the UI may still block it"
        echo "  [INFO] gemmi_final can still run independently of the UI flag"
        echo "  [INFO] For full UI unlock, use eol_modifier.py --remove-range"
    fi
elif [ -n "$LSD" ] && [ $LSD_WRITABLE -eq 0 ]; then
    echo "  [SKIP] lsd.jxe is on read-only IFS"
    echo "  [INFO] To patch, use eol_modifier.py on PC + IFS reflash"
    echo "  [INFO] Or: gemmi_final may run independently of EOL flags"
else
    echo "  [WARN] lsd.jxe not found"
fi
echo ""

# ============================================================
# Step 6: Backup + modify drivers.ini
# ============================================================
echo "[STEP 6] drivers.ini modification..."
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
# Step 7: Network check
# ============================================================
echo "[STEP 7] Network connectivity..."
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
# Step 8: Direct GEMMI launch (no reboot needed!)
# ============================================================
echo "[STEP 8] Direct GEMMI launch..."

GEMMI_LAUNCHED=0
GEMMI_BIN="${GEMMI_TARGET}/gemmi_final"
GEMMI_RUN="${GEMMI_TARGET}/run_gemmi.sh"

# Check if GEMMI is already running
GEMMI_PID=$(pidin -F "%a %N" 2>/dev/null | grep gemmi_final | awk '{print $1}')
if [ -n "$GEMMI_PID" ]; then
    echo "  [OK] gemmi_final already running (PID: $GEMMI_PID)"
    GEMMI_LAUNCHED=1
elif [ -x "$GEMMI_BIN" ]; then
    echo "  [INFO] Attempting direct launch of gemmi_final..."

    # Set up library path for GEMMI
    export LD_LIBRARY_PATH="${GEMMI_TARGET}:${LD_LIBRARY_PATH}"

    if [ -x "$GEMMI_RUN" ]; then
        # Use the official run_gemmi.sh (handles region, memory, priority)
        echo "  [EXEC] ${GEMMI_RUN}"
        ksh "${GEMMI_RUN}" > /dev/null 2>&1 &
        GEMMI_LAUNCHED=1
    else
        # Direct launch with sensible defaults
        echo "  [EXEC] ${GEMMI_BIN} (direct)"
        "${GEMMI_BIN}" \
            -roadwidthscale 0.0116 \
            -opt 1 \
            -prefetch 1 \
            -maxfps 12 \
            -maxmem 55 \
            -targetmem 40 \
            -maxpingtime 2000 \
            -framestats 0 \
            -minsleep 10 \
            -streetviewtexeldensity 2.0 \
            -createroadsinmultibunch \
            > /dev/null 2>&1 &
        GEMMI_LAUNCHED=1
    fi

    if [ $GEMMI_LAUNCHED -eq 1 ]; then
        sleep 2
        # Verify it's running
        CHECK_PID=$(pidin -F "%a %N" 2>/dev/null | grep gemmi_final | awk '{print $1}')
        if [ -n "$CHECK_PID" ]; then
            echo "  [OK] gemmi_final running! (PID: $CHECK_PID)"
            echo "  [OK] Google Earth should appear on the nav map"
        else
            echo "  [WARN] gemmi_final started but may have exited"
            echo "  [INFO] Check log for errors, may need internet first"
            GEMMI_LAUNCHED=0
        fi
    fi
else
    echo "  [SKIP] gemmi_final not found at ${GEMMI_BIN}"
    echo "  [INFO] Deploy GEMMI binaries first"
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
echo " EOL flag:         $(strings "${LSD:-none}" 2>/dev/null | grep '^EOLFLAG_GOOGLE_EARTH=' | head -1 || echo 'UNKNOWN')"
echo " RANGE lock:       $(strings "${LSD:-none}" 2>/dev/null | grep -c '^RANGE_EOLFLAG_GOOGLE_EARTH=0' || echo '?') entries"
echo " disableAuthKey:   $(grep -q disableAuthKey "$DRIVERS_INI" 2>/dev/null && echo 'SET' || echo 'NOT SET')"
echo " Internet:         $([ $HAS_NET -eq 1 ] && echo 'CONNECTED' || echo 'NOT CONNECTED')"
echo " GEMMI running:    $([ $GEMMI_LAUNCHED -eq 1 ] && echo 'YES' || echo 'NO')"
echo " Backup:           ${BACKUP}/"
echo ""

if [ $GEMMI_LAUNCHED -eq 1 ]; then
    echo " GEMMI launched directly — check nav map for GE overlay!"
    echo " Note: direct launch is non-persistent (lost on reboot)"
    echo " For persistent launch, the EOL flag + menu enable is needed"
    echo " (or reflash IFS with patched srv-starter.cfg)"
elif [ $CHANGES -gt 0 ]; then
    echo " REBOOT to apply EOL flag + drivers.ini changes"
    echo ""
    echo " After reboot:"
    echo "   1. Ensure internet is connected"
    echo "   2. Open NAV > Map Settings > check for Google Earth"
    echo "   3. If GE option appears, enable it"
    echo "   4. If not, run ge_probe.sh and share results"
fi

echo ""
echo " To revert: run ge_restore.sh from SD card"

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
