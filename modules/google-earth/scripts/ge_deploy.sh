#!/bin/ksh
# ============================================================
# MMI3G-Toolkit — GEMMI Binary Deployer
# Deploys Google Earth binaries to cars that don't have them
#
# Sources (checked in order):
#   1. SD card /gemmi/ directory (user-provided)
#   2. Already installed on /mnt/efs-system/gemmi/
#   3. EU firmware lsd.jxe on EFS (extract if present)
#
# Target: /mnt/efs-system/gemmi/
#
# Required files:
#   gemmi_final            — 1.9MB — Native SH4 Google Earth process
#   libembeddedearth.so    — 20MB  — Rendering library  
#   libmessaging.so        — 807KB — IPC messaging
#   drivers.ini            — 1.1KB — Connection/render config
#   run_gemmi.sh           — 4.1KB — Startup script
#   scripts/               — Control scripts (start/stop/info)
#
# How to get the files:
#   Option A: Run gemmi-dump module on a car that HAS Google Earth
#             (any EU Audi MMI3G+ or pre-2020 NAR with working GE)
#             → copies to SD card var/gemmi_dump/
#             → move those files to SD card /gemmi/ directory
#
#   Option B: Extract from EU firmware lsd.jxe
#             (HN+R_EU_AU_K0942_4 contains full GEMMI package)
#
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
LOG="${OUTDIR}/ge-deploy-${TS}.log"
BACKUP="${SDPATH}/var/backup/google-earth"
mkdir -p "${OUTDIR}" 2>/dev/null
mkdir -p "${BACKUP}" 2>/dev/null

EFSDIR="/mnt/efs-system"
GEMMI_TARGET="/mnt/nav/gemmi"

exec > "${LOG}" 2>&1

echo "============================================"
echo " GEMMI Binary Deployer"
echo " $(date)"
echo " Train: $(cat /dev/shmem/sw_trainname.txt 2>/dev/null)"
echo "============================================"
echo ""

# ============================================================
# Step 1: Check if GEMMI is already installed
# ============================================================
echo "[STEP 1] Checking existing GEMMI installation..."

if [ -f "${GEMMI_TARGET}/gemmi_final" ]; then
    EXISTING_SIZE=$(ls -la "${GEMMI_TARGET}/gemmi_final" | awk '{print $5}')
    echo "  [OK] GEMMI already installed at ${GEMMI_TARGET}"
    echo "  gemmi_final: ${EXISTING_SIZE} bytes"
    echo "  No deployment needed — run ge_enable.sh instead"
    echo ""
    echo "  To force redeploy, remove ${GEMMI_TARGET} first"
    exit 0
fi

echo "  [INFO] GEMMI not installed — looking for source files..."
echo ""

# ============================================================
# Step 2: Find GEMMI source files
# ============================================================
echo "[STEP 2] Searching for GEMMI source files..."

SOURCE=""

# Check SD card /gemmi/ directory first
if [ -f "${SDPATH}/gemmi/gemmi_final" ] && \
   [ -f "${SDPATH}/gemmi/libembeddedearth.so" ]; then
    SOURCE="${SDPATH}/gemmi"
    echo "  [FOUND] SD card: ${SOURCE}"
fi

# Check gemmi-dump output on SD card
if [ -z "$SOURCE" ]; then
    for dump in ${SDPATH}/var/gemmi_dump; do
        if [ -f "${dump}/gemmi_final" ] && \
           [ -f "${dump}/libembeddedearth.so" ]; then
            SOURCE="${dump}"
            echo "  [FOUND] gemmi-dump output: ${SOURCE}"
        fi
    done
fi

# Check other common locations
if [ -z "$SOURCE" ]; then
    for dir in /mnt/nav/gemmi /HBpersistence/gemmi \
               /mnt/persistence/gemmi; do
        if [ -f "${dir}/gemmi_final" ]; then
            SOURCE="${dir}"
            echo "  [FOUND] System path: ${SOURCE}"
        fi
    done
fi

if [ -z "$SOURCE" ]; then
    echo "  [ERROR] No GEMMI source files found!"
    echo ""
    echo "  To deploy GEMMI, you need the binary files."
    echo "  Get them by:"
    echo "    1. Run gemmi-dump on a car that HAS Google Earth"
    echo "    2. Copy the output from var/gemmi_dump/ to SD card /gemmi/"
    echo "    3. Re-run this script"
    echo ""
    echo "  Required files in /gemmi/ on SD card:"
    echo "    gemmi_final"
    echo "    libembeddedearth.so"
    echo "    libmessaging.so (optional)"
    echo "    drivers.ini"
    echo "    run_gemmi.sh"
    exit 1
