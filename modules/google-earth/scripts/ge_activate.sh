#!/bin/ksh
# ============================================================
# MMI3G-Toolkit — Google Earth Activation
# Deploys: patched libembeddedearth.so, custom dbRoot, auth cache,
#          mini HTTP server, /etc/hosts entry
#
# Requirements:
#   - Root shell access
#   - LTE internet (USB ethernet + Digi WR11 or similar)
#   - GEMMI binaries already present at /mnt/nav/gemmi/
#
# Revert with ge_restore.sh
# ============================================================

_SDPATH_GUESS="${SDPATH:-$(dirname $0)}"
if [ -f "${_SDPATH_GUESS}/scripts/common/platform.sh" ]; then
    . "${_SDPATH_GUESS}/scripts/common/platform.sh"
elif [ -f "/mnt/efs-system/scripts/common/platform.sh" ]; then
    . "/mnt/efs-system/scripts/common/platform.sh"
fi

SDPATH="${_SDPATH_GUESS}"
OUTDIR="${SDPATH}/var/google-earth"
LOG="${OUTDIR}/ge-activate.log"
BACKUP="/mnt/nav/.mmi3g_toolkit/google-earth"
GEMMI="/mnt/nav/gemmi"
PAYLOAD="${SDPATH}/gemmi"

mkdir -p "${OUTDIR}" 2>/dev/null
mkdir -p "${BACKUP}" 2>/dev/null

# Show status
if [ -x "${SDPATH}/bin/showScreen" ] && [ -f "${SDPATH}/lib/running.png" ]; then
    "${SDPATH}/bin/showScreen" "${SDPATH}/lib/running.png" 2>/dev/null &
    SHOW_PID=$!
fi

log() { echo "$1" | tee -a "$LOG"; }

log "=== Google Earth Activation ==="
log "$(date 2>/dev/null || echo 'no date')"
log ""

# --- Pre-flight checks ---
if [ ! -d "$GEMMI" ]; then
    log "ERROR: $GEMMI not found. GEMMI not installed."
    log "This module requires GEMMI binaries to be present."
    exit 1
fi

if [ ! -f "$GEMMI/libembeddedearth.so" ]; then
    log "ERROR: libembeddedearth.so not found in $GEMMI/"
    exit 1
fi

# Check if payload files exist on SD card
if [ ! -f "$PAYLOAD/dbRoot_custom.bin" ]; then
    log "ERROR: Payload files not found at $PAYLOAD/"
    log "Expected: dbRoot_custom.bin, auth_resp1.bin, auth_resp2.bin"
    exit 1
fi

# --- Backup originals ---
if [ ! -f "$BACKUP/libembeddedearth.so.orig" ]; then
    log "Backing up original files..."
    cp "$GEMMI/libembeddedearth.so" "$BACKUP/libembeddedearth.so.orig"
    cp "$GEMMI/run_gemmi.sh" "$BACKUP/run_gemmi.sh.orig" 2>/dev/null
    cp /etc/hosts "$BACKUP/hosts.orig" 2>/dev/null
    log "  Backed up to $BACKUP/"
else
    log "Backups already exist, skipping."
fi

# --- Stop GEMMI ---
log "Stopping GEMMI..."
slay gemmi_final 2>/dev/null
sleep 1

# --- Apply binary patches ---
log "Applying code patches to libembeddedearth.so..."

# We need the pre-patched binary from the SD card
if [ -f "$PAYLOAD/libembeddedearth.so" ]; then
    log "  Deploying pre-patched binary from SD card..."
    cp "$PAYLOAD/libembeddedearth.so" "$GEMMI/libembeddedearth.so"
    log "  libembeddedearth.so deployed ($(wc -c < $GEMMI/libembeddedearth.so) bytes)"
else
    log "  WARNING: No pre-patched binary on SD card."
    log "  Manual patching needed — see research/BINARY_PATCH_ANALYSIS.md"
fi

# --- Deploy support files ---
log "Deploying Google Earth files..."
cp "$PAYLOAD/dbRoot_custom.bin" "$GEMMI/dbRoot_custom.bin"
cp "$PAYLOAD/auth_resp1.bin" "$GEMMI/auth_resp1.bin"
cp "$PAYLOAD/auth_resp2.bin" "$GEMMI/auth_resp2.bin"
log "  dbRoot: $(wc -c < $GEMMI/dbRoot_custom.bin) bytes (custom, kh.google.com)"
log "  Auth1: $(wc -c < $GEMMI/auth_resp1.bin) bytes"
log "  Auth2: $(wc -c < $GEMMI/auth_resp2.bin) bytes"

# Deploy mini server and control scripts
if [ -f "$PAYLOAD/gemmi_server.sh" ]; then
    cp "$PAYLOAD/gemmi_server.sh" "$GEMMI/gemmi_server.sh"
    chmod +x "$GEMMI/gemmi_server.sh"
    log "  Mini server deployed"
fi

if [ -f "$PAYLOAD/gemmi_control.sh" ]; then
    cp "$PAYLOAD/gemmi_control.sh" "$GEMMI/gemmi_control.sh"
    chmod +x "$GEMMI/gemmi_control.sh"
    log "  Control script deployed"
fi

# --- Set up /etc/hosts ---
log "Configuring /etc/hosts..."
if ! grep -q "127.0.0.1 kh.google.com" /etc/hosts 2>/dev/null; then
    echo "127.0.0.1 kh.google.com" >> /etc/hosts
    log "  Added: 127.0.0.1 kh.google.com"
else
    log "  Already configured"
fi

# --- Clear GEMMI cache ---
log "Clearing GEMMI tile cache..."
rm -rf /mnt/img-cache/gemmi/cache/* 2>/dev/null
log "  Cache cleared"

# --- Summary ---
log ""
log "=== Google Earth Activation Complete ==="
log ""
log "Deployed files:"
log "  $GEMMI/libembeddedearth.so (patched)"
log "  $GEMMI/dbRoot_custom.bin"
log "  $GEMMI/auth_resp1.bin + auth_resp2.bin"
log "  $GEMMI/gemmi_server.sh"
log "  $GEMMI/gemmi_control.sh"
log ""
log "Next steps:"
log "  1. Hard reboot the MMI unit"
log "  2. Ensure LTE internet is connected"
log "  3. Open Google Earth from map menu"
log "  4. Satellite imagery should load!"
log ""
log "To revert: run ge_restore.sh from SD card"

# Show done
if [ -n "$SHOW_PID" ]; then
    kill $SHOW_PID 2>/dev/null
    if [ -x "${SDPATH}/bin/showScreen" ] && [ -f "${SDPATH}/lib/done.png" ]; then
        "${SDPATH}/bin/showScreen" "${SDPATH}/lib/done.png" 2>/dev/null &
    fi
fi
