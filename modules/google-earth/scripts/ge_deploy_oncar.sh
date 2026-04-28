#!/bin/ksh
# Google Earth Deploy wrapper
SDPATH="${1:-${0%/*}/..}"
ksh "${SDPATH}/scripts/ge_deploy.sh" "${SDPATH}"
