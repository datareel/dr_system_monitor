#!/bin/bash
# ----------------------------------------------------------- 
# BASH Script
# Operating System(s): RHEL/CENTOS
# Run Level(s): 3, 5
# Shell: BASH shell
# Original Author(s): DataReel Software Development
# File Creation Date: 10/23/2026
# Date Last Modified: 10/23/2026
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
# Collector for Linux hosts over keyed SSH. The plugins a host needs
# are copied as one tar stream into DRSM_REMOTE_BASE in the remote
# user's home directory. The copy is skipped when the remote
# checksum matches, so most runs cost a single SSH session.
# See collectors/local.sh for the collector functions.
#
# ----------------------------------------------------------- 
if [ "${DRSM_REMOTE_BASE}" == "" ]; then DRSM_REMOTE_BASE="drsm_agent"; fi
if [ "${DRSM_SSH}" == "" ]; then DRSM_SSH="ssh"; fi
COLLECTOR_BASE="${DRSM_REMOTE_BASE}"

function collector_check()
{
    # shellcheck disable=SC2086
    ${DRSM_SSH} ${SSH_OPTS} "${1}" "hostname -s" &> /dev/null
}

function collector_sync()
{
    local host="${1}"
    shift
    local files=("lib/drsm_plugin.sh") id sum remote
    for id in "$@"; do files+=("plugins/${id}"); done
    sum=$(tar -cf - -C "${DRSMHOME}" --mtime='2000-01-01' --owner=0 --group=0 --sort=name "${files[@]}" 2> /dev/null | md5sum | awk '{ print $1 }')
    # shellcheck disable=SC2086
    remote=$(${DRSM_SSH} ${SSH_OPTS} "${host}" "cat ${DRSM_REMOTE_BASE}/.bundle_md5 2> /dev/null")
    if [ "${sum}" == "${remote}" ]; then return 0; fi
    # shellcheck disable=SC2086
    tar -czf - -C "${DRSMHOME}" "${files[@]}" | ${DRSM_SSH} ${SSH_OPTS} "${host}" \
	"mkdir -p ${DRSM_REMOTE_BASE} && tar -xzf - -C ${DRSM_REMOTE_BASE} && echo ${sum} > ${DRSM_REMOTE_BASE}/.bundle_md5"
}

function collector_exec()
{
    # shellcheck disable=SC2086
    ${DRSM_SSH} ${SSH_OPTS} "${1}" "bash -s" < "${2}"
}
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
