#!/bin/ksh
# ============================================================
# DNS Refresh Probe
# One-shot diagnostic for RNS-850/MMI3G+ LTE routing.
# Logs current route/DNS state, rewrites resolv.conf to a better DNS target,
# and reruns connectivity checks. Results are written to SD card.
# ============================================================

_SDPATH_GUESS="${SDPATH:-${0%/*}}"
if [ -f "${_SDPATH_GUESS}/scripts/common/platform.sh" ]; then
    . "${_SDPATH_GUESS}/scripts/common/platform.sh"
elif [ -f "/mnt/efs-system/scripts/common/platform.sh" ]; then
    . "/mnt/efs-system/scripts/common/platform.sh"
fi

SDPATH="${1:-${_SDPATH_GUESS}}"
TS=$(date +%H%M%S 2>/dev/null || echo "000000")
if command -v getTime >/dev/null 2>&1; then
    TS="epoch-$(getTime 2>/dev/null)"
fi

OUTROOT="${SDPATH}/var"
OUTDIR="${OUTROOT}/dns-refresh"
REPORT="${OUTDIR}/dns-refresh-${TS}.txt"
BACKUP="${OUTDIR}/resolv-before-${TS}.conf"
OVERRIDE_FILE="${SDPATH}/dns-refresh-target.txt"
TARGET_DNS=""
TARGET_REASON=""

mkdir "${OUTROOT}" 2>/dev/null
mkdir "${OUTDIR}" 2>/dev/null

if [ -x "${SDPATH}/bin/showScreen" ] && [ -f "${SDPATH}/lib/running.png" ]; then
    "${SDPATH}/bin/showScreen" "${SDPATH}/lib/running.png" 2>/dev/null &
fi

run_ping() {
    _target="$1"
    echo "\$ ping -c 1 -w 3 ${_target}"
    ping -c 1 -w 3 "${_target}" 2>&1
}

{
echo "============================================"
echo " DNS Refresh Probe"
echo " $(date)"
echo " Train: $(cat /dev/shmem/sw_trainname.txt 2>/dev/null)"
echo " Target DNS: ${TARGET_DNS}"
echo "============================================"
echo ""

echo "--- Variant ---"
echo "MMI_VARIANT: ${MMI_VARIANT:-unknown}"
echo "MMI_VARIANT_ID: ${MMI_VARIANT_ID:-unknown}"
echo ""

echo "--- Interfaces Before ---"
ifconfig -a 2>/dev/null
echo ""

echo "--- Routing Table Before ---"
netstat -rn 2>/dev/null
echo ""

GW=$(netstat -rn 2>/dev/null | grep "^default" | awk '{print $2}')
echo "Detected default gateway: ${GW:-<none>}"
echo ""

echo "--- resolv.conf Before ---"
CURRENT_DNS=""
if [ -f /etc/resolv.conf ]; then
    cat /etc/resolv.conf
    cp /etc/resolv.conf "${BACKUP}" 2>/dev/null
    CURRENT_DNS=$(awk '/^nameserver[ \t]+/ {print $2; exit}' /etc/resolv.conf 2>/dev/null)
else
    echo "(missing)"
fi
echo ""

if [ -f "${OVERRIDE_FILE}" ]; then
    TARGET_DNS=$(sed -n '1s/[[:space:]]//gp' "${OVERRIDE_FILE}" 2>/dev/null)
    TARGET_REASON="sd-override"
fi

if [ -z "${TARGET_DNS}" ] && [ -n "${GW}" ]; then
    TARGET_DNS="${GW}"
    TARGET_REASON="default-gateway"
fi

if [ -z "${TARGET_DNS}" ] && [ -n "${CURRENT_DNS}" ]; then
    TARGET_DNS="${CURRENT_DNS}"
    TARGET_REASON="existing-resolv-conf"
fi

echo "Chosen DNS target: ${TARGET_DNS:-<none>} (${TARGET_REASON:-none})"
echo ""

echo "--- Connectivity Before ---"
if [ -n "$GW" ]; then
    run_ping "$GW"
else
    echo "No default gateway to ping"
fi
echo ""
run_ping 1.1.1.1
echo ""
run_ping kh.google.com
echo ""

echo "--- Rewriting resolv.conf ---"
if [ -n "${TARGET_DNS}" ]; then
    echo "# Written by DNS Refresh Probe $(date)" > /etc/resolv.conf
    echo "nameserver ${TARGET_DNS}" >> /etc/resolv.conf
    echo "[OK] Wrote /etc/resolv.conf with nameserver ${TARGET_DNS}"
else
    echo "[WARN] No DNS target available; resolv.conf left unchanged"
fi
echo ""

echo "--- resolv.conf After ---"
cat /etc/resolv.conf 2>/dev/null
echo ""

echo "--- Connectivity After ---"
if [ -n "$GW" ]; then
    run_ping "$GW"
else
    echo "No default gateway to ping"
fi
echo ""
run_ping 1.1.1.1
echo ""
run_ping kh.google.com
echo ""

echo "--- Summary ---"
echo "Backup: ${BACKUP}"
echo "Report: ${REPORT}"
echo "Gateway: ${GW:-<none>}"
echo "DNS chosen: ${TARGET_DNS:-<none>}"
echo "DNS reason: ${TARGET_REASON:-none}"
echo "============================================"
} > "${REPORT}" 2>&1

cat "${REPORT}"

if [ -x "${SDPATH}/bin/showScreen" ] && [ -f "${SDPATH}/lib/done.png" ]; then
    "${SDPATH}/bin/showScreen" "${SDPATH}/lib/done.png" 2>/dev/null &
fi
