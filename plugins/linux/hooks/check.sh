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
# DRSM plugin: the HOOKS section of the last DataReel Reporting Agent
# for Linux report. Each hook is a site script in /etc/drra/report.d
# on the host; this shows every hook's output and takes the worst
# state of their exit codes (0 OK, 1 WARNING, 2 ERROR, 3 UNKNOWN). A
# plugin with LRA_HOOK=<name> in its manifest shows one hook as its
# own check instead; list those hooks in SKIP.
#
# ----------------------------------------------------------- 
# shellcheck source=lib/drsm_plugin.sh
source "${DRSM_LIB:-$(dirname "$0")/../../../lib}/drsm_plugin.sh"
# shellcheck source=plugins/linux/lra_report.sh
source "$(dirname "$0")/../lra_report.sh"

SKIP=$(drsm_setting SKIP NONE)
NONE_OK=$(drsm_setting NONE_OK 1)

lra_load_report || drsm_exit
LINES=$(drsm_lra_hook_lines "${REPORT}" "")
shown=0
skip=0
while IFS= read -r line
do
    case "${line}" in
	hook=*)
	    name=$(echo "${line}" | sed -n 's/^hook=\([^ ]*\) .*/\1/p')
	    skip=0
	    if ! drsm_is_none "${SKIP}"; then
		for s in ${SKIP}; do if [ "${s}" == "${name}" ]; then skip=1; fi; done
	    fi
	    [ ${skip} -eq 1 ] && continue
	    rc=$(echo "${line}" | sed -n 's/.* exit=\(-\?[0-9]*\).*/\1/p')
	    secs=$(echo "${line}" | sed -n 's/.* secs=\([0-9]*\).*/\1/p')
	    timed=$(echo "${line}" | sed -n 's/.* timed_out=\([01]\).*/\1/p')
	    shown=$((shown + 1))
	    echo ""
	    echo "Hook ${name}: exit ${rc}, ${secs} seconds"
	    if [ "${timed}" == "1" ]; then
		drsm_crit "${LRA_HOST} report hook ${name} timed out on the host"
		rc=2
	    fi
	    case "${rc}" in
		0) ;;
		1) DRSM_HAS_WARNING=1 ;;
		2) DRSM_HAS_ERROR=1 ;;
		3) DRSM_HAS_UNKNOWN=1 ;;
		*) drsm_crit "${LRA_HOST} report hook ${name} exited ${rc}" ;;
	    esac
	    ;;
	skipped=*)
	    name=$(echo "${line}" | sed -n 's/^skipped="\([^"]*\)".*/\1/p')
	    why=$(echo "${line}" | sed -n 's/.* reason="\([^"]*\)".*/\1/p')
	    drsm_warn "${LRA_HOST} report hook ${name} was skipped by the agent: ${why}"
	    ;;
	"| "*)
	    [ ${skip} -eq 1 ] && continue
	    echo "${line#| }"
	    ;;
    esac
done <<< "${LINES}"
if [ ${shown} -eq 0 ]; then
    if [ "${NONE_OK}" == "1" ]; then
	drsm_ok "${LRA_HOST} has no report hooks to show"
    else
	drsm_unknown "${LRA_HOST} agent report has no report hooks"
    fi
else
    drsm_metric lra_hooks "${shown}"
fi
drsm_exit
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
