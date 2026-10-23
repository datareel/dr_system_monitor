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
# Version control: 1.10
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
# System monitoring script for users
#
# ----------------------------------------------------------- 

BLACKLIST=""
WARNLIST=""
if [ "${1}" != "" ] && [ "${1^^}" != "NONE" ]; then BLACKLIST=$1; fi
if [ "${2}" != "" ] && [ "${2^^}" != "NONE" ]; then WARNLIST=$2; fi

HOST=$(hostname -s)
has_error="0"
has_warning="0"

# Unique list of logged in user names
LOGGEDIN=$(who 2> /dev/null | awk '{ print $1 }' | sort -u)

for u in ${BLACKLIST}
do
    if echo "${LOGGEDIN}" | grep -qx "${u}"
    then
	echo "ERROR - ${HOST} black listed user ${u} logged in"
	has_error="1"
    fi
done

for u in ${WARNLIST}
do
    if echo "${LOGGEDIN}" | grep -qx "${u}"
    then
	echo "WARNING - ${HOST} user ${u} logged in"
	has_warning="1"
    fi
done

echo "User information for ${HOST}"
NUM=$(who 2> /dev/null | wc -l)
echo "Number of user sessions logged in: ${NUM}"
w -h 2> /dev/null

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
