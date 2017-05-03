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
# Version control: 1.12
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
# System monitoring script for network usage and errors 
#
# ----------------------------------------------------------- 
# NICS is a space seperated list of interfaces to monitor"
# NICS="eth0 eth1 eth2"

IP="ip"
if [ -f /sbin/ip ]; then IP="/sbin/ip"; fi
if [ -f /usr/sbin/ip ]; then IP="/usr/sbin/ip"; fi

if [ "${1}" != "" ]; then 
    NICS="${1}"; 

else
    NICS=$(${IP} link | grep -v lo: | grep -v ' virbr' | grep 'state UP' | awk -F: '{ print $2 }' | sed s/' '//g)
fi

HOST=$(hostname -s)
has_error="0"
has_warning="0"

DROPPEDMAX=5000
COLLMAX=5000
MAXERRORS=5000

for n in ${NICS}
do
    UPTIME=$(uptime | awk -F, '{ print $1 $2 }')
    ETH=$(echo "${n}")
    IPADDR=$($IP addr show dev ${ETH} | grep 'inet ' | awk '{ print $2}')
    DESCRIPTION=$(echo "${IPADDR} NIC")
    ETHinfo=$(cat  /proc/net/dev | grep ${ETH}: | awk -F: '{ print $2 }')
    
    RXBYTES=$(echo "${ETHinfo}" | awk '{ print $1 }')
    RXPACKETS=$(echo "${ETHinfo}" | awk '{ print $2 }')
    RXERRORS=$(echo "${ETHinfo}" | awk '{ print $3 }')
    RXDROPPED=$(echo "${ETHinfo}" | awk '{ print $4 }')
    RXFRAME=$(echo "${ETHinfo}" | awk '{ print $6 }')
    TXBYTES=$(echo "${ETHinfo}" | awk '{ print $9 }')
    TXPACKETS=$(echo "${ETHinfo}" | awk '{ print $10 }')
    TXERRORS=$(echo "${ETHinfo}" | awk '{ print $11 }')
    TXDROPPED=$(echo "${ETHinfo}" | awk '{ print $12 }')
    COLLISIONS=$(echo "${ETHinfo}" | awk '{ print $14 }')
    TXCARRIER=$(echo "${ETHinfo}" | awk '{ print $15 }')

    if [ ${RXERRORS} -gt ${MAXERRORS} ] || [ ${TXERRORS} -gt ${MAXERRORS} ] 
    then
	echo "INFO - ${HOST} ${ETH} detected RXERRORS/TXERRORS, will retry check in 60 seconds"
	sleep 60
	RXERRORS_RETRY=$(echo "${ETHinfo}" | awk '{ print $3 }')
	TXERRORS_RETRY=$(echo "${ETHinfo}" | awk '{ print $11 }')
	if [ ${RXERRORS} -ne ${RXERRORS_RETRY} ] || [ ${TXERRORS} -gt ${TXERRORS_RETRY} ]
	then
	    RXERRORS=$(echo "${RXERRORS_RETRY} - ${RXERRORS}" | bc)
	    TXERRORS=$(echo "${TXERRORS_RETRY} - ${TXERRORS}" | bc)
	    if [ ${RXERRORS} -gt ${MAXERRORS} ] || [ ${TXERRORS} -gt ${MAXERRORS} ] 
	    then
		echo "ERROR - ${HOST} ${ETH} ${DESCRIPTION} has errors"
		echo "RX errors: ${RXERRORS} TX errors: ${TXERRORS}"
		has_error="1"
	    else
		echo "INFO - ${HOST} ${ETH} 60 second error count RX=${RXERRORS} TX=${TXERRORS}"
	    fi
	fi
    fi

    if [ ${RXDROPPED} -gt ${DROPPEDMAX} ] || [ ${TXDROPPED} -gt ${DROPPEDMAX} ] || [ ${COLLISIONS} -gt ${COLLMAX} ]
    then
	echo "INFO - ${HOST} ${ETH} detected DROPPED/FRAME/COLLISIONS, will retry check in 60 seconds"
	sleep 60
	RXDROPPED_RETRY=$(echo "${ETHinfo}" | awk '{ print $4 }')
	TXDROPPED_RETRY=$(echo "${ETHinfo}" | awk '{ print $12 }')
	COLLISIONS_RETRY=$(echo "${ETHinfo}" | awk '{ print $14 }')
	if [ ${RXDROPPED} -ne ${RXDROPPED_RETRY} ] || [ ${TXDROPPED} -ne ${TXDROPPED_RETRY} ] || [ ${COLLISIONS} -ne ${COLLISIONS_RETRY} ]
	then
	    echo "WARNING - ${HOST} ${ETH} ${DESCRIPTION} has packet loss"
	    echo "${HOST} ${ETH} RX dropped per 60 secs:  ${RXDROPPED_RETRY}/${RXDROPPED}  TX dropped: ${TXDROPPED_RETRY}/${TXDROPPED}"
	    echo "${HOST} ${ETH} Collisions per 60 secs:  ${COLLISIONS_RETRY}/${COLLISIONS}"
	    has_warning="1"
	fi
    fi

    echo "${HOST} ${ETH} ${DESCRIPTION} stats"
    echo "${ETH} - Uptime:  ${UPTIME} hours"
    echo "${ETH} - RX Btyes: ${RXBYTES}"
    echo "${ETH} - TX Btyes: ${TXBYTES}"
done

if [ "${has_error}" == "1" ]
then
    exit 2
fi

if [ "${has_warning}" == "1" ]
then
    exit 1
fi

exit 0
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
