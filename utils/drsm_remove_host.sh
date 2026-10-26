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
# Usage: drsm_remove_host.sh [--apply] [--remote] [--keep-reports] host
#   --apply         Remove the files, default is to list what would go
#   --remote        Also remove the plugin bundle (${DRSM_REMOTE_BASE},
#                   default drsm_agent) and the older ${REMOTEdir} check
#                   scripts from the host over SSH
#   --keep-reports  Keep ${REPORTdir}/systems/<host>, only stop monitoring
#   host            Host file name in ${HOSTSdir} without .conf, or the
#                   HOST= value inside it
#
# Removed:
#   ${HOSTSdir}/<host>.conf, saved first to ${HOSTSdir}/removed/
#   ${REPORTdir}/systems/<host>/ with its archive and any other per host
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
if [ -f "${HOME}/.drsm.sh" ]; then CONFIG_FILE="${HOME}/.drsm.sh"; else CONFIG_FILE="${BASEdir}/etc/drsm.sh"; fi
if [ ! -f "${CONFIG_FILE}" ]; then echo "ERROR - Missing base config ${CONFIG_FILE}"; exit 1; fi
# shellcheck source=etc/drsm.sh
source "${CONFIG_FILE}"
# shellcheck source=bin/system_functions.sh
source "${DRSMHOME}/bin/system_functions.sh"
# shellcheck source=lib/drsm_conf.sh
source "${DRSMHOME}/lib/drsm_conf.sh"

apply="0"
remote="0"
keep="0"
name=""
function usage() { sed -n '/^# Usage:/,/^#                   HOST= value/p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
while [ $# -gt 0 ]; do
    case "${1}" in
	--apply) apply="1" ;;
	--remote) remote="1" ;;
	--keep-reports) keep="1" ;;
	-*) usage ;;
	*) if [ "${name}" != "" ]; then usage; fi; name="${1}" ;;
    esac
    shift
done
if [ "${name}" == "" ]; then usage; fi
# A host name, never a path
if ! [[ "${name}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
    echo "ERROR - Not a host name: ${name}"
    exit 1
fi

if [ "${HOSTSdir}" == "" ]; then HOSTSdir="${DRSMHOME}/etc/hosts"; fi
if [ "${DRSM_REMOTE_BASE}" == "" ]; then DRSM_REMOTE_BASE="drsm_agent"; fi

# Find the host file by file name, or by the HOST= value inside it
hostfile=""
if [ -f "${HOSTSdir}/${name}.conf" ]; then
    hostfile="${HOSTSdir}/${name}.conf"
else
    for f in "${HOSTSdir}"/*.conf; do
	[ -f "${f}" ] || continue
	case "$(basename "${f}")" in _*) continue ;; esac
	declare -A H=()
	drsm_read_conf "${f}" H
	if [ "${H[HOST]}" == "${name}" ]; then hostfile="${f}"; break; fi
    done
fi

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

if [ "${apply}" == "1" ]; then
    echo "Removing ${host} from DRSM"
else
    echo "Dry run, add --apply to remove ${host} from DRSM"
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

if [ "${keep}" == "0" ] && [ "${REPORTdir}" != "" ] && [ -d "${REPORTdir}/systems/${host}" ]; then
    echo "Reports, $(find "${REPORTdir}/systems/${host}" -type f | wc -l) files:"
    do_remove "${REPORTdir}/systems/${host}"
fi

# Setup from before host files
if [ "${CONFIGdir}" != "" ] && [ -f "${CONFIGdir}/${host}_profile.sh" ]; then
    echo "Old profile:"
    do_backup "${CONFIGdir}/${host}_profile.sh"
    do_remove "${CONFIGdir}/${host}_profile.sh"
fi
for dat in "${CONFIGdir}"/systems.dat "${CONFIGdir}"/*_systems.dat; do
    [ -f "${dat}" ] || continue
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
    echo "ERROR - Nothing found for ${name} in ${HOSTSdir} or ${REPORTdir}/systems"
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
