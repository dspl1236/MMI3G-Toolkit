#!/bin/ksh

_SDPATH_GUESS="${SDPATH:-$(dirname $0)}"
if [ -f "${_SDPATH_GUESS}/scripts/common/platform.sh" ]; then
    . "${_SDPATH_GUESS}/scripts/common/platform.sh"
elif [ -f "/mnt/efs-system/scripts/common/platform.sh" ]; then
    . "/mnt/efs-system/scripts/common/platform.sh"
fi

SDPATH="${1:-${_SDPATH_GUESS}}"
TS=$(date +%H%M%S 2>/dev/null || echo "000000")
if command -v mmi_logstamp >/dev/null 2>&1; then TS="$(mmi_logstamp)"; fi

OUTDIR="${SDPATH}/var/google-earth"
LOG="${OUTDIR}/ge-p0824-deploy-${TS}.log"
mkdir -p "${OUTDIR}" 2>/dev/null

NAVDIR="/mnt/nav"
GEMMI_TARGET="${NAVDIR}/gemmi"
SOURCE_DIR="${SDPATH}/gemmi"
BUNDLED_SOURCE_DIR="${SDPATH}/modules/google-earth-p0824-deploy/gemmi"
STATE_ROOT="${NAVDIR}/.mmi3g_toolkit/google-earth-p0824"
SESSION_DIR="${STATE_ROOT}/sessions/${TS}"
ACTIVE_META="${STATE_ROOT}/active.env"
DRIVERS_INI="${GEMMI_TARGET}/drivers.ini"

exec > "${LOG}" 2>&1

echo "============================================"
echo " Google Earth P0824 Donor Deploy"
echo " $(date)"
echo " Train: $(cat /dev/shmem/sw_trainname.txt 2>/dev/null)"
echo " Variant: ${MMI_VARIANT:-UNKNOWN} (${MMI_VARIANT_ID:-n/a})"
echo "============================================"
echo ""

if [ ! -d "${NAVDIR}" ]; then
    echo "[ERROR] ${NAVDIR} not found"
    exit 1
fi

if [ ! -d "${SOURCE_DIR}" ] && [ -d "${BUNDLED_SOURCE_DIR}" ]; then
    SOURCE_DIR="${BUNDLED_SOURCE_DIR}"
fi

if [ ! -d "${SOURCE_DIR}" ]; then
    echo "[ERROR] Donor payload missing at ${SOURCE_DIR}"
    echo "        This SD bundle must include the bundled /gemmi directory."
    exit 1
fi

for required in gemmi_final libembeddedearth.so run_gemmi.sh; do
    if [ ! -f "${SOURCE_DIR}/${required}" ]; then
        echo "[ERROR] Missing donor file: ${SOURCE_DIR}/${required}"
        exit 1
    fi
done
# drivers.ini may be renamed to drivers.cfg to work around Chrome FAT32 bug
if [ ! -f "${SOURCE_DIR}/drivers.ini" ] && [ ! -f "${SOURCE_DIR}/drivers.cfg" ]; then
    echo "[ERROR] Missing donor file: drivers.ini (or drivers.cfg)"
    exit 1
fi

mount -uw "${NAVDIR}" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "[ERROR] Failed to remount ${NAVDIR} read-write"
    exit 1
fi
echo "[OK] ${NAVDIR} remounted rw"

mkdir -p "${STATE_ROOT}/sessions" 2>/dev/null
mkdir -p "${SESSION_DIR}" 2>/dev/null

BACKUP_STATE="absent"
BACKUP_PATH=""

if [ -d "${GEMMI_TARGET}" ]; then
    BACKUP_STATE="present"
    BACKUP_PATH="${SESSION_DIR}/gemmi.before"
    echo "[BACKUP] Copying existing ${GEMMI_TARGET} -> ${BACKUP_PATH}"
    cp -R "${GEMMI_TARGET}" "${BACKUP_PATH}"
    if [ ! -d "${BACKUP_PATH}" ]; then
        echo "[ERROR] Backup failed; aborting"
        exit 1
    fi
else
    echo "[INFO] ${GEMMI_TARGET} not present; deploy will create it"
fi

