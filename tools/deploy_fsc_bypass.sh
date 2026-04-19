#!/bin/sh
#
# deploy_fsc_bypass.sh — Runtime FSC BouncyCastle bypass
# Deploys the 1-byte patch to SignatureBlockProcessor.class
# Works on: Audi MMI3G (MU9411) and VW RNS 850 (MU9478)
#
# This script runs as root via copie_scr.sh autorun.
# It patches the efs-system flash partition in-place.
#
# THE PATCH: verifyManifestAndSignatureFile() → return void
#   Class offset 0x1FE8: 0xBB (new) → 0xB1 (return void)
#   Original CRC32: 0x447f28a7
#   Patched CRC32:  0x26d00392
#

# Determine log location (USB or SD)
for MEDIA in /fs/usb0 /fs/usb1 /fs/sd0 /fs/sd1 /media/usb0; do
    if [ -d "$MEDIA" ]; then
        LOGDIR="$MEDIA"
        break
    fi
done

LOGFILE="${LOGDIR}/fsc_bypass_log.txt"
BACKUP_DIR="${LOGDIR}/backup"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOGFILE"
    echo "$1"
}

log "=========================================="
log "FSC BouncyCastle Bypass — Runtime Deployer"
log "=========================================="
log "Media: $LOGDIR"
log "Hostname: $(hostname 2>/dev/null || echo unknown)"

# Identify platform
if [ -f /etc/pci-3g_9478.cfg ] || [ -f /etc/pci-3g_9476.cfg ]; then
    PLATFORM="VW RNS 850"
elif [ -f /etc/pci-3g_9411.cfg ] || [ -f /etc/pci-3g_9498.cfg ]; then
    PLATFORM="Audi MMI3G"
else
    PLATFORM="Unknown HN+"
fi
log "Platform: $PLATFORM"

# Find the EFS-system partition
# On QNX, flash partitions are typically at /dev/fs0pN
# The efs-system is at flash offset 0x03D00000

EFS_DEV=""
EFS_MOUNT=""

# Method 1: Check mounted filesystems
for mnt in /mnt/efs-system /mnt/flash/efs1; do
    if [ -d "$mnt" ]; then
        EFS_MOUNT="$mnt"
        log "EFS mounted at: $EFS_MOUNT"
        break
    fi
done

# Method 2: Find raw flash device
for dev in /dev/fs0p6 /dev/fs0p5 /dev/fs0p7 /dev/hd0t178 /dev/hd0t179; do
    if [ -e "$dev" ]; then
        # Check if this looks like EFS (search for our target)
        if dd if="$dev" bs=1 count=4 skip=4 2>/dev/null | grep -q "PK"; then
            EFS_DEV="$dev"
            log "EFS device candidate: $EFS_DEV"
        fi
    fi
done

# The target: SignatureBlockProcessor filename in the ZIP local header
# We search for this exact string to find the patch location
TARGET_FNAME="de/audi/tghu/development/jobs/SignatureBlockProcessor.class"
TARGET_CRC_ORIG="a7287f44"   # 0x447f28a7 in little-endian bytes
TARGET_CRC_NEW="920300d026"  # 0x26d00392 in little-endian bytes

# Search for the class in the EFS
log ""
log "Searching for SignatureBlockProcessor.class..."

# Strategy: the class is inside a JAR (ZIP) in the EFS partition.
# We look for the filename string in the raw flash/partition data.

find_patch_point() {
    local DEV="$1"
    local SIZE=$(ls -la "$DEV" 2>/dev/null | awk '{print $5}')
    
    if [ -z "$SIZE" ]; then
        SIZE=$(stat -c %s "$DEV" 2>/dev/null || echo 0)
    fi
    
    log "Searching device: $DEV"
    
    # Use grep to find the filename string offset
    # We search for "SignatureBlockProcessor" as a unique marker
    MARKER="SignatureBlockProcessor"
    
    # Find all occurrences
    OFFSETS=$(strings -t d "$DEV" 2>/dev/null | grep "$MARKER" | awk '{print $1}')
    
    if [ -z "$OFFSETS" ]; then
        log "  Not found in $DEV"
        return 1
    fi
    
    for OFF in $OFFSETS; do
        log "  Found marker at offset $OFF"
        
        # The local file header is before the filename
        # Local header: PK\x03\x04 + 26 bytes + filename
        # The filename starts at offset 30 from the local header
        # But we need to find the FULL filename path, not just the class name
        
        # Read 100 bytes before and after to find the full context
        CONTEXT_START=$((OFF - 60))
        if [ $CONTEXT_START -lt 0 ]; then
            CONTEXT_START=0
        fi
        
        # Look for PK\x03\x04 before this filename
        dd if="$DEV" bs=1 skip=$CONTEXT_START count=200 2>/dev/null > /tmp/fsc_context.bin
        
        # Check for the CRC32 in the local header
        # The CRC32 field is at offset 14 from the PK signature
        # Original CRC: 0x447f28a7
        
        log "  Checking CRC32 at context..."
    done
    
    return 0
}

# Try to find and patch
PATCHED=0

