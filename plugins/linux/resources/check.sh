#!/bin/bash
# ----------------------------------------------------------- 
# BASH Script
# Operating System(s): RHEL/CENTOS
# Run Level(s): 3, 5
# Shell: BASH shell
# Original Author(s): DataReel Software Development
# File Creation Date: 10/29/2026
# Date Last Modified: 10/29/2026
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
#
# DRSM plugin: CPU, load, memory, swap, disk space and network use from
# the PERFORMANCE, DISK USAGE and NETWORK sections of the last DataReel
# Reporting Agent for Linux report. The metrics use the names of the
# core and storage plugins, so agent hosts get the same gauges and
# trends as hosts DRSM checks over SSH. Network counters are totals
# since the interface came up; the trends page turns the change between
# reports into rates, timed by the report (sample_etime).
#
# ----------------------------------------------------------- 
# shellcheck source=lib/drsm_plugin.sh
source "${DRSM_LIB:-$(dirname "$0")/../../../lib}/drsm_plugin.sh"
# shellcheck source=plugins/linux/lra_report.sh
source "$(dirname "$0")/../lra_report.sh"

CPU_WARN=$(drsm_setting CPU_WARN 85)
CPU_CRIT=$(drsm_setting CPU_CRIT 95)
LOAD_WARN_PER_CPU=$(drsm_setting LOAD_WARN_PER_CPU 2)
MIN_AVAIL_MB=$(drsm_setting MIN_AVAIL_MB 256)
SWAP_WARN=$(drsm_setting SWAP_WARN 80)
DISK_WARN=$(drsm_setting DISK_WARN 90)
DISK_CRIT=$(drsm_setting DISK_CRIT 99)
INODE_WARN=$(drsm_setting INODE_WARN 90)
DISK_SKIP=$(drsm_setting DISK_SKIP "")
UPTIME_WARN_DAYS=$(drsm_setting UPTIME_WARN_DAYS 0)
MAX_AGE_HOURS=$(drsm_setting MAX_AGE_HOURS 2)
if drsm_is_none "${DISK_SKIP}"; then DISK_SKIP=""; fi

lra_load_report || drsm_exit
etime=$(lra_field ETIME "${REPORT}")
if [[ ! "${etime}" =~ ^[0-9]+$ ]]; then
    drsm_unknown "${LRA_HOST} report has no time stamp, see linux/checkin"
    drsm_exit
fi
age=$(( $(date +%s) - etime ))
if [ ${age} -gt $((MAX_AGE_HOURS * 3600)) ]; then
    drsm_info "${LRA_HOST} report is $((age / 3600)) hours old, resource use not checked, see linux/checkin"
    drsm_exit
fi

declare -A P
while IFS='=' read -r k v; do
    if [[ "${k}" =~ ^[a-z0-9_]+$ ]] && [[ "${v}" =~ ^-?[0-9.]+$ ]]; then P[${k}]="${v}"; fi
done < <(lra_section "PERFORMANCE" "${REPORT}")

function uptime_text()
{
    # Uptime as days, or hours under a day, $1 == seconds
    local s="${1%.*}"
    local n=$((s / 3600)) unit="hour"
    if [ "${s}" -ge 86400 ]; then n=$((s / 86400)); unit="day"; fi
    if [ ${n} -eq 1 ]; then echo "1 ${unit}"; else echo "${n} ${unit}s"; fi
}

summary="CPU ${P[cpu_used_pct]:-?}%, load ${P[load_15]:-?}, memory ${P[mem_used_pct]:-?}% used"
root_pct=$(lra_section "DISK USAGE" "${REPORT}" | lra_kv mount used_pct | awk -F'\t' '$1 == "/" { print $2 }')
if [ "${root_pct}" != "" ]; then summary="${summary}, / ${root_pct}%"; fi
if [ "${P[uptime_seconds]}" != "" ]; then summary="${summary}, up $(uptime_text "${P[uptime_seconds]}")"; fi
echo "${summary}"
if [ "${P[cpu_count]}" != "" ] && [ "${P[mem_total_mb]}" != "" ]; then
    drsm_detail "Hardware size" "${P[cpu_count]} CPUs, $(awk -v m="${P[mem_total_mb]}" 'BEGIN { printf "%.1f", m / 1024 }') GB memory"
fi
if [ "${P[uptime_seconds]}" != "" ]; then
    drsm_detail "Up since" "$(date -d "@$((etime - ${P[uptime_seconds]%.*}))" '+%Y-%m-%d %H:%M'), $(uptime_text "${P[uptime_seconds]}")"
fi

# CPU, sampled when the report was written
if [ "${P[cpu_used_pct]}" != "" ]; then
    echo "CPU: ${P[cpu_used_pct]}% used, iowait ${P[cpu_iowait_pct]:-?}%, steal ${P[cpu_steal_pct]:-?}%, ${P[cpu_count]:-?} CPUs, sampled over ${P[cpu_sample_seconds]:-?} seconds"
    if drsm_gt "${P[cpu_used_pct]}" "${CPU_CRIT}"; then
	drsm_crit "${LRA_HOST} CPU usage is ${P[cpu_used_pct]}%"
    elif drsm_gt "${P[cpu_used_pct]}" "${CPU_WARN}"; then
	drsm_warn "${LRA_HOST} CPU usage is ${P[cpu_used_pct]}%"
    fi
    drsm_metric cpu_used_pct "${P[cpu_used_pct]}"
    if [ "${P[cpu_steal_pct]}" != "" ]; then drsm_metric cpu_steal_pct "${P[cpu_steal_pct]}"; fi
    if [ "${P[cpu_iowait_pct]}" != "" ]; then drsm_metric cpu_iowait_pct "${P[cpu_iowait_pct]}"; fi
