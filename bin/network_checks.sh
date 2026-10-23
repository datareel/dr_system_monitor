#!/bin/bash
# ----------------------------------------------------------- 
# BASH Script
# Operating System(s): RHEL/CENTOS
# Run Level(s): 3, 5
# Shell: BASH shell
# Original Author(s): DataReel Software Development
# File Creation Date: 05/25/2013
# Date Last Modified: 10/23/2026
#
# Version control: 1.16
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
# NICS is a space separated list of interfaces to monitor
# NICS="eth0 eth1 eth2"
#
# $1 == list of NICs to check, default is all active physical NICs
# $2 == MAX dropped packets during the sample window, default 1000
# $3 == MAX collisions during the sample window, default 100
# $4 == MAX errors during the sample window, default 100
# $5 == Sample window in seconds, default 5
#
# The kernel counters are totals since boot, so alerts are based on
# how much they grow during the sample window.

if [ "${1}" != "" ]; then 
    NICS="${1}"; 
else
    # All interfaces that are up, skipping loopback and virtual
    # bridge, container, and VM tap devices
    NICS=""
    for d in /sys/class/net/*
    do
	n=$(basename ${d})
	case "${n}" in
	    lo|virbr*|macvtap*|veth*|docker*|br-*|cni*|flannel*|cali*|vnet*|tap*) continue ;;
	esac
	if [ "$(cat ${d}/operstate 2> /dev/null)" == "up" ]; then NICS="${NICS} ${n}"; fi
    done
fi

HOST=$(hostname -s)
has_error="0"
has_warning="0"

DROPPEDMAX=1000
COLLMAX=100
MAXERRORS=100
retry_wait=5

if [ "${2}" != "" ]; then DROPPEDMAX=$2; fi
if [ "${3}" != "" ]; then COLLMAX=$3; fi
if [ "${4}" != "" ]; then MAXERRORS=$4; fi 
if [ "${5}" != "" ]; then retry_wait=$5; fi 

IP="ip"
if [ -x /usr/sbin/ip ]; then IP="/usr/sbin/ip"; elif [ -x /sbin/ip ]; then IP="/sbin/ip"; fi

function nicstat() { cat /sys/class/net/${1}/statistics/${2} 2> /dev/null || echo 0; }

UPTIME=$(uptime -p 2> /dev/null || uptime)

declare -A start
for n in ${NICS}
do
    if [ ! -d /sys/class/net/${n} ]; then
	echo "WARNING - ${HOST} network interface ${n} not found"
	has_warning="1"
	continue
    fi
    for c in rx_errors tx_errors rx_dropped tx_dropped collisions; do
	start[${n}_${c}]=$(nicstat ${n} ${c})
    done
done

sleep ${retry_wait}

for n in ${NICS}
do
    if [ ! -d /sys/class/net/${n} ]; then continue; fi
    ETH="${n}"
    IPADDR=$(${IP} -o -4 addr show dev ${ETH} 2> /dev/null | awk '{ print $4 }' | tr '\n' ' ')
    DESCRIPTION="${IPADDR}NIC"

    RXBYTES=$(nicstat ${n} rx_bytes)
    TXBYTES=$(nicstat ${n} tx_bytes)
    RXERRORS=$(( $(nicstat ${n} rx_errors) - ${start[${n}_rx_errors]} ))
    TXERRORS=$(( $(nicstat ${n} tx_errors) - ${start[${n}_tx_errors]} ))
    RXDROPPED=$(( $(nicstat ${n} rx_dropped) - ${start[${n}_rx_dropped]} ))
    TXDROPPED=$(( $(nicstat ${n} tx_dropped) - ${start[${n}_tx_dropped]} ))
    COLLISIONS=$(( $(nicstat ${n} collisions) - ${start[${n}_collisions]} ))

    if [ ${RXERRORS} -gt ${MAXERRORS} ] || [ ${TXERRORS} -gt ${MAXERRORS} ] 
    then
	echo "ERROR - ${HOST} ${ETH} ${DESCRIPTION} has errors"
	echo "${HOST} ${ETH} errors per ${retry_wait} secs: RX=${RXERRORS} TX=${TXERRORS}"
	has_error="1"
    fi

    if [ ${RXDROPPED} -gt ${DROPPEDMAX} ] || [ ${TXDROPPED} -gt ${DROPPEDMAX} ] || [ ${COLLISIONS} -gt ${COLLMAX} ]
    then
	echo "WARNING - ${HOST} ${ETH} ${DESCRIPTION} has packet loss"
	echo "${HOST} ${ETH} dropped per ${retry_wait} secs: RX=${RXDROPPED} TX=${TXDROPPED}"
	echo "${HOST} ${ETH} collisions per ${retry_wait} secs: ${COLLISIONS}"
	has_warning="1"
    fi

    echo "${HOST} ${ETH} ${DESCRIPTION} stats"
    echo "${ETH} - Uptime:  ${UPTIME}"
    echo "${ETH} - RX Bytes: ${RXBYTES}"
    echo "${ETH} - TX Bytes: ${TXBYTES}"
    echo "${ETH} - RX/TX errors total: $(nicstat ${n} rx_errors)/$(nicstat ${n} tx_errors)"
    echo "${ETH} - RX/TX dropped total: $(nicstat ${n} rx_dropped)/$(nicstat ${n} tx_dropped)"
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
