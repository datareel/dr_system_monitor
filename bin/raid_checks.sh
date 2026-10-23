#!/bin/bash
# ----------------------------------------------------------- 
# BASH Script
# Operating System(s): RHEL/CENTOS
# Run Level(s): 3, 5
# Shell: BASH shell
# Original Author(s): DataReel Software Development
# File Creation Date: 02/20/2018
# Date Last Modified: 10/23/2026
#
# Version control: 1.05
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
# Check of local RAID controllers for drive failures.
#
# NOTE: This version checks Linux software RAID (mdadm) arrays
# and RAID contollers using the LSI chipset. The LSI check requires MegaCli utility to be
# installed. To setup MegaCli check the system to see if
# it has an LSI controller:
#
# dmesg | grep -i megaraid
# 
# If so install the MegaCli utiltiy, for example:
#
# dnf install ./MegaCli-8.07.14-1.noarch.rpm
#
# Your system admin account must have sudo rights 
# to run the MegaCli64 binary, for example:
#
# visudo
#
#  sysadmin ALL= NOPASSWD:/opt/MegaRAID/MegaCli/MegaCli64
# ----------------------------------------------------------- 
HOST=$(hostname -s)
has_error="0"
has_warning="0"

# Linux software RAID (mdadm) checks
MDSTAT="/proc/mdstat"
if [ "${MDSTAT_FILE}" != "" ]; then MDSTAT="${MDSTAT_FILE}"; fi
if [ -r ${MDSTAT} ] && grep -q '^md' ${MDSTAT}
then
    md=""
    while read -r line
    do
	if [[ "${line}" =~ ^(md[^[:space:]]+)[[:space:]]*:[[:space:]]*([a-z]+) ]]; then
	    md="${BASH_REMATCH[1]}"
	    state="${BASH_REMATCH[2]}"
	    if [ "${state}" == "inactive" ]; then
		echo "ERROR - ${HOST} software RAID ${md} is inactive"
		has_error="1"
	    fi
	    if [[ "${line}" == *"(F)"* ]]; then
		echo "ERROR - ${HOST} software RAID ${md} has a failed member: ${line}"
		has_error="1"
	    fi
	    continue
	fi
	if [ "${md}" == "" ]; then continue; fi
	# Member status, for example [UU] is healthy and [U_] is degraded
	if [[ "${line}" =~ \[([U_]+)\][[:space:]]*$ ]]; then
	    members="${BASH_REMATCH[1]}"
	    if [[ "${members}" == *_* ]]; then
		echo "ERROR - ${HOST} software RAID ${md} is degraded [${members}]"
		has_error="1"
	    else
		echo "INFO - ${HOST} software RAID ${md} checks good [${members}]"
	    fi
	fi
	if [[ "${line}" =~ (recovery|resync|reshape)[[:space:]]*=[[:space:]]*([0-9.]+%) ]]; then
	    echo "WARNING - ${HOST} software RAID ${md} ${BASH_REMATCH[1]} in progress ${BASH_REMATCH[2]}"
	    has_warning="1"
	fi
    done < ${MDSTAT}
fi

function raid_exit()
{
    if [ "${has_error}" == "1" ]; then exit 2; fi
    if [ "${has_warning}" == "1" ]; then exit 1; fi
    exit 0
}

# Check for LSI RAID contollers bound to the megaraid driver
if ! ls -d /sys/bus/pci/drivers/*megaraid*/0000:* &> /dev/null; then
    echo "INFO: This system does not have LSI RAID controller hardware installed"
    raid_exit
fi

MEGACLI="/opt/MegaRAID/MegaCli/MegaCli64"
if [ ! -f ${MEGACLI} ]; then
    echo "INFO: This system has LSI RAID hardware but does not have the MegaRAID utility installed"
    raid_exit
fi

if ! sudo -n -l ${MEGACLI} &> /dev/null; then
    echo "INFO: Our system admin account does not sudo rights to run the MegaRAID utility"
    raid_exit
fi

PDLIST=$(sudo -n ${MEGACLI} -PdList -aAll)
if echo "${PDLIST}" | grep -i 'Firmware state: Failed' ; then
    echo "ERROR - ${HOST} One or more hard drives have failed in RAID array"
    echo "ERROR - ${HOST} For more info run: ${MEGACLI} -PdList -aAll"
    has_error="1"
else
    has_drive_warning=0
    for count in $(echo "${PDLIST}" | grep 'Predictive Failure Count' | awk -F: '{ print $2 }')
    do
	if [[ "${count}" =~ ^[0-9]+$ ]] && [ ${count} -ne 0 ]; then
	    has_drive_warning=1
	fi
    done
    if [ ${has_drive_warning} -ne 0 ]; then
	echo "WARNING - ${HOST} One or more hard drives predictive failure"
	has_warning="1"
    else
	echo "INFO - All drives RAID drives check good" 
    fi
fi

raid_exit
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
