#!/bin/bash
# ----------------------------------------------------------- 
# BASH Script
# Operating System(s): RHEL/CENTOS
# Run Level(s): 3, 5
# Shell: BASH shell
# Original Author(s): DataReel Software Development
# File Creation Date: 10/23/2026
# Date Last Modified: 10/23/2026
#
# Version control: 1.00
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
# DRSM plugin: CPU usage, ported from bin/cpu_checks.sh
#
# ----------------------------------------------------------- 
# shellcheck source=lib/drsm_plugin.sh
source "${DRSM_LIB:-$(dirname "$0")/../../../lib}/drsm_plugin.sh"

THRESHOLD=$(drsm_setting WARN 85)
MAX=$(drsm_setting CRIT 95)
NUMPROCS=$(drsm_setting NUMPROCS 100)
SAMPLE_SECS=$(drsm_setting SAMPLE_SECS 2)
TEMPS=$(drsm_setting TEMPS yes)

num_cpus=$(grep -c '^cpu[0-9]' /proc/stat)

# /proc/stat counters are totals since boot, so take two samples and
# use the difference to get the current usage.
# Fields: user nice system idle iowait irq softirq steal
declare -A prev_total prev_idle prev_steal
while read -r name user nice system idle iowait irq softirq steal _
do
    prev_total[$name]=$((user+nice+system+idle+iowait+irq+softirq+steal))
    prev_idle[$name]=$((idle+iowait))
    prev_steal[$name]=${steal}
done < <(grep '^cpu' /proc/stat)

sleep "${SAMPLE_SECS}"

declare -A usage steal_pct
while read -r name user nice system idle iowait irq softirq steal _
do
    total=$((user+nice+system+idle+iowait+irq+softirq+steal))
    diff_total=$((total - ${prev_total[$name]:-0}))
    diff_idle=$((idle + iowait - ${prev_idle[$name]:-0}))
    diff_steal=$((steal - ${prev_steal[$name]:-0}))
    if [ ${diff_total} -le 0 ]; then diff_total=1; fi
    usage[$name]=$(( (1000 * (diff_total - diff_idle) / diff_total + 5) / 10 ))
    steal_pct[$name]=$(( (1000 * diff_steal / diff_total + 5) / 10 ))
done < <(grep '^cpu' /proc/stat)

cpu_usage=${usage[cpu]}

PROCS=$(ps -eo "%cpu,%mem,etime,args" --sort=-%cpu | sed '1d' | grep -v " 0.0  0.0 " | head -n "${NUMPROCS}")

if [ "${cpu_usage}" -gt "${MAX}" ]
then
    drsm_crit "${HOST} total CPU usage is above ${MAX}%"
elif [ "${cpu_usage}" -gt "${THRESHOLD}" ]
then
    drsm_warn "${HOST} total CPU usage is above ${THRESHOLD}%"
fi

echo "Total CPU stats for ${HOST}"
echo "Total CPUs: ${num_cpus}"
for (( i=0 ; i < num_cpus ; i=i+1 )); do
    if [ "${usage[cpu${i}]}" == "" ]; then continue; fi
    echo "CPU $i usage: ${usage[cpu${i}]}%"
done

echo "Total usage: ${cpu_usage}%"
# Steal time is CPU time taken by the hypervisor, mostly seen on cloud VMs
echo "Total steal: ${steal_pct[cpu]}%"
drsm_metric cpu_used_pct "${cpu_usage}"
drsm_metric cpu_steal_pct "${steal_pct[cpu]}"
echo "Process usage:"
echo ' %CPU %MEM     ELAPSED COMMAND'
echo "${PROCS}"

## NOTE: To include CPU temps install the lm_sensors (RHEL/Fedora) or
## lm-sensors (Debian/Ubuntu) package and run sensors-detect as root.
## Cloud VMs do not expose temperature sensors.
if [ "${TEMPS,,}" == "yes" ] && command -v sensors &> /dev/null
then
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

    if [ "${temps}" != "" ]; then echo ""; fi
    for t in ${temps}
    do
	IFS=, read -r core actual high crit <<< "${t}"
	core="${core//_/ }"
	if [ "${crit}" != "" ] && [ "${actual}" -ge "${crit}" ]
	then
	    drsm_crit "${HOST} ${core} is at or above critical temperature: actual_temp=${actual}°C high_temp=${high}°C crit_temp=${crit}°C"
	    continue
	fi

	if [ "${high}" != "" ] && [ "${actual}" -ge "${high}" ]
	then
	    drsm_warn "${HOST} ${core} is at or above high temperature: actual_temp=${actual}°C high_temp=${high}°C crit_temp=${crit}°C"
	    continue
	fi

	drsm_info "${core} temperature: actual_temp=${actual}°C high_temp=${high}°C crit_temp=${crit}°C"
    done
fi

drsm_exit
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
