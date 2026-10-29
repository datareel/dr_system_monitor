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
# Collector for Linux hosts that run the DataReel Reporting Agent for
# Linux. The agent pushes its report to the monitor side (HTTPS upload
# page, CIFS share, or SCP), so nothing connects to the host and it can
# be monitored over the internet from behind NAT. The linux/* plugins
# run here, in place from DRSMHOME, and read the host's last report:
#
#   ${LRA_REPORTS_DIR}/<name>_linux_report_agent.txt
#
# Linux hosts DRSM can reach over SSH keep COLLECTOR=ssh and the core
# plugins (the clientless mode); this collector is for hosts with the
# agent.
#
# Host file keys:
#   COLLECTOR=lra
#   PLATFORM=linux
#   LRA_REPORTS_DIR  reports_dir from the agent server.ini, or the
#                    CIFS/SCP folder, default /var/www/html/linux/reports
#   LRA_NAME         host name the agent reports as, default HOST in
#                    lower case without the domain
#
# See collectors/local.sh for the collector functions.
#
# ----------------------------------------------------------- 
COLLECTOR_BASE="${DRSMHOME}"

function lra_report_path()
{
    local dir="${HCONF[LRA_REPORTS_DIR]:-/var/www/html/linux/reports}"
    local name="${HCONF[LRA_NAME]:-${1%%.*}}"
    echo "${dir%/}/${name,,}_linux_report_agent.txt"
}

# A missing or old report is reported by the linux/checkin plugin,
# so the host is always reachable
function collector_check() { return 0; }

function collector_sync() { return 0; }

function collector_exec()
{
    DRSM_LRA_REPORT="$(lra_report_path "${1}")" bash "${2}"
}
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# *******************************
