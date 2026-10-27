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
# DRSM plugin: age of the newest Windows patch in the last Windows
# Reporting Agent report. Uses the Windows Update history, and the
# Win32_QuickFixEngineering hotfix list when the history is empty.
#
# ----------------------------------------------------------- 
# shellcheck source=lib/drsm_plugin.sh
source "${DRSM_LIB:-$(dirname "$0")/../../../lib}/drsm_plugin.sh"
# shellcheck source=plugins/windows/wra_report.sh
source "$(dirname "$0")/../wra_report.sh"

WARN_DAYS=$(drsm_setting WARN_DAYS 45)
CRIT_DAYS=$(drsm_setting CRIT_DAYS 90)
IGNORE=$(drsm_setting IGNORE "Security Intelligence Update|Definition Update|Malicious Software Removal Tool")

wra_load_report || drsm_exit
if ! wra_has_section "INSTALLED WINDOWS PATCHES" "${REPORT}" && ! wra_has_section "HOT FIXES" "${REPORT}"; then
    drsm_unknown "${WRA_HOST} report has no patch sections, it may be from send_test_report.exe"
    drsm_exit
fi

# Date and title of every installed update, minus the ignored titles
patches=$(wra_section "INSTALLED WINDOWS PATCHES" "${REPORT}" | awk '
    /^Date:/ { d = $2; next }
    /^ *Patch:/ { t = $0; sub(/^ *Patch: */, "", t); print d "|" t }')
if [ "${IGNORE}" != "" ]; then
    patches=$(echo "${patches}" | grep -Ev -- "${IGNORE}")
fi
count=0
if [ "${patches}" != "" ]; then count=$(echo "${patches}" | wc -l); fi
last=$(echo "${patches}" | cut -d'|' -f1 | wra_newest_date)
source="Windows Update history"

hotfixes=$(wra_section "HOT FIXES" "${REPORT}" | sed -n 's/^Installed On: *//p')
hcount=0
if [ "${hotfixes}" != "" ]; then hcount=$(echo "${hotfixes}" | wc -l); fi
if [ "${last}" == "" ]; then
    last=$(echo "${hotfixes}" | wra_newest_date)
    source="hotfix list"
fi

if [ "${last}" == "" ]; then
    drsm_warn "${WRA_HOST} report lists no installed Windows patches"
    drsm_exit
fi

age=$(( ( $(date +%s) - $(date -d "${last}" +%s) ) / 86400 ))
if [ ${age} -lt 0 ]; then age=0; fi
echo "Newest Windows patch ${last}, ${age} days ago, ${count} updates and ${hcount} hotfixes"
drsm_detail "Newest Windows patch" "${last}"
if [ ${age} -gt "${CRIT_DAYS}" ]; then
    drsm_crit "${WRA_HOST} newest Windows patch is ${age} days old, installed ${last}"
    echo "IMPACT - ${WRA_HOST} is missing Windows security updates"
elif [ ${age} -gt "${WARN_DAYS}" ]; then
    drsm_warn "${WRA_HOST} newest Windows patch is ${age} days old, installed ${last}"
else
    drsm_ok "${WRA_HOST} newest Windows patch installed ${last}, ${age} days ago (${source})"
fi

# Full update history, newest first, then the hotfix list
echo ""
echo "Windows Update history, newest first (definition updates left out):"
echo "${patches}" | awk -F'|' 'NF > 1 { split($1, a, "-"); printf "%04d-%02d-%02d  %s\n", a[1], a[2], a[3], $2 }' | sort -r -s -k1,1
if wra_has_section "HOT FIXES" "${REPORT}"; then
    echo ""
    echo "Hotfixes:"
    wra_section "HOT FIXES" "${REPORT}" | awk '
	/^Hotfix ID:/ { id = $3 }
	/^Description:/ { d = $0; sub(/^Description: */, "", d) }
	/^Installed On:/ { split($3, a, "/"); printf "  %04d-%02d-%02d  %s  %s\n", a[3], a[1], a[2], id, d }' | sort -r
fi

drsm_metric wra_patch_age_days "${age}"
drsm_metric wra_patches "${count}"
drsm_exit
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
