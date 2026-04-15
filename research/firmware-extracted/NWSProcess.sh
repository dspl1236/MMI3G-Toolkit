#!/bin/ksh
#/*********************************************************************
# * Project        Audi MMI3G+
# * (c) Copyright  2008
# * Company        Harman/Becker Automotive Systems GmbH
# *                All rights reserved
# * Secrecy Level STRICTLY CONFIDENTIAL 
# *-------------------------------------------------------------------*/
#/**
# * @file
# * @author        Robert Klarer
# * @brief         NWS startup script
# *
# *********************************************************************/
   
if test -a /mnt/efs-system/RSE ; then
 echo "RSE no clearing of nameserver" >> /dev/ser1
else
 echo "_CS_RESOLVE:" >> /dev/ser1
 getconf _CS_RESOLVE >> /dev/ser1
 setconf _CS_RESOLVE "nocache_on"
 echo "=== Workaround: set "nocache_on" to _CS_RESOLVE: ===" >> /dev/ser1
 getconf _CS_RESOLVE >> /dev/ser1
fi

usr/bin/NWSProcess -f /usr/data/nws.cfg -s pss_config -c HostAgent MonitorService AliveService RmssService ConfigService NetworkingService UPnPService DSIService -k VerboseLevel=2 &