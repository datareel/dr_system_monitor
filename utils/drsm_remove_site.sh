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
# Stop monitoring a site: its hosts, its site file and its reports.
# Dry run unless --apply.
# Usage: drsm_remove_site.sh [--apply] [--remote] org/site
#   --apply   Remove the files, default is to list what would go
#   --remote  Also remove the plugin bundle from each of the site's
#             hosts over SSH, see drsm_remove_host.sh --remote
#   org/site  Site to remove
# Removed:
#   Each host file with SITE=<org>/<site>, through drsm_remove_host.sh,
#   saved first to ${HOSTSdir}/removed/
#   ${SITESdir}/<org>/<site>.site, saved first to ${SITESdir}/removed/
#   ${REPORTdir}/orgs/<org>/<site>/ with every host's reports, archives
#   and metrics history, and org.json when no other site of the
#   organization is left. The <org>.org file is kept.
# A hosted dashboard fed by drsm_web_sync.sh keeps its copy of the site,
# remove orgs/<org>/<site> there by hand.
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
remote="0"
site=""
function usage() { sed -n '/^# Usage:/,/^#   org\/site  Site/p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
while [ $# -gt 0 ]; do
    case "${1}" in
	--apply) apply="1" ;;
	--remote) remote="1" ;;
	-*) usage ;;
	*) if [ "${site}" != "" ]; then usage; fi; site="${1,,}" ;;
    esac
    shift
done
if [ "${site}" == "" ]; then usage; fi
if ! drsm_valid_site "${site}" || [ "${site}" == "${DRSM_LEGACY_SITE}" ]; then
    echo "ERROR - Not a site: ${site}, use org/site, not ${DRSM_LEGACY_SITE}"
    exit 1
fi
if [ "${HOSTSdir}" == "" ]; then HOSTSdir="${DRSMHOME}/etc/hosts"; fi
org="${site%%/*}"
sitefile=$(drsm_site_file "${site}")
siteroot=$(drsm_site_root "${site}")
stamp=$(date +%Y%m%d_%H%M%S)

if [ "${apply}" == "1" ]; then
    echo "Removing site ${site} from DRSM"
else
    echo "Dry run, add --apply to remove site ${site} from DRSM"
fi

found="0"
rv=0
# The site's hosts, one at a time so each is saved and checked
args=()
if [ "${apply}" == "1" ]; then args+=(--apply); fi
if [ "${remote}" == "1" ]; then args+=(--remote); fi
shopt -s nullglob
for f in "${HOSTSdir}"/*.conf; do
    case "$(basename "${f}")" in _*) continue ;; esac
    if [ "$(drsm_host_file_site "${f}")" != "${site}" ]; then continue; fi
    declare -A H=()
    drsm_read_conf "${f}" H
    h="${H[HOST]:-$(basename "${f}" .conf)}"
    unset H
    found="1"
    echo "Host ${h}:"
    bash "${DRSMHOME}/utils/drsm_remove_host.sh" "${args[@]}" "${site}/${h}" | sed 's/^/  /'
    if [ "${PIPESTATUS[0]}" != "0" ]; then rv=1; fi
done
shopt -u nullglob

if [ -f "${sitefile}" ]; then
    found="1"
    echo "Site file (backup in $(drsm_sites_dir)/removed):"
    echo "  remove ${sitefile}"
    if [ "${apply}" == "1" ]; then
	mkdir -p "$(drsm_sites_dir)/removed"
	cp -p "${sitefile}" "$(drsm_sites_dir)/removed/${org}_$(basename "${sitefile}").${stamp}"
	rm -f -- "${sitefile}"
	rmdir "$(dirname "${sitefile}")" 2> /dev/null
    fi
fi

if [ -d "${siteroot}" ]; then
    found="1"
    echo "Reports, $(find "${siteroot}" -type f | wc -l) files:"
    echo "  remove ${siteroot}"
    if [ "${apply}" == "1" ]; then rm -rf -- "${siteroot}"; fi
    others=$(find "${REPORTdir}/orgs/${org}" -mindepth 1 -maxdepth 1 -type d ! -path "${siteroot}" | wc -l)
    if [ "${others}" -eq 0 ]; then
	echo "  remove ${REPORTdir}/orgs/${org}, no other site of ${org} is left"
	if [ "${apply}" == "1" ]; then rm -rf -- "${REPORTdir:?}/orgs/${org}"; fi
    fi
fi

if [ "${found}" == "0" ]; then
    echo "ERROR - Nothing found for site ${site} in ${HOSTSdir}, $(drsm_sites_dir) or ${REPORTdir}/orgs"
    exit 1
fi
if [ "${WEBSYNC_DEST}" != "" ]; then
    echo "Remove orgs/${site} from the hosted dashboard at ${WEBSYNC_DEST} by hand, drsm_web_sync.sh no longer copies it"
fi
exit ${rv}
# -----------------------------------------------------------
# *******************************
# ********* End of File *********
# *******************************
