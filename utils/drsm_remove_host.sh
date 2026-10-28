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
# Stop monitoring a host and remove its reports. Dry run unless --apply.
#
# Usage: drsm_remove_host.sh [--apply] [--remote] [--keep-reports] [org/site/]host
#        drsm_remove_host.sh [--apply] [--remote] [--keep-reports] -f list
#   --apply         Remove the files, default is to list what would go
#   --remote        Also remove the plugin bundle (${DRSM_REMOTE_BASE},
#                   default drsm_agent) and the older ${REMOTEdir} check
#                   scripts from the host over SSH
#   --keep-reports  Keep ${REPORTdir}/systems/<host>, only stop monitoring
#   host            Host file name in ${HOSTSdir} without .conf, or the
#                   HOST= value inside it. Use org/site/host when two
#                   sites have a host with that name.
#   -f list         A file with one host per line (# starts a comment),
#                   each removed as above
#
# Removed:
#   ${HOSTSdir}/<host>.conf, saved first to ${HOSTSdir}/removed/
#   ${REPORTdir}/systems/<host>/, or orgs/<org>/<site>/systems/<host>/
#   for a host in a site, with its archive and any other per host
#   files kept there, such as metrics history
#   ${CONFIGdir}/<host>_profile.sh and the <host> lines of systems.dat
#   and *_systems.dat, used before the move to host files (saved to
#   ${HOSTSdir}/removed/ first)
#
# The host drops out of the group reports on the next drsm_run.sh run.
# A Web only copy fed by utils/drsm_web_sync.sh loses the host on the
# next sync, which deletes files that are gone from ${REPORTdir}.
#
# -----------------------------------------------------------
if [ "${BASEdir}" == "" ]; then export BASEdir="${HOME}/drsm"; fi
if [ -f "${DRSM_CONFIG:-${HOME}/.drsm.sh}" ]; then CONFIG_FILE="${DRSM_CONFIG:-${HOME}/.drsm.sh}"; else CONFIG_FILE="${BASEdir}/etc/drsm.sh"; fi
if [ ! -f "${CONFIG_FILE}" ]; then echo "ERROR - Missing base config ${CONFIG_FILE}"; exit 1; fi
# shellcheck source=etc/drsm.sh
source "${CONFIG_FILE}"
# shellcheck source=bin/system_functions.sh
source "${DRSMHOME}/bin/system_functions.sh"
# shellcheck source=lib/drsm_conf.sh
source "${DRSMHOME}/lib/drsm_conf.sh"
# shellcheck source=lib/drsm_sites.sh
source "${DRSMHOME}/lib/drsm_sites.sh"

apply="0"
remote="0"
keep="0"
name=""
list=""
function usage() { sed -n '/^# Usage:/,/^#                   sites have a host/p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
while [ $# -gt 0 ]; do
    case "${1}" in
	--apply) apply="1" ;;
	--remote) remote="1" ;;
	--keep-reports) keep="1" ;;
	-f) list="${2}"; shift ;;
	-*) usage ;;
	*) if [ "${name}" != "" ]; then usage; fi; name="${1}" ;;
    esac
    shift
done
if [ "${list}" != "" ]; then
    # One run of this script for each host in the list
    if [ "${name}" != "" ] || [ ! -r "${list}" ]; then usage; fi
    opts=()
    if [ "${apply}" == "1" ]; then opts+=(--apply); fi
    if [ "${remote}" == "1" ]; then opts+=(--remote); fi
    if [ "${keep}" == "1" ]; then opts+=(--keep-reports); fi
    rv=0
    while IFS= read -r h || [ -n "${h}" ]; do
	h="${h%%#*}"
	h="${h//[[:space:]]/}"
	if [ "${h}" == "" ]; then continue; fi
	echo "== ${h}"
	bash "$0" "${opts[@]}" "${h}" || rv=1
    done < "${list}"
    exit ${rv}
