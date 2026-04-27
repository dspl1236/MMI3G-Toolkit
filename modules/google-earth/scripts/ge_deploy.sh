#!/bin/ksh
# ============================================================
# MMI3G-Toolkit — Google Earth Deploy
# Deploys patched GEMMI binaries from SD card to car HDD
#
# Handles: remount writable, kill GEMMI, copy files, verify
# Supports: proxy mode (PC required) and dream mode (no PC)
#
# Usage: ksh ge_deploy.sh [mode]
#   mode: proxy (default) — requires PC proxy at 192.168.0.91
#         dream           — self-contained, no PC needed
#
# Part of MMI3G-Toolkit: github.com/dspl1236/MMI3G-Toolkit
# ============================================================

SDPATH="${SDPATH:-${0%/*}/..}"
if [ -f "${SDPATH}/scripts/common/platform.sh" ]; then
    . "${SDPATH}/scripts/common/platform.sh"
fi

MODE="${1:-proxy}"
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
if [ "${MODE}" = "dream" ] && [ -f "${GEMMI_SRC}/libembeddedearth_dream.so" ]; then
    SO_FILE="${GEMMI_SRC}/libembeddedearth_dream.so"
    echo "[INFO] Using dream binary (file:///mnt/nav/gedb/)"
fi

if [ ! -f "${SO_FILE}" ]; then
    echo "[ERROR] libembeddedearth.so not found on SD card!"
    echo "Download from: github.com/dspl1236/MMI3G-Toolkit/releases/tag/v1.1-ge-patched"
    exit 1
fi

SO_SIZE=$(ls -la "${SO_FILE}" | awk '{print $5}')
echo "[OK] Source .so: ${SO_SIZE} bytes"

for f in gemmi_final libmessaging.so drivers.ini run_gemmi.sh dbRoot_custom.bin auth_resp1.bin auth_resp2.bin; do
    if [ -f "${GEMMI_SRC}/${f}" ]; then
        echo "[OK] ${f}"
    else
        echo "[WARN] Missing: ${f}"
    fi
done

# --- Step 2: Kill GEMMI ---
echo ""
echo "=== Step 2: Kill GEMMI ==="
slay -f gemmi_final 2>/dev/null
sleep 2
slay -f run_gemmi.sh 2>/dev/null
sleep 1
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

# Copy the .so (proxy or dream version)
cp "${SO_FILE}" "${GEMMI_DST}/libembeddedearth.so"
echo "[OK] libembeddedearth.so deployed ($(ls -la "${GEMMI_DST}/libembeddedearth.so" | awk '{print $5}') bytes)"

# Copy other GEMMI files (only if present on SD)
for f in gemmi_final libmessaging.so libthirdparty_icu_3_5.so mapStylesWrite drivers.ini gemmi_models_res.zip dbRoot_custom.bin auth_resp1.bin auth_resp2.bin gemmi_control.sh gemmi_server.sh; do
    if [ -f "${GEMMI_SRC}/${f}" ]; then
        cp "${GEMMI_SRC}/${f}" "${GEMMI_DST}/${f}"
        echo "[OK] ${f}"
    fi
done

chmod +x "${GEMMI_DST}/gemmi_final" 2>/dev/null
chmod +x "${GEMMI_DST}/run_gemmi.sh" 2>/dev/null

# --- Step 6: Mode-specific setup ---
echo ""
echo "=== Step 6: Mode setup (${MODE}) ==="

if [ "${MODE}" = "dream" ]; then
    # Dream mode: dbRoot on HDD, no proxy needed
    mkdir -p "${GEDB_DIR}" 2>/dev/null
    cp "${GEMMI_DST}/dbRoot_custom.bin" "${GEDB_DIR}/dbRoot.v5"
    echo "[OK] dbRoot deployed to ${GEDB_DIR}/dbRoot.v5"

    # Remove proxy hosts entry from run_gemmi.sh if present
    if grep -q "192.168.0.91" "${GEMMI_DST}/run_gemmi.sh" 2>/dev/null; then
        # Rewrite run_gemmi.sh without the hosts line
        grep -v "192.168.0.91\|kh.google.com.*hosts\|hosts.*kh.google.com" "${GEMMI_DST}/run_gemmi.sh" > "${GEMMI_DST}/run_gemmi.sh.tmp"
        mv "${GEMMI_DST}/run_gemmi.sh.tmp" "${GEMMI_DST}/run_gemmi.sh"
        chmod +x "${GEMMI_DST}/run_gemmi.sh"
        echo "[OK] Removed proxy hosts entry from run_gemmi.sh"
    fi

    # Clean /etc/hosts (remove proxy redirect)
    if grep -q "192.168.0.91" /etc/hosts 2>/dev/null; then
        grep -v "192.168.0.91" /etc/hosts > /etc/hosts.tmp
        cp /etc/hosts.tmp /etc/hosts
        rm /etc/hosts.tmp 2>/dev/null
        echo "[OK] Cleaned /etc/hosts"
    fi

    echo "[OK] Dream mode: no proxy needed, tiles go direct to Google"

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
if [ "${MODE}" = "dream" ]; then
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
