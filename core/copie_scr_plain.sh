#!/bin/ksh
# MMI3G SD shell script launcher
# DrGER2 improved format - auto-detects SD card path
export SDPATH=$1
export PATH=${SDPATH}/bin:$PATH
export SDLIB=${SDPATH}/lib
export SDVAR=${SDPATH}/var
export SWTRAIN="`cat /dev/shmem/sw_trainname.txt`"
mount -u $SDPATH
cd $SDPATH
exec ksh ./run.sh $SDPATH
