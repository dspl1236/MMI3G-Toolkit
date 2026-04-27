#!/bin/ksh
# Read fault codes from a specific module
# Usage: ksh read_dtc.sh <module_addr_hex> [uds_send_path]
# Example: ksh read_dtc.sh 17        (cluster)
#          ksh read_dtc.sh 01        (engine)
#          ksh read_dtc.sh 03        (ABS)

ADDR="${1}"
UDS="${2:-/tmp/uds_send}"

if [ -z "$ADDR" ]; then
    echo "Usage: read_dtc.sh <module_address_hex>"
    echo "  17 = Instrument Cluster"
    echo "  01 = DME/Engine"
    echo "  02 = Transmission"
    echo "  03 = ABS/ESP"
    echo "  19 = Gateway"
    echo "  09 = Front Electronics"
    exit 1
fi

echo "=== Read DTCs from module 0x${ADDR} ==="
echo ""

# Step 1: Open extended diagnostic session
echo ">> Extended Session (0x10 0x03)"
echo "${ADDR} 10 03" > /tmp/uds_cmd
$UDS 2>&1
sleep 1

# Step 2: Read all DTCs
echo ""
echo ">> Read DTCs (0x19 0x02 0xFF)"
echo "${ADDR} 19 02 FF" > /tmp/uds_cmd
$UDS 2>&1
sleep 1

# Step 3: Read DTC count
echo ""
echo ">> DTC Count (0x19 0x01 0xFF)"
echo "${ADDR} 19 01 FF" > /tmp/uds_cmd
$UDS 2>&1

echo ""
echo "=== Done ==="
