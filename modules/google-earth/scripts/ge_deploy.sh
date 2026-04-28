#!/bin/ksh
# ============================================================
# MMI3G-Toolkit — Google Earth Deploy
# Deploys patched GEMMI binaries from SD card to car HDD
#
# Handles: remount writable, kill GEMMI, copy files, verify
# Supports: proxy mode (PC required) and oncar mode (no PC)
#
# Usage: ksh ge_deploy.sh [mode]
#   mode: proxy (default) — requires PC proxy at 192.168.0.91
#         oncar           — self-contained, no PC needed
#
# Part of MMI3G-Toolkit: github.com/dspl1236/MMI3G-Toolkit
# ============================================================

SDPATH="${1:-${0%/*}/..}"
if [ -f "${SDPATH}/scripts/common/platform.sh" ]; then
    . "${SDPATH}/scripts/common/platform.sh"
fi

# Auto-detect mode: if oncar .so exists on SD card, use oncar mode
if [ -f "${SDPATH}/gemmi/libembeddedearth_oncar.so" ]; then
    MODE="oncar"
else
    MODE="proxy"
fi
GEMMI_SRC="${SDPATH}/gemmi"
GEMMI_DST="/mnt/nav/gemmi"
GEDB_DIR="/mnt/nav/gedb"

OUTDIR="${SDPATH}/var/google-earth"
mkdir -p "${OUTDIR}" 2>/dev/null
LOG="${OUTDIR}/ge-deploy.log"

exec > "${LOG}" 2>&1

echo "============================================"
echo " Google Earth Deploy — Mode: ${MODE}"
echo "============================================"
echo ""

# --- Step 1: Verify source files ---
echo "=== Step 1: Verify SD card files ==="
if [ ! -d "${GEMMI_SRC}" ]; then
    echo "[ERROR] No gemmi/ directory on SD card!"
    exit 1
fi

SO_FILE="${GEMMI_SRC}/libembeddedearth.so"
if [ "${MODE}" = "oncar" ] && [ -f "${GEMMI_SRC}/libembeddedearth_oncar.so" ]; then
    SO_FILE="${GEMMI_SRC}/libembeddedearth_oncar.so"
    echo "[INFO] Using oncar binary (hostnames → 127.0.0.1 for on-car proxy)"
fi

if [ ! -f "${SO_FILE}" ]; then
    echo "[ERROR] libembeddedearth.so not found on SD card!"
    echo "Download from: github.com/dspl1236/MMI3G-Toolkit/releases/tag/v1.1-ge-patched"
    exit 1
fi

SO_SIZE=$(ls -la "${SO_FILE}" | awk '{print $5}')
echo "[OK] Source .so: ${SO_SIZE} bytes"

for f in gemmi_final libmessaging.so ge_settings.dat run_gemmi.sh dbRoot_custom.bin auth_resp1.bin auth_resp2.bin; do
    if [ -f "${GEMMI_SRC}/${f}" ]; then
        echo "[OK] ${f}"
    else
        echo "[WARN] Missing: ${f}"
    fi
done

# --- Step 2: Kill GEMMI ---
echo ""
echo "=== Step 2: Kill GEMMI ==="
# Kill run_gemmi.sh FIRST to prevent it from restarting gemmi_final
slay -f run_gemmi.sh 2>/dev/null
sleep 1
# Now kill gemmi_final and gemmi_proxy (nothing will restart them)
slay -f gemmi_final 2>/dev/null
slay -f gemmi_proxy 2>/dev/null
sleep 3
# Verify everything is dead
if pidin ar 2>/dev/null | grep -q "gemmi_final"; then
    echo "[WARN] gemmi_final still running — trying SIGKILL"
    slay -s KILL gemmi_final 2>/dev/null
    sleep 2
fi
echo "[OK] GEMMI processes killed"

# --- Step 3: Remount /mnt/nav writable ---
echo ""
echo "=== Step 3: Remount /mnt/nav writable ==="
mount -u -o rw /dev/hd0t77 /mnt/nav 2>/dev/null
# Verify writable
touch /mnt/nav/.write_test 2>/dev/null
if [ $? -eq 0 ]; then
    rm /mnt/nav/.write_test 2>/dev/null
    echo "[OK] /mnt/nav is writable"
else
    echo "[ERROR] Cannot make /mnt/nav writable!"
    exit 1
fi

# --- Step 4: Backup originals ---
echo ""
echo "=== Step 4: Backup originals ==="
if [ -f "${GEMMI_DST}/libembeddedearth.so" ] && [ ! -f "${GEMMI_DST}/libembeddedearth.so.orig" ]; then
    cp "${GEMMI_DST}/libembeddedearth.so" "${GEMMI_DST}/libembeddedearth.so.orig"
    echo "[OK] Backed up original .so"
