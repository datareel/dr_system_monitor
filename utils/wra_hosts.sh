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
# Create DRSM host files for Windows hosts that run the Windows
# Reporting Agent, one per report in the agent reports directory.
# Existing host files are never changed. Dry run unless --apply.
#
# Usage: wra_hosts.sh [--apply] [-d reports dir] [-g group] [-o output dir]
#   --apply  Write the host files, default is to list what would be written
#   -d       Agent reports directory, default WRA_REPORTS_DIR from
#            _defaults.conf, else /var/www/html/windows/reports
#   -g       Host group, default production
#   -o       Output directory, default ${HOSTSdir} or ${DRSMHOME}/etc/hosts
#
# Put the shared Windows settings in _defaults.conf, for example
# WRA_REPORTS_DIR and windows_checkin_CRIT_DAYS, so the host files
# only name the host.
#
# ----------------------------------------------------------- 
if [ "${BASEdir}" == "" ]; then export BASEdir="${HOME}/drsm"; fi
if [ -f "${HOME}/.drsm.sh" ]; then CONFIG_FILE="${HOME}/.drsm.sh"; else CONFIG_FILE="${BASEdir}/etc/drsm.sh"; fi
if [ ! -f "${CONFIG_FILE}" ]; then echo "Missing base config ${CONFIG_FILE}"; exit 1; fi
# shellcheck source=etc/drsm.sh
source "${CONFIG_FILE}"
# shellcheck source=lib/drsm_conf.sh
source "${DRSMHOME}/lib/drsm_conf.sh"

apply="0"
group="production"
outdir="${HOSTSdir:-${DRSMHOME}/etc/hosts}"
reportsdir=""
function usage() { sed -n '/^# Usage:/,/^#   -o/p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
while [ $# -gt 0 ]; do
    case "${1}" in
	--apply) apply="1" ;;
	-d) reportsdir="${2}"; shift ;;
	-g) group="${2}"; shift ;;
	-o) outdir="${2}"; shift ;;
	*) usage ;;
    esac
    shift
done

if [ "${reportsdir}" == "" ]; then
    declare -A DEFAULTS=()
    if [ -f "${outdir}/_defaults.conf" ]; then drsm_read_conf "${outdir}/_defaults.conf" DEFAULTS; fi
    reportsdir="${DEFAULTS[WRA_REPORTS_DIR]:-/var/www/html/windows/reports}"
fi
if [ ! -d "${reportsdir}" ]; then
    echo "ERROR - Agent reports directory ${reportsdir} not found, use -d"
    exit 1
fi
if [ "${apply}" == "0" ]; then echo "Dry run, nothing is written. Run with --apply to write the host files."; fi

added=0
skipped=0
shopt -s nullglob
for f in "${reportsdir}"/*_windows_report_agent.txt
do
    name=$(basename "${f}" _windows_report_agent.txt)
    if [[ ! "${name}" =~ ^[a-z0-9][a-z0-9_-]*$ ]]; then
	echo "WARNING - Skipping ${f}, not a host name"
	continue
    fi
    conf="${outdir}/${name}.conf"
    if [ -e "${conf}" ]; then
	skipped=$((skipped + 1))
	continue
    fi
    echo "New host file ${conf}"
    added=$((added + 1))
    if [ "${apply}" == "0" ]; then continue; fi
    mkdir -p "${outdir}"
    cat > "${conf}" <<HOST
# DRSM host file for a Windows Reporting Agent host, made by
# utils/wra_hosts.sh. See etc/hosts/windows.conf_example.
HOST=${name}
DESCRIPTION="Windows host ${name}"
IMPACT="${name} may be missing security updates or protection"
GROUP=${group}
PLATFORM=windows
COLLECTOR=wra
# Laptops move between networks, so no ping probe
PROBES=""
PLUGINS="windows/checkin windows/defender windows/patches windows/apps"
HOST
done
shopt -u nullglob

verb="would be written"
if [ "${apply}" == "1" ]; then verb="written"; fi
echo "${added} host files ${verb}, ${skipped} hosts already have a host file"
exit 0
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
