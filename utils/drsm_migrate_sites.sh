#!/bin/bash
# -----------------------------------------------------------
# BASH Script
# Operating System(s): RHEL/CENTOS
# Run Level(s): 3, 5
# Shell: BASH shell
# Original Author(s): DataReel Software Development
# File Creation Date: 10/27/2026
# Date Last Modified: 10/27/2026
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
# <http://www.gnu.org/licenses/>.
#
# Move hosts from the default site into an organization and site.
# Dry run unless --apply.
# Usage: drsm_migrate_sites.sh [--apply] [-o "Org name"] [-n "Site name"]
#                              [-l location] [-c collector ID] org/site [host ...]
#   --apply  Make the changes, default is to list what would change
#   -o       Organization name for a new <org>.org file, default the ID
#   -n       Site name for a new <site>.site file, default the ID
#   -l       Site location for a new site file
#   -c       COLLECTOR_ID for a new site file, the short host name of
#            the monitor host that runs the site
#   org/site Site to move the hosts to, IDs use a-z, 0-9, _ and -
#   host     Hosts to move, default every host file without SITE=
# Changes:
#   Writes ${SITESdir}/<org>.org and <org>/<site>.site if missing
#   Adds SITE=<org>/<site> to each host file, saved first to
#   ${HOSTSdir}/removed/
#   Moves ${REPORTdir}/systems/<host> to
#   ${REPORTdir}/orgs/<org>/<site>/systems/<host>, with its archive
#   and metrics history
#   With no host list, also moves the group reports and archive in
#   ${REPORTdir} into the site, so the default site is left empty
# Stop cron while migrating, or run between drsm_run.sh runs.
# -----------------------------------------------------------
if [ "${BASEdir}" == "" ]; then export BASEdir="${HOME}/drsm"; fi
if [ -f "${HOME}/.drsm.sh" ]; then CONFIG_FILE="${HOME}/.drsm.sh"; else CONFIG_FILE="${BASEdir}/etc/drsm.sh"; fi
if [ ! -f "${CONFIG_FILE}" ]; then echo "ERROR - Missing base config ${CONFIG_FILE}"; exit 1; fi
# shellcheck source=etc/drsm.sh
source "${CONFIG_FILE}"
# shellcheck source=lib/drsm_conf.sh
source "${DRSMHOME}/lib/drsm_conf.sh"
# shellcheck source=lib/drsm_sites.sh
source "${DRSMHOME}/lib/drsm_sites.sh"

apply="0"
orgname=""
sitename=""
location=""
collector=""
site=""
hosts=()
function usage() { sed -n '/^# Usage:/,/^#   host     Hosts/p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
while [ $# -gt 0 ]; do
    case "${1}" in
	--apply) apply="1" ;;
	-o) orgname="${2}"; shift ;;
	-n) sitename="${2}"; shift ;;
	-l) location="${2}"; shift ;;
	-c) collector="${2}"; shift ;;
	-*) usage ;;
	*) if [ "${site}" == "" ]; then site="${1,,}"; else hosts+=("${1}"); fi ;;
    esac
    shift
done
if [ "${site}" == "" ]; then usage; fi
if ! drsm_valid_site "${site}" || [ "${site}" == "${DRSM_LEGACY_SITE}" ]; then
    echo "ERROR - Not a site: ${site}, use org/site with a-z, 0-9, _ and -, not ${DRSM_LEGACY_SITE}"
    exit 1
fi
org="${site%%/*}"
if [ "${HOSTSdir}" == "" ]; then HOSTSdir="${DRSMHOME}/etc/hosts"; fi
sitesdir=$(drsm_sites_dir)
siteroot=$(drsm_site_root "${site}")
stamp=$(date +%Y%m%d_%H%M%S)
backupdir="${HOSTSdir}/removed"

if [ "${apply}" == "1" ]; then
    echo "Moving hosts to site ${site}"
else
    echo "Dry run, add --apply to move hosts to site ${site}"
fi

function quote() {
    # Value for a KEY=value line
    printf '"%s"' "${1//\"/}"
}

# Site and org files
orgfile=$(drsm_org_file "${org}")
sitefile=$(drsm_site_file "${site}")
if [ ! -f "${orgfile}" ]; then
    echo "  write ${orgfile}"
    if [ "${apply}" == "1" ]; then
	mkdir -p "${sitesdir}"
	{
	    echo "# DRSM organization, see etc/sites/example.org_example"
	    echo "NAME=$(quote "${orgname:-${org}}")"
	    echo "CONTACT="
	} > "${orgfile}"
    fi
