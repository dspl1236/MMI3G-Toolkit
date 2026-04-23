#!/bin/ksh

echo "---------------------------------------"
echo "Cache Status: (measures in kbytes)"
echo "---------------------------------------"
echo "PARTITION                TOTAL       USED    FREE      %-USED  MOUNTPOINT"
df -k 2>/dev/null | grep /mnt/img-cache
echo "EFFECTIVE:"
du -k -s /mnt/img-cache/gemmi/* 2>/dev/null
