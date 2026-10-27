#!/bin/bash
# ----------------------------------------------------------- 
# BASH Script
# Operating System(s): RHEL/CENTOS
# Run Level(s): 3, 5
# Shell: BASH shell
# Original Author(s): DataReel Software Development
# File Creation Date: 10/26/2026
# Date Last Modified: 10/26/2026
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
# DRSM plugin: CPU, memory, disk space and network use from the
# PERFORMANCE, DISK USAGE and NETWORK sections of the last Windows
# Reporting Agent report (agent 3.3 and later). The metrics use the
# names of the Linux plugins, so Windows hosts get the same gauges and
# trends. Network counters are totals since the adapter came up; the
# trends page turns the change between reports into rates, timed by
# the report (sample_etime) because the agent and drsm_run.sh run on
# their own schedules.
#
# ----------------------------------------------------------- 
# shellcheck source=lib/drsm_plugin.sh
source "${DRSM_LIB:-$(dirname "$0")/../../../lib}/drsm_plugin.sh"
# shellcheck source=plugins/windows/wra_report.sh
source "$(dirname "$0")/../wra_report.sh"

CPU_WARN=$(drsm_setting CPU_WARN 85)
CPU_CRIT=$(drsm_setting CPU_CRIT 95)
MIN_AVAIL_MB=$(drsm_setting MIN_AVAIL_MB 256)
COMMIT_WARN=$(drsm_setting COMMIT_WARN 90)
DISK_WARN=$(drsm_setting DISK_WARN 90)
DISK_CRIT=$(drsm_setting DISK_CRIT 99)
DISK_SKIP=$(drsm_setting DISK_SKIP "")
UPTIME_WARN_DAYS=$(drsm_setting UPTIME_WARN_DAYS 0)
MAX_AGE_HOURS=$(drsm_setting MAX_AGE_HOURS 2)
if drsm_is_none "${DISK_SKIP}"; then DISK_SKIP=""; fi

wra_load_report || drsm_exit
if ! wra_has_section "PERFORMANCE" "${REPORT}"; then
    drsm_unknown "${WRA_HOST} report has no PERFORMANCE section, the agent needs version 3.3 or later"
    drsm_exit
fi

etime=$(wra_field ETIME "${REPORT}")
if [[ ! "${etime}" =~ ^[0-9]+$ ]]; then
    drsm_unknown "${WRA_HOST} report has no time stamp, see windows/checkin"
    drsm_exit
fi
age=$(( $(date +%s) - etime ))
if [ ${age} -gt $((MAX_AGE_HOURS * 3600)) ]; then
    drsm_info "${WRA_HOST} report is $((age / 3600)) hours old, resource use not checked, see windows/checkin"
    drsm_exit
fi

declare -A P
while IFS='=' read -r k v; do
    if [[ "${k}" =~ ^[a-z_]+$ ]] && [[ "${v}" =~ ^-?[0-9.]+$ ]]; then P[${k}]="${v}"; fi
done < <(wra_section "PERFORMANCE" "${REPORT}")

function uptime_text()
{
    # Uptime as days, or hours under a day, $1 == seconds
    local s="${1%.*}"
    local n=$((s / 3600)) unit="hour"
    if [ "${s}" -ge 86400 ]; then n=$((s / 86400)); unit="day"; fi
    if [ ${n} -eq 1 ]; then echo "1 ${unit}"; else echo "${n} ${unit}s"; fi
}
drives=$(wra_section "DISK USAGE" "${REPORT}" | sed -n 's/^drive=\([A-Za-z]:\).*used_pct=\([0-9.]*\).*/\1 \2%/p' | paste -sd ',' - | sed 's/,/, /g')
summary="CPU ${P[cpu_used_pct]:-?}%, memory ${P[mem_used_pct]:-?}% used"
if [ "${drives}" != "" ]; then summary="${summary}, ${drives}"; fi
if [ "${P[uptime_seconds]}" != "" ]; then summary="${summary}, up $(uptime_text "${P[uptime_seconds]}")"; fi
echo "${summary}"
if [ "${P[cpu_count]}" != "" ] && [ "${P[mem_total_mb]}" != "" ]; then
    drsm_detail "Hardware" "${P[cpu_count]} CPUs, $(awk -v m="${P[mem_total_mb]}" 'BEGIN { printf "%.1f", m / 1024 }') GB memory"
