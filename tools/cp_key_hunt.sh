#!/bin/ksh
# cp_key_hunt.sh — Focused Component Protection key extraction
# Paste sections into root shell at 192.168.0.154:2323
# Goal: Find where CP keys (IKA, FAZIT) are stored on live system

echo "===== CP KEY HUNT ====="

# 1. Search ALL persistence for CP-related files
echo "--- PERSISTENCE SEARCH ---"
find / -name "*compo*" -o -name "*cprot*" -o -name "*fazit*" \
       -o -name "*FAZIT*" -o -name "*IKA*" -o -name "*ika*" \
       -o -name "*component*protect*" 2>/dev/null

# 2. Check DataPST.db — CP keys are likely stored as persistence entries
echo "--- DataPST.db ---"
ls -la /mnt/efs-persist/DataPST.db 2>/dev/null
# If sqlite3 is available:
sqlite3 /mnt/efs-persist/DataPST.db ".tables" 2>/dev/null
sqlite3 /mnt/efs-persist/DataPST.db "SELECT * FROM persistence WHERE key LIKE '%compo%' OR key LIKE '%fazit%' OR key LIKE '%ika%' OR key LIKE '%cprot%';" 2>/dev/null
# Dump all tables
sqlite3 /mnt/efs-persist/DataPST.db ".schema" 2>/dev/null

# 3. Check HBpersistence
echo "--- HBpersistence ---"
ls -laR /HBpersistence/ 2>/dev/null
find /HBpersistence -type f 2>/dev/null | while read f; do
    echo "FILE: $f ($(wc -c < "$f") bytes)"
done

# 4. Look for raw key files
echo "--- KEY FILES ---"
find /mnt -name "*.key" -o -name "*.bin" -o -name "*.dat" 2>/dev/null | while read f; do
    size=$(wc -c < "$f" 2>/dev/null)
    echo "$f ($size bytes)"
    # 34 bytes = IKA key (DID 0x00BE)
    if [ "$size" = "34" ]; then
        echo "  *** POSSIBLE IKA KEY (34 bytes)! ***"
        od -A x -t x1z "$f" 2>/dev/null | head -5
    fi
done

# 5. Check /dev/scp_pss — SCP bus device for CP communication
echo "--- SCP BUS ---"
ls -la /dev/scp* 2>/dev/null
# Check if we can read from it
cat /proc/devinf 2>/dev/null | grep -i scp

# 6. Check EEPROM devices
echo "--- EEPROM ---"
ls -la /dev/eeprom* /dev/i2c* /dev/spi* 2>/dev/null

# 7. MMI3GApplication CP string deep dive
echo "--- CP STRINGS DEEP DIVE ---"
strings /mnt/ifs-root/usr/apps/MMI3GApplication 2>/dev/null | grep -i "component.protection\|ComponentProtection" | sort -u
strings /mnt/ifs-root/usr/apps/MMI3GApplication 2>/dev/null | grep -i "FAZIT" | sort -u
strings /mnt/ifs-root/usr/apps/MMI3GApplication 2>/dev/null | grep -i "authstring\|auth_string\|AuthStr" | sort -u
strings /mnt/ifs-root/usr/apps/MMI3GApplication 2>/dev/null | grep -i "cipher\|encrypt\|decrypt\|aes" | sort -u
strings /mnt/ifs-root/usr/apps/MMI3GApplication 2>/dev/null | grep -i "0x00BE\|0x00BF\|DID.*BE\|readDid\|writeDid" | sort -u

# 8. Look at the MMI3GMisc binary too (79 CP references)
echo "--- MMI3GMisc CP ---"
strings /mnt/ifs-root/usr/apps/MMI3GMisc 2>/dev/null | grep -i "compo.prot\|fazit\|ika\|authstring" | sort -u

# 9. Check runtime memory for CP keys
echo "--- RUNTIME CP PROCESSES ---"
pidin 2>/dev/null | grep -i "compo\|cprot\|fazit\|auth"

# 10. Extract cipher-aes.so symbols
echo "--- CIPHER-AES SYMBOLS ---"
strings /mnt/ifs-root/lib/cipher-aes.so 2>/dev/null

echo ""
echo "===== CP KEY HUNT COMPLETE ====="
