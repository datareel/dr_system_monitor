#!/bin/bash
# ----------------------------------------------------------- 
# BASH Script
# Operating System(s): RHEL/CENTOS
# Run Level(s): 3, 5
# Shell: BASH shell
# Original Author(s): DataReel Software Development
# File Creation Date: 10/23/2026
# Date Last Modified: 10/23/2026
#
# Version control: 1.00
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
# DRSM plugin: RAID state, ported from bin/raid_checks.sh.
# The LSI check needs the MegaCli utility and a sudo rule for the
# system admin account, for example:
#  sysadmin ALL= NOPASSWD:/opt/MegaRAID/MegaCli/MegaCli64
#
# ----------------------------------------------------------- 
# shellcheck source=lib/drsm_plugin.sh
source "${DRSM_LIB:-$(dirname "$0")/../../../lib}/drsm_plugin.sh"

MDSTAT=$(drsm_setting MDSTAT_FILE /proc/mdstat)
MEGACLI=$(drsm_setting MEGACLI /opt/MegaRAID/MegaCli/MegaCli64)

# Linux software RAID (mdadm) checks
if [ -r "${MDSTAT}" ] && grep -q '^md' "${MDSTAT}"
then
    md=""
    while read -r line
    do
	if [[ "${line}" =~ ^(md[^[:space:]]+)[[:space:]]*:[[:space:]]*([a-z]+) ]]; then
	    md="${BASH_REMATCH[1]}"
	    state="${BASH_REMATCH[2]}"
	    if [ "${state}" == "inactive" ]; then
		drsm_crit "${HOST} software RAID ${md} is inactive"
	    fi
	    if [[ "${line}" == *"(F)"* ]]; then
		drsm_crit "${HOST} software RAID ${md} has a failed member: ${line}"
	    fi
	    continue
	fi
	if [ "${md}" == "" ]; then continue; fi
	# Member status, for example [UU] is healthy and [U_] is degraded
	if [[ "${line}" =~ \[([U_]+)\][[:space:]]*$ ]]; then
	    members="${BASH_REMATCH[1]}"
	    if [[ "${members}" == *_* ]]; then
		drsm_crit "${HOST} software RAID ${md} is degraded [${members}]"
	    else
		drsm_info "${HOST} software RAID ${md} checks good [${members}]"
	    fi
	fi
	if [[ "${line}" =~ (recovery|resync|reshape)[[:space:]]*=[[:space:]]*([0-9.]+%) ]]; then
	    drsm_warn "${HOST} software RAID ${md} ${BASH_REMATCH[1]} in progress ${BASH_REMATCH[2]}"
	fi
    done < "${MDSTAT}"
else
    echo "INFO: This system does not have Linux software RAID arrays"
fi

# Check for LSI RAID controllers bound to the megaraid driver
if ! ls -d /sys/bus/pci/drivers/*megaraid*/0000:* &> /dev/null; then
    echo "INFO: This system does not have LSI RAID controller hardware installed"
    drsm_exit
fi

if [ ! -f "${MEGACLI}" ]; then
    echo "INFO: This system has LSI RAID hardware but does not have the MegaRAID utility installed"
    drsm_exit
fi

if ! sudo -n -l "${MEGACLI}" &> /dev/null; then
    echo "INFO: Our system admin account does not have sudo rights to run the MegaRAID utility"
    drsm_exit
fi

PDLIST=$(sudo -n "${MEGACLI}" -PdList -aAll)
if echo "${PDLIST}" | grep -i 'Firmware state: Failed'; then
    drsm_crit "${HOST} One or more hard drives have failed in RAID array"
    drsm_crit "${HOST} For more info run: ${MEGACLI} -PdList -aAll"
else
    has_drive_warning=0
    for count in $(echo "${PDLIST}" | grep 'Predictive Failure Count' | awk -F: '{ print $2 }')
    do
	if [[ "${count}" =~ ^[0-9]+$ ]] && [ "${count}" -ne 0 ]; then
	    has_drive_warning=1
	fi
    done
    if [ ${has_drive_warning} -ne 0 ]; then
	drsm_warn "${HOST} One or more hard drives predictive failure"
    else
	drsm_info "All drives RAID drives check good"
    fi
fi

drsm_exit
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
