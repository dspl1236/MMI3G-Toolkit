#!/bin/ksh
# ============================================================
# MMI3G Variant / Identification / Configuration Dumper
# ============================================================
#
# READ-ONLY. Writes a structured report to SD card only.
# Uses the shared platform.sh helper for variant detection and
# getTime-preferred timestamps.
#
# Captures what a shell script can see on the MMI:
#   * Identification (variant, train, versions, hwSample)
#   * Kernel info (uname, pidin)
#   * Storage (fdisk, mount, df)
#   * Navigation database + FSC + unblocker state
#   * Gracenote info
#   * Persistence file inventory
#
# Per-3 / DSI adaptation values are NOT in this report —
# they are only readable from inside the Java VM. Use the
# long-coding module's GEM screens for those, or VCDS/ODIS.
# ============================================================

SDPATH="${1:-$(dirname $0)}"

# Source the shared platform helper
if [ -f "${SDPATH}/scripts/common/platform.sh" ]; then
    . "${SDPATH}/scripts/common/platform.sh"
elif [ -f "/mnt/efs-system/scripts/common/platform.sh" ]; then
    . "/mnt/efs-system/scripts/common/platform.sh"
else
    # Inline fallback — minimal platform detection if helper missing
    MMI_VARIANT="UNKNOWN"
    MMI_VARIANT_ID=""
    for f in /etc/pci-3g_*.cfg; do
        [ -f "$f" ] || continue
        MMI_VARIANT_ID="$(echo "$f" | sed -n 's,^/etc/pci-3g_\([0-9]*\)\.cfg$,\1,p')"
        case "$MMI_VARIANT_ID" in
            9304) MMI_VARIANT="MMI3G_BASIC" ;;
            9308) MMI_VARIANT="MMI3G_HIGH" ;;
            9411|9478) MMI_VARIANT="MMI3GP" ;;
        esac
        break
    done
    MMI_TRAIN="$(cat /dev/shmem/sw_trainname.txt 2>/dev/null)"
    [ -z "$MMI_TRAIN" ] && MMI_TRAIN="$(sloginfo -m 10000 -s 5 2>/dev/null | sed -n 's/^.* +++ Train //p' | sed -n 1p)"
    [ -z "$MMI_TRAIN" ] && MMI_TRAIN="n/a"
    if [ "$MMI_VARIANT" = "MMI3GP" ] && echo "$MMI_TRAIN" | grep -q "_VW_"; then
        MMI_VARIANT="RNS850"
    fi
    MMI_SW_VERSION="$(sed -n 's/^version = //p' /etc/version/MainUnit-version.txt 2>/dev/null | head -1)"
    [ -z "$MMI_SW_VERSION" ] && MMI_SW_VERSION="n/a"
    MMI_HW_SAMPLE="$([ -f /etc/hwSample ] && cat /etc/hwSample 2>/dev/null)"
    [ -z "$MMI_HW_SAMPLE" ] && MMI_HW_SAMPLE="n/a"
    mmi_logstamp() {
        if command -v getTime >/dev/null 2>&1; then
            T="$(getTime 2>/dev/null)"
            [ -n "$T" ] && { date -r "$T" +%Y%m%d-%H%M%S 2>/dev/null || echo "epoch-$T"; return 0; }
        fi
        date +%Y%m%d-%H%M%S 2>/dev/null
    }
fi

TIMESTAMP="$(mmi_logstamp)"
OUTDIR="${SDPATH}/var/variant"
OUTFILE="${OUTDIR}/variant-${TIMESTAMP}.txt"
mkdir -p ${OUTDIR}

