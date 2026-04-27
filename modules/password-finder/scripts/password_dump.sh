#!/bin/ksh
# ============================================================
# MMI3G Password Finder
# Scans persistence partitions for stored credentials
# ============================================================
#
# READ-ONLY operation. Writes results to SD card only.
# Does NOT modify the MMI in any way.
#
# Inspired by jilleb/mib2-toolbox 'Password' screen, adapted
# for MMI3G/3G+/RNS-850 persistence layout.
#
# Output: var/passwords-YYYYMMDD-HHMMSS.txt on SD card
# ============================================================

# --- platform.sh (shared variant detection + getTime helper) ---
# Defines MMI_VARIANT / MMI_VARIANT_ID / MMI_TRAIN and mmi_logstamp().
# Must be sourced before any code that calls mmi_logstamp.
_SDPATH_GUESS="${SDPATH:-${0%/*}}"
if [ -f "${_SDPATH_GUESS}/scripts/common/platform.sh" ]; then
    . "${_SDPATH_GUESS}/scripts/common/platform.sh"
elif [ -f "/mnt/efs-system/scripts/common/platform.sh" ]; then
    . "/mnt/efs-system/scripts/common/platform.sh"
else
    # Inline minimal fallback (DrGER2 review corrections applied)
    MMI_VARIANT="UNKNOWN"; MMI_VARIANT_ID=""
    for _f in /etc/pci-3g_*.cfg; do
        [ -f "$_f" ] || continue
        MMI_VARIANT_ID="$(echo "$_f" | sed -n 's,^/etc/pci-3g_\([0-9]*\)\.cfg$,\1,p')"
        case "$MMI_VARIANT_ID" in
            9304) MMI_VARIANT="MMI3G_BASIC" ;;
            9308) MMI_VARIANT="MMI3G_HIGH" ;;
            9411|9436|9478) MMI_VARIANT="MMI3GP" ;;
        esac
        break
    done
    MMI_TRAIN="$(cat /dev/shmem/sw_trainname.txt 2>/dev/null)"
    [ -z "$MMI_TRAIN" ] && MMI_TRAIN="$(sloginfo -m 10000 -s 5 2>/dev/null | sed -n 's/^.* +++ Train //p' | sed -n 1p)"
    [ -z "$MMI_TRAIN" ] && MMI_TRAIN="n/a"
    if [ "$MMI_VARIANT" = "MMI3GP" ] && echo "$MMI_TRAIN" | grep -q "_VW_"; then
        MMI_VARIANT="RNS850"
    fi
    mmi_logstamp() {
        if command -v getTime >/dev/null 2>&1; then
            _T="$(getTime 2>/dev/null)"
            [ -n "$_T" ] && { date -r "$_T" +%Y%m%d-%H%M%S 2>/dev/null || echo "epoch-$_T"; return 0; }
        fi
        date +%Y%m%d-%H%M%S 2>/dev/null
    }
    mmi_getTime() {
        if command -v getTime >/dev/null 2>&1; then getTime 2>/dev/null; else date +%s 2>/dev/null; fi
    }
fi
# --- end platform.sh source ---

SDPATH="${1:-${0%/*}}"
TIMESTAMP=$(mmi_logstamp)
OUTDIR="${SDPATH}/var/passwords"
OUTFILE="${OUTDIR}/passwords-${TIMESTAMP}.txt"

mkdir -p ${OUTDIR}

