#!/bin/ksh
# ============================================================
# MMI3G-Toolkit — Google Earth Activation
# Deploys: patched libembeddedearth.so, custom dbRoot, auth cache,
#          mini HTTP server, /etc/hosts entry
# ============================================================

_SDPATH_GUESS="${SDPATH:-${0%/*}}"
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

# No tee on QNX — just echo to log
log() { echo "$1" >> "$LOG" 2>/dev/null; echo "$1"; }

log "=== Google Earth Activation ==="

# --- Pre-flight checks ---
if [ ! -d "$GEMMI" ]; then
    log "ERROR: $GEMMI not found. GEMMI not installed."
    exit 1
fi

if [ ! -f "$GEMMI/libembeddedearth.so" ]; then
    log "ERROR: libembeddedearth.so not found in $GEMMI/"
    exit 1
fi

if [ ! -f "$PAYLOAD/dbRoot_custom.bin" ]; then
    log "ERROR: Payload not found at $PAYLOAD/"
    exit 1
fi

# --- Backup originals ---
if [ ! -f "$BACKUP/libembeddedearth.so.orig" ]; then
    log "Backing up originals..."
    cp "$GEMMI/libembeddedearth.so" "$BACKUP/libembeddedearth.so.orig"
    cp "$GEMMI/run_gemmi.sh" "$BACKUP/run_gemmi.sh.orig" 2>/dev/null
    cp /etc/hosts "$BACKUP/hosts.orig" 2>/dev/null
    log "  Backed up to $BACKUP/"
else
    log "Backups already exist."
fi

# --- Stop GEMMI ---
log "Stopping GEMMI..."
slay gemmi_final 2>/dev/null
sleep 1

# --- Deploy patched binary ---
if [ -f "$PAYLOAD/libembeddedearth.so" ]; then
    log "Deploying patched libembeddedearth.so..."
    cp "$PAYLOAD/libembeddedearth.so" "$GEMMI/libembeddedearth.so"
    log "  Done ($(wc -c < $GEMMI/libembeddedearth.so 2>/dev/null) bytes)"
else
    log "WARNING: No patched binary on SD card."
fi

# --- Deploy support files ---
log "Deploying GE files..."
cp "$PAYLOAD/dbRoot_custom.bin" "$GEMMI/dbRoot_custom.bin"
cp "$PAYLOAD/auth_resp1.bin" "$GEMMI/auth_resp1.bin"
cp "$PAYLOAD/auth_resp2.bin" "$GEMMI/auth_resp2.bin"

if [ -f "$PAYLOAD/gemmi_server.sh" ]; then
    cp "$PAYLOAD/gemmi_server.sh" "$GEMMI/gemmi_server.sh"
    chmod +x "$GEMMI/gemmi_server.sh"
fi

if [ -f "$PAYLOAD/gemmi_control.sh" ]; then
    cp "$PAYLOAD/gemmi_control.sh" "$GEMMI/gemmi_control.sh"
    chmod +x "$GEMMI/gemmi_control.sh"
fi
log "  All files deployed."

# --- Set up /etc/hosts (volatile — also add to run_gemmi.sh) ---
log "Configuring /etc/hosts..."
if ! grep -q "kh.google.com" /etc/hosts 2>/dev/null; then
    echo "192.168.0.91 kh.google.com" >> /etc/hosts
    log "  Added: 192.168.0.91 kh.google.com"
else
    log "  Already configured"
fi

# --- Patch run_gemmi.sh to persist /etc/hosts across reboots ---
log "Patching run_gemmi.sh for boot persistence..."
if [ -f "$GEMMI/run_gemmi.sh" ]; then
    if ! grep -q "kh.google.com" "$GEMMI/run_gemmi.sh" 2>/dev/null; then
        # Add hosts entry at the TOP of run_gemmi.sh (before gemmi starts)
        cp "$GEMMI/run_gemmi.sh" "$GEMMI/run_gemmi.sh.tmp"
        echo '#!/bin/ksh' > "$GEMMI/run_gemmi.sh"
        echo '# Google Earth: add hosts entry on every boot' >> "$GEMMI/run_gemmi.sh"
        echo 'grep -q "kh.google.com" /etc/hosts 2>/dev/null || echo "192.168.0.91 kh.google.com" >> /etc/hosts' >> "$GEMMI/run_gemmi.sh"
        # Append original content (skip first shebang line)
        tail -n +2 "$GEMMI/run_gemmi.sh.tmp" >> "$GEMMI/run_gemmi.sh"
        rm "$GEMMI/run_gemmi.sh.tmp"
        chmod +x "$GEMMI/run_gemmi.sh"
        log "  run_gemmi.sh patched for boot persistence"
    else
        log "  run_gemmi.sh already patched"
    fi
else
    log "  WARNING: run_gemmi.sh not found"
fi

# --- Clear cache ---
log "Clearing tile cache..."
rm -rf /mnt/img-cache/gemmi/cache/* 2>/dev/null
log "  Cache cleared"

# --- Summary ---
log ""
log "=== Google Earth Activation Complete ==="
log "Deployed to $GEMMI/"
log "Reboot MMI. Start proxy on PC (192.168.0.91)."
log "To revert: run ge_restore.sh"
