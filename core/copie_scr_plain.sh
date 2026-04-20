#!/bin/ksh
# 20231112 drger; Added MMI3GB
# 20221220 drger; Added MUVER
# 20220103 drger; MMI3G/MMI3GP SD shell script launcher
# Adapted for MMI3G-Toolkit (dspl1236)
export SDPATH=$1
export PATH=${PATH}:${SDPATH}/bin
export SDLIB=${SDPATH}/lib
export SDVAR=${SDPATH}/var
export MUVER="n/a"
export SWTRAIN="n/a"
if [ -e /etc/pci-3g_9304.cfg ]
then
 MUVER="MMI3GB"
elif [ -e /etc/pci-3g_9308.cfg ]
then
 MUVER="MMI3GH"
elif [ -e /etc/pci-3g_9411.cfg ]
then
 MUVER="MMI3GP"
 SWTRAIN="$(cat /dev/shmem/sw_trainname.txt)"
fi
mount -u $SDPATH
cd $SDPATH
exec ksh ./run.sh $SDPATH