fi
if [ "${P[uptime_seconds]}" != "" ]; then
    drsm_detail "Up since" "$(date -d "@$((etime - ${P[uptime_seconds]%.*}))" '+%Y-%m-%d %H:%M'), $(uptime_text "${P[uptime_seconds]}")"
fi
sizes=$(wra_section "DISK USAGE" "${REPORT}" | sed -n 's/^drive=\([A-Za-z]:\) size_mb=\([0-9]*\).*/\1 \2/p' | awk '{ printf "%s%s %.0f GB", (NR > 1 ? ", " : ""), $1, $2 / 1024 }')
if [ "${sizes}" != "" ]; then drsm_detail "Drives" "${sizes}"; fi

# CPU, a 5 second sample taken when the report was written
if [ "${P[cpu_used_pct]}" != "" ]; then
    echo "CPU: ${P[cpu_used_pct]}% used, ${P[cpu_count]:-?} CPUs, sampled over ${P[cpu_sample_seconds]:-?} seconds"
    if drsm_gt "${P[cpu_used_pct]}" "${CPU_CRIT}"; then
	drsm_crit "${WRA_HOST} CPU usage is ${P[cpu_used_pct]}%"
    elif drsm_gt "${P[cpu_used_pct]}" "${CPU_WARN}"; then
	drsm_warn "${WRA_HOST} CPU usage is ${P[cpu_used_pct]}%"
    fi
    drsm_metric cpu_used_pct "${P[cpu_used_pct]}"
fi
if [ "${P[cpu_count]}" != "" ]; then drsm_metric cpu_count "${P[cpu_count]}"; fi

# Memory, and commit charge, the Windows counterpart of memory plus swap
if [ "${P[mem_available_mb]}" != "" ]; then
    echo "Memory: ${P[mem_available_mb]} MB available of ${P[mem_total_mb]:-?} MB, ${P[mem_used_pct]:-?}% used"
    if [ "${P[mem_available_mb]%.*}" -le "${MIN_AVAIL_MB}" ]; then
	drsm_crit "${WRA_HOST} available memory ${P[mem_available_mb]} MB is at or below ${MIN_AVAIL_MB} MB"
    fi
    drsm_metric mem_available_mb "${P[mem_available_mb]}"
fi
if [ "${P[mem_total_mb]}" != "" ]; then drsm_metric mem_total_mb "${P[mem_total_mb]}"; fi
if [ "${P[commit_limit_mb]:-0}" != "0" ] && [ "${P[commit_used_mb]}" != "" ]; then
    commit_pct=$(awk -v u="${P[commit_used_mb]}" -v l="${P[commit_limit_mb]}" 'BEGIN { printf "%.1f", u / l * 100 }')
    echo "Commit charge: ${P[commit_used_mb]} MB of ${P[commit_limit_mb]} MB, ${commit_pct}%"
    if drsm_gt "${commit_pct}" "${COMMIT_WARN}"; then
	drsm_warn "${WRA_HOST} commit charge is ${commit_pct}% of the limit, memory plus page file is nearly full"
    fi
    drsm_metric commit_used_mb "${P[commit_used_mb]}"
    drsm_metric commit_limit_mb "${P[commit_limit_mb]}"
fi
if [ "${P[process_count]}" != "" ]; then
    echo "Processes: ${P[process_count]}, threads: ${P[thread_count]:-?}"
    drsm_metric process_count "${P[process_count]}"
