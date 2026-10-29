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
# Create DRSM host files for Linux hosts that run the DataReel
# Reporting Agent for Linux, one per report in the agent reports directory.
# Existing host files are never changed. Dry run unless --apply.
#
# Usage: lra_hosts.sh [--apply] [-d reports dir] [-g group] [-s org/site] [-o output dir]
#   --apply  Write the host files, default is to list what would be written
#   -d       Agent reports directory, default LRA_REPORTS_DIR from the
#            site file with -s, else _defaults.conf, else
#            /var/www/html/linux/reports
#   -g       Host group, default production
#   -s       Site of the hosts, written as SITE=. The host files are
#            named <org>_<site>_<host>.conf.
#   -o       Output directory, default ${HOSTSdir} or ${DRSMHOME}/etc/hosts
#
# Put the shared Linux agent settings in _defaults.conf, for example
# LRA_REPORTS_DIR and linux_checkin_CRIT_HOURS, so the host files
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
# shellcheck source=lib/drsm_sites.sh
source "${DRSMHOME}/lib/drsm_sites.sh"

apply="0"
group="production"
outdir="${HOSTSdir:-${DRSMHOME}/etc/hosts}"
reportsdir=""
site=""
function usage() { sed -n '/^# Usage:/,/^#   -o/p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
while [ $# -gt 0 ]; do
    case "${1}" in
	--apply) apply="1" ;;
	-d) reportsdir="${2}"; shift ;;
	-g) group="${2}"; shift ;;
	-s) site="${2,,}"; shift ;;
	-o) outdir="${2}"; shift ;;
	*) usage ;;
    esac
    shift
done

if [ "${site}" != "" ] && ! drsm_valid_site "${site}"; then
    echo "ERROR - Site ${site} is not org/site, IDs use a-z, 0-9, _ and -"
    exit 1
fi
if [ "${reportsdir}" == "" ]; then
    # The site file's agent reports directory, else _defaults.conf's
    declare -A DEFAULTS=()
    if [ -f "${outdir}/_defaults.conf" ]; then drsm_read_conf "${outdir}/_defaults.conf" DEFAULTS; fi
    if [ "${site}" != "" ]; then drsm_read_site "${site}" DEFAULTS; fi
    reportsdir="${DEFAULTS[LRA_REPORTS_DIR]:-/var/www/html/linux/reports}"
fi
if [ ! -d "${reportsdir}" ]; then
    echo "ERROR - Agent reports directory ${reportsdir} not found, use -d"
    exit 1
fi
if [ "${apply}" == "0" ]; then echo "Dry run, nothing is written. Run with --apply to write the host files."; fi

added=0
skipped=0
shopt -s nullglob
for f in "${reportsdir}"/*_linux_report_agent.txt
do
    name=$(basename "${f}" _linux_report_agent.txt)
    if [[ ! "${name}" =~ ^[a-z0-9][a-z0-9_-]*$ ]]; then
	echo "WARNING - Skipping ${f}, not a host name"
	continue
    fi
    # Hosts in a site get the site in the file name, two sites may
    # have a host with the same name
    conf="${outdir}/${name}.conf"
    if [ "${site}" != "" ]; then conf="${outdir}/${site%%/*}_${site#*/}_${name}.conf"; fi
    if [ -e "${conf}" ]; then
	skipped=$((skipped + 1))
	continue
    fi
    echo "New host file ${conf}"
    added=$((added + 1))
    if [ "${apply}" == "0" ]; then continue; fi
    mkdir -p "${outdir}"
    cat > "${conf}" <<HOST
# DRSM host file for a DataReel Reporting Agent for Linux host, made by
# utils/lra_hosts.sh. See etc/hosts/linux_agent.conf_example.
HOST=${name}
DESCRIPTION="Linux host ${name}"
IMPACT="${name} may be down, full or missing security updates"
GROUP=${group}
PLATFORM=linux
COLLECTOR=lra
# The agent reports over the internet, DRSM may not reach the host
PROBES=""
PLUGINS="linux/checkin linux/resources linux/updates linux/security linux/vulnerabilities"
HOST
    if [ "${site}" != "" ]; then sed -i "s|^GROUP=.*|&\nSITE=${site}|" "${conf}"; fi
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
