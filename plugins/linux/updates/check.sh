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
# DRSM plugin: the UPDATES section of the last DataReel Reporting Agent
# for Linux report: pending package updates, the last time a package
# was installed and whether the host needs a restart for a new kernel.
# Security advisories are checked by linux/vulnerabilities.
#
# ----------------------------------------------------------- 
# shellcheck source=lib/drsm_plugin.sh
source "${DRSM_LIB:-$(dirname "$0")/../../../lib}/drsm_plugin.sh"
# shellcheck source=plugins/linux/lra_report.sh
source "$(dirname "$0")/../lra_report.sh"

WARN_DAYS=$(drsm_setting WARN_DAYS 45)
PENDING_WARN=$(drsm_setting PENDING_WARN 0)
REBOOT_WARN=$(drsm_setting REBOOT_WARN 1)

lra_load_report || drsm_exit
if ! lra_has_section "UPDATES" "${REPORT}"; then
    drsm_unknown "${LRA_HOST} report has no UPDATES section"
    drsm_exit
fi
etime=$(lra_field ETIME "${REPORT}")
check=$(lra_value UPDATES check "${REPORT}")
pending=$(lra_value UPDATES pending_count "${REPORT}")
last=$(lra_value UPDATES last_install_etime "${REPORT}")
reboot=$(lra_value UPDATES reboot_required "${REPORT}")
running=$(lra_value UPDATES running_kernel "${REPORT}")
newest=$(lra_value UPDATES newest_kernel "${REPORT}")

days=""
if [[ "${last}" =~ ^[0-9]+$ ]] && [[ "${etime}" =~ ^[0-9]+$ ]]; then
    days=$(( (etime - last) / 86400 ))
    drsm_detail "Last update" "$(date -d "@${last}" '+%Y-%m-%d'), ${days} days before the report"
fi
case "${check}" in
    ok) echo "${pending:-0} package updates pending${days:+, last package installed ${days} days ago}" ;;
    disabled) echo "Update check turned off on the agent (check_updates=0)${days:+, last package installed ${days} days ago}" ;;
    failed) drsm_warn "${LRA_HOST} agent could not check for updates: $(lra_section UPDATES "${REPORT}" | sed -n 's/^ERROR - //p' | head -1)" ;;
    *) echo "No update check on this host (${check:-unknown})" ;;
esac
if [ "${check}" == "ok" ]; then drsm_detail "Pending updates" "${pending:-0}"; fi

if [ "${days}" != "" ] && [ "${days}" -gt "${WARN_DAYS}" ]; then
    drsm_warn "${LRA_HOST} has not installed a package update for ${days} days"
fi
if [ "${PENDING_WARN}" -gt 0 ] && [ "${pending:-0}" -ge "${PENDING_WARN}" ]; then
    drsm_warn "${LRA_HOST} has ${pending} package updates pending"
fi
echo "Running kernel: ${running:-unknown}${newest:+, newest installed ${newest}}"
if [ "${reboot}" == "1" ]; then
    if [ "${REBOOT_WARN}" == "1" ]; then
	drsm_warn "${LRA_HOST} needs a restart to run its updated kernel or libraries${newest:+ (${newest})}"
    else
	echo "Restart needed for the updated kernel or libraries"
    fi
fi
if [ "${DRSM_HAS_ERROR}" == "0" ] && [ "${DRSM_HAS_WARNING}" == "0" ]; then
    drsm_ok "${LRA_HOST} updates check good"
fi

if [ "${check}" == "ok" ] && [ "${pending:-0}" -gt 0 ]; then
    echo ""
    echo "Pending updates:"
    lra_section "UPDATES" "${REPORT}" | sed -n 's/^update //p' | lra_kv package version repo | awk -F'\t' '{ printf "  %s %s (%s)\n", $1, $2, $3 }'
fi
if [[ "${pending}" =~ ^[0-9]+$ ]]; then drsm_metric updates_pending "${pending}"; fi
if [ "${days}" != "" ]; then drsm_metric updates_last_days "${days}"; fi
if [ "${reboot}" != "" ]; then drsm_metric reboot_required "${reboot}"; fi
drsm_exit
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# *******************************