fi

# --- Step 5: Deploy files ---
echo ""
echo "=== Step 5: Deploy files ==="
mkdir -p "${GEMMI_DST}" 2>/dev/null

# Copy the .so (proxy or oncar version)
# Use copy-then-rename trick for locked files (QNX allows mv on open files)
cp "${SO_FILE}" "${GEMMI_DST}/libembeddedearth.so.NEW" 2>&1
if [ $? -eq 0 ]; then
    mv "${GEMMI_DST}/libembeddedearth.so" "${GEMMI_DST}/libembeddedearth.so.OLD" 2>/dev/null
    mv "${GEMMI_DST}/libembeddedearth.so.NEW" "${GEMMI_DST}/libembeddedearth.so"
    echo "[OK] libembeddedearth.so deployed ($(ls -la "${GEMMI_DST}/libembeddedearth.so" | awk '{print $5}') bytes)"
else
    echo "[ERROR] Failed to copy libembeddedearth.so!"
fi

# Copy other GEMMI files (only if present on SD)
for f in gemmi_final libmessaging.so libthirdparty_icu_3_5.so mapStylesWrite ge_settings.dat gemmi_models_res.zip dbRoot_custom.bin auth_resp1.bin auth_resp2.bin gemmi_control.sh gemmi_server.sh gemmi_proxy; do
    if [ -f "${GEMMI_SRC}/${f}" ]; then
        cp "${GEMMI_SRC}/${f}" "${GEMMI_DST}/${f}" 2>&1
        if [ $? -ne 0 ]; then
            # File locked — use copy+rename trick
            cp "${GEMMI_SRC}/${f}" "${GEMMI_DST}/${f}.NEW" 2>&1
            if [ $? -eq 0 ]; then
                mv "${GEMMI_DST}/${f}" "${GEMMI_DST}/${f}.OLD" 2>/dev/null
                mv "${GEMMI_DST}/${f}.NEW" "${GEMMI_DST}/${f}"
                echo "[OK] ${f} (via rename)"
            else
                echo "[ERROR] ${f} — copy failed!"
            fi
        else
            echo "[OK] ${f}"
        fi
    fi
done

# Rename ge_settings.dat back to drivers.ini (Chrome blocks .ini on SD cards)
if [ -f "${GEMMI_DST}/ge_settings.dat" ] && [ ! -f "${GEMMI_DST}/drivers.ini" ]; then
    mv "${GEMMI_DST}/ge_settings.dat" "${GEMMI_DST}/drivers.ini"
    echo "[OK] Renamed ge_settings.dat → drivers.ini"
fi

chmod +x "${GEMMI_DST}/gemmi_final" 2>/dev/null
chmod +x "${GEMMI_DST}/run_gemmi.sh" 2>/dev/null

# Rename .cfg to .ini (Chrome blocks .ini in File System Access API)
if [ -f "${GEMMI_DST}/ge_settings.dat" ]; then
    mv "${GEMMI_DST}/ge_settings.dat" "${GEMMI_DST}/drivers.ini"
    echo "[OK] ge_settings.dat → drivers.ini"
fi

# --- Step 6: Mode-specific setup ---
echo ""
echo "=== Step 6: Mode setup (${MODE}) ==="

