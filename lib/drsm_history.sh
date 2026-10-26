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
# Metrics history for the trends page. Each host keeps one line per
# report in ${REPORTdir}/systems/<host>/metrics_history.tsv:
#
#   <epoch><TAB>name{labels}=value<TAB>name=value ...
#
# The values are the METRIC lines of the report, so new plugin metrics
# are kept without changes here. Older reports that came before the
# size metrics get cpu_count, mem_total_mb and swap_total_mb from the
# report text. Reports are kept for days, this file for
# ${HISTORYdays} days (default 730), so trends cover years.
#
# ----------------------------------------------------------- 
DRSM_HISTORY_FILE="metrics_history.tsv"

function drsm_history_line()
{
    # One history line for report $1, nothing if it has no ETIME or
    # no metrics
    awk '
	function add(k, v) { if (!(k in seen)) { seen[k] = 1; out = out "\t" k "=" v } }
	/^ETIME:[0-9]+$/ && etime == "" { etime = substr($0, 7) }
	/^METRIC [A-Za-z0-9_.]+(\{[^\t]*\})?=-?[0-9.]+/ {
	    s = substr($0, 8)
	    p = index(s, "=")
	    while (substr(s, p + 1) !~ /^-?[0-9.]+$/ && p > 0) {
		q = index(substr(s, p + 1), "="); if (q == 0) break; p += q
	    }
	    add(substr(s, 1, p - 1), substr(s, p + 1))
	}
	/^Total CPUs: [0-9]+/ { d["cpu_count"] = $3 }
	/^Total physical: [0-9]+/ { d["mem_total_mb"] = $3 }
	/^Total SWAP: [0-9]+/ { d["swap_total_mb"] = $3 }
	END {
	    # No metrics when the host was down: leave a gap, not a line
	    if (etime == "" || (out == "" && length(d) == 0)) exit
	    for (k in d) add(k, d[k])
	    print etime out
	}' "${1}"
}

function drsm_history_append()
{
    # Add report $1 to history file $2 when it is newer than the last line
    local line last
    line=$(drsm_history_line "${1}")
    if [ "${line}" == "" ]; then return 0; fi
    last=0
    if [ -s "${2}" ]; then last=$(tail -n 1 "${2}" | cut -f 1); fi
    if [[ ! "${last}" =~ ^[0-9]+$ ]]; then last=0; fi
    if [ "${line%%$'\t'*}" -le "${last}" ]; then return 0; fi
    echo "${line}" >> "${2}"
    drsm_history_trim "${2}"
}

function drsm_history_trim()
{
    # Drop lines older than ${HISTORYdays} from history file $1. Only
    # rewrites the file when the oldest line is a day past the limit.
    local days="${HISTORYdays:-730}" first cutoff tmp
    if [ ! -s "${1}" ] || [ "${days}" -le 0 ]; then return 0; fi
    cutoff=$(( $(date +%s) - days * 86400 ))
    first=$(head -n 1 "${1}" | cut -f 1)
    if [[ ! "${first}" =~ ^[0-9]+$ ]] || [ "${first}" -ge $(( cutoff - 86400 )) ]; then return 0; fi
    # Hidden temp name, drsm_web_sync.sh skips .*.tmp files
    tmp="$(dirname "${1}")/.$(basename "${1}").tmp"
    awk -F '\t' -v c="${cutoff}" '$1 >= c' "${1}" > "${tmp}" && mv -f "${tmp}" "${1}"
}
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
