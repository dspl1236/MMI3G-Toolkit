#!/bin/ksh
# Quick module scanner — run from telnet
# Usage: ksh scan_modules.sh [uds_send_path]
#
# Scans all common VAG ECU addresses with DiagnosticSessionControl
# Reports which modules respond

UDS="${1:-/tmp/uds_send}"

if [ ! -x "$UDS" ]; then
    echo "uds_send not found at $UDS"
    echo "Deploy first: cp /mnt/sdcard*/bin/uds_send /tmp/ && chmod +x /tmp/uds_send"
    exit 1
fi

echo "=== MMI3G CAN Module Scanner ==="
echo "Tool: $UDS"
echo "Method: DiagnosticSessionControl Default (0x10 0x01)"
echo ""
echo "Addr  Module                  Status"
echo "----  ----------------------  ------"

for entry in \
    "01 DME/Engine" \
    "02 Transmission" \
    "03 ABS/ESP" \
    "08 HVAC" \
    "09 FrontElectronics" \
    "15 Airbag" \
    "17 Cluster" \
    "19 Gateway" \
    "25 Immobilizer" \
    "2E KESSY" \
    "36 SeatLeft" \
    "37 SeatRight" \
    "44 DoorFL" \
    "45 DoorFR" \
    "46 DoorRL" \
    "47 DoorRR" \
    "4F CentralElec" \
    "52 ParkingAid" \
    "55 Headlights" \
    "56 HeadUnit" \
    "5F InfoElec" \
    "65 TPMS" \
    "69 TowModule" \
    "6C RearCamera" \
    "76 ParkDistance" \
    "77 Telephone"; do

    addr=$(echo "$entry" | awk '{print $1}')
    name=$(echo "$entry" | awk '{print $2}')

    echo "${addr} 10 01" > /tmp/uds_cmd
    RESULT=$($UDS 2>&1)

    if echo "$RESULT" | grep -q "ret=0"; then
        printf "0x%s  %-22s  FOUND\n" "$addr" "$name"
    elif echo "$RESULT" | grep -q "NRC\|7F"; then
        nrc=$(echo "$RESULT" | grep "NRC" | tail -1)
        printf "0x%s  %-22s  NRC (%s)\n" "$addr" "$name" "$nrc"
    else
        printf "0x%s  %-22s  ---\n" "$addr" "$name"
    fi
done

echo ""
echo "=== Scan Complete ==="
