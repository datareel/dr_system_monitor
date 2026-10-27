#!/bin/bash
# ----------------------------------------------------------- 
# BASH Script
# Operating System(s): RHEL/CENTOS
# Run Level(s): 3, 5
# Shell: BASH shell
# Original Author(s): DataReel Software Development
# File Creation Date: 10/25/2026
# Date Last Modified: 10/25/2026
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
# DRSM plugin: age and completeness of the last Windows Reporting
# Agent report, ported from bash/run_windows_laptop_inventory.sh in
# the agent distribution.
#
# ----------------------------------------------------------- 
# shellcheck source=lib/drsm_plugin.sh
source "${DRSM_LIB:-$(dirname "$0")/../../../lib}/drsm_plugin.sh"
# shellcheck source=plugins/windows/wra_report.sh
source "$(dirname "$0")/../wra_report.sh"

WARN_HOURS=$(drsm_setting WARN_HOURS 48)
CRIT_DAYS=$(drsm_setting CRIT_DAYS 15)
MIN_VERSION=$(drsm_setting MIN_VERSION "")
REPORT="${DRSM_WRA_REPORT}"

if [ "${REPORT}" == "" ]; then
    drsm_unknown "${WRA_HOST} DRSM_WRA_REPORT is not set, use COLLECTOR=wra for Windows hosts"
    drsm_exit
fi
if [ ! -e "${REPORT}" ]; then
    drsm_crit "${WRA_HOST} has never sent a Windows agent report, no ${REPORT}"
    echo "IMPACT - ${WRA_HOST} needs the DataReel Reporting Agent installed or registered"
    drsm_exit
fi
if [ ! -r "${REPORT}" ]; then
    drsm_unknown "${WRA_HOST} report ${REPORT} is not readable by $(whoami)"
    drsm_exit
fi
if [ ! -s "${REPORT}" ]; then
    drsm_crit "${WRA_HOST} Windows agent report file is empty"
    echo "IMPACT - ${WRA_HOST} needs the DataReel Reporting Agent installed or fixed"
    drsm_exit
fi

etime=$(wra_field ETIME "${REPORT}")
if [[ ! "${etime}" =~ ^[0-9]+$ ]]; then
    drsm_crit "${WRA_HOST} Windows agent report is missing its time stamp"
    drsm_exit
fi
version=$(wra_field VERSION "${REPORT}")
datetime=$(wra_field DATETIME "${REPORT}")
reported=$(wra_field HOSTNAME "${REPORT}")
now=$(date +%s)
age=$((now - etime))
if [ ${age} -lt 0 ]; then age=0; fi
hours=$((age / 3600))
days=$((age / 86400))

ips=$(wra_section "IP ADDRESS" "${REPORT}" | sed -n 's/^IPv4 Address: *//p' | tr -d ' ' | paste -sd ' ' -)
ago="${hours} hours ago"
if [ ${hours} -eq 0 ]; then ago="$((age / 60)) minutes ago"; elif [ ${hours} -eq 1 ]; then ago="1 hour ago"; fi
echo "Agent ${version:-unknown} reported ${ago}${ips:+, IP ${ips}}"
drsm_detail "Agent" "DataReel Reporting Agent ${version:-unknown}"
if [ "${ips}" != "" ]; then drsm_detail "IP address" "${ips// /, }"; fi
echo "Agent version: ${version:-unknown}"
echo "Reported host name: ${reported}"
echo "Last report: ${datetime} (${hours} hours ago)"

if [ ${age} -gt $((CRIT_DAYS * 86400)) ]; then
    drsm_crit "${WRA_HOST} has not reported for ${days} days, last report ${datetime}"
    echo "IMPACT - ${WRA_HOST} Windows agent is not running, or the laptop is off or offline"
elif [ ${age} -gt $((WARN_HOURS * 3600)) ]; then
    drsm_warn "${WRA_HOST} has not reported for ${hours} hours, last report ${datetime}"
else
    drsm_ok "${WRA_HOST} reported ${hours} hours ago, last report ${datetime}"
fi

# Sections the service always writes, a missing one means the report
# was cut short. send_test_report.exe leaves out the patch sections.
missing=""
for s in "ALL INSTALLED PROGRAMS" "WINDOWS DEFENDER ALERTS" "INSTALLED WINDOWS PATCHES" "HOT FIXES"; do
    if ! grep -q "^END ${s}" "${REPORT}"; then missing="${missing}, ${s}"; fi
done
if [ "${missing}" != "" ]; then
    drsm_warn "${WRA_HOST} Windows agent report is incomplete, missing ${missing#, }"
fi

if [ "${MIN_VERSION}" != "" ] && [ "${version}" != "" ]; then
    lowest=$(printf '%s\n%s\n' "${MIN_VERSION}" "${version}" | sort -V | head -1)
    if [ "${lowest}" != "${MIN_VERSION}" ]; then
	drsm_warn "${WRA_HOST} runs Windows agent version ${version}, ${MIN_VERSION} or later is required"
    fi
fi

# Inventory from the report
if wra_has_section "SERVICE TAG AND BARCODE" "${REPORT}"; then
    # Lines with a value after the colon, a VM has no BIOS serial or asset tag
    tag=$(wra_section "SERVICE TAG AND BARCODE" "${REPORT}" | grep -E ':[[:space:]]*[^[:space:]]')
    echo ""
    echo "Service tag and barcode:"
    if [ "${tag}" != "" ]; then
	echo "${tag}" | sed 's/^/  /'
	drsm_detail "Service tag" "$(echo "${tag}" | sed 's/^[^:]*: *//' | paste -sd ' ' - | sed 's/ \{1,\}/, /g')"
    else
	echo "  no service tag (virtual machine or no BIOS asset tag)"
	drsm_detail "Service tag" "none (virtual machine or no BIOS asset tag)"
    fi
fi
if wra_has_section "IP ADDRESS" "${REPORT}"; then
    echo ""
    echo "IP addresses:"
    wra_section "IP ADDRESS" "${REPORT}" | grep -v '^ *$' | sed 's/^/  /'
fi
if wra_has_section "USERS" "${REPORT}"; then
    # Profile folders, without the built in ones
    users=$(wra_section "USERS" "${REPORT}" | sed -n 's/^\[DIR\] *//p' | grep -Ev '^(All Users|Default|Default User|Public)$')
    echo ""
    echo "User profiles: $(echo "${users}" | grep -c .)"
    drsm_detail "User profiles" "$(echo "${users}" | grep . | paste -sd ',' - | sed 's/,/, /g')"
    echo "${users}" | grep . | sed 's/^/  /'
fi

drsm_metric wra_report_age_seconds "${age}"
drsm_exit
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
