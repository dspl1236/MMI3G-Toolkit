#!/bin/ksh
# ============================================================
# per3_read.sh — shell client for the per3-reader bundle
# ============================================================
# Usage:
#   per3_read.sh <type> <address-hex> [namespace]
#
#   <type>         int | string | buffer | array
#   <address-hex>  e.g. 0x00100015 or 00100015
#   [namespace]    default 0
#
# Examples:
#   per3_read.sh int 0x00100015           -> e.g. "1"
#   per3_read.sh string 0x00120004        -> e.g. "HN+R_EU_AU_K0942_4"
#   per3_read.sh int 0x00000023           -> battery voltage x 100 mV
#
# The read goes through the per3-reader bundle running inside the MMI's
# J9 VM. This script just writes a request file into the bundle's trigger
# directory and polls for the response.
#
# Output on stdout:
#   the raw value (for int / string)
#   hex-encoded bytes (for buffer)
#   comma-separated ints (for array)
# Exit code: 0 success, 1 error.
# ============================================================

TRIGDIR_SD="/fs/sda1/per3req"
TRIGDIR_FALLBACK="/tmp/per3req"
TIMEOUT_MS=3000

if [ $# -lt 2 ]; then
    echo "Usage: $0 <int|string|buffer|array> <address-hex> [namespace]" >&2
    exit 1
fi

TYPE="$1"
ADDR_IN="$2"
NS="${3:-0}"

# Strip 0x prefix, lowercase, ensure hex
ADDR="$(echo "$ADDR_IN" | sed 's/^0[xX]//' | tr 'A-F' 'a-f')"

# Pick trigger dir: SD card first, then /tmp
if [ -d "$TRIGDIR_SD" ]; then
    TRIGDIR="$TRIGDIR_SD"
elif [ -d "$TRIGDIR_FALLBACK" ]; then
    TRIGDIR="$TRIGDIR_FALLBACK"
else
    echo "err no-trigger-directory (insert SD or create $TRIGDIR_SD)" >&2
    exit 1
fi

REQ="${TRIGDIR}/${NS}.${ADDR}.${TYPE}.req"
RESP="${TRIGDIR}/${NS}.${ADDR}.${TYPE}.resp"

# Clean any stale response from a previous read
rm -f "$RESP" 2>/dev/null

# Write the request (content ignored; filename is the whole request)
echo "" > "$REQ"

# Poll for response
WAITED=0
while [ $WAITED -lt $TIMEOUT_MS ]; do
    if [ -f "$RESP" ]; then
        cat "$RESP"
        rm -f "$RESP" 2>/dev/null
        # If first word is "err", return non-zero
        FIRST="$(head -c 3 "$RESP" 2>/dev/null)"
        case "$(cat "$RESP" 2>/dev/null | head -1)" in
            ok*)  exit 0 ;;
            err*) exit 1 ;;
            *)    exit 1 ;;
        esac
    fi
    # No usleep on QNX 6.3 base tools — use sleep 0.1 if supported, else 1s
    sleep 0 2>/dev/null || sleep 1
    WAITED=$((WAITED + 100))
done

# Timeout — clean up the orphaned request
rm -f "$REQ" 2>/dev/null
echo "err client-timeout (per3-reader bundle not responding — check sloginfo | grep per3-reader)" >&2
exit 1