fi
if [ "${P[uptime_seconds]}" != "" ]; then
    up_days=$(( ${P[uptime_seconds]%.*} / 86400 ))
    echo "Up $(uptime_text "${P[uptime_seconds]}")"
    if [ "${UPTIME_WARN_DAYS}" -gt 0 ] && [ ${up_days} -ge "${UPTIME_WARN_DAYS}" ]; then
	drsm_warn "${WRA_HOST} has not restarted for ${up_days} days, updates may be waiting for a restart"
    fi
    drsm_metric uptime_seconds "${P[uptime_seconds]}"
fi

# Disk space: drive=C: size_mb=N used_mb=N free_mb=N used_pct=N.N
while read -r drive size used pct; do
    [ "${drive}" == "" ] && continue
    if [[ " ${DISK_SKIP^^} " == *" ${drive^^} "* ]]; then continue; fi
    echo "Drive ${drive} ${pct}% used, ${used} MB of ${size} MB"
    if drsm_gt "${pct}" "${DISK_CRIT}"; then
	drsm_crit "${WRA_HOST}:${drive} is at ${pct}% capacity."
    elif drsm_gt "${pct}" "${DISK_WARN}"; then
	drsm_warn "${WRA_HOST}:${drive} is at ${pct}% capacity."
    fi
    lbl="mount=\"${drive}\""
    drsm_metric disk_used_pct "${pct}" "${lbl}"
    drsm_metric disk_used_mb "${used}" "${lbl}"
    drsm_metric disk_size_mb "${size}" "${lbl}"
done < <(wra_section "DISK USAGE" "${REPORT}" | awk '
    {
	d = ""; s = ""; u = ""; p = ""
	for (i = 1; i <= NF; i++) {
	    split($i, kv, "=")
	    if (kv[1] == "drive") d = kv[2]
	    else if (kv[1] == "size_mb") s = kv[2]
	    else if (kv[1] == "used_mb") u = kv[2]
	    else if (kv[1] == "used_pct") p = kv[2]
	}
	if (d ~ /^[A-Za-z]:$/ && p != "") print d, s + 0, u + 0, p
    }')

# Network adapters that are up. The quoted adapter name comes first,
# printed tab separated so names keep their spaces.
while IFS=$'\t' read -r nic speed rxb txb rxe txe rxd txd; do
    [ "${nic}" == "" ] && continue
    echo "Adapter ${nic}: ${speed} Mb/s, received ${rxb} bytes, sent ${txb} bytes, errors ${rxe}/${txe}, discards ${rxd}/${txd}"
    lbl="nic=\"${nic}\""
    drsm_metric nic_rx_bytes "${rxb}" "${lbl}"
    drsm_metric nic_tx_bytes "${txb}" "${lbl}"
    drsm_metric nic_rx_errors "${rxe}" "${lbl}"
    drsm_metric nic_tx_errors "${txe}" "${lbl}"
    drsm_metric nic_rx_discards "${rxd}" "${lbl}"
    drsm_metric nic_tx_discards "${txd}" "${lbl}"
done < <(wra_section "NETWORK" "${REPORT}" | awk '
    match($0, /^adapter="([^"\\]|\\.)*"/) {
	name = substr($0, 10, RLENGTH - 10)
	rest = substr($0, RLENGTH + 1)
	gsub(/\\"/, "\047", name)
	gsub(/\\\\/, "\\", name)
	gsub(/["\t]/, "", name)
	n = split(rest, f, " ")
	delete v
	for (i = 1; i <= n; i++) { split(f[i], kv, "="); v[kv[1]] = kv[2] + 0 }
	printf "%s\t%d\t%.0f\t%.0f\t%.0f\t%.0f\t%.0f\t%.0f\n", name, v["speed_mbps"], v["rx_bytes"], v["tx_bytes"], v["rx_errors"], v["tx_errors"], v["rx_discards"], v["tx_discards"]
    }')

if [ "${DRSM_HAS_ERROR}" == "0" ] && [ "${DRSM_HAS_WARNING}" == "0" ]; then
    drsm_ok "${WRA_HOST} resource use checks good"
fi
# When the counters were read, so rates use the time between reports
drsm_metric sample_etime "${etime}"
drsm_exit
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
