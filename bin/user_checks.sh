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
# System monitoring script for users
#
# ----------------------------------------------------------- 

BLACKLIST=""
WARNLIST=""
if [ "${1}" != "" ]; then BLACKLIST=$1; fi
if [ "${2}" != "" ]; then WARNLIST=$2; fi

HOST=$(hostname -s)
has_error="0"
has_warning="0"

for u in ${BLACKLIST}
do
    w | grep "${u}" &> /dev/null
    if [ "$?" == "0" ]
    then
	echo "ERROR - ${HOST} black listed user ${u} logged in"
	has_error="1"
    fi
done

for u in ${WARNLIST}
do
    w | grep "${u}" &> /dev/null
    if [ "$?" == "0" ]
    then
	echo "WARNING - ${HOST} user ${u} logged in"
	has_warning="1"
    fi
done

echo "User information for ${HOST}"
NUM=$(w | grep "load average:" | awk -F, '{ print $3 }')
echo "Number of users logged in:${NUM}"
w | grep -v "load average:"

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
