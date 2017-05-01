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
# System monitoring script for CPU usage
#
# ----------------------------------------------------------- 
THRESHOLD=85
MAX=95
NUMPROCS=100

if [ "${1}" != "" ]; then THRESHOLD=$1; fi
if [ "${2}" != "" ]; then MAX=$2; fi
if [ "${3}" != "" ]; then NUMPROCS=$3; fi

HOST=$(hostname -s)
has_error="0"
has_warning="0"

# Get the number of CPUs 
num_cpus=$(cat /proc/cpuinfo | grep 'processor' | wc -l)

# Calculate our total usage for all CPUs
prev_total=0
prev_idle=0
cpu=$(cat /proc/stat | grep "^cpu " | sed s/'cpu  '//)
user=`echo $cpu | awk '{print $1}'`
system=`echo $cpu | awk '{print $2}'`
nice=`echo $cpu | awk '{print $3}'`
idle=`echo $cpu | awk '{print $4}'`
wait=`echo $cpu | awk '{print $5}'`
irq=`echo $cpu | awk '{print $6}'`
srq=`echo $cpu | awk '{print $7}'`
zero=`echo $cpu | awk '{print $8}'`
total=$(($user+$system+$nice+$idle+$wait+$irq+$srq+$zero))
diff_idle=$(($idle-$prev_idle))
diff_total=$(($total-$prev_total))
cpu_usage=$(($((1000*$(($diff_total-$diff_idle))/$diff_total+5))/10))
# Use /proc/stat for total average instead of TOP
##cpu_usage=$(top -b -n 1  | awk -F'[:,]' '/^Cpu/{sub("\\..*","",$2); print $2}' | sed s/' '//g)

# Get our top processes
PROCS=$(ps -eo "%cpu,%mem,etime,args" | grep -v '%CPU' | grep -v " 0.0  0.0 " | sort -rn -k 1 | head -n $NUMPROCS)

if [ ${cpu_usage} -gt ${MAX} ] 
then
    echo "ERROR - ${HOST} total CPU usage is above ${MAX}%"
    has_error="1"
fi

if [ ${cpu_usage} -gt ${THRESHOLD} ] 
then
    echo "WARNING - ${HOST} total CPU usage is above ${THRESHOLD}%"
    has_warning="1"
fi

echo "Total CPU stats for ${HOST}"
echo "Total CPUs: ${num_cpus}"
for (( i=0 ; i < "${num_cpus}" ; i=i+1 )); do
    prev_total=0
    prev_idle=0
    cpu=$(cat /proc/stat | grep "cpu${i}" | sed s/cpu${i}//)
    user=`echo $cpu | awk '{print $1}'`
    system=`echo $cpu | awk '{print $2}'`
    nice=`echo $cpu | awk '{print $3}'`
    idle=`echo $cpu | awk '{print $4}'`
    wait=`echo $cpu | awk '{print $5}'`
    irq=`echo $cpu | awk '{print $6}'`
    srq=`echo $cpu | awk '{print $7}'`
    zero=`echo $cpu | awk '{print $8}'`
    total=$(($user+$system+$nice+$idle+$wait+$irq+$srq+$zero))
    diff_idle=$(($idle-$prev_idle))
    diff_total=$(($total-$prev_total))
    usage=$(($((1000*$(($diff_total-$diff_idle))/$diff_total+5))/10))
    echo "CPU $i usage: $usage%"
    prev_total=$total
    prev_idle=$idle
done

echo "Total usage: ${cpu_usage}%"
echo "Process usage:"
echo ' %CPU %MEM     ELAPSED COMMAND'
echo "${PROCS}"


## NOTE: On servers you must install the lm_sensors package and run sensors-detect
## # yum -y install lm_sensors
## # sensors-detect 
## Answer YES to all propmts

if [ -e /usr/bin/sensors ] && [ -e /etc/sysconfig/lm_sensors ]
then
    echo ""

    temps=$(sensors | grep "Core [0-9]" | sed s/' '//g | sed s/'°C'//g | sed s/'(high='/,/g | sed s/'crit='//g | sed s/')'//g | sed s/'+'//g)
    
    for t in ${temps}
    do
	core=$(echo "${t}" | awk -F: '{ print $1 }')
	templine=$(echo "${t}" | awk -F: '{ print $2 }')
	acutal=$(echo "${templine}" | awk -F, '{ print $1 }')
	acutal=$(echo "${acutal}" | awk -F. '{ print $1 }')
	high=$(echo "${templine}" | awk -F, '{ print $2 }')
	high=$(echo "${high}" | awk -F. '{ print $1 }')
	crit=$(echo "${templine}" | awk -F, '{ print $3 }')
	crit=$(echo "${crit}" | awk -F. '{ print $1 }')
	
	if [ $acutal -ge $crit ]
	then
	    echo "ERROR - ${core} is at or above critical tempature: actual_temp=${acutal}°C high_temp=${high}°C crit_temp=${crit}°C" 
	    has_error="1"
	    continue
	fi
	
	
	if [ $acutal -ge $high ] && [ $acutal -lt $crit ]
	then
	    echo "WARNING - ${core} is at or above high tempature: actual_temp=${acutal}°C high_temp=${high}°C crit_temp=${crit}°C" 
	    has_warning="1"
	    continue
	fi
	
	echo "INFO - ${core} tempature: actual_temp=${acutal}°C high_temp=${high}°C crit_temp=${crit}°C" 
    done
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