fi
if [ "${name}" == "" ]; then usage; fi
# org/site/host names the site
wantsite=""
if [[ "${name}" == */*/* ]]; then
    wantsite="${name%/*}"
    wantsite="${wantsite,,}"
    name="${name##*/}"
    if ! drsm_valid_site "${wantsite}"; then
	echo "ERROR - Not a site: ${wantsite}"
	exit 1
    fi
fi
# A host name, never a path
if ! [[ "${name}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
    echo "ERROR - Not a host name: ${name}"
    exit 1
fi

if [ "${HOSTSdir}" == "" ]; then HOSTSdir="${DRSMHOME}/etc/hosts"; fi
if [ "${DRSM_REMOTE_BASE}" == "" ]; then DRSM_REMOTE_BASE="drsm_agent"; fi

# Find the host by its file name or HOST= value, in every site or the
# one asked for, and by its reports for hosts with no host file
declare -A FOUND=()
for f in "${HOSTSdir}"/*.conf; do
    [ -f "${f}" ] || continue
    case "$(basename "${f}")" in _*) continue ;; esac
    declare -A H=()
    drsm_read_conf "${f}" H
    if [ "${H[HOST]}" == "${name}" ] || { [ "${H[HOST]}" == "" ] && [ "$(basename "${f}" .conf)" == "${name}" ]; }; then
	fs=$(drsm_host_file_site "${f}")
	if [ "${wantsite}" == "" ] || [ "${wantsite}" == "${fs}" ]; then FOUND[${fs}]="${f}"; fi
    elif [ "$(basename "${f}" .conf)" == "${name}" ] && [ "${wantsite}" == "" ]; then
	FOUND[$(drsm_host_file_site "${f}")]="${f}"
    fi
    unset H
done
for d in "${REPORTdir}/systems/${name}" "${REPORTdir}"/orgs/*/*/systems/"${name}"; do
    [ -d "${d}" ] || continue
    if [ "${d}" == "${REPORTdir}/systems/${name}" ]; then
	fs="${DRSM_LEGACY_SITE}"
    else
	fs="${d#"${REPORTdir}/orgs/"}"
	fs="${fs%/systems/*}"
    fi
    if [ "${wantsite}" != "" ] && [ "${wantsite}" != "${fs}" ]; then continue; fi
    if [ "${FOUND[${fs}]+set}" != "set" ]; then FOUND[${fs}]=""; fi
done
if [ ${#FOUND[@]} -gt 1 ]; then
    echo "ERROR - ${name} is in more than one site, use org/site/host:"
    for fs in $(printf '%s\n' "${!FOUND[@]}" | sort); do echo "  ${fs}/${name}"; done
    exit 1
fi
site="${wantsite:-$(drsm_default_site)}"
hostfile=""
if [ ${#FOUND[@]} -eq 1 ]; then
    site="${!FOUND[*]}"
    hostfile="${FOUND[${site}]}"
fi
hostreports="$(drsm_site_root "${site}")/systems"

host="${name}"
collector="ssh"
if [ "${hostfile}" != "" ]; then
    declare -A HCONF=()
    drsm_read_conf "${hostfile}" HCONF
    if [ "${HCONF[HOST]}" != "" ]; then host="${HCONF[HOST]}"; fi
    if [ "${HCONF[COLLECTOR]}" != "" ]; then collector="${HCONF[COLLECTOR]}"; fi
fi
if ! [[ "${host}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
    echo "ERROR - Not a host name: ${host}"
    exit 1
fi

label="${host}"
if [ "${site}" != "${DRSM_LEGACY_SITE}" ]; then label="${site}/${host}"; fi
if [ "${apply}" == "1" ]; then
    echo "Removing ${label} from DRSM"
else
    echo "Dry run, add --apply to remove ${label} from DRSM"
fi

found="0"
stamp=$(date +%Y%m%d_%H%M%S)
backupdir="${HOSTSdir}/removed"

function do_backup() {
    # $1 == file to save before it is removed or changed
    if [ "${apply}" == "1" ]; then
	mkdir -p "${backupdir}"
	cp -p "${1}" "${backupdir}/$(basename "${1}").${stamp}"
    fi
}

function do_remove() {
    # $1 == file or directory
    found="1"
    echo "  remove ${1}"
    if [ "${apply}" == "1" ]; then rm -rf -- "${1}"; fi
}

if [ "${hostfile}" != "" ]; then
    echo "Host file (backup in ${backupdir}):"
    do_backup "${hostfile}"
    do_remove "${hostfile}"
fi

if [ "${keep}" == "0" ] && [ "${REPORTdir}" != "" ] && [ -d "${hostreports}/${host}" ]; then
    echo "Reports, $(find "${hostreports}/${host}" -type f | wc -l) files:"
    do_remove "${hostreports}/${host}"
fi

# Setup from before host files, only in the default site
if [ "${site}" != "${DRSM_LEGACY_SITE}" ]; then
    :
elif [ "${CONFIGdir}" != "" ] && [ -f "${CONFIGdir}/${host}_profile.sh" ]; then
    echo "Old profile:"
    do_backup "${CONFIGdir}/${host}_profile.sh"
    do_remove "${CONFIGdir}/${host}_profile.sh"
fi
for dat in "${CONFIGdir}"/systems.dat "${CONFIGdir}"/*_systems.dat; do
    [ -f "${dat}" ] || continue
    if [ "${site}" != "${DRSM_LEGACY_SITE}" ]; then continue; fi
    if grep -q "^${host}," "${dat}"; then
	found="1"
	echo "Line in ${dat}:"
	grep "^${host}," "${dat}" | sed 's/^/  remove line: /'
	if [ "${apply}" == "1" ]; then
	    do_backup "${dat}"
	    grep -v "^${host}," "${dat}" > "${dat}.tmp.$$"
	    cat "${dat}.tmp.$$" > "${dat}"
	    rm -f "${dat}.tmp.$$"
	fi
    fi
done

if [ "${remote}" == "1" ]; then
    if [ "${collector}" != "ssh" ]; then
	echo "Collector is ${collector}, nothing to remove on ${host}"
    else
	found="1"
	echo "On ${host} over SSH:"
	echo "  remove ~/${DRSM_REMOTE_BASE} ~/${REMOTEdir}"
	if [ "${apply}" == "1" ]; then
	    # shellcheck disable=SC2086
	    if ! ${DRSM_SSH:-ssh} ${SSH_OPTS} "${host}" "rm -rf -- ${DRSM_REMOTE_BASE} ${REMOTEdir}"; then
		echo "WARNING - Could not remove the DRSM files on ${host}"
	    fi
	fi
    fi
fi

if [ "${found}" == "0" ]; then
    echo "ERROR - Nothing found for ${name} in ${HOSTSdir} or ${hostreports}"
    exit 1
fi
if [ "${WEBSYNC_DEST}" != "" ]; then
    echo "The hosted dashboard at ${WEBSYNC_DEST} drops ${host} on the next drsm_web_sync.sh --apply"
fi
exit 0
# -----------------------------------------------------------
# *******************************
# ********* End of File *********
# *******************************
