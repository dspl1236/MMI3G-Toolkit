#!/bin/ksh
# rootshell_explore.sh — MMI3G+ Root Shell Exploration Script
# Paste into PuTTY connected to 192.168.0.154:2323
# Captures system info, CP internals, key storage, filesystem gold
# Output: paste results back for analysis
#
# Usage: Copy sections and paste into root shell one at a time
#        (raw TCP shell has no PTY, so run sections individually)

###############################################################################
# SECTION 1: SYSTEM IDENTITY
###############################################################################
echo "===== SYSTEM IDENTITY ====="
uname -a
echo "--- hostname ---"
hostname 2>/dev/null || cat /etc/HOSTNAME 2>/dev/null
echo "--- build info ---"
cat /etc/build_info 2>/dev/null
cat /mnt/ifs-root/etc/build_info 2>/dev/null
echo "--- variant ---"
cat /mnt/efs-system/version.txt 2>/dev/null
cat /mnt/efs-system/variant.txt 2>/dev/null
ls /mnt/efs-system/version* 2>/dev/null
echo "--- uptime/pidin ---"
pidin info 2>/dev/null

###############################################################################
# SECTION 2: CREDENTIALS & AUTH
###############################################################################
echo "===== CREDENTIALS ====="
cat /etc/passwd
echo "--- shadow ---"
cat /etc/shadow 2>/dev/null
echo "--- inetd ---"
cat /etc/inetd.conf 2>/dev/null
echo "--- sshd config ---"
cat /etc/ssh/sshd_config 2>/dev/null

###############################################################################
# SECTION 3: MOUNT POINTS & STORAGE
###############################################################################
echo "===== MOUNTS ====="
mount
echo "--- df ---"
df -h 2>/dev/null || df
echo "--- flash partitions ---"
ls -la /dev/fs* 2>/dev/null
ls -la /dev/hd* 2>/dev/null

###############################################################################
# SECTION 4: NETWORK
###############################################################################
echo "===== NETWORK ====="
ifconfig -a 2>/dev/null || ifconfig
echo "--- routing ---"
netstat -rn 2>/dev/null
echo "--- listening ports ---"
netstat -an 2>/dev/null | head -40
echo "--- dns ---"
cat /etc/resolv.conf 2>/dev/null

###############################################################################
# SECTION 5: RUNNING PROCESSES
###############################################################################
echo "===== PROCESSES ====="
pidin 2>/dev/null | head -80
echo "--- pidin args ---"
pidin -F "%a %b %N %J" 2>/dev/null | head -80