{
echo "################################################################"
echo "#  MMI3G-Toolkit Variant / Identification Dump"
echo "#  Generated: $(date) [QNX date — may be since-boot if cold]"
echo "#  Epoch from getTime: $(mmi_getTime 2>/dev/null || echo n/a)"
echo "################################################################"
echo ""

# ---------- Identification (from platform helper) ----------
echo "================================================================"
echo "  MAIN UNIT IDENTIFICATION"
echo "================================================================"
printf "  %-32s %s (id=%s)\n" "Variant:"           "${MMI_VARIANT}" "${MMI_VARIANT_ID:-n/a}"
printf "  %-32s %s\n"         "Train name:"        "${MMI_TRAIN}"
printf "  %-32s %s\n"         "MU software version:" "${MMI_SW_VERSION}"
printf "  %-32s %s\n"         "MU hwSample:"       "${MMI_HW_SAMPLE}"

# Variant-specific extras
if [ "$MMI_VARIANT" = "MMI3GP" ] || [ "$MMI_VARIANT" = "RNS850" ]; then
    HMI_TYPE="$([ -f /etc/hmi_type.txt ] && cat /etc/hmi_type.txt 2>/dev/null | sed 's/"//g')"
    HMI_REGION="$([ -f /etc/hmi_country.txt ] && cat /etc/hmi_country.txt 2>/dev/null | sed 's/"//g')"
    printf "  %-32s %s\n" "HMI type:"   "${HMI_TYPE:-n/a}"
    printf "  %-32s %s\n" "HMI region:" "${HMI_REGION:-n/a}"

    MU_XML_VARIANT="$(sed -n 's,^<VariantName>,,;s,</VariantName>\r\?$,,p' /etc/mmi3g-srv-starter.cfg 2>/dev/null | head -1)"
    printf "  %-32s %s\n" "mmi3g-srv-starter variant:" "${MU_XML_VARIANT:-n/a}"
fi
echo ""

# ---------- QNX Kernel / OS ----------
echo "================================================================"
echo "  QNX KERNEL / OS"
echo "================================================================"
echo "  uname -a:"
uname -a 2>/dev/null | sed 's/^/    /'
echo ""
echo "  pidin info:"
pidin info 2>/dev/null | sed 's/^/    /' | head -20
echo ""

# ---------- Storage / Partitions ----------
echo "================================================================"
echo "  STORAGE / PARTITIONS"
echo "================================================================"

HDDINFO="$(sloginfo -m 19 -s 2 2>/dev/null | grep 'eide_display_devices.*tid 1' | sed 's/^.*mdl //;s/ tid 1.*$//' | head -1)"
printf "  %-32s %s\n" "Installed HDD:" "${HDDINFO:-n/a}"

if [ -e /dev/hd0 ]; then
    HDDC="$(fdisk /dev/hd0 query -T 2>/dev/null)"
    HDDH="$(fdisk /dev/hd0 info 2>/dev/null | sed -n 's,^    Heads            : ,,p')"
    HDDS="$(fdisk /dev/hd0 info 2>/dev/null | sed -n 's,^    Sectors/Track    : ,,p')"
    if [ -n "$HDDC" ] && [ -n "$HDDH" ] && [ -n "$HDDS" ]; then
        printf "  %-32s %s x %s x %s (%s sectors)\n" "HDD geometry C/H/S:" "$HDDC" "$HDDH" "$HDDS" "$((HDDC * HDDH * HDDS))"
    fi
    echo ""
    echo "  HDD partition table:"
    fdisk /dev/hd0 show 2>/dev/null | sed 's/^/    /'
fi
echo ""

echo "  Mounted filesystems:"
mount 2>/dev/null | sed 's/^/    /'
echo ""

echo "  Free space (df -k -P):"
df -k -P 2>/dev/null | sed 's/^/    /'
echo ""

# ---------- Navigation ----------
echo "================================================================"
echo "  NAVIGATION DATABASE"
echo "================================================================"
DBINFO=/mnt/nav/db/DBInfo.txt
if [ -f "$DBINFO" ]; then
    DBPKG="$(ls /mnt/nav/db/pkgdb/*.pkg 2>/dev/null | sed -n 1p)"
    if [ -n "$DBPKG" ]; then
        DBDESC="$(sed -n 's/^description="//p' "$DBPKG" 2>/dev/null | sed 's/".*$//' | head -1)"
        DBREL="$(sed -n 's/^SystemName=[^ ]* //p' "$DBINFO" 2>/dev/null | sed 's/".*$//' | head -1)"
        printf "  %-32s %s %s\n" "HDD navdb:" "${DBDESC}" "${DBREL}"
        FSCSPEC="$(sed -n 's/^userflags=fsc@//p' "$DBPKG" 2>/dev/null | sed 's/;region.*$//' | head -1)"
        printf "  %-32s 000%s.fsc\n" "Required FSC file:" "${FSCSPEC}"
        if [ -f "/mnt/efs-persist/FSC/000${FSCSPEC}.fsc" ] || [ -f "/HBpersistence/FSC/000${FSCSPEC}.fsc" ]; then
            echo "  FSC status:                       PRESENT"
        else
            echo "  FSC status:                       NOT FOUND"
        fi
    fi

    # Activation / unblocker state
    if pidin -f an 2>/dev/null | grep -q vdev-logvolmgr; then
        echo "  H-B navdb activation:             enabled (vdev-logvolmgr running)"
    else
        echo "  H-B navdb activation:             disabled (vdev-logvolmgr not running)"
    fi
    if grep -q 'acios_db.ini' /usr/bin/manage_cd.sh 2>/dev/null; then
        echo "  LVM unblocker patch:              present in /usr/bin/manage_cd.sh"
    elif [ -f /etc/mmelauncher.cfg ] && grep -q 'mme-becker.sh' /etc/mmelauncher.cfg 2>/dev/null; then
        echo "  LVM unblocker patch:              legacy Keldo/Vlasoff via mmelauncher.cfg"
    else
        echo "  LVM unblocker patch:              not present"
    fi
else
    echo "  No navigation database on HDD"
fi
echo ""

# ---------- Gracenote (CD database) ----------
GNDBF=/mnt/gracenode/db/gracenote.txt
if [ -f "$GNDBF" ]; then
    echo "================================================================"
    echo "  GRACENOTE CD DATABASE"
    echo "================================================================"
    GNPN="$(sed -n 's/^PartNumber=//p' "$GNDBF" 2>/dev/null | sed 's/\r$//' | head -1)"
    GNSVN="$(sed -n 's/^SoftwareVersionNumber=//p' "$GNDBF" 2>/dev/null | sed 's/\r$//' | head -1)"
    printf "  %-32s %s\n" "Part number:" "${GNPN:-n/a}"
    printf "  %-32s %s\n" "Software version:" "${GNSVN:-n/a}"
    echo ""
fi

# ---------- Persistence file inventory ----------
echo "================================================================"
echo "  PERSISTENCE FILE INVENTORY"
echo "================================================================"
for p in /mnt/efs-persist /HBpersistence /mnt/persistence; do
    if [ -d "$p" ]; then
        echo "--- $p ---"
        ls -laR "$p" 2>/dev/null | sed 's/^/  /' | head -80
        echo ""
    fi
done

# ---------- Where to go for adaptation values ----------
echo "================================================================"
echo "  ADAPTATION / PER-3 VALUES — HOW TO READ"
echo "================================================================"
echo ""
echo "  Car-device list (0x00100000-0x0010003F), CAN-assignment"
echo "  (0x00140000-0x001400FF), and other per-3 namespace values"
echo "  cannot be read from a shell script. They live behind the"
echo "  DSI persistence API (org.dsi.ifc.persistence.DSIPersistence)"
echo "  which is Java-only IPC inside the J9 VM."
echo ""
echo "  To read them, use:"
echo "    * VCDS:       5F -> Adaptation -> channel N"
echo "    * ODIS E17:   long-coding data set on address 5F"
echo "    * This toolkit's long-coding GEM screens (which call"
echo "      DSIPersistence.readInt() from inside the HMI VM)"
echo ""

echo "################################################################"
echo "#  Dump complete. Output: ${OUTFILE}"
echo "################################################################"

} > ${OUTFILE} 2>&1

echo "Variant dump complete."
echo "Variant: ${MMI_VARIANT} (id=${MMI_VARIANT_ID:-n/a})"
echo "Output:  ${OUTFILE}"
sync
