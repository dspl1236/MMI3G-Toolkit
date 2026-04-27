#!/bin/ksh
# Dream Mode Deploy wrapper — calls ge_deploy.sh
# Dream mode is auto-detected by ge_deploy.sh when
# libembeddedearth_dream.so exists on the SD card
SDPATH="${1:-${0%/*}/..}"
ksh "${SDPATH}/scripts/ge_deploy.sh" "${SDPATH}"