if [ "${MODE}" = "oncar" ]; then
    # On-car proxy mode: gemmi_proxy serves dbRoot + auth locally
    # All hostnames in .so → 127.0.0.1, proxy forwards tiles to Google

    # Deploy gemmi_proxy
    if [ -f "${GEMMI_SRC}/gemmi_proxy" ]; then
        cp "${GEMMI_SRC}/gemmi_proxy" "${GEMMI_DST}/gemmi_proxy"
        chmod +x "${GEMMI_DST}/gemmi_proxy"
        echo "[OK] gemmi_proxy deployed"
    else
        echo "[ERROR] gemmi_proxy not found on SD card!"
    fi

    # Remove proxy hosts entry from run_gemmi.sh if present
    if grep -q "192.168.0.91" "${GEMMI_DST}/run_gemmi.sh" 2>/dev/null; then
        grep -v "192.168.0.91\|kh.google.com.*hosts\|hosts.*kh.google.com" "${GEMMI_DST}/run_gemmi.sh" > "${GEMMI_DST}/run_gemmi.sh.tmp"
        mv "${GEMMI_DST}/run_gemmi.sh.tmp" "${GEMMI_DST}/run_gemmi.sh"
        chmod +x "${GEMMI_DST}/run_gemmi.sh"
        echo "[OK] Removed PC proxy hosts entry from run_gemmi.sh"
    fi

    # Add gemmi_proxy startup to run_gemmi.sh (before GEMMI starts)
    if ! grep -q "gemmi_proxy" "${GEMMI_DST}/run_gemmi.sh" 2>/dev/null; then
        echo '# Start on-car proxy (serves dbRoot + auth, forwards tiles to Google)' > "${GEMMI_DST}/run_gemmi.sh.tmp"
        echo 'if [ -x /mnt/nav/gemmi/gemmi_proxy ]; then' >> "${GEMMI_DST}/run_gemmi.sh.tmp"
        echo '    /mnt/nav/gemmi/gemmi_proxy &' >> "${GEMMI_DST}/run_gemmi.sh.tmp"
        echo '    sleep 1' >> "${GEMMI_DST}/run_gemmi.sh.tmp"
        echo 'fi' >> "${GEMMI_DST}/run_gemmi.sh.tmp"
        cat "${GEMMI_DST}/run_gemmi.sh" >> "${GEMMI_DST}/run_gemmi.sh.tmp"
        mv "${GEMMI_DST}/run_gemmi.sh.tmp" "${GEMMI_DST}/run_gemmi.sh"
        chmod +x "${GEMMI_DST}/run_gemmi.sh"
        echo "[OK] Added gemmi_proxy startup to run_gemmi.sh"
    fi

    # Clean /etc/hosts (no PC proxy redirect needed)
    if grep -q "192.168.0.91" /etc/hosts 2>/dev/null; then
        grep -v "192.168.0.91" /etc/hosts > /etc/hosts.tmp
        cp /etc/hosts.tmp /etc/hosts
        rm /etc/hosts.tmp 2>/dev/null
        echo "[OK] Cleaned /etc/hosts"
    fi

    echo "[OK] On-car proxy mode: gemmi_proxy on 127.0.0.1:80, tiles via LTE"

elif [ "${MODE}" = "proxy" ]; then
    # Proxy mode: add hosts entry for PC proxy
    # Add to /etc/hosts
    grep -q "192.168.0.91 kh.google.com" /etc/hosts 2>/dev/null || \
        echo "192.168.0.91 kh.google.com geoauth.google.com maps.google.com" >> /etc/hosts
    echo "[OK] Proxy hosts entry added (192.168.0.91)"

    # Ensure run_gemmi.sh adds hosts on reboot
    if ! grep -q "192.168.0.91" "${GEMMI_DST}/run_gemmi.sh" 2>/dev/null; then
        # Prepend hosts line to run_gemmi.sh
        echo 'grep -q "192.168.0.91 kh.google.com" /etc/hosts || echo "192.168.0.91 kh.google.com geoauth.google.com maps.google.com" >> /etc/hosts' > "${GEMMI_DST}/run_gemmi.sh.tmp"
        cat "${GEMMI_DST}/run_gemmi.sh" >> "${GEMMI_DST}/run_gemmi.sh.tmp"
        mv "${GEMMI_DST}/run_gemmi.sh.tmp" "${GEMMI_DST}/run_gemmi.sh"
        chmod +x "${GEMMI_DST}/run_gemmi.sh"
        echo "[OK] Added proxy hosts entry to run_gemmi.sh"
    fi

    echo "[OK] Proxy mode: start proxy on PC before rebooting"
fi

# --- Step 7: Wipe tile cache ---
echo ""
echo "=== Step 7: Wipe tile cache ==="
rm -rf /mnt/img-cache/gemmi/cache/* 2>/dev/null
rm -rf /mnt/img-cache/gemmi/scache/* 2>/dev/null
rm -rf /mnt/img-cache/gemmi/temp/* 2>/dev/null
echo "[OK] Tile cache wiped"

# --- Step 8: Verify ---
echo ""
echo "=== Step 8: Verify deployment ==="
echo "Deployed .so: $(cksum "${GEMMI_DST}/libembeddedearth.so" 2>/dev/null)"
echo "Hosts: $(cat /etc/hosts)"
if [ "${MODE}" = "oncar" ]; then
    echo "dbRoot: $(ls -la "${GEDB_DIR}/dbRoot.v5" 2>/dev/null)"
fi
ls -la "${GEMMI_DST}/" 2>/dev/null

echo ""
echo "============================================"
echo " Deploy Complete!"
echo ""
echo " IMPORTANT: Eject SD card, then hard reboot"
echo " the MMI to activate Google Earth."
if [ "${MODE}" = "proxy" ]; then
    echo " Start PC proxy BEFORE rebooting:"
    echo "   cd D:\\MMI\\proxy"
    echo "   python gemmi_tile_proxy.py"
fi
echo "============================================"