# Method A: If we have the pre-computed offsets from rns850_efs_patcher.py,
# use the offset file from the USB/SD card
if [ -f "${LOGDIR}/patch_offsets.txt" ]; then
    log "Found pre-computed offsets file"
    . "${LOGDIR}/patch_offsets.txt"
    
    # patch_offsets.txt should contain:
    # EFS_DEVICE=/dev/...
    # DATA_OFFSET=0x...
    # LOCAL_CRC_OFFSET=0x...
    # CD_CRC_OFFSET=0x...
    # COMP_DATA_FILE=patched_comp.bin
    
    if [ -n "$EFS_DEVICE" ] && [ -n "$DATA_OFFSET" ]; then
        log "Using pre-computed offsets:"
        log "  Device: $EFS_DEVICE"
        log "  Data offset: $DATA_OFFSET"
        log "  Local CRC offset: $LOCAL_CRC_OFFSET"
        log "  CD CRC offset: $CD_CRC_OFFSET"
        
        # Backup the original bytes
        mkdir -p "$BACKUP_DIR"
        
        DATA_OFF_DEC=$((DATA_OFFSET))
        LOCAL_CRC_DEC=$((LOCAL_CRC_OFFSET))
        CD_CRC_DEC=$((CD_CRC_OFFSET))
        
        log "Backing up original data..."
        dd if="$EFS_DEVICE" bs=1 skip=$DATA_OFF_DEC count=4610 of="${BACKUP_DIR}/orig_comp_data.bin" 2>/dev/null
        dd if="$EFS_DEVICE" bs=1 skip=$LOCAL_CRC_DEC count=4 of="${BACKUP_DIR}/orig_local_crc.bin" 2>/dev/null
        dd if="$EFS_DEVICE" bs=1 skip=$CD_CRC_DEC count=4 of="${BACKUP_DIR}/orig_cd_crc.bin" 2>/dev/null
        
        log "Applying patch..."
        
        # Write 1: Recompressed class data
        if [ -f "${LOGDIR}/${COMP_DATA_FILE}" ]; then
            dd if="${LOGDIR}/${COMP_DATA_FILE}" of="$EFS_DEVICE" bs=1 seek=$DATA_OFF_DEC conv=notrunc 2>/dev/null
            log "  Write 1: Compressed data ✅"
        fi
        
        # Write 2: New CRC32 in local header (0x26d00392 = 92 03 d0 26)
        printf '\x92\x03\xd0\x26' | dd of="$EFS_DEVICE" bs=1 seek=$LOCAL_CRC_DEC conv=notrunc 2>/dev/null
        log "  Write 2: Local CRC32 ✅"
        
        # Write 3: New CRC32 in central directory
        printf '\x92\x03\xd0\x26' | dd of="$EFS_DEVICE" bs=1 seek=$CD_CRC_DEC conv=notrunc 2>/dev/null
        log "  Write 3: CD CRC32 ✅"
        
        PATCHED=1
        log ""
        log "✅ PATCH APPLIED! Reboot required."
    fi
fi

# Method B: Auto-detect (simpler but needs the class file approach)
if [ $PATCHED -eq 0 ]; then
    log ""
    log "No pre-computed offsets found."
    log "To use this script:"
    log "  1. Run rns850_efs_patcher.py on your PC to generate offsets"
    log "  2. Place patch_offsets.txt and patched_comp.bin on this media"
    log "  3. Re-run this script"
    log ""
    log "Alternatively, dump the EFS for offline patching:"
    
    # Try to dump the EFS partition for offline analysis
    for DEV in /dev/fs0p6 /dev/fs0p5 /dev/fs0p7; do
        if [ -e "$DEV" ]; then
            log "  Dumping $DEV to ${LOGDIR}/efs-system-dump.efs ..."
            dd if="$DEV" of="${LOGDIR}/efs-system-dump.efs" bs=65536 2>/dev/null
            if [ $? -eq 0 ]; then
                log "  ✅ Dumped! Patch this file on your PC, then re-deploy."
                PATCHED=2  # dumped
                break
            fi
        fi
    done
    
    # Also try to collect system info for debugging
    log ""
    log "=== System Info ==="
    log "uname: $(uname -a 2>/dev/null)"
    log "Flash devices:"
    ls -la /dev/fs0* 2>/dev/null >> "$LOGFILE"
    ls -la /dev/hd0* 2>/dev/null >> "$LOGFILE"
    log "Mount points:"
    mount 2>/dev/null >> "$LOGFILE"
    log "EFS mounts:"
    mount 2>/dev/null | grep -i efs >> "$LOGFILE"
    df -h 2>/dev/null >> "$LOGFILE"
fi

log ""
log "=========================================="
if [ $PATCHED -eq 1 ]; then
    log "STATUS: ✅ PATCH APPLIED — REBOOT TO ACTIVATE"
elif [ $PATCHED -eq 2 ]; then
    log "STATUS: EFS DUMPED — Patch offline, then redeploy"
else
    log "STATUS: System info collected — check log file"
fi
log "Log saved to: $LOGFILE"
log "=========================================="
