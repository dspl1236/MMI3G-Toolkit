#!/bin/ksh
# GEMMI Dump — Extract Google Earth binaries and config for analysis
# Copies gemmi_final, libembeddedearth.so, and all config to SD card
# Part of MMI-Toolkit: github.com/dspl1236/MMI-Toolkit

SDPATH="${1:-${0%/*}}"

# Source platform.sh for QNX compatibility shims
if [ -f "${SDPATH}/scripts/common/platform.sh" ]; then
    . "${SDPATH}/scripts/common/platform.sh"
elif [ -f "/mnt/efs-system/scripts/common/platform.sh" ]; then
    . "/mnt/efs-system/scripts/common/platform.sh"
fi

TS=$(date +%H%M%S 2>/dev/null || echo "000000")
if command -v getTime >/dev/null 2>&1; then TS="epoch-$(getTime)"; fi

OUTDIR="${SDPATH}/var/gemmi_dump"
mkdir "${SDPATH}/var" 2>/dev/null
mkdir "${OUTDIR}" 2>/dev/null

# Show status
if [ -x "${SDPATH}/bin/showScreen" ] && [ -f "${SDPATH}/lib/running.png" ]; then
    "${SDPATH}/bin/showScreen" "${SDPATH}/lib/running.png" 2>/dev/null &
fi

LOG="${OUTDIR}/gemmi_dump.log"

{
echo "============================================"
echo " GEMMI Dump — Google Earth Binary Extraction"
echo " $(date 2>/dev/null)"
echo "============================================"
echo ""

GEMMI_DIR="/mnt/nav/gemmi"

if [ ! -d "$GEMMI_DIR" ]; then
    echo "[ERROR] GEMMI directory not found: $GEMMI_DIR"
    exit 1
fi

echo "[INFO] GEMMI directory found"
echo ""

# List everything
echo "--- Contents ---"
ls -la "$GEMMI_DIR/"
echo ""

# Copy binaries
echo "[COPY] gemmi_final..."
cp "$GEMMI_DIR/gemmi_final" "$OUTDIR/" 2>/dev/null && echo "  OK" || echo "  FAILED"

echo "[COPY] libembeddedearth.so..."
cp "$GEMMI_DIR/libembeddedearth.so" "$OUTDIR/" 2>/dev/null && echo "  OK" || echo "  FAILED"

echo "[COPY] libmessaging.so..."
cp "$GEMMI_DIR/libmessaging.so" "$OUTDIR/" 2>/dev/null && echo "  OK" || echo "  FAILED"

echo "[COPY] libthirdparty_icu_3_5.so..."
cp "$GEMMI_DIR/libthirdparty_icu_3_5.so" "$OUTDIR/" 2>/dev/null && echo "  OK" || echo "  FAILED"

# Config files
for f in drivers.ini run_gemmi.sh debug_gemmi.sh debug_memcpu.sh pg.sh mapStylesWrite; do
    if [ -f "$GEMMI_DIR/$f" ]; then
        echo "[COPY] $f"
        cp "$GEMMI_DIR/$f" "$OUTDIR/" 2>/dev/null
    fi
done

# Copy activation scripts from EFS
echo ""
echo "--- GEMMI Scripts ---"
if [ -d /mnt/efs-system/scripts/GEMMI ]; then
    mkdir "${OUTDIR}/scripts" 2>/dev/null
    cp /mnt/efs-system/scripts/GEMMI/* "${OUTDIR}/scripts/" 2>/dev/null
    ls -la /mnt/efs-system/scripts/GEMMI/
fi

# Get GEMMI info if script exists
echo ""
echo "--- GEMMI Info ---"
if [ -x /mnt/efs-system/scripts/GEMMI/getInfoGEMMI.sh ]; then
    /mnt/efs-system/scripts/GEMMI/getInfoGEMMI.sh 2>/dev/null
fi

# Check cache
echo ""
echo "--- GEMMI Cache ---"
ls -la /mnt/img-cache/gemmi/ 2>/dev/null
du -sk /mnt/img-cache/gemmi/ 2>/dev/null

# Get process info
echo ""
echo "--- GEMMI Process ---"
pidin ar 2>/dev/null | grep gemmi

echo ""
echo "============================================"
echo " Dump complete: ${OUTDIR}/"
echo " Total size: $(du -sk "$OUTDIR" 2>/dev/null | awk '{print $1}') KB"
echo ""
echo " Upload gemmi_final + libembeddedearth.so"
echo " for offline Ghidra analysis of Google"
echo " hostnames and auth bypass points."
echo "============================================"
} > "$LOG" 2>&1
cat "$LOG"

# Show done
if [ -x "${SDPATH}/bin/showScreen" ] && [ -f "${SDPATH}/lib/done.png" ]; then
    "${SDPATH}/bin/showScreen" "${SDPATH}/lib/done.png" 2>/dev/null &
fi
