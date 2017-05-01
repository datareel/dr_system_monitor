#!/bin/bash
# ----------------------------------------------------------- 
# BASH Script
# Operating System(s): RHEL/CENTOS
# Run Level(s): 3, 5
# Shell: BASH shell
# Original Author(s): DataReel Software Development
# File Creation Date: 05/25/2013
# Date Last Modified: 05/01/2017
#
# Version control: 1.09
#
# Contributor(s):
# ----------------------------------------------------------- 
# ------------- Program Description and Details ------------- 
# ----------------------------------------------------------- 
# This file is part of the DataReel system monitor distribution.
#
# Datareel is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation, either version 3 of the License, or (at your
# option) any later version. 
#
# Datareel software is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with the DataReel software distribution.  If not, see
# <http://www.gnu.org/licenses/>.
#
# Utility script used to ping all IPv4 systems on a specified network.
#
# ----------------------------------------------------------- 
NET=$1
MASK=$2

LOGdir="${HOME}/logs"

if [ "${NET}" == "" ]
then 
    echo "ERROR - you must enter a network and mask"
    echo "${0} 192.168.122.0 255"
    exit 1
fi

if [ "${MASK}" == "" ]
then 
    echo "ERROR - you must enter a network and mask"
    echo "${0} 192.168.122.0 255"
    exit 1
fi

mkdir -p ${LOGdir}
LOGfile="${LOGdir}/pingscan_${NET}_${MASK}.txt"

oct1=$(echo "${NET}" | awk -F. '{ print $1 }')
oct2=$(echo "${NET}" | awk -F. '{ print $2 }')
oct3=$(echo "${NET}" | awk -F. '{ print $3 }')

count=$(echo "${NET}" | awk -F. '{ print $4 }')
let count=count+1

NUM=$(echo "255-${MASK}" | bc)
if [ $NUM -eq 0 ]; then NUM=255; fi

cat /dev/null > ${LOGfile}

echo "IP ADDRESS, STATUS, HOSTNAME, MAC ADDRESS" | tee -a ${LOGfile}
while [ $count -lt $NUM ]
do
    alive=$(ping -c 1 -w 1 $oct1.$oct2.$oct3.$count | grep ' bytes from ' | awk '{ print $4}')
    if [ "${alive}" != "" ]
	then
	host=$(echo $alive | sed s/://g)
	ARP=$(arp -a $oct1.$oct2.$oct3.$count)
	HOSTNAME=$(echo "${ARP}" | awk '{ print $1 }')
	MAC=$(echo "${ARP}" | awk '{ print $4 }')
	echo "${host}, UP, ${HOSTNAME}, ${MAC}" | tee -a ${LOGfile}
    else
	host="${oct1}.${oct2}.${oct3}.${count}"
	HOSTNAME=$(host $oct1.$oct2.$oct3.$count | grep -v 'not found')
	if [ "${HOSTNAME}" == "" ]; then HOSTNAME="NONE"; fi
	MAC="NONE"
	echo "${host}, DOWN, ${HOSTNAME}, ${MAC}" | tee -a ${LOGfile}
    fi
    let count=count+1
done

exit 0
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
