#!/bin/ksh
# Read identification info from a specific module
# Usage: ksh read_module_info.sh <module_addr_hex> [uds_send_path]

ADDR="${1}"
UDS="${2:-/tmp/uds_send}"

if [ -z "$ADDR" ]; then
    echo "Usage: read_module_info.sh <module_address_hex>"
    exit 1
fi

echo "=== Module 0x${ADDR} Identification ==="
echo ""

# Standard UDS DIDs for module identification
for entry in \
    "F190 VIN" \
    "F187 PartNumber" \
    "F189 SoftwareVersion" \
    "F191 HardwareVersion" \
    "F19E ECUAssyPartNum" \
    "F1A0 BootloaderVersion" \
    "F1A2 SystemSupplierID" \
    "F197 SystemName"; do

    did=$(echo "$entry" | awk '{print $1}')
    name=$(echo "$entry" | awk '{print $2}')
    did_hi=$(echo "$did" | cut -c1-2)
    did_lo=$(echo "$did" | cut -c3-4)

    echo ">> ${name} (DID 0x${did})"
    echo "${ADDR} 22 ${did_hi} ${did_lo}" > /tmp/uds_cmd
    $UDS 2>&1 | grep -v "^==\|^$\|^devctl\|^Commands\|^NDR"
    echo ""
done

echo "=== Done ==="