echo "DEPLOY_TS=${TS}" > "${SESSION_DIR}/meta.env"
echo "BACKUP_STATE=${BACKUP_STATE}" >> "${SESSION_DIR}/meta.env"
echo "BACKUP_PATH=${BACKUP_PATH}" >> "${SESSION_DIR}/meta.env"
echo "TARGET=${GEMMI_TARGET}" >> "${SESSION_DIR}/meta.env"
echo "TRAIN=$(cat /dev/shmem/sw_trainname.txt 2>/dev/null)" >> "${SESSION_DIR}/meta.env"
echo "DONOR=HN+_EU_VW_P0824" >> "${SESSION_DIR}/meta.env"

if [ -d "${GEMMI_TARGET}" ]; then
    echo "[DEPLOY] Removing existing ${GEMMI_TARGET}"
    rm -rf "${GEMMI_TARGET}"
fi

mkdir -p "${GEMMI_TARGET}" 2>/dev/null
echo "[DEPLOY] Copying donor payload from ${SOURCE_DIR}"
cp -R "${SOURCE_DIR}/." "${GEMMI_TARGET}/"

# Rename drivers.cfg back to drivers.ini (Chrome FAT32 workaround)
if [ -f "${GEMMI_TARGET}/drivers.cfg" ] && [ ! -f "${GEMMI_TARGET}/drivers.ini" ]; then
    mv "${GEMMI_TARGET}/drivers.cfg" "${GEMMI_TARGET}/drivers.ini"
    echo "[OK] Renamed drivers.cfg -> drivers.ini"
fi

for exe in gemmi_final libembeddedearth.so libmessaging.so libthirdparty_icu_3_5.so \
           mapStylesWrite run_gemmi.sh pg.sh debug_gemmi.sh debug_memcpu.sh; do
    if [ -f "${GEMMI_TARGET}/${exe}" ]; then
        chmod +x "${GEMMI_TARGET}/${exe}" 2>/dev/null
    fi
done

if [ -d "${GEMMI_TARGET}/scripts" ]; then
    for script in "${GEMMI_TARGET}"/scripts/*.sh; do
        [ -f "${script}" ] || continue
        chmod +x "${script}" 2>/dev/null
    done
fi

if [ -f "${DRIVERS_INI}" ]; then
    if grep -q "disableAuthKey" "${DRIVERS_INI}" 2>/dev/null; then
        echo "[OK] drivers.ini already carries disableAuthKey"
    else
        TMP_DRV="/tmp/ge_p0824_drivers_${TS}.ini"
        sed '$d' "${DRIVERS_INI}" > "${TMP_DRV}"
        cat >> "${TMP_DRV}" <<'EOF'
    ; Google Earth auth bypass (MMI3G-Toolkit P0824 donor)
    maxLoginAttempts = 0
    disableAuthKey = true
    loginTimeout = 1

}
EOF
        cp "${TMP_DRV}" "${DRIVERS_INI}"
        rm -f "${TMP_DRV}"
        echo "[MOD] Added auth-bypass settings to ${DRIVERS_INI}"
    fi
else
    echo "[WARN] ${DRIVERS_INI} missing after deploy"
fi

for cachedir in /mnt/img-cache/gemmi /mnt/img-cache/gemmi/.config \
                /mnt/img-cache/gemmi/cache /mnt/img-cache/gemmi/scache \
                /mnt/img-cache/gemmi/temp; do
    if [ ! -d "${cachedir}" ]; then
        mkdir -p "${cachedir}" 2>/dev/null
        echo "[MKDIR] ${cachedir}"
    fi
done

echo "ACTIVE_TS=${TS}" > "${ACTIVE_META}"
echo "SESSION_DIR=${SESSION_DIR}" >> "${ACTIVE_META}"
echo "BACKUP_STATE=${BACKUP_STATE}" >> "${ACTIVE_META}"
echo "BACKUP_PATH=${BACKUP_PATH}" >> "${ACTIVE_META}"
echo "TARGET=${GEMMI_TARGET}" >> "${ACTIVE_META}"
echo "DONOR=HN+_EU_VW_P0824" >> "${ACTIVE_META}"

echo "${TS}" > "${GEMMI_TARGET}/.mmi3g_toolkit_p0824_deploy"
sync 2>/dev/null

echo ""
echo "============================================"
echo " Deploy Summary"
echo "============================================"
echo " Donor:       HN+_EU_VW_P0824"
echo " Source:      ${SOURCE_DIR}"
echo " Target:      ${GEMMI_TARGET}"
echo " Backup:      ${BACKUP_STATE} ${BACKUP_PATH}"
echo " Active meta: ${ACTIVE_META}"
echo ""
echo " Reboot required before retesting."
echo " This does NOT patch lsd.jxe or remove VW RANGE_ locks."
echo "============================================"
