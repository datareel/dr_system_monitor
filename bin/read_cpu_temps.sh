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
# Version control: 1.11
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
# NOTE: To read CPU temps install the lm_sensors (RHEL/Fedora) or
# lm-sensors (Debian/Ubuntu) package and run sensors-detect as root.
# Cloud VMs do not expose temperature sensors.
#
if ! command -v sensors &> /dev/null
then
    echo "INFO: Install the lm_sensors package if you want to monitor CPU temps"
    exit 0
fi

temps=$(sensors 2> /dev/null | awk '
    /^(Core [0-9]+|Package id [0-9]+|Tctl|Tdie):/ {
	split($0, a, ":"); label=a[1]; gsub(/ /, "_", label)
	n=0; delete v
	s=a[2]
	while (match(s, /[+-]?[0-9]+(\.[0-9]+)?°C/)) {
	    t=substr(s, RSTART, RLENGTH); gsub(/[+°C]/, "", t)
	    v[++n]=int(t); s=substr(s, RSTART+RLENGTH)
	}
	if (n >= 1) printf "%s,%d,%s,%s\n", label, v[1], (n>=2 ? v[2] : ""), (n>=3 ? v[3] : "")
    }')

if [ "${temps}" == "" ]
then
    echo "INFO: No CPU temperature sensors found, run sensors-detect as root to configure the system sensors"
    exit 0
fi

for t in ${temps}
do
    IFS=, read -r core actual high crit <<< "${t}"
    core="${core//_/ }"
    if [ "${crit}" != "" ] && [ ${actual} -ge ${crit} ]
    then
	echo "ERROR - $(hostname -s) ${core} is at or above critical temperature: actual_temp=${actual}°C high_temp=${high}°C crit_temp=${crit}°C" 
	continue
    fi

    if [ "${high}" != "" ] && [ ${actual} -ge ${high} ]
    then
	echo "WARNING - $(hostname -s) ${core} is at or above high temperature: actual_temp=${actual}°C high_temp=${high}°C crit_temp=${crit}°C" 
	continue
    fi
    
    echo "INFO - ${core} temperature: actual_temp=${actual}°C high_temp=${high}°C crit_temp=${crit}°C" 
done

exit 0
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
