#!/bin/ksh
# Dream Mode Deploy — Google Earth without PC proxy
# Wrapper that calls ge_deploy.sh in dream mode
SDPATH="${SDPATH:-${0%/*}/..}"
ksh "${SDPATH}/scripts/ge_deploy.sh" dream
