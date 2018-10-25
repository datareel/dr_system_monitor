#!/bin/bash
# ----------------------------------------------------------- 
# BASH Script
# Operating System(s): RHEL/CENTOS
# Run Level(s): 3, 5
# Shell: BASH shell
# Original Author(s): DataReel Software Development
# File Creation Date: 05/25/2013
# Date Last Modified: 10/25/2018
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
# System monitoring CPU temps 
#
# NOTE: On servers you must install the lm_sensors package 
# and run sensors-detect:
#
# yum -y install lm_sensors
# sensors-detect 
#
# Answer YES to all propmts
#
# ----------------------------------------------------------- 
if [ ! -e /usr/bin/sensors ]
then
    echo "INFO: Install the lm_sensors package if you want to monitor CPU temps"
    exit 0
fi

if [ ! -e /etc/sysconfig/lm_sensors ]
then
    echo "INFO: You must run sensors-detect as root to configure the system sensors"
    exit 0
fi

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
	echo "ERROR - $(hostname) ${core} is at or above critical tempature: actual_temp=${acutal}°C high_temp=${high}°C crit_temp=${crit}°C" 
	continue
    fi


    if [ $acutal -ge $high ] && [ $acutal -lt $crit ]
    then
	echo "WARNING - $(hostname) ${core} is at or above high tempature: actual_temp=${acutal}°C high_temp=${high}°C crit_temp=${crit}°C" 
	continue
    fi
    
    echo "INFO - ${core} tempature: actual_temp=${acutal}°C high_temp=${high}°C crit_temp=${crit}°C" 

done

exit 0
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
