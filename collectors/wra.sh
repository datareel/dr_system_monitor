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
# Collector for Windows hosts that run the Windows Reporting Agent.
# The agent pushes its report to the monitor side (HTTPS upload page,
# CIFS share, or SCP), so nothing connects to the Windows host. The
# windows/* plugins run here, in place from DRSMHOME, and read the
# host's last report:
#
#   ${WRA_REPORTS_DIR}/<name>_windows_report_agent.txt
#
# Host file keys:
#   COLLECTOR=wra
#   PLATFORM=windows
#   WRA_REPORTS_DIR  reports_dir from the agent server.ini, or the
#                    CIFS/SCP folder, default /var/www/html/windows/reports
#   WRA_NAME         host name the agent reports as, default HOST in
#                    lower case without the domain
#
# See collectors/local.sh for the collector functions.
#
# ----------------------------------------------------------- 
COLLECTOR_BASE="${DRSMHOME}"

function wra_report_path()
{
    local dir="${HCONF[WRA_REPORTS_DIR]:-/var/www/html/windows/reports}"
    local name="${HCONF[WRA_NAME]:-${1%%.*}}"
    echo "${dir%/}/${name,,}_windows_report_agent.txt"
}

# A missing or old report is reported by the windows/checkin plugin,
# so the host is always reachable
function collector_check() { return 0; }

function collector_sync() { return 0; }

function collector_exec()
{
    DRSM_WRA_REPORT="$(wra_report_path "${1}")" bash "${2}"
}
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
