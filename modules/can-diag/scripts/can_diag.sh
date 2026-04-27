#!/bin/ksh
# MMI3G-Toolkit CAN Diagnostics — Read-Only Vehicle Probe
# Part of MMI3G-Toolkit: github.com/dspl1236/MMI3G-Toolkit
#
# This module is READ-ONLY. It does not write to any vehicle
# module or modify any vehicle configuration. Safe to run
# while the car is on.
#
# Requires: USB ethernet + telnet active (run lte-setup first)

USBROOT="${1:-/mnt/sdcard10t12}"
LOG="${USBROOT}/can_diag.log"
BINDIR="/tmp"

{
echo "============================================"
echo "  MMI3G-Toolkit CAN Diagnostics"
echo "  Read-Only Vehicle Probe"
echo "============================================"
echo ""

# Deploy binaries
echo "=== Deploying Binaries ==="
for bin in uds_send ndr_probe; do
    if [ -f "${USBROOT}/bin/${bin}" ]; then
        cp "${USBROOT}/bin/${bin}" "${BINDIR}/${bin}"
        chmod +x "${BINDIR}/${bin}"
        echo "[OK] ${bin} deployed to ${BINDIR}"
    elif [ -f "${USBROOT}/CanDiag/${bin}" ]; then
        cp "${USBROOT}/CanDiag/${bin}" "${BINDIR}/${bin}"
        chmod +x "${BINDIR}/${bin}"
        echo "[OK] ${bin} deployed from CanDiag/"
    else
        echo "[ERROR] ${bin} not found!"
    fi
done

echo ""
echo "=== NDR Device ==="
ls -la /dev/ndr/ 2>&1

echo ""
echo "=== IOC Channels ==="
ls -la /dev/ipc/ioc/ 2>&1

echo ""
echo "=== NDR Process ==="
pidin ar 2>/dev/null | grep ndr

echo ""
echo "============================================"
echo "  Phase 1: NDR devctl Probe"
echo "============================================"
echo ""
echo "Testing devctl class/cmd combinations..."
${BINDIR}/ndr_probe 2>&1

echo ""
echo "============================================"
echo "  Phase 2: ECU Module Scan"
echo "============================================"
echo ""
echo "Scanning for responding UDS modules (read-only)..."
echo "Sending DiagnosticSessionControl Default (0x10 0x01) to each address"
echo ""

# Common VAG/Porsche UDS module addresses
# Format: hex_addr description
MODULES="
01 DME_Engine
02 Transmission
03 ABS_ESP
08 HVAC_Climate
09 FrontElectronics
15 Airbag_SRS
17 InstrumentCluster
19 Gateway
25 ImmobilizerKESSY
2E KESSY_KeylessEntry
36 SeatModuleLeft
37 SeatModuleRight
44 DoorFrontLeft
45 DoorFrontRight
46 DoorRearLeft
47 DoorRearRight
4F CentralElectronics
52 ParkingAid
55 Headlights
56 Radio_HeadUnit
5F InfoElectronics
65 TirePressure
69 TowModule
6C RearCamera
76 ParkDistanceCtrl
77 Telephone
"

echo "$MODULES" | while read addr name; do
    [ -z "$addr" ] && continue
    echo "0x${addr} 10 01" > /tmp/uds_cmd
    RESULT=$(${BINDIR}/uds_send 2>&1)

    # Check if we got a positive response (not just errors)
    if echo "$RESULT" | grep -q "OK"; then
        echo "  [FOUND] 0x${addr} ${name} — RESPONDS"
        echo "$RESULT" | grep -v "^==\|^$\|^devctl\|^Commands\|^NDR"
    elif echo "$RESULT" | grep -q "ret=0"; then
        echo "  [FOUND] 0x${addr} ${name} — devctl OK"
        echo "$RESULT" | grep "ret="
    else
        # Check for NRC (negative response = module exists but rejected)
        if echo "$RESULT" | grep -q "NRC\|7F"; then
            echo "  [FOUND] 0x${addr} ${name} — NRC response (module exists)"
            echo "$RESULT" | grep "NRC\|7F\|<-"
        fi
        # Silent = no response = module not present or filtered
    fi
done

echo ""
echo "============================================"
echo "  Phase 3: Module Identification"
echo "============================================"
echo ""
echo "Reading module info from known-responding addresses..."
echo "(ReadDataByIdentifier: VIN, part number, HW/SW version)"
echo ""

# Try to read from cluster (usually responds)
for did_name in "F190 VIN" "F187 PartNumber" "F189 SWVersion" "F191 HWVersion" "F19E AsyPartNum"; do
    did=$(echo "$did_name" | awk '{print $1}')
    name=$(echo "$did_name" | awk '{print $2}')
    did_hi=$(echo "$did" | cut -c1-2)
    did_lo=$(echo "$did" | cut -c3-4)

    echo "--- Cluster (0x17) ${name} (DID 0x${did}) ---"
    echo "17 22 ${did_hi} ${did_lo}" > /tmp/uds_cmd
    ${BINDIR}/uds_send 2>&1 | grep -v "^==\|^$\|^devctl\|^Commands\|^NDR"
    echo ""
done

# Try gateway
echo "--- Gateway (0x19) VIN ---"
echo "19 22 F1 90" > /tmp/uds_cmd
${BINDIR}/uds_send 2>&1 | grep -v "^==\|^$\|^devctl\|^Commands\|^NDR"

echo ""
echo "============================================"
echo "  Phase 4: Fault Code Scan"  
echo "============================================"
echo ""
echo "Reading DTCs from key modules (Service 0x19)..."
echo "(ReadDTCInformation: report all stored DTCs)"
echo ""

for mod in "17 Cluster" "19 Gateway" "01 DME" "03 ABS" "09 FrontElec"; do
    addr=$(echo "$mod" | awk '{print $1}')
    name=$(echo "$mod" | awk '{print $2}')

    echo "--- ${name} (0x${addr}) DTCs ---"
    # Service 0x19, Sub 0x02 = report by status mask, mask 0xFF = all
    echo "${addr} 19 02 FF" > /tmp/uds_cmd
    ${BINDIR}/uds_send 2>&1 | grep -v "^==\|^$\|^devctl\|^Commands\|^NDR"
    echo ""
done

echo ""
echo "============================================"
echo "  Phase 5: System Summary"
echo "============================================"
echo ""
echo "=== NDR Message Queue ==="
cat /dev/ndr/msq 2>&1 | pidin -F"%x" 2>/dev/null
echo ""

echo "=== IOC Debug Info ==="
cat /dev/ipc/ioc/debug 2>&1

echo ""
echo "=== HFS Config (CAN routing) ==="
cat /etc/hfs.cfg 2>&1

echo ""
echo "============================================"
echo "  CAN Diagnostics Complete"
echo "  Log: ${LOG}"
echo "============================================"
} > "$LOG" 2>&1

echo "can-diag done" >> "${USBROOT}/mmi_ran.txt" 2>/dev/null
echo "can-diag done" >> "${USBROOT}/pcm_ran.txt" 2>/dev/null
