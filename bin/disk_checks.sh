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
# System monitoring script for disk space 
#
# ----------------------------------------------------------- 
DIRS="/boot / /var /tmp"
if [ "${1}" != "" ]; then DIRS="${1}"; fi

ALERT=90
MAX=99
HOST=$(hostname -s)
has_error="0"
has_warning="0"

echo "Disk usage checks for ${HOST}"

for d in ${DIRS}
do
    DISKSPACE=$(df -HP ${d} | sed '1d' | awk '{print $5}' | cut -d'%' -f1)
    if [ ${DISKSPACE} -ge ${ALERT} ] 
    then
	if [ ${DISKSPACE} -ge ${MAX} ]
	then
	    echo "ERROR - ${HOST}:${d} is fill at ${DISKSPACE}% capacity."
	    has_error="1"
	else
	    echo "WARNING - ${HOST}:${d} is at ${DISKSPACE}% capacity."
	    has_warning="1"
	fi
    else 
	echo "${HOST}:${d} checks good at ${DISKSPACE}% capacity."
    fi
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