{
echo "################################################################"
echo "#  MMI3G-Toolkit Password Finder Report"
echo "#  Generated: $(date)"
echo "#  Train: $(cat /dev/shmem/sw_trainname.txt 2>/dev/null)"
echo "################################################################"
echo ""
echo "NOTE: This is a READ-ONLY scan. Nothing on the MMI was changed."
echo "      All data below is extracted from existing persistent storage."
echo ""
echo ""

# === Wi-Fi Hotspot / wpa_supplicant credentials ===
echo "================================================================"
echo "  Wi-Fi / Hotspot Configuration"
echo "================================================================"
echo ""

for searchdir in /mnt/efs-persist /mnt/persist /mnt/efs-system/etc /etc; do
    if [ -d "$searchdir" ]; then
        # wpa_supplicant style configs
        for f in $(find $searchdir -type f \( \
            -name "wpa_supplicant*.conf" \
            -o -name "hostapd*.conf" \
            -o -name "*.wpa" \
            -o -name "wifi*.conf" \
            -o -name "wlan*.conf" \
            -o -name "AP_config*" \
            -o -name "hotspot*.cfg" \
        \) 2>/dev/null); do
            echo "--- $f ---"
            cat "$f" 2>/dev/null
            echo ""
        done
    fi
done

# Grep for SSID/PSK patterns in any text config file
echo "--- SSID/PSK pattern search ---"
for searchdir in /mnt/efs-persist /mnt/persist /mnt/efs-system/etc; do
    if [ -d "$searchdir" ]; then
        grep -rl -E "ssid|psk|passphrase|password" $searchdir 2>/dev/null | while read f; do
            # Only text files, skip binaries
            if file "$f" 2>/dev/null | grep -q "text\|ASCII"; then
                echo "  Candidate: $f"
                grep -Ein "ssid=|psk=|passphrase=|password=" "$f" 2>/dev/null | head -10
                echo ""
            fi
        done
    fi
done
echo ""

# === Bluetooth pairing keys ===
echo "================================================================"
echo "  Bluetooth Pairing Data"
echo "================================================================"
echo ""
for searchdir in /mnt/efs-persist /mnt/persist; do
    if [ -d "$searchdir" ]; then
        # Bluetooth config / link keys / paired device lists
        for f in $(find $searchdir -type f \( \
            -name "linkkeys*" \
            -o -name "bt_*.cfg" \
            -o -name "bluetooth*.conf" \
            -o -name "paired_devices*" \
            -o -path "*/bluetooth/*" \
            -o -path "*/bt/*" \
        \) 2>/dev/null); do
            echo "--- $f ---"
            if file "$f" 2>/dev/null | grep -q "text\|ASCII"; then
                cat "$f" 2>/dev/null
            else
                echo "(binary file, $(wc -c < "$f") bytes) — dumping hex:"
                xxd "$f" 2>/dev/null | head -20
            fi
            echo ""
        done
    fi
done
echo ""

# === Audi Connect / mOD / myAudi credentials ===
echo "================================================================"
echo "  Audi Connect / Telematics Credentials"
echo "================================================================"
echo ""
for searchdir in /mnt/efs-persist /mnt/persist /mnt/efs-system/etc; do
    if [ -d "$searchdir" ]; then
        for f in $(find $searchdir -type f \( \
            -name "myaudi*" \
            -o -name "audiconnect*" \
            -o -name "*.auth" \
            -o -name "credentials*" \
            -o -name "*.cert" \
            -o -name "*.pem" \
            -o -name "*.key" \
            -o -name "mod_config*" \
            -o -name "telematics*.conf" \
        \) 2>/dev/null); do
            echo "--- $f ---"
            SIZE=$(wc -c < "$f" 2>/dev/null)
            if [ -n "$SIZE" ] && [ "$SIZE" -lt 5000 ]; then
                if file "$f" 2>/dev/null | grep -q "text\|ASCII\|certificate\|PEM"; then
                    cat "$f" 2>/dev/null
                else
                    echo "(binary, $SIZE bytes)"
                fi
            else
                echo "(file too large or missing; size=$SIZE bytes)"
            fi
            echo ""
        done
    fi
done
echo ""

# === Persistent config tree listing ===
echo "================================================================"
echo "  Persistence Tree Overview (for further investigation)"
echo "================================================================"
echo ""
for searchdir in /mnt/efs-persist /mnt/persist; do
    if [ -d "$searchdir" ]; then
        echo "--- Tree of $searchdir ---"
        find "$searchdir" -type f 2>/dev/null | head -100
        echo "..."
        echo ""
    fi
done

# === Known credential-like strings in persistent storage (broad sweep) ===
echo "================================================================"
echo "  Broad String Sweep (password/secret/token/apikey)"
echo "================================================================"
echo ""
for searchdir in /mnt/efs-persist /mnt/persist; do
    if [ -d "$searchdir" ]; then
        echo "--- Matches in $searchdir ---"
        grep -ril -E "password|secret|token|apikey|api_key|bearer" "$searchdir" 2>/dev/null | head -20 | while read f; do
            SIZE=$(wc -c < "$f" 2>/dev/null)
            if [ -n "$SIZE" ] && [ "$SIZE" -lt 10000 ]; then
                if file "$f" 2>/dev/null | grep -q "text\|ASCII"; then
                    echo "  [$f]:"
                    grep -Ein "password|secret|token|apikey|api_key|bearer" "$f" 2>/dev/null | head -5
                    echo ""
                fi
            fi
        done
    fi
done

echo ""
echo "################################################################"
echo "#  Report complete: ${OUTFILE}"
echo "#"
echo "#  NOTE: This is a best-effort dump. Some MMI variants store"
echo "#  credentials encrypted in binary config files (not readable"
echo "#  as plaintext). The tree overview section shows all persistent"
echo "#  files so you can investigate further with 'xxd' or 'strings'."
echo "################################################################"

} > ${OUTFILE} 2>&1

echo "Password finder complete. Output: ${OUTFILE}"
sync
