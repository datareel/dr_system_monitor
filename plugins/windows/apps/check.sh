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
# DRSM plugin: required and forbidden programs in the last Windows
# Reporting Agent report.
#
# ----------------------------------------------------------- 
# shellcheck source=lib/drsm_plugin.sh
source "${DRSM_LIB:-$(dirname "$0")/../../../lib}/drsm_plugin.sh"
# shellcheck source=plugins/windows/wra_report.sh
source "$(dirname "$0")/../wra_report.sh"

REQUIRED=$(drsm_setting REQUIRED NONE)
FORBIDDEN=$(drsm_setting FORBIDDEN NONE)
WARNLIST=$(drsm_setting WARN NONE)

wra_load_report || drsm_exit
echo "Installed program checks for ${WRA_HOST}"
if ! wra_has_section "ALL INSTALLED PROGRAMS" "${REPORT}"; then
    drsm_unknown "${WRA_HOST} report has no installed programs section"
    drsm_exit
fi

# "Name: 7-Zip 25.01 (x64) | Version: 25.01" becomes "7-Zip 25.01 (x64) 25.01"
apps=$(wra_section "ALL INSTALLED PROGRAMS" "${REPORT}" | sed -n 's/^Name: \(.*\) | Version: *\(.*\)$/\1 \2/p; t; s/^Name: //p' | sort -uf)
count=0
if [ "${apps}" != "" ]; then count=$(echo "${apps}" | wc -l); fi
echo "Installed programs: ${count}"

function each_pattern()
{
    # Print the ; separated patterns in $1, one per line
    drsm_is_none "${1}" && return
    echo "${1}" | tr ';' '\n' | sed 's/^ *//; s/ *$//' | grep -v '^$'
}

while IFS= read -r p; do
    if ! echo "${apps}" | grep -Eiq -- "${p}"; then
	drsm_crit "${WRA_HOST} required program ${p} is not installed"
    else
	echo "Required program found: $(echo "${apps}" | grep -Ei -- "${p}" | head -1)"
    fi
done < <(each_pattern "${REQUIRED}")

while IFS= read -r p; do
    while IFS= read -r a; do
	[ "${a}" != "" ] && drsm_crit "${WRA_HOST} forbidden program installed: ${a}"
    done < <(echo "${apps}" | grep -Ei -- "${p}")
done < <(each_pattern "${FORBIDDEN}")

while IFS= read -r p; do
    while IFS= read -r a; do
	[ "${a}" != "" ] && drsm_warn "${WRA_HOST} program installed: ${a}"
    done < <(echo "${apps}" | grep -Ei -- "${p}")
done < <(each_pattern "${WARNLIST}")

if [ "${DRSM_HAS_ERROR}" == "0" ] && [ "${DRSM_HAS_WARNING}" == "0" ]; then
    drsm_ok "${WRA_HOST} installed program checks good"
fi
drsm_metric wra_installed_programs "${count}"
drsm_exit
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