###############################################################################
# SECTION 6: COMPONENT PROTECTION — THE GOLD
###############################################################################
echo "===== COMPONENT PROTECTION ====="
echo "--- /dev/scp_pss (SCP bus) ---"
ls -la /dev/scp* 2>/dev/null
echo "--- CP-related devices ---"
ls -la /dev/ipc/ 2>/dev/null
ls -la /dev/dspipc/ 2>/dev/null
ls -la /dev/can* 2>/dev/null
echo "--- CP persistence files ---"
find /mnt/efs-persist -name "*compo*" -o -name "*cprot*" -o -name "*fazit*" -o -name "*ika*" -o -name "*CP*" 2>/dev/null
find /HBpersistence -name "*compo*" -o -name "*cprot*" -o -name "*fazit*" -o -name "*ika*" -o -name "*CP*" 2>/dev/null
echo "--- DataPST.db (persistence database) ---"
ls -la /mnt/efs-persist/DataPST.db 2>/dev/null
ls -la /HBpersistence/*.db 2>/dev/null
echo "--- CP key in EEPROM/persistence ---"
# DID 0x00BE = 34 bytes IKA key
# Search for CP-related persistence keys
find /mnt/efs-persist -name "*.db" -o -name "*.dat" -o -name "*.key" -o -name "*.bin" 2>/dev/null
echo "--- FAZIT/IKA in binary ---"
strings /mnt/ifs-root/usr/apps/MMI3GApplication 2>/dev/null | grep -i "fazit\|ika_key\|IKA\|compo.prot\|cprot\|AuthString\|0x00BE" | head -30

###############################################################################
# SECTION 7: FSC / ACTIVATION CODES
###############################################################################
echo "===== FSC SYSTEM ====="
ls -laR /mnt/efs-persist/FSC/ 2>/dev/null
echo "--- illegal FSCs ---"
ls -laR /mnt/efs-persist/FSC/illegal/ 2>/dev/null
echo "--- crypto keys ---"
ls -la /mnt/efs-persist/crypto* 2>/dev/null
ls -la /mnt/efs-system/crypto* 2>/dev/null
find /mnt -name "*.pem" -o -name "*.key" -o -name "*.pub" -o -name "*.cert" 2>/dev/null

###############################################################################
# SECTION 8: CIPHER/CRYPTO LIBRARIES
###############################################################################
echo "===== CRYPTO LIBS ====="
ls -la /mnt/ifs-root/lib/cipher* 2>/dev/null
ls -la /mnt/ifs-root/usr/lib/cipher* 2>/dev/null
ls -la /mnt/efs-system/lib/cipher* 2>/dev/null
echo "--- strings from cipher-aes.so ---"
strings /mnt/ifs-root/lib/cipher-aes.so 2>/dev/null | head -20
echo "--- libcrypto ---"
ls -la /mnt/ifs-root/lib/libcrypto* 2>/dev/null
ls -la /mnt/efs-system/lib/libcrypto* 2>/dev/null

###############################################################################
# SECTION 9: MOST BUS / CAN BUS
###############################################################################
echo "===== MOST/CAN ====="
ls -la /dev/most* 2>/dev/null
ls -la /dev/can* 2>/dev/null
echo "--- MOST config ---"
cat /mnt/efs-system/etc/most.cfg 2>/dev/null
echo "--- CAN config ---"
cat /mnt/efs-system/etc/can.cfg 2>/dev/null

###############################################################################
# SECTION 10: LSD / GOOGLE EARTH
###############################################################################
echo "===== LSD / GOOGLE EARTH ====="
ls -la /mnt/efs-system/lsd/ 2>/dev/null
cat /mnt/efs-system/lsd/lsd.sh 2>/dev/null
cat /mnt/efs-system/lsd/drivers.ini 2>/dev/null
echo "--- lsd.jxe ---"
ls -la /mnt/efs-system/lsd/lsd.jxe 2>/dev/null
ls -la /mnt/nav/gemmi/ 2>/dev/null
echo "--- GE config ---"
find /mnt -name "*google*" -o -name "*gemmi*" -o -name "*earth*" 2>/dev/null

###############################################################################
# SECTION 11: EFS-SYSTEM KEY DIRECTORIES
###############################################################################
echo "===== EFS-SYSTEM ====="
ls -la /mnt/efs-system/ 2>/dev/null
ls -la /mnt/efs-system/etc/ 2>/dev/null
ls -la /mnt/efs-persist/ 2>/dev/null
echo "--- HBpersistence ---"
ls -la /HBpersistence/ 2>/dev/null
echo "--- IFS root ---"
ls -la /mnt/ifs-root/ 2>/dev/null
ls -la /mnt/ifs-root/usr/apps/ 2>/dev/null
echo "--- binary sizes ---"
ls -la /mnt/ifs-root/usr/apps/MMI3G* 2>/dev/null

###############################################################################
# SECTION 12: SQLITE DATABASES (CP KEYS MAY BE HERE)
###############################################################################
echo "===== SQLITE DATABASES ====="
find /mnt -name "*.db" -o -name "*.sqlite" 2>/dev/null
echo "--- Check if sqlite3 exists ---"
which sqlite3 2>/dev/null
ls /mnt/efs-system/bin/sqlite3 2>/dev/null

###############################################################################
# SECTION 13: ENVIRONMENT & CONFIG
###############################################################################
echo "===== ENVIRONMENT ====="
env
echo "--- shell ---"
echo $SHELL
echo "--- path ---"
echo $PATH
echo "--- available tools ---"
ls /bin/ /usr/bin/ /sbin/ /usr/sbin/ 2>/dev/null | sort -u | head -60

###############################################################################
# SECTION 14: EXTRACT CP BINARY SECTIONS (for offline analysis)
###############################################################################
echo "===== CP BINARY STRINGS ====="
echo "--- CSPHComponentProtection references ---"
strings /mnt/ifs-root/usr/apps/MMI3GApplication 2>/dev/null | grep -i "CSPHComp\|SPHComp\|CompoProte" | sort -u
echo "--- RQST/RPST AuthString ---"
strings /mnt/ifs-root/usr/apps/MMI3GApplication 2>/dev/null | grep -i "AuthString\|RQST_Auth\|RPST_Auth" | sort -u
echo "--- DID 0x00BE / IKA ---"
strings /mnt/ifs-root/usr/apps/MMI3GApplication 2>/dev/null | grep -i "0x00BE\|IKA\|ika_key\|IkaKey" | sort -u
echo "--- Routine control ---"
strings /mnt/ifs-root/usr/apps/MMI3GApplication 2>/dev/null | grep -i "RoutiContr\|RoutineControl\|0x31" | sort -u

echo ""
echo "===== EXPLORATION COMPLETE ====="
echo "Copy all output and paste back for analysis."
