#!/bin/ksh
# Read live data from vehicle modules via UDS
# Usage: ksh read_live_data.sh [module_addr] [uds_send_path]
# Example: ksh read_live_data.sh 01    (engine live data)
#          ksh read_live_data.sh 17    (cluster live data)
#
# READ-ONLY: Does not write to any vehicle system

ADDR="${1:-01}"
UDS="${2:-/tmp/uds_send}"

if [ ! -x "$UDS" ]; then
    echo "uds_send not found at $UDS"
    echo "Deploy first: cp /mnt/sdcard*/bin/uds_send /tmp/ && chmod +x /tmp/uds_send"
    exit 1
fi

echo "=== Live Data Reader ==="
echo "Module: 0x${ADDR}"
echo "Tool: $UDS"
echo ""

# Enter extended diagnostic session first
echo ">> Entering Extended Session..."
echo "${ADDR} 10 03" > /tmp/uds_cmd
$UDS 2>&1 | grep -v "^==\|^$"
sleep 1

echo ""
echo "=== Standard PIDs (ReadDataByIdentifier 0x22) ==="
echo ""

case "$ADDR" in
    01|1)
        # DME/Engine — common Porsche/Audi DIDs
        echo "--- Engine Data ---"
        for entry in \
            "F40C RPM" \
            "F405 CoolantTemp" \
            "F40D VehicleSpeed" \
            "F404 EngineLoad" \
            "F40F IntakeAirTemp" \
            "F410 MAF_AirFlow" \
            "F411 ThrottlePosition" \
            "F42F FuelLevel" \
            "F443 AbsFuelPress" \
            "F444 EquivRatio" \
            "2000 EngineRPM_OEM" \
            "2001 VehicleSpeed_OEM" \
            "2002 EngineLoad_OEM" \
            "2003 CoolantTemp_OEM" \
            "2004 BoostPressure"; do

            did=$(echo "$entry" | awk '{print $1}')
            name=$(echo "$entry" | awk '{print $2}')
            did_hi=$(echo "$did" | cut -c1-2)
            did_lo=$(echo "$did" | cut -c3-4)

            echo "${ADDR} 22 ${did_hi} ${did_lo}" > /tmp/uds_cmd
            RESULT=$($UDS 2>&1)
            if echo "$RESULT" | grep -q "ret=0\|OK"; then
                data=$(echo "$RESULT" | grep "<-" | head -1)
                if [ -n "$data" ]; then
                    printf "  %-20s DID 0x%s: %s\n" "$name" "$did" "$data"
                fi
            fi
        done
        ;;
    17)
        # Cluster — mileage, fuel, service info
        echo "--- Cluster Data ---"
        for entry in \
            "F190 VIN" \
            "0156 ServiceInterval" \
            "0D17 InspectDistance" \
            "0D18 InspectTime" \
            "0100 Odometer" \
            "0101 FuelLevel" \
            "0102 CoolantTemp" \
            "0103 OutdoorTemp" \
            "0104 EngineRPM" \
            "0105 VehicleSpeed" \
            "0300 OilTemp" \
            "0301 OilLevel" \
            "0302 OilPressure"; do

            did=$(echo "$entry" | awk '{print $1}')
            name=$(echo "$entry" | awk '{print $2}')
            did_hi=$(echo "$did" | cut -c1-2)
            did_lo=$(echo "$did" | cut -c3-4)

            echo "${ADDR} 22 ${did_hi} ${did_lo}" > /tmp/uds_cmd
            RESULT=$($UDS 2>&1)
            if echo "$RESULT" | grep -q "ret=0\|OK"; then
                data=$(echo "$RESULT" | grep "<-" | head -1)
                if [ -n "$data" ]; then
                    printf "  %-20s DID 0x%s: %s\n" "$name" "$did" "$data"
                fi
            fi
        done
        ;;
    *)
        # Generic — try standard OBD PIDs mapped to UDS DIDs
        echo "--- Generic Module Data ---"
        for entry in \
            "F190 VIN" \
            "F187 PartNumber" \
            "F189 SWVersion" \
            "F191 HWVersion"; do

            did=$(echo "$entry" | awk '{print $1}')
            name=$(echo "$entry" | awk '{print $2}')
            did_hi=$(echo "$did" | cut -c1-2)
            did_lo=$(echo "$did" | cut -c3-4)

            echo "${ADDR} 22 ${did_hi} ${did_lo}" > /tmp/uds_cmd
            RESULT=$($UDS 2>&1)
            if echo "$RESULT" | grep -q "ret=0\|OK"; then
                data=$(echo "$RESULT" | grep "<-" | head -1)
                if [ -n "$data" ]; then
                    printf "  %-20s DID 0x%s: %s\n" "$name" "$did" "$data"
                fi
            fi
        done
        ;;
esac

echo ""
echo "=== Done ==="
