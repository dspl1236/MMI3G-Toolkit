#!/bin/ksh
# ============================================================
# MMI3G-Toolkit — Google Earth Deploy
# Deploys GEMMI + on-car proxy for satellite imagery
# No PC required — proxy runs on the MMI, tiles via internet
#
# Usage: ksh ge_deploy.sh [sdpath]
#
# Part of MMI3G-Toolkit: github.com/dspl1236/MMI3G-Toolkit
# ============================================================

SDPATH="${1:-${0%/*}/..}"
if [ -f "${SDPATH}/scripts/common/platform.sh" ]; then
    . "${SDPATH}/scripts/common/platform.sh"
fi

GEMMI_SRC="${SDPATH}/gemmi"
GEMMI_DST="/mnt/nav/gemmi"

OUTDIR="${SDPATH}/var/google-earth"
mkdir -p "${OUTDIR}" 2>/dev/null
LOG="${OUTDIR}/ge-deploy.log"

exec > "${LOG}" 2>&1

echo "============================================"
echo " Google Earth Deploy"
echo "============================================"
echo ""

# --- Step 1: Verify source files ---
echo "=== Step 1: Verify SD card files ==="
if [ ! -d "${GEMMI_SRC}" ]; then
    echo "[ERROR] No gemmi/ directory on SD card!"
    exit 1
fi

SO_FILE="${GEMMI_SRC}/libembeddedearth_oncar.so"
if [ ! -f "${SO_FILE}" ]; then
    SO_FILE="${GEMMI_SRC}/libembeddedearth.so"
fi

if [ ! -f "${SO_FILE}" ]; then
    echo "[ERROR] No libembeddedearth .so found on SD card!"
    exit 1
fi

SO_SIZE=$(ls -la "${SO_FILE}" | awk '{print $5}')
echo "[OK] Source .so: ${SO_SIZE} bytes (${SO_FILE##*/})"

for f in gemmi_final libmessaging.so ge_settings.dat run_gemmi.sh dbRoot_custom.bin auth_resp1.bin auth_resp2.bin gemmi_proxy; do
    if [ -f "${GEMMI_SRC}/${f}" ]; then
        echo "[OK] ${f}"
    else
        echo "[WARN] Missing: ${f}"
    fi
done

# --- Step 2: Remount /mnt/nav writable ---
echo ""
echo "=== Step 2: Remount /mnt/nav writable ==="
mount -u -o rw /dev/hd0t77 /mnt/nav 2>/dev/null
touch /mnt/nav/.write_test 2>/dev/null
if [ $? -eq 0 ]; then
    rm /mnt/nav/.write_test 2>/dev/null
    echo "[OK] /mnt/nav is writable"
else
    echo "[ERROR] Cannot make /mnt/nav writable!"
    exit 1
fi

# --- Step 3: Kill GEMMI ---
echo ""
echo "=== Step 3: Kill GEMMI ==="
slay -f gemmi_proxy 2>/dev/null
slay -f gemmi_final 2>/dev/null
sleep 2
echo "[OK] GEMMI kill signal sent (rm -f will handle any remaining locks)"

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

# Deploy the .so — rm first (mhhauto technique: running process keeps old fd)
rm -f "${GEMMI_DST}/libembeddedearth.so" 2>/dev/null
cp "${SO_FILE}" "${GEMMI_DST}/libembeddedearth.so"
echo "[OK] libembeddedearth.so deployed ($(ls -la "${GEMMI_DST}/libembeddedearth.so" | awk '{print $5}') bytes)"

# Deploy all other GEMMI files — rm -f before each cp
for f in gemmi_final libmessaging.so libthirdparty_icu_3_5.so mapStylesWrite ge_settings.dat gemmi_models_res.zip dbRoot_custom.bin auth_resp1.bin auth_resp2.bin gemmi_control.sh gemmi_server.sh gemmi_proxy run_gemmi.sh; do
    if [ -f "${GEMMI_SRC}/${f}" ]; then
        rm -f "${GEMMI_DST}/${f}" 2>/dev/null
        cp "${GEMMI_SRC}/${f}" "${GEMMI_DST}/${f}"
        echo "[OK] ${f}"
    fi
done

# Rename ge_settings.dat → drivers.ini (Chrome blocks .ini on SD cards)
if [ -f "${GEMMI_DST}/ge_settings.dat" ]; then
    mv "${GEMMI_DST}/ge_settings.dat" "${GEMMI_DST}/drivers.ini"
    echo "[OK] ge_settings.dat → drivers.ini"
fi

chmod +x "${GEMMI_DST}/gemmi_final" 2>/dev/null
chmod +x "${GEMMI_DST}/gemmi_proxy" 2>/dev/null

# Deploy StreetView assets (models/ subdirectory)
if [ -d "${GEMMI_SRC}/models" ]; then
    mkdir -p "${GEMMI_DST}/models" 2>/dev/null
    for f in $(ls "${GEMMI_SRC}/models/" 2>/dev/null); do
        cp "${GEMMI_SRC}/models/${f}" "${GEMMI_DST}/models/${f}" 2>/dev/null
    done
    echo "[OK] models/ assets deployed"
fi
chmod +x "${GEMMI_DST}/run_gemmi.sh" 2>/dev/null

# --- Step 6: Configure on-car proxy ---
echo ""
echo "=== Step 6: Configure on-car proxy ==="

# Remove any old hosts-file entries from run_gemmi.sh (from previous installs)
if grep -q "kh.google.com" "${GEMMI_DST}/run_gemmi.sh" 2>/dev/null; then
    grep -v "kh.google.com\|geoauth.google.com\|maps.google.com" "${GEMMI_DST}/run_gemmi.sh" > "${GEMMI_DST}/run_gemmi.sh.tmp"
    mv "${GEMMI_DST}/run_gemmi.sh.tmp" "${GEMMI_DST}/run_gemmi.sh"
    chmod +x "${GEMMI_DST}/run_gemmi.sh"
    echo "[OK] Cleaned old hosts entries from run_gemmi.sh"
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

# Clean /etc/hosts (remove any old proxy redirects for Google Earth servers)
if grep -q "kh.google.com" /etc/hosts 2>/dev/null; then
    grep -v "kh.google.com\|geoauth.google.com\|maps.google.com\|cbk0.google.com" /etc/hosts > /etc/hosts.tmp
    cp /etc/hosts.tmp /etc/hosts
    rm /etc/hosts.tmp 2>/dev/null
    echo "[OK] Cleaned old proxy entries from /etc/hosts"
fi

echo "[OK] On-car proxy configured: gemmi_proxy on 127.0.0.1:80"

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
echo "Proxy: $(ls -la "${GEMMI_DST}/gemmi_proxy" 2>/dev/null)"
echo "Hosts: $(cat /etc/hosts)"

echo ""
echo "============================================"
echo " Deploy Complete!"
echo ""
echo " IMPORTANT: Eject SD card, then hard reboot"
echo " the MMI to activate Google Earth."
echo " Internet connectivity required (any method)."
echo "============================================"
