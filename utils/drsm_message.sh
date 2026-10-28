#!/bin/bash
# -----------------------------------------------------------
# BASH Script
# Operating System(s): RHEL/CENTOS
# Run Level(s): 3, 5
# Shell: BASH shell
# Original Author(s): DataReel Software Development
# File Creation Date: 10/28/2026
# Date Last Modified: 10/28/2026
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
# Post, list and remove the status messages that scroll across the top
# of every dashboard page (www/php/drsm_messages.php). Changes are a dry
# run unless --apply.
#
# Usage: drsm_message.sh list
#        drsm_message.sh [--apply] add <info|warning|critical> "<text>" [--link URL] [--until "YYYY-MM-DD HH:MM"] [--pin]
#        drsm_message.sh [--apply] remove <number>
#        drsm_message.sh [--apply] clean
#   list    Every message with its number, level, end time and state
#   add     A new message. --link: a page with the details (http, https
#           or a path on the site), --until: when it ends, --pin: keep it
#           in view instead of scrolling
#   remove  The message with that number (from list)
#   clean   Remove the messages that have ended
# The file is ${MESSAGESfile}, default ${CONFIGdir}/messages.conf.
#
# -----------------------------------------------------------
if [ "${BASEdir}" == "" ]; then export BASEdir="${HOME}/drsm"; fi
if [ -f "${DRSM_CONFIG:-${HOME}/.drsm.sh}" ]; then CONFIG_FILE="${DRSM_CONFIG:-${HOME}/.drsm.sh}"; else CONFIG_FILE="${BASEdir}/etc/drsm.sh"; fi
if [ ! -f "${CONFIG_FILE}" ]; then echo "Missing base config ${CONFIG_FILE}"; exit 1; fi
# shellcheck source=etc/drsm.sh
source "${CONFIG_FILE}"

file="${MESSAGESfile:-${CONFIGdir}/messages.conf}"
function usage() { sed -n '/^# Usage:/,/^#   clean/p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

apply="0"
args=()
while [ $# -gt 0 ]; do
    case "${1}" in
	--apply) apply="1" ;;
	*) args+=("${1}") ;;
    esac
    shift
done
set -- "${args[@]}"
cmd="${1}"
shift

function lines() { if [ -f "${file}" ]; then grep -nvE '^[[:space:]]*(#|$)' "${file}"; fi; }

function write_file()
{
    # $1 == new content file
    if [ "${apply}" == "0" ]; then
	echo "Dry run, ${file} would become:"
	sed 's/^/  /' "${1}"
	echo "Run again with --apply to save it."
	rm -f "${1}"
	return 0
    fi
    if [ -f "${file}" ]; then cp -p "${file}" "${file}.bak"; fi
    mkdir -p "$(dirname "${file}")"
    cat "${1}" > "${file}" && rm -f "${1}"
    chmod 664 "${file}"
    echo "Saved ${file}"
}

case "${cmd}" in
    list)
	n=0
	now=$(date +%s)
	while IFS= read -r l; do
	    n=$((n + 1))
	    IFS='|' read -r level text link until opts <<< "${l#*:}"
	    until="$(echo "${until}" | xargs)"
	    state="current"
	    if [ "${until}" != "" ] && [ "$(date -d "${until}" +%s 2> /dev/null || echo 0)" -lt "${now}" ]; then state="ended"; fi
	    printf '%2d  %-8s %-8s %-17s %s\n' "${n}" "$(echo "${level}" | xargs)" "${state}" "${until:--}" "$(echo "${text}" | xargs)"
	done < <(lines)
	if [ ${n} -eq 0 ]; then echo "No messages in ${file}"; fi
	;;
    add)
	level="${1,,}"; text="${2}"; shift 2
	link=""; until=""; opts=""
	while [ $# -gt 0 ]; do
	    case "${1}" in
		--link) link="${2}"; shift ;;
		--until) until="${2}"; shift ;;
		--pin) opts="pin" ;;
		*) usage ;;
	    esac
	    shift
	done
	if [[ ! "${level}" =~ ^(info|warning|critical)$ ]] || [ "${text}" == "" ]; then usage; fi
	if [[ "${text}${link}${until}" == *"|"* ]]; then echo "ERROR - the text, link and time cannot hold |"; exit 1; fi
	if [ "${link}" != "" ] && [[ ! "${link}" =~ ^(https?://|/)[^[:space:]\"\<\>]*$ ]]; then echo "ERROR - the link must be an http or https URL or a path on the site"; exit 1; fi
	if [ "${until}" != "" ] && ! date -d "${until}" > /dev/null 2>&1; then echo "ERROR - ${until} is not a date and time"; exit 1; fi
	tmp=$(mktemp)
	if [ -f "${file}" ]; then cat "${file}" > "${tmp}"; else printf '# DRSM status messages: level | message | link | until | options\n' > "${tmp}"; fi
	printf '%s | %s | %s | %s | %s\n' "${level}" "${text}" "${link}" "${until}" "${opts}" >> "${tmp}"
	write_file "${tmp}"
	;;
    remove|clean)
	want="${1}"
	if [ "${cmd}" == "remove" ] && [[ ! "${want}" =~ ^[0-9]+$ ]]; then usage; fi
	[ -f "${file}" ] || { echo "No messages in ${file}"; exit 0; }
	tmp=$(mktemp)
	n=0
	now=$(date +%s)
	while IFS= read -r raw || [ -n "${raw}" ]; do
	    if [[ "${raw}" =~ ^[[:space:]]*(#|$) ]]; then echo "${raw}" >> "${tmp}"; continue; fi
	    n=$((n + 1))
	    if [ "${cmd}" == "remove" ] && [ "${n}" == "${want}" ]; then echo "Removing: ${raw}"; continue; fi
	    if [ "${cmd}" == "clean" ]; then
		IFS='|' read -r level text link until opts <<< "${raw}"
		until="$(echo "${until}" | xargs)"
		if [ "${until}" != "" ] && [ "$(date -d "${until}" +%s 2> /dev/null || echo 0)" -lt "${now}" ]; then echo "Removing: ${raw}"; continue; fi
	    fi
	    echo "${raw}" >> "${tmp}"
	done < "${file}"
	write_file "${tmp}"
	;;
    *) usage ;;
esac
exit 0
# -----------------------------------------------------------
# *******************************
# ********* End of File *********
# *******************************
