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
# DRSM plugin: age and completeness of the last DataReel Reporting
# Agent for Linux report, and the host facts in it (release, kernel,
# hardware, addresses) for the host card.
#
# ----------------------------------------------------------- 
# shellcheck source=lib/drsm_plugin.sh
source "${DRSM_LIB:-$(dirname "$0")/../../../lib}/drsm_plugin.sh"
# shellcheck source=plugins/linux/lra_report.sh
source "$(dirname "$0")/../lra_report.sh"

WARN_MINUTES=$(drsm_setting WARN_MINUTES 60)
CRIT_HOURS=$(drsm_setting CRIT_HOURS 24)
MIN_VERSION=$(drsm_setting MIN_VERSION "")
REPORT="${DRSM_LRA_REPORT}"

if [ "${REPORT}" == "" ]; then
    drsm_unknown "${LRA_HOST} DRSM_LRA_REPORT is not set, use COLLECTOR=lra for Linux agent hosts"
    drsm_exit
fi
if [ ! -e "${REPORT}" ]; then
    drsm_crit "${LRA_HOST} has never sent a Linux agent report, no ${REPORT}"
    echo "IMPACT - ${LRA_HOST} needs the DataReel Reporting Agent for Linux installed or registered"
    drsm_exit
fi
if [ ! -r "${REPORT}" ]; then
    drsm_unknown "${LRA_HOST} report ${REPORT} is not readable by $(whoami)"
    drsm_exit
fi
if [ ! -s "${REPORT}" ]; then
    drsm_crit "${LRA_HOST} Linux agent report file is empty"
    drsm_exit
fi

etime=$(lra_field ETIME "${REPORT}")
if [[ ! "${etime}" =~ ^[0-9]+$ ]]; then
    drsm_crit "${LRA_HOST} Linux agent report is missing its time stamp"
    drsm_exit
fi
version=$(lra_field VERSION "${REPORT}")
datetime=$(lra_field DATETIME "${REPORT}")
reported=$(lra_field HOSTNAME "${REPORT}")
age=$(( $(date +%s) - etime ))
if [ ${age} -lt 0 ]; then age=0; fi
mins=$((age / 60))
hours=$((age / 3600))
ago="${mins} minutes ago"
if [ ${hours} -ge 2 ]; then ago="${hours} hours ago"; elif [ ${mins} -eq 1 ]; then ago="1 minute ago"; fi

os=$(lra_value SYSTEM os_name "${REPORT}")
kernel=$(lra_value SYSTEM kernel "${REPORT}")
ips=$(lra_section "IP ADDRESS" "${REPORT}" | lra_kv family address | awk -F'\t' '$1 == "inet" { print $2 }' | paste -sd ' ' -)
echo "Agent ${version:-unknown} reported ${ago}${ips:+, IP ${ips}}"
drsm_detail "Agent" "DataReel Reporting Agent for Linux ${version:-unknown}"
if [ "${os}" != "" ]; then drsm_detail "Operating system" "${os}"; fi
if [ "${kernel}" != "" ]; then drsm_detail "Kernel" "${kernel}"; fi
if [ "${ips}" != "" ]; then drsm_detail "IP address" "${ips// /, }"; fi
hw=$(printf '%s %s' "$(lra_value SYSTEM vendor "${REPORT}")" "$(lra_value SYSTEM product "${REPORT}")" | sed 's/^ *//; s/ *$//')
virt=$(lra_value SYSTEM virtualization "${REPORT}")
if [ "${virt}" != "" ] && [ "${virt}" != "none" ]; then hw="${hw:+${hw}, }${virt} virtual machine"; fi
if [ "${hw}" != "" ]; then drsm_detail "Hardware" "${hw}"; fi
serial=$(lra_value SYSTEM serial_number "${REPORT}")
if [ "${serial}" != "" ]; then drsm_detail "Serial number" "${serial}"; fi
echo "Reported host name: ${reported}"
echo "Last report: ${datetime} (${ago})"

if [ ${age} -gt $((CRIT_HOURS * 3600)) ]; then
    drsm_crit "${LRA_HOST} has not reported for ${hours} hours, last report ${datetime}"
    echo "IMPACT - ${LRA_HOST} Linux agent is not running, or the host is down or offline"
elif [ ${age} -gt $((WARN_MINUTES * 60)) ]; then
    drsm_warn "${LRA_HOST} has not reported for ${mins} minutes, last report ${datetime}"
else
    drsm_ok "${LRA_HOST} reported ${ago}, last report ${datetime}"
fi

# Sections the agent always writes, a missing one means the report
# was cut short
missing=""
for s in "PERFORMANCE" "DISK USAGE" "SECURITY" "UPDATES" "VULNERABILITIES" "INSTALLED PACKAGES"; do
    if ! grep -q "^END ${s}" "${REPORT}"; then missing="${missing}, ${s}"; fi
done
if [ "${missing}" != "" ]; then
    drsm_warn "${LRA_HOST} Linux agent report is incomplete, missing ${missing#, }"
fi

if [ "${MIN_VERSION}" != "" ] && [ "${version}" != "" ]; then
    lowest=$(printf '%s\n%s\n' "${MIN_VERSION}" "${version}" | sort -V | head -1)
    if [ "${lowest}" != "${MIN_VERSION}" ]; then
	drsm_warn "${LRA_HOST} runs Linux agent version ${version}, ${MIN_VERSION} or later is required"
    fi
fi

echo ""
echo "System:"
lra_section "SYSTEM" "${REPORT}" | sed 's/^/  /'
if lra_has_section "IP ADDRESS" "${REPORT}"; then
    echo ""
    echo "IP addresses:"
    lra_section "IP ADDRESS" "${REPORT}" | sed 's/^/  /'
fi
users=$(lra_section "USERS" "${REPORT}" | lra_kv user from | awk -F'\t' '{ print $1 ($2 != "" ? " from " $2 : "") }' | sort -u)
echo ""
echo "Logged in: $(echo "${users}" | grep -c .)"
echo "${users}" | grep . | sed 's/^/  /'
accounts=$(lra_section "ACCOUNTS" "${REPORT}" | lra_kv account | paste -sd ',' - | sed 's/,/, /g')
if [ "${accounts}" != "" ]; then drsm_detail "Login accounts" "${accounts}"; fi
drsm_metric user_sessions "$(echo "${users}" | grep -c .)"
drsm_metric lra_report_age_seconds "${age}"
drsm_exit
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# *******************************
