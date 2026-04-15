#!/bin/ksh

## Java path setup:
export JAVA_HOME=/j9
export PATH=$JAVA_HOME/bin:$PATH

if [ -f /HBpersistence/DLinkReplacesPPP ]; then
	mount -uw /mnt/efs-system
	mount -uw /mnt/efs-persist
fi

## TODO: is TIMELOGGER really needed?
## Benchmark time logger:
TIMELOGGER=/usr/apps/bench/TimeLogger

##
## JVM general setup:
##

VMOPTIONS="$VMOPTIONS -Djdsi.trialtimeout=50000"

## Setup library paths for Java generally, J9 and system:
export LD_LIBRARY_PATH=.:/proc/boot:/lib:/lib/dll:/usr/lib:/usr/lib/dll:$JAVA_HOME/bin:/lsd
export EMP_PARAMS="xres=800,yres=480,disp=lvds,head=1,edid=/lsd/audi800x480_B2.edid"

VMOPTIONS="$VMOPTIONS -Djava.library.path=$LD_LIBRARY_PATH"
VMOPTIONS="$VMOPTIONS -Dcom.ibm.oti.vm.bootstrap.library.path=$LD_LIBRARY_PATH"

## JVM memory management parameters:
VMOPTIONS="$VMOPTIONS -Xmca8k -Xmco8k -Xmo11264k -Xmoi0 -Xmn512k -Xmx13312k"

## Limit Jit memory usage
VMOPTIONS="$VMOPTIONS -Xjit:code=512 -Xjit:codeTotal=2048"

##
## HMI framework setup:
##

## enable use of Iconextractor DSI
VMOPTIONS="$VMOPTIONS -DUseIconExtractor=true"

## configure Benchmark logging to slog
VMOPTIONS="$VMOPTIONS -DSLOG=Ext.Benchmark=0"


## disable trace client connection
#
# depending on trace scope setting the trace client connection can have a severe performance impact
# for all profiling activities, the trace client connection should be disabled

# use this option only for non-asia variants
VMOPTIONS="$VMOPTIONS -DNoTraceClient"

ETCDIR=/lsd

##
## JDSI specific settings:
##

VMOPTIONS="$VMOPTIONS -Djdsi.3SoftOSGi=true"
VMOPTIONS="$VMOPTIONS -Djdsi.noDispatcher"
VMOPTIONS="$VMOPTIONS -Djdsi.trialcount=2000"
VMOPTIONS="$VMOPTIONS -Ddsi.debuglevel=2"
VMOPTIONS="$VMOPTIONS -Ddsi.channel.priority=+1"
VMOPTIONS="$VMOPTIONS -Ddsi.decoder.priority=+1"
VMOPTIONS="$VMOPTIONS -Ddsi.maxPacketLength=16384"
VMOPTIONS="$VMOPTIONS -Ddsi.channel=msgpassing"
VMOPTIONS="$VMOPTIONS -Ddsi.memmode=nopooling"

##
## Graphic adapter specific setup:
##
VMOPTIONS="$VMOPTIONS -Dshowcombi=true"

##
## Green engineering screens setup:
##

## definition directory for green engineering screens:
VMOPTIONS="$VMOPTIONS -Dde.audi.tghu.engineering.base_dir=/HBpersistence/engdefs"

## images reside in file-system
VMOPTIONS="$VMOPTIONS -DImageRoot=/lsd/images"

##
## settings for POI Online Search:
##
VMOPTIONS="$VMOPTIONS -Dpoiproducer.properties=/lsd/poiproducer.properties"
VMOPTIONS="$VMOPTIONS -DMMI3G_MyAudi.properties=/lsd/MMI3G_MyAudi.properties"
## EU server
VMOPTIONS="$VMOPTIONS -Donlineservices.url=http://menu.audi-online.de/menu/template"

##
## Setup boot class path / conditionally include TestServer and DSITracer:
##
BOOTCLASSPATH=-Xbootclasspath
MODULAR=no

DSITRACER=/lsd/DSITracer.jar
if [ -f "$DSITRACER" ]; then
  BOOTCLASSPATH="$BOOTCLASSPATH:$DSITRACER"
  MODULAR=yes
fi

GEM=/lsd/AppDevelopment.jar
if [ -f "$GEM" ]; then
  BOOTCLASSPATH="$BOOTCLASSPATH:$GEM"
fi

TEXT=/lsd/texts.jar
if [ -f "$TEXT" ]; then
  BOOTCLASSPATH="$BOOTCLASSPATH:$TEXT"
fi

if [ -f /HBpersistence/DLinkReplacesPPP ]; then
MYAUDI=$ETCDIR/myaudiconnect_nodataconnect.jar
VMOPTIONS="$VMOPTIONS -DmyAudi.IMSI=232106908113543"

if [ -f "$MYAUDI" ]; then
BOOTCLASSPATH="$BOOTCLASSPATH:$MYAUDI"
MODULAR=yes
fi
fi

BOOTCLASSPATH="$BOOTCLASSPATH:/lsd/lsd.jxe"

##
## Launch J9
##

## TODO: is TIMELOGGER really needed?
$TIMELOGGER "Before J9 start"

## start j9 in background to finish ksh process.
## if the ksh is left running, this seems to cause some memory management trouble in QNX

if [ $MODULAR = no ]; then
  j9 $VMOPTIONS $BOOTCLASSPATH -jxe /lsd/lsd.jxe &
else
  echo "WARNING: NON PERFORMANT MODULAR STARTUP!!!"
  j9 $VMOPTIONS $BOOTCLASSPATH de.dreisoft.lsd.LSD &
fi
