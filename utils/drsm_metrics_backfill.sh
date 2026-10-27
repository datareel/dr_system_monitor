#!/bin/bash
# -----------------------------------------------------------
# BASH Script
# Operating System(s): RHEL/CENTOS
# Run Level(s): 3, 5
# Shell: BASH shell
# Original Author(s): DataReel Software Development
# File Creation Date: 10/26/2026
# Date Last Modified: 10/26/2026
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
# Builds or fills in the metrics history the trends page reads, from
# the archived host reports in ${REPORTdir}/systems/<host>/archive and
# the offline report archives in ${OFFLINEarchive} (archive.sh). Run it
# once after an upgrade so the trends start with the reports you
# already have. bin/drsm_run.sh keeps the history up to date after that.
# Lines already in a history file are kept; a report time that is
# already there is not added again.
#
# Usage: utils/drsm_metrics_backfill.sh [--apply] [--no-offline] [-s org/site] [host ...]
#
#   --apply       Write the history files. Without it the script only
#                 lists how many report lines it would add (dry run).
#   --no-offline  Skip the offline .tar.gz archives
#   -s            Hosts of this site, in ${REPORTdir}/orgs/<org>/<site>,
#                 default the hosts in no site
#   host          Only these hosts, default every host in the site
#
# -----------------------------------------------------------
if [ "${BASEdir}" == "" ]; then export BASEdir="${HOME}/drsm"; fi

if [ -f ${HOME}/.drsm.sh ]; then
    CONFIG_FILE=${HOME}/.drsm.sh
else
    CONFIG_FILE=${BASEdir}/etc/drsm.sh
fi

if [ ! -f ${CONFIG_FILE} ]; then
    echo "ERROR - Missing base config ${CONFIG_FILE}"
    exit 1
fi

source ${CONFIG_FILE}
source ${DRSMHOME}/lib/drsm_history.sh
# shellcheck source=lib/drsm_conf.sh
source "${DRSMHOME}/lib/drsm_conf.sh"
# shellcheck source=lib/drsm_sites.sh
source "${DRSMHOME}/lib/drsm_sites.sh"

apply="0"
offline="1"
hosts=()
site="${DRSM_LEGACY_SITE}"
while [ $# -gt 0 ]
do
    case ${1} in
	--apply) apply="1" ;;
	--no-offline) offline="0" ;;
	-s) site="${2,,}"; shift ;;
	-*) echo "Usage: $0 [--apply] [--no-offline] [-s org/site] [host ...]"; exit 1 ;;
	*) hosts+=("${1}") ;;
    esac
    shift
done

if ! drsm_valid_site "${site}"; then
    echo "ERROR - Site ${site} is not org/site"
    exit 1
fi
# Host folders of the site, and the same folders inside the archives
SYSdir="$(drsm_site_root "${site}")/systems"
if [ "${site}" == "${DRSM_LEGACY_SITE}" ]; then
    archpath="*/systems"
else
    archpath="*/orgs/${site}/systems"
fi
if [ ! -d "${SYSdir}" ]; then
    echo "ERROR - Missing report directory ${SYSdir}"
    exit 1
fi
if [ ${#hosts[@]} -eq 0 ]; then
    for d in "${SYSdir}"/*/; do
	[ -d "${d}" ] && hosts+=("$(basename "${d}")")
    done
fi

work=$(mktemp -d "${TMPDIR:-/tmp}/drsm_backfill.XXXXXX") || exit 1
trap 'rm -rf "${work}"' EXIT

# Unpack only the host report archives from the offline archives
if [ "${offline}" == "1" ] && [ -d "${OFFLINEarchive}" ]; then
    n=0
    while read -r tgz
    do
	n=$((n + 1))
	mkdir -p "${work}/offline/${n}"
	tar xzf "${tgz}" -C "${work}/offline/${n}" --wildcards '*/systems/*/archive/*_report_*.txt' 2> /dev/null
    done < <(find "${OFFLINEarchive}" -name "*.tar.gz" -type f | sort)
    echo "INFO - Read ${n} offline archive(s) from ${OFFLINEarchive}"
fi

if [ "${apply}" == "0" ]; then echo "INFO - Dry run, use --apply to write the history files"; fi

for host in "${hosts[@]}"
do
    if [[ ! "${host}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
	echo "WARNING - Skipping bad host name ${host}"
	continue
    fi
    hist="${SYSdir}/${host}/${DRSM_HISTORY_FILE}"
    new="${work}/${host}.new"
    : > "${new}"
    while read -r f
    do
	drsm_history_line "${f}" >> "${new}"
    done < <(
	# The default site's hosts are the ones outside orgs/
	if [ "${site}" == "${DRSM_LEGACY_SITE}" ]; then
	    find "${SYSdir}/${host}/archive" "${work}/offline" -path "${archpath}/${host}/archive/${host}_report_*.txt" ! -path "*/orgs/*" -type f 2> /dev/null
	else
	    find "${SYSdir}/${host}/archive" "${work}/offline" -path "${archpath}/${host}/archive/${host}_report_*.txt" -type f 2> /dev/null
	fi)

    # Merge, one line per report time, oldest first. Existing lines win.
    touch "${work}/${host}.old"
    if [ -s "${hist}" ]; then cp "${hist}" "${work}/${host}.old"; fi
    cat "${work}/${host}.old" "${new}" | awk -F '\t' '$1 ~ /^[0-9]+$/ && !seen[$1]++' | sort -t "$(printf '\t')" -k1,1n > "${work}/${host}.merged"
    before=$(wc -l < "${work}/${host}.old")
    after=$(wc -l < "${work}/${host}.merged")
    echo "${host}: $(wc -l < "${new}") archived reports, ${before} lines in history, $((after - before)) to add"
    if [ "${apply}" == "1" ] && [ "${after}" -gt "${before}" ]; then
	cat "${work}/${host}.merged" > "${hist}"
	drsm_history_trim "${hist}"
    fi
done

exit 0
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