fi
if [ ! -f "${sitefile}" ]; then
    echo "  write ${sitefile}"
    if [ "${apply}" == "1" ]; then
	mkdir -p "$(dirname "${sitefile}")"
	{
	    echo "# DRSM site, see etc/sites/example/example.site_example"
	    echo "NAME=$(quote "${sitename:-${site#*/}}")"
	    echo "LOCATION=$(quote "${location}")"
	    if [ "${collector}" != "" ]; then echo "COLLECTOR_ID=${collector}"; fi
	} > "${sitefile}"
    fi
fi

# Host files to move: the ones named, else every one in the default site
files=()
shopt -s nullglob
for f in "${HOSTSdir}"/*.conf; do
    case "$(basename "${f}")" in _*) continue ;; esac
    declare -A H=()
    drsm_read_conf "${f}" H
    h="${H[HOST]:-$(basename "${f}" .conf)}"
    if [ ${#hosts[@]} -gt 0 ]; then
	for want in "${hosts[@]}"; do
	    if [ "${want}" == "${h}" ] || [ "${want}" == "$(basename "${f}" .conf)" ]; then files+=("${f}"); fi
	done
    elif [ "${H[SITE]}" == "" ]; then
	files+=("${f}")
    fi
    unset H
done
shopt -u nullglob
if [ ${#files[@]} -eq 0 ]; then
    echo "ERROR - No host files to move in ${HOSTSdir}, convert systems.dat first with utils/migrate_systems_dat.sh"
    exit 1
fi

moved=0
for f in "${files[@]}"; do
    declare -A H=()
    drsm_read_conf "${f}" H
    h="${H[HOST]:-$(basename "${f}" .conf)}"
    from=$(drsm_host_file_site "${f}")
    unset H
    if [ "${from}" == "${site}" ]; then echo "  ${h} is already in ${site}"; continue; fi
    if [ -d "${siteroot}/systems/${h}" ]; then
	echo "WARNING - ${siteroot}/systems/${h} exists, ${h} not moved"
	continue
    fi
    echo "  ${h}: set SITE=${site} in ${f}"
    if [ "${apply}" == "1" ]; then
	mkdir -p "${backupdir}"
	cp -p "${f}" "${backupdir}/$(basename "${f}").${stamp}"
	grep -v '^[[:space:]]*\(export \)\{0,1\}SITE=' "${f}" > "${f}.tmp.$$"
	echo "SITE=${site}" >> "${f}.tmp.$$"
	cat "${f}.tmp.$$" > "${f}"
	rm -f "${f}.tmp.$$"
    fi
    fromdir="$(drsm_site_root "${from}")/systems/${h}"
    if [ -d "${fromdir}" ]; then
	echo "  ${h}: move ${fromdir} to ${siteroot}/systems/${h}"
	if [ "${apply}" == "1" ]; then
	    mkdir -p "${siteroot}/systems"
	    mv "${fromdir}" "${siteroot}/systems/${h}"
	fi
    fi
    moved=$((moved + 1))
done

# Group reports and their archive, when the whole default site moves
if [ ${#hosts[@]} -eq 0 ]; then
    shopt -s nullglob
    for f in "${REPORTdir}"/system_check*_report*.txt "${REPORTdir}"/system_health_report*.txt; do
	echo "  move ${f} to ${siteroot}/"
	if [ "${apply}" == "1" ]; then mkdir -p "${siteroot}"; mv "${f}" "${siteroot}/"; fi
    done
    if [ -d "${REPORTdir}/archive" ]; then
	n=$(find "${REPORTdir}/archive" -maxdepth 1 -type f | wc -l)
	if [ "${n}" -gt 0 ]; then
	    echo "  move ${n} files in ${REPORTdir}/archive to ${siteroot}/archive/"
	    if [ "${apply}" == "1" ]; then
		mkdir -p "${siteroot}/archive"
		find "${REPORTdir}/archive" -maxdepth 1 -type f -exec mv -t "${siteroot}/archive/" {} +
	    fi
	fi
    fi
    shopt -u nullglob
fi

echo "${moved} host(s) to move to ${site}"
if [ "${apply}" == "1" ] && [ -d "${REPORTdir}/orgs" ]; then
    drsm_write_site_json "${site}"
    drsm_write_org_json "${org}"
fi
if [ "${WEBSYNC_DEST}" != "" ]; then
    echo "Run drsm_web_sync.sh --apply after the next drsm_run.sh to move the hosts on the hosted dashboard"
fi
exit 0
# -----------------------------------------------------------
# *******************************
# ********* End of File *********
# *******************************
