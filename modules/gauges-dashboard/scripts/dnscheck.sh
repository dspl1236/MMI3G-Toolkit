#!/bin/ksh
# dnscheck.sh - Show DNS config (shown in GEM console)
echo "--- /etc/resolv.conf ---"
cat /etc/resolv.conf 2>/dev/null
echo ""
echo "--- ppp0 status ---"
ifconfig ppp0 2>/dev/null || echo "ppp0: not active"
echo ""
echo "--- en5 status ---"
ifconfig en5 2>/dev/null || echo "en5: not active"
