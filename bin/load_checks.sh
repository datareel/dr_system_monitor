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
# System monitoring script for load average
#
# ----------------------------------------------------------- 
THRESHOLD=35
MAX=50
if [ "${1}" != "" ]; then THRESHOLD=$1; fi
if [ "${2}" != "" ]; then MAX=$2; fi

HOST=$(hostname -s)
has_error="0"
has_warning="0"
TRUE="1"

# 1 minute load average
LA1M=$(uptime | awk -F "load average:" '{ print $2 }' | cut -d, -f1 | sed s/' '//g)
# 5 min load average
LA5M=$(uptime | awk -F "load average:" '{ print $2 }' | cut -d, -f2 | sed s/' '//g)
# 15 min load average
LA15M=$(uptime | awk -F "load average:" '{ print $2 }' | cut -d, -f3 | sed s/' '//g)

RESULT=$(echo "$LA15M > $MAX" | bc)
if [ "$RESULT" == "$TRUE" ]
then
    echo "ERROR - ${HOST} 15 minute load average is above ${MAX}%"
    has_error="1"
fi

RESULT=$(echo "$LA15M > $THRESHOLD" | bc)
if [ "$RESULT" == "$TRUE" ]
then
    echo "WARNING - ${HOST} 15 minute load average is above ${THRESHOLD}%"
    has_error="1"
fi

echo "Load averages for ${HOST}"
echo "1 minute load:  ${LA1M}"
echo "5 minute load:  ${LA5M}"
echo "15 minute load: ${LA15M}" 

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
