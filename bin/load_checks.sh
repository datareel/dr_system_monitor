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
# System monitoring script for load average
#
# ----------------------------------------------------------- 
# By default the alert levels scale with the number of CPUs, a
# warning at 2x and an error at 4x the CPU count. Pass explicit
# levels to override.
NUMCPUS=$(nproc 2> /dev/null || grep -c '^processor' /proc/cpuinfo)
THRESHOLD=$((NUMCPUS * 2))
MAX=$((NUMCPUS * 4))
if [ "${1}" != "" ]; then THRESHOLD=$1; fi
if [ "${2}" != "" ]; then MAX=$2; fi

HOST=$(hostname -s)
has_error="0"
has_warning="0"

# 1, 5, and 15 minute load averages
read -r LA1M LA5M LA15M rest < /proc/loadavg

# Compare as floating point numbers with awk, bc is not installed on
# many minimal and cloud images
function gt() { awk -v a="$1" -v b="$2" 'BEGIN { exit !(a > b) }'; }

if gt "${LA15M}" "${MAX}"
then
    echo "ERROR - ${HOST} 15 minute load average ${LA15M} is above ${MAX}"
    has_error="1"
elif gt "${LA15M}" "${THRESHOLD}"
then
    echo "WARNING - ${HOST} 15 minute load average ${LA15M} is above ${THRESHOLD}"
    has_warning="1"
fi

echo "Load averages for ${HOST}"
echo "Number of CPUs: ${NUMCPUS}"
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
