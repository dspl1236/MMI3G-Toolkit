#!/bin/ksh
# On-Car Proxy Deploy wrapper — calls ge_deploy.sh
# On-car mode auto-detected by ge_deploy.sh when
# libembeddedearth_oncar.so exists on the SD card
SDPATH="${1:-${0%/*}/..}"
ksh "${SDPATH}/scripts/ge_deploy.sh" "${SDPATH}"
