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
# Version control: 1.14
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
SWAPALERT=1024
NUMPROCS=100

if [ "${1}" != "" ]; then ALERT=$1; fi
if [ "${2}" != "" ]; then SWAPALERT=$2; fi
if [ "${3}" != "" ]; then NUMPROCS=$3; fi

HOST=$(hostname -s)
has_error="0"
has_warning="0"

# Read a /proc/meminfo value in MB
function meminfo() { awk -v k="$1:" '$1 == k { printf "%d", $2 / 1024; f=1 } END { if (!f) print 0 }' /proc/meminfo; }

total_physical=$(meminfo MemTotal)
free_physical=$(meminfo MemFree)
buffers=$(meminfo Buffers)
cache=$(( $(meminfo Cached) + $(meminfo SReclaimable) ))
# MemAvailable is the kernel's estimate of memory available to start
# new programs without swapping, it accounts for cache that cannot be
# reclaimed
MemAvailable=$(meminfo MemAvailable)
if [ ${MemAvailable} -eq 0 ]; then MemAvailable=$((free_physical + buffers + cache)); fi
used_physical=$((total_physical - MemAvailable))
total_swap=$(meminfo SwapTotal)
free_swap=$(meminfo SwapFree)
used_swap=$((total_swap - free_swap))
free=$((MemAvailable + free_swap))

# Get our top processes
PROCS=$(ps -eo %mem,pid,user,args --sort=-%mem | sed '1d' | grep -v "^ *0.0 " | head -n $NUMPROCS)

if [ ${MemAvailable} -le ${ALERT} ] 
then
    echo "ERROR - ${HOST} available memory ${MemAvailable} MB is at or below ${ALERT} MB"
    has_error="1"
fi

# Only warn when swap use is high and more than the memory still
# available, idle pages swapped out on a healthy host are normal
if [ ${used_swap} -ge ${SWAPALERT} ] && [ ${used_swap} -gt ${MemAvailable} ]
then
    echo "WARNING - ${HOST} is using ${used_swap} MB of SWAP space"
    has_warning="1"
fi

echo "Memory stats for ${HOST}"
echo "Total physical: ${total_physical} MB"
echo "Used physical:  ${used_physical} MB"
echo "Free physical:  ${free_physical} MB"
echo "Buffers:  ${buffers} MB"
echo "Cache:  ${cache} MB"
echo "Physical Memory Available: ${MemAvailable} MB"
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
