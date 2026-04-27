#!/bin/sh

# For debugging purposes, off by default
if [[ 0 -eq 1 ]] ; then
if [ -a /mnt/nav/gemmi/debug_memcpu.sh ] ; then
	cp /mnt/nav/gemmi/debug_memcpu.sh /tmp
	chmod 777 /tmp/debug_memcpu.sh
	/tmp/debug_memcpu.sh &
fi
fi

export Region13=`ls -l /database/MMI3G_MapArchives.xar | grep 13`

if [[ $Region13 -eq 13 ]] ; then
	export AGCC2=1
else
	export AGCC2=0
fi

# Region Check
case `cat /etc/hmi_country.txt`
in
	"\"NAR\"")
		echo "GEMMI: Detected NAR region."
		export myRegion=0;;
	
	"\"EUROPE\"")
		echo "GEMMI: Detected ECE region."
		export myRegion=2;;
	
	"\"CHINA\"")
		echo "GEMMI: Detected CN region."
		export myRegion=1;;
	
	"\"KOREA\"")
		echo "GEMMI: Detected KR region."
		export myRegion=1;;
	
	"\"JAPAN\"")
		echo "GEMMI: Detected JP region."
		export myRegion=1;;
	
	*)
		echo "GEMMI: Unknown region. Defaulting to ECE."
		export myRegion=1;;
esac

# RSE Flag Check
echo "GEMMI checking if on RSE Unit"

if test -a /mnt/efs-system/RSE ; then
	export variantArgs="-maxcpu 1.0 -targetcpu 1.0 -streetviewtexeldensity 2.0 -rse"
	export myTargetPrio=9
	echo "VARIANT=REAR"
else
	export variantArgs="-streetviewtexeldensity 2.0"
	export myTargetPrio=10
	echo "VARIANT=FRONT"
fi

export myPID=`print $$`
export myPidin=`pidin -p $myPID -f p`
export myPrio=`echo $myPidin | sed -e "s/^.* //" -e "s/r$//"`
export myRelPrio=$((myPrio - myTargetPrio))

#
# sanity check on myRelPrio
if [[ ($myRelPrio -gt 4) || ($myRelPrio -lt -4) ]]
then
	export myRelPrio=0
fi


checkCachePartition()
{
	if ( ! [ -d /mnt/img-cache/gemmi ] )
	then
		echo "[GEMMI] Restoring /mnt/img-cache (corrupted/repartitioned/reformatted)"
		echo "[GEMMI] All cache data is lost, require initial login"
		mkdir /mnt/img-cache/gemmi
		mkdir /mnt/img-cache/gemmi/.config
		mkdir /mnt/img-cache/gemmi/cache
		mkdir /mnt/img-cache/gemmi/scache
		mkdir /mnt/img-cache/gemmi/temp
	fi

	if ( ! [ -d /mnt/img-cache/gemmi/.config ] )
	then
		echo "[GEMMI] Restoring /mnt/img-cache/gemmi/.config (corrupted)"
		mkdir /mnt/img-cache/gemmi/.config
	fi

	if ( ! [ -d /mnt/img-cache/gemmi/cache ] )
	then
		echo "[GEMMI] Restoring /mnt/img-cache/gemmi/cache (corrupted)"
		mkdir /mnt/img-cache/gemmi/cache
	fi

	if ( ! [ -d /mnt/img-cache/gemmi/scache ] )
	then
		echo "[GEMMI] Restoring /mnt/img-cache/gemmi/scache (corrupted)"
		mkdir /mnt/img-cache/gemmi/scache
	fi

	if ( ! [ -d /mnt/img-cache/gemmi/temp ] )
	then
		echo "[GEMMI] Restoring /mnt/img-cache/gemmi/temp (corrupted)"
		mkdir /mnt/img-cache/gemmi/temp
	fi
}

if [ -x /mnt/nav/gemmi/gemmi_final ]
then
	export GEMMI_NAME=gemmi_final
	export LD_LIBRARY_PATH=/mnt/nav/gemmi
	
	if [ -a /tmp/floater ]
	then
		echo "[GEMMI] Remove floater"
		rm -rf /dev/shmem/floater
	fi
	
	export memorySettings="-maxmem 55 -targetmem 40"
	
	restart_countdown=5
	while [[ $restart_countdown -gt 0 ]];
	do
		(( restart_countdown -= 1))
		checkCachePartition

		if [ -a /tmp/reducedmemory ]
		then
			echo "[GEMMI] Found reducedmemory file, reducing GEMMI memory targets"
			export memorySettings="-maxmem 45 -targetmem 30"
			rm /tmp/reducedmemory
			(( restart_countdown += 1))
		fi

		echo "[GEMMI] starting GEMMI $restart_countdown times left"
		cd /
		if [ $myRelPrio -ne 0 ]
		then
			echo "[GEMMI] run_gemmi.sh script is running at priority $myPrio."
			echo "[GEMMI] GEMMI is being launched with 'nice -n $myRelPrio'."
		fi

		nice -n $myRelPrio $LD_LIBRARY_PATH/$GEMMI_NAME -roadwidthscale 0.0116 -opt 1 -prefetch 1 -printromeevents 0 -poithresholdspeed 500 -lodmode 12 -roadnamescale 0.85 -roadnamecolor ffd0ffff -framestats 0 -minsleep 10 -maxfps 12 $memorySettings -maxpingtime 2000 -createroadsinmultibunch -trafficregion $myRegion $variantArgs --tp=/etc/DefaultScope.hbtc --bp

		# exit if flag is set
		if [ -a /tmp/factory_reset_gemmi ]
		then
			echo "[GEMMI] factory reset active, run_gemmi.sh exit"
			exit 0
		else
			echo "no fr active, restarting"
		fi
		
	done
	
	# GEMMI was started 5 times, now format HDD
	echo "[GEMMI] Re-formatting /mnt/img-cache"
	umount -f /mnt/img-cache
	mkqnx6fs -q -o +lfncksum /dev/hd0t187.3
	mount -t qnx6 /dev/hd0t187.3 /mnt/img-cache
else
	echo "[GEMMI] not installed"
fi
