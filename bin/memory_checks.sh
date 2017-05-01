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
# System monitoring script for memory usage
#
# ----------------------------------------------------------- 

ALERT=256
SWAPALERT=256
NUMPROCS=100

if [ "${1}" != "" ]; then ALERT=$1; fi
if [ "${2}" != "" ]; then SWAPALERT=$2; fi
if [ "${3}" != "" ]; then NUMPROCS=$3; fi

HOST=$(hostname -s)
has_error="0"
has_warning="0"

total_physical=$(free -mt | grep Mem | awk '{print $2}')
used_physical=$(free -mt | grep Mem | awk '{print $3}')
free_physical=$(free -mt | grep Mem | awk '{print $4}')
total_swap=$(free -mt | grep Swap | awk '{print $2}')
used_swap=$(free -mt | grep Swap | awk '{print $3}')
free_swap=$(free -mt | grep Swap | awk '{print $4}')
free=$(free -mt | grep Total | awk '{print $4}')

# Get our top processes
PROCS=$(ps -eo %mem,pid,user,args | grep -v '%MEM' | grep -v " 0.0 " | sort -rn | head -n $NUMPROCS)

if [ $free -le $ALERT ] 
then
    echo "ERROR - ${HOST} total free memory is below ${free} MB"
    has_error="1"
fi

if [ $used_swap -ge $SWAPALERT ] 
then
    echo "WARNING - ${HOST} is using ${used_swap} MB of SWAP space"
    has_warning="1"
fi

echo "Memory stats for ${HOST}"
echo "Total physical: ${total_physical} MB"
echo "Used physical:  ${used_physical} MB"
echo "Free physical:  ${free_physical} MB"
echo "Total SWAP: ${total_swap} MB"
echo "Used SWAP:  ${used_swap} MB"
echo "Free SWAP:  ${free_swap} MB"
echo "Total free: ${free} MB"
echo "Process usage:"
echo ' %MEM   PID USER     COMMAND'
echo "${PROCS}"

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