fi
if [ "${P[cpu_count]}" != "" ]; then drsm_metric cpu_count "${P[cpu_count]}"; fi

# Load average against the CPU count
if [ "${P[load_15]}" != "" ]; then
    echo "Load: ${P[load_1]:-?} ${P[load_5]:-?} ${P[load_15]}"
    limit=$(awk -v c="${P[cpu_count]:-1}" -v p="${LOAD_WARN_PER_CPU}" 'BEGIN { print c * p }')
    if drsm_gt "${P[load_15]}" "${limit}"; then
	drsm_warn "${LRA_HOST} 15 minute load average ${P[load_15]} is over ${limit} (${LOAD_WARN_PER_CPU} per CPU)"
    fi
    drsm_metric load_15m "${P[load_15]}"
fi

# Memory and swap
if [ "${P[mem_available_mb]}" != "" ]; then
    echo "Memory: ${P[mem_available_mb]} MB available of ${P[mem_total_mb]:-?} MB, ${P[mem_used_pct]:-?}% used"
    if [ "${P[mem_available_mb]%.*}" -le "${MIN_AVAIL_MB}" ]; then
	drsm_crit "${LRA_HOST} available memory ${P[mem_available_mb]} MB is at or below ${MIN_AVAIL_MB} MB"
    fi
    drsm_metric mem_available_mb "${P[mem_available_mb]}"
fi
if [ "${P[mem_total_mb]}" != "" ]; then drsm_metric mem_total_mb "${P[mem_total_mb]}"; fi
if [ "${P[swap_total_mb]:-0}" != "0" ]; then
    echo "Swap: ${P[swap_used_mb]:-?} MB used of ${P[swap_total_mb]} MB, ${P[swap_used_pct]:-?}%"
    if drsm_gt "${P[swap_used_pct]:-0}" "${SWAP_WARN}"; then
	drsm_warn "${LRA_HOST} swap is ${P[swap_used_pct]}% used"
    fi
    drsm_metric swap_used_mb "${P[swap_used_mb]:-0}"
    drsm_metric swap_total_mb "${P[swap_total_mb]}"
fi
if [ "${P[process_count]}" != "" ]; then
    echo "Processes: ${P[process_count]}"
    drsm_metric process_count "${P[process_count]}"
fi
if [ "${P[uptime_seconds]}" != "" ]; then
    up_days=$(( ${P[uptime_seconds]%.*} / 86400 ))
    echo "Up $(uptime_text "${P[uptime_seconds]}")"
    if [ "${UPTIME_WARN_DAYS}" -gt 0 ] && [ ${up_days} -ge "${UPTIME_WARN_DAYS}" ]; then
	drsm_warn "${LRA_HOST} has not restarted for ${up_days} days, updates may be waiting for a restart"
    fi
    drsm_metric uptime_seconds "${P[uptime_seconds]}"
fi

# Disk space and inodes, one line per local file system
while IFS=$'\t' read -r mnt fstype size used pct ipct; do
    [ "${mnt}" == "" ] && continue
    if [[ " ${DISK_SKIP} " == *" ${mnt} "* ]]; then continue; fi
    echo "${mnt} (${fstype}) ${pct}% used, ${used} MB of ${size} MB${ipct:+, inodes ${ipct}%}"
    if drsm_gt "${pct}" "${DISK_CRIT}"; then
	drsm_crit "${LRA_HOST}:${mnt} is at ${pct}% capacity."
    elif drsm_gt "${pct}" "${DISK_WARN}"; then
	drsm_warn "${LRA_HOST}:${mnt} is at ${pct}% capacity."
    fi
    if [ "${ipct}" != "" ] && drsm_gt "${ipct}" "${INODE_WARN}"; then
	drsm_warn "${LRA_HOST}:${mnt} has used ${ipct}% of its inodes."
    fi
    lbl="mount=\"${mnt//\"/}\""
    drsm_metric disk_used_pct "${pct}" "${lbl}"
    drsm_metric disk_used_mb "${used}" "${lbl}"
    drsm_metric disk_size_mb "${size}" "${lbl}"
done < <(lra_section "DISK USAGE" "${REPORT}" | lra_kv mount fstype size_mb used_mb used_pct inodes_used_pct)

# Network interfaces that are up
while IFS=$'\t' read -r nic speed rxb txb rxe txe rxd txd; do
    [ "${nic}" == "" ] && continue
    echo "Interface ${nic}: ${speed:-?} Mb/s, received ${rxb} bytes, sent ${txb} bytes, errors ${rxe}/${txe}, drops ${rxd}/${txd}"
    lbl="nic=\"${nic//\"/}\""
    drsm_metric nic_rx_bytes "${rxb}" "${lbl}"
    drsm_metric nic_tx_bytes "${txb}" "${lbl}"
    drsm_metric nic_rx_errors "${rxe}" "${lbl}"
    drsm_metric nic_tx_errors "${txe}" "${lbl}"
    drsm_metric nic_rx_discards "${rxd}" "${lbl}"
    drsm_metric nic_tx_discards "${txd}" "${lbl}"
done < <(lra_section "NETWORK" "${REPORT}" | lra_kv adapter speed_mbps rx_bytes tx_bytes rx_errors tx_errors rx_discards tx_discards)

if [ "${DRSM_HAS_ERROR}" == "0" ] && [ "${DRSM_HAS_WARNING}" == "0" ]; then
    drsm_ok "${LRA_HOST} resource use checks good"
fi
# When the counters were read, so rates use the time between reports
drsm_metric sample_etime "${etime}"
drsm_exit
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# *******************************