fi

echo ""
echo "  Source files:"
ls -lh "${SOURCE}"/gemmi_final "${SOURCE}"/libembeddedearth.so \
       "${SOURCE}"/drivers.ini 2>/dev/null
echo ""

# ============================================================
# Step 3: Remount EFS and create target directory
# ============================================================
echo "[STEP 3] Preparing target directory..."

mount -uw ${EFSDIR} 2>/dev/null
mkdir -p "${GEMMI_TARGET}" 2>/dev/null
mkdir -p "${GEMMI_TARGET}/scripts" 2>/dev/null
mkdir -p "${GEMMI_TARGET}/models" 2>/dev/null
mkdir -p "${GEMMI_TARGET}/res" 2>/dev/null

if [ ! -d "${GEMMI_TARGET}" ]; then
    echo "  [ERROR] Could not create ${GEMMI_TARGET}"
    exit 1
fi
echo "  [OK] Target directory ready: ${GEMMI_TARGET}"
echo ""

# ============================================================
# Step 4: Deploy GEMMI binaries
# ============================================================
echo "[STEP 4] Deploying GEMMI binaries..."

DEPLOYED=0

# Core binaries
for file in gemmi_final libembeddedearth.so libmessaging.so \
            libthirdparty_icu_3_5.so mapStylesWrite; do
    if [ -f "${SOURCE}/${file}" ]; then
        cp "${SOURCE}/${file}" "${GEMMI_TARGET}/${file}"
        chmod +x "${GEMMI_TARGET}/${file}"
        SIZE=$(ls -la "${GEMMI_TARGET}/${file}" | awk '{print $5}')
        echo "  [COPY] ${file} (${SIZE} bytes)"
        DEPLOYED=$((DEPLOYED + 1))
    fi
done

# Config files
for file in drivers.ini run_gemmi.sh pg.sh \
            debug_gemmi.sh debug_memcpu.sh; do
    if [ -f "${SOURCE}/${file}" ]; then
        cp "${SOURCE}/${file}" "${GEMMI_TARGET}/${file}"
        chmod +x "${GEMMI_TARGET}/${file}" 2>/dev/null
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
        echo "  [COPY] ${subdir}/ directory"
        DEPLOYED=$((DEPLOYED + 1))
    fi
done

echo ""
echo "  Deployed ${DEPLOYED} files to ${GEMMI_TARGET}"
echo ""

# ============================================================
# Step 5: Verify deployment
# ============================================================
echo "[STEP 5] Verifying deployment..."

VERIFIED=1
for required in gemmi_final libembeddedearth.so drivers.ini; do
    if [ -f "${GEMMI_TARGET}/${required}" ]; then
        echo "  [OK] ${required}"
    else
        echo "  [FAIL] ${required} MISSING"
        VERIFIED=0
    fi
done

echo ""

# ============================================================
# Summary
# ============================================================
echo "============================================"
echo " Deployment Summary"
echo "============================================"
echo ""
echo " Source:     ${SOURCE}"
echo " Target:     ${GEMMI_TARGET}"
echo " Files:      ${DEPLOYED} deployed"
echo " Verified:   $([ $VERIFIED -eq 1 ] && echo 'OK' || echo 'INCOMPLETE')"
echo ""

if [ $VERIFIED -eq 1 ]; then
    echo " ✅ GEMMI binaries deployed successfully"
    echo ""
    echo " NEXT STEPS:"
    echo "   1. Run ge_enable.sh to add disableAuthKey"
    echo "   2. Connect internet (USB ethernet + LTE router)"
    echo "   3. Reboot MMI"
    echo "   4. Check NAV → Map Settings for Google Earth option"
else
    echo " ⚠️ Deployment incomplete — check missing files"
fi
echo ""
echo " Log: ${LOG}"
echo "============================================"

# ============================================================
# Step 6: Set up GEMMI cache directory
# ============================================================
echo "[STEP 6] Setting up GEMMI cache..."

for cachedir in /mnt/img-cache/gemmi /mnt/img-cache/gemmi/.config \
                /mnt/img-cache/gemmi/cache /mnt/img-cache/gemmi/scache \
                /mnt/img-cache/gemmi/temp; do
    if [ ! -d "$cachedir" ]; then
        mkdir -p "$cachedir" 2>/dev/null
        echo "  [MKDIR] $cachedir"
    fi
done
echo "  [OK] Cache directories ready"
echo ""
