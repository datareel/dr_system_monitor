#!/bin/bash
# ----------------------------------------------------------- 
# BASH Script
# Operating System(s): RHEL/CENTOS
# Run Level(s): 3, 5
# Shell: BASH shell
# Original Author(s): DataReel Software Development
# File Creation Date: 05/25/2013
# Date Last Modified: 02/20/2018
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
# System monitoring script for disk space 
#
# ----------------------------------------------------------- 
SKIPDIRS=""
ALERT=90
MAX=99
HOST=$(hostname -s)
has_error="0"
has_warning="0"

echo "Disk usage checks for ${HOST}"

if [ "${1}" != "" ]; then SKIPDIRS="${1}"; fi
if [ "${2}" != "" ]; then ALERT="${2}"; fi
if [ "${3}" != "" ]; then MAX="${3}"; fi

while read line
do
    DATLINE=$(echo $line | grep -v "^#")
    if [ "${DATLINE}" != "" ]; then
	FSTYPE=$(echo "${DATLINE}" | awk '{ print $3 }')
	DIR=$(echo "${DATLINE}" | awk '{ print $2 }')
	if [ "${FSTYPE}" == "xfs" ] || [ "${FSTYPE}" == "ext4" ] || [ "${FSTYPE}" == "ext3" ] || [ "${FSTYPE}" == "ext2" ]; then
	    for d in ${SKIPDIRS}
	    do
		if [ "${DIR}" == "${d}" ]; then
		    echo "Skipping DIR check on ${d}"
		    continue
		fi
	    done
	    DISKSPACE=$(df -HP ${DIR} | sed '1d' | awk '{print $5}' | cut -d'%' -f1)
	    if [ ${DISKSPACE} -ge ${ALERT} ] 
	    then
		if [ ${DISKSPACE} -ge ${MAX} ]
		then
		    echo "ERROR - ${HOST}:${DIR} is fill at ${DISKSPACE}% capacity."
		    has_error="1"
		else
		    echo "WARNING - ${HOST}:${DIR} is at ${DISKSPACE}% capacity."
		    has_warning="1"
		fi
	    else 
		echo "${HOST}:${DIR} checks good at ${DISKSPACE}% capacity."
	    fi
	fi
    fi
done < /etc/fstab

if [ -f ${HOME}/drsm/health_check_scripts/raid_check.sh ]; then
    echo ""
    rv=$(${HOME}/drsm/health_check_scripts/raid_check.sh)
    if [ $rv -eq 2 ]; then has_error=1; fi
    if [ $rv -eq 1 ]; then has_warning=1; fi
fi

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
