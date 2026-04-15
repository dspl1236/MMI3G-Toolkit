#!/bin/ksh
# Author: DHuerlimann

if [ -f /HBpersistence/DLinkReplacesPPP ]
then
	echo "[INFO] /HBpersistence/DLinkReplacesPPP exists"
	echo "[ACTI] Deleting /HBpersistence/DLinkReplacesPPP"
	rm /HBpersistence/DLinkReplacesPPP
else			
	echo "[INFO] no /HBpersistence/DLinkReplacesPPP"
	echo "[ACTI] Creating /HBpersistence/DLinkReplacesPPP"
	touch /HBpersistence/DLinkReplacesPPP
fi   

echo ""
echo "----NEW CONFIGURATION--------------------"
echo ""

ksh /scripts/Connectivity/getConf.sh
