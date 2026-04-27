#!/bin/ksh

_SDPATH_GUESS="${SDPATH:-${0%/*}}"
if [ -f "${_SDPATH_GUESS}/scripts/common/platform.sh" ]; then
    . "${_SDPATH_GUESS}/scripts/common/platform.sh"
elif [ -f "/mnt/efs-system/scripts/common/platform.sh" ]; then
    . "/mnt/efs-system/scripts/common/platform.sh"
fi

SDPATH="${1:-${_SDPATH_GUESS}}"
TS=$(date +%H%M%S 2>/dev/null || echo "000000")
if command -v mmi_logstamp >/dev/null 2>&1; then TS="$(mmi_logstamp)"; fi

OUTDIR="${SDPATH}/var/google-earth"
LOG="${OUTDIR}/gemmi-wrapper-install-${TS}.log"
mkdir -p "${OUTDIR}" 2>/dev/null

exec > "${LOG}" 2>&1

echo "============================================"
echo " Google Earth GEMMI Wrapper Install"
echo " $(date)"
echo " Train: $(cat /dev/shmem/sw_trainname.txt 2>/dev/null)"
echo "============================================"
echo ""
echo "[INFO] Installing legacy /scripts/GEMMI wrappers expected by the OEM GoogleEarth screen"
echo "[INFO] Wrappers will be copied by the generated installer to /mnt/efs-system/scripts/GEMMI/"
echo "[INFO] Target donor runtime: /mnt/nav/gemmi/"
echo ""

if [ -d /mnt/nav/gemmi ]; then
    echo "[OK] /mnt/nav/gemmi exists"
    ls -la /mnt/nav/gemmi 2>/dev/null
else
    echo "[WARN] /mnt/nav/gemmi missing"
    echo "[WARN] Install the P0824 donor runtime first"
fi

echo ""
echo "Log: ${LOG}"
echo "============================================"
