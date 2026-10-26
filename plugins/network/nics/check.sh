#!/bin/bash
# ----------------------------------------------------------- 
# BASH Script
# Operating System(s): RHEL/CENTOS
# Run Level(s): 3, 5
# Shell: BASH shell
# Original Author(s): DataReel Software Development
# File Creation Date: 10/23/2026
# Date Last Modified: 10/26/2026
#
# Version control: 1.01
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
# DRSM plugin: network interface errors, ported from bin/network_checks.sh.
# The kernel counters are totals since boot, so alerts are based on
# how much they grow during the sample window.
#
# The counters come from /sys/class/net, or from /proc/net/dev on hosts
# without /sys/class/net, such as jailed shells on shared hosting.
#
# ----------------------------------------------------------- 
# shellcheck source=lib/drsm_plugin.sh
source "${DRSM_LIB:-$(dirname "$0")/../../../lib}/drsm_plugin.sh"

NICS=$(drsm_setting NICS "")
DROPPEDMAX=$(drsm_setting MAX_DROPPED 1000)
COLLMAX=$(drsm_setting MAX_COLLISIONS 100)
MAXERRORS=$(drsm_setting MAX_ERRORS 100)
retry_wait=$(drsm_setting SAMPLE_SECS 5)

USE_PROC="no"
if [ ! -d /sys/class/net ] && [ -r /proc/net/dev ]; then USE_PROC="yes"; fi

function skip_nic() {
    case "${1}" in
	lo|virbr*|macvtap*|veth*|docker*|br-*|cni*|flannel*|cali*|vnet*|tap*) return 0 ;;
    esac
    return 1
}

if drsm_is_none "${NICS}"; then
    # All interfaces that are up, skipping loopback and virtual
    # bridge, container, and VM tap devices
    NICS=""
    if [ "${USE_PROC}" == "yes" ]; then
	# No link state in /proc/net/dev, so take every listed interface
	for n in $(awk -F: 'NR > 2 { gsub(/ /, "", $1); print $1 }' /proc/net/dev)
	do
	    if ! skip_nic "${n}"; then NICS="${NICS} ${n}"; fi
	done
    else
	for d in /sys/class/net/*
	do
	    n=$(basename "${d}")
	    if skip_nic "${n}"; then continue; fi
	    if [ "$(cat "${d}/operstate" 2> /dev/null)" == "up" ]; then NICS="${NICS} ${n}"; fi
	done
    fi
fi

IP="ip"
if [ -x /usr/sbin/ip ]; then IP="/usr/sbin/ip"; elif [ -x /sbin/ip ]; then IP="/sbin/ip"; fi

# /proc/net/dev fields after "name:": rx bytes packets errs drop fifo
# frame compressed multicast, then tx bytes packets errs drop fifo colls
function nicstat() {
    if [ "${USE_PROC}" == "yes" ]; then
	local f
	case "${2}" in
	    rx_bytes) f=1 ;; rx_errors) f=3 ;; rx_dropped) f=4 ;;
	    tx_bytes) f=9 ;; tx_errors) f=11 ;; tx_dropped) f=12 ;; collisions) f=14 ;;
	    *) echo 0; return ;;
	esac
	awk -F: -v n="${1}" -v f="${f}" '{ i = $1; gsub(/ /, "", i) } i == n { split($2, v, " "); print v[f] + 0; found = 1 } END { if (!found) print 0 }' /proc/net/dev
    else
	cat "/sys/class/net/${1}/statistics/${2}" 2> /dev/null || echo 0
    fi
}

function nic_exists() {
    if [ "${USE_PROC}" == "yes" ]; then
	awk -F: -v n="${1}" '{ i = $1; gsub(/ /, "", i) } i == n { found = 1 } END { exit !found }' /proc/net/dev
    else
	[ -d "/sys/class/net/${1}" ]
    fi
}

UPTIME=$(uptime -p 2> /dev/null || uptime)

declare -A start
for n in ${NICS}
do
    if ! nic_exists "${n}"; then
	drsm_warn "${HOST} network interface ${n} not found"
	continue
    fi
    for c in rx_errors tx_errors rx_dropped tx_dropped collisions; do
	start[${n}_${c}]=$(nicstat "${n}" ${c})
    done
done

if [ "$(echo ${NICS})" == "" ]; then
    drsm_warn "${HOST} no network interfaces found to check"
fi

sleep "${retry_wait}"

for n in ${NICS}
do
    if ! nic_exists "${n}"; then continue; fi
    ETH="${n}"
    IPADDR=$(${IP} -o -4 addr show dev "${ETH}" 2> /dev/null | awk '{ print $4 }' | tr '\n' ' ')
    DESCRIPTION="${IPADDR}NIC"

    RXBYTES=$(nicstat "${n}" rx_bytes)
    TXBYTES=$(nicstat "${n}" tx_bytes)
    RXERRORS=$(( $(nicstat "${n}" rx_errors) - ${start[${n}_rx_errors]} ))
    TXERRORS=$(( $(nicstat "${n}" tx_errors) - ${start[${n}_tx_errors]} ))
    RXDROPPED=$(( $(nicstat "${n}" rx_dropped) - ${start[${n}_rx_dropped]} ))
    TXDROPPED=$(( $(nicstat "${n}" tx_dropped) - ${start[${n}_tx_dropped]} ))
    COLLISIONS=$(( $(nicstat "${n}" collisions) - ${start[${n}_collisions]} ))

    if [ ${RXERRORS} -gt "${MAXERRORS}" ] || [ ${TXERRORS} -gt "${MAXERRORS}" ]
    then
	drsm_crit "${HOST} ${ETH} ${DESCRIPTION} has errors"
	echo "${HOST} ${ETH} errors per ${retry_wait} secs: RX=${RXERRORS} TX=${TXERRORS}"
    fi

    if [ ${RXDROPPED} -gt "${DROPPEDMAX}" ] || [ ${TXDROPPED} -gt "${DROPPEDMAX}" ] || [ ${COLLISIONS} -gt "${COLLMAX}" ]
    then
	drsm_warn "${HOST} ${ETH} ${DESCRIPTION} has packet loss"
	echo "${HOST} ${ETH} dropped per ${retry_wait} secs: RX=${RXDROPPED} TX=${TXDROPPED}"
	echo "${HOST} ${ETH} collisions per ${retry_wait} secs: ${COLLISIONS}"
    fi

    echo "${HOST} ${ETH} ${DESCRIPTION} stats"
    echo "${ETH} - Uptime:  ${UPTIME}"
    echo "${ETH} - RX Bytes: ${RXBYTES}"
    echo "${ETH} - TX Bytes: ${TXBYTES}"
    echo "${ETH} - RX/TX errors total: $(nicstat "${n}" rx_errors)/$(nicstat "${n}" tx_errors)"
    echo "${ETH} - RX/TX dropped total: $(nicstat "${n}" rx_dropped)/$(nicstat "${n}" tx_dropped)"
    drsm_metric nic_rx_bytes "${RXBYTES}" "nic=\"${ETH}\""
    drsm_metric nic_tx_bytes "${TXBYTES}" "nic=\"${ETH}\""
done

drsm_exit
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
