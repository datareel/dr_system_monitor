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
# Job runner functions. drsm_run.sh writes a job script made of this
# file followed by one drsm_job_plugin call per plugin, then runs
# the job on the target with bash, locally or over SSH. Each plugin's
# output is framed by marker lines that drsm_run.sh parses:
#
#   @@DRSM_BEGIN <plugin id>
#   ...plugin output...
#   @@DRSM_END <plugin id> <exit code> <seconds>
#
# ----------------------------------------------------------- 
# DRSM_BASE is set by the job before calling drsm_job_plugin. A
# relative path is relative to the home directory of the remote user.
function drsm_job_base()
{
    if [ "${DRSM_BASE:0:1}" != "/" ]; then DRSM_BASE="${HOME}/${DRSM_BASE}"; fi
    export DRSM_BASE
}

function drsm_job_plugin()
{
    # $1 == plugin ID, $2 == timeout in seconds, $3 == entry script,
    # $4 == required commands, the rest are NAME=value settings
    local id="${1}" t="${2}" entry="${3}" req="${4}"
    shift 4
    local dir="${DRSM_BASE}/plugins/${id}"
    local rc=0 start c missing=""
    local h
    h=$(hostname -s 2> /dev/null || hostname)
    echo "@@DRSM_BEGIN ${id}"
    start=$(date +%s)
    for c in ${req}; do
	command -v "${c}" &> /dev/null || missing="${missing} ${c}"
    done
    if [ ! -f "${dir}/${entry}" ]; then
	echo "UNKNOWN - ${h} plugin ${id} is not installed in ${dir}"
	rc=3
    elif [ "${missing}" != "" ]; then
	echo "UNKNOWN - ${h} plugin ${id} needs missing command(s):${missing}"
	rc=3
    else
	( cd "${dir}" && exec env DRSM_LIB="${DRSM_BASE}/lib" DRSM_PLUGIN_ID="${id}" "$@" \
	    timeout -k 5 "${t}" bash "./${entry}" ) < /dev/null 2>&1
	rc=$?
	if [ ${rc} -eq 124 ] || [ ${rc} -eq 137 ]; then
	    echo "WARNING - ${h} plugin ${id} timed out after ${t} seconds"
	    rc=1
	elif [ ${rc} -gt 3 ]; then
	    echo "WARNING - ${h} plugin ${id} failed with exit code ${rc}"
	    rc=1
	fi
    fi
    echo "@@DRSM_END ${id} ${rc} $(( $(date +%s) - start ))"
}
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
