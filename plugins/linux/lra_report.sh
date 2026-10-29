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
# Shared functions for the linux/* plugins, which read the last report
# the DataReel Reporting Agent for Linux sent for a host. The lra
# collector sets DRSM_LRA_REPORT. To run a plugin by hand:
#
#   DRSM_TARGET=web1 DRSM_LRA_REPORT=/path/web1_linux_report_agent.txt \
#       bash ~/drsm/plugins/linux/checkin/check.sh
#
# Report sections hold name=value lines; values with spaces are quoted
# with \" and \\ escapes, for example mount="/data 1" used_pct=4.0
#
# ----------------------------------------------------------- 
LRA_HOST="${DRSM_TARGET:-${HOST}}"

# DRSM 1.31 has no drsm_detail
if ! declare -F drsm_detail > /dev/null; then
    function drsm_detail() { echo "DETAIL ${1}=${2}"; }
fi

function lra_load_report()
{
    # Sets REPORT to the report path. Without a report it prints
    # UNKNOWN and returns 1, call it as: lra_load_report || drsm_exit
    # linux/checkin turns a missing report into an ERROR itself.
    REPORT="${DRSM_LRA_REPORT}"
    if [ "${REPORT}" == "" ]; then
	drsm_unknown "${LRA_HOST} DRSM_LRA_REPORT is not set, use COLLECTOR=lra for Linux agent hosts"
	return 1
    fi
    if [ ! -s "${REPORT}" ]; then
	drsm_unknown "${LRA_HOST} has no Linux agent report, see linux/checkin"
	return 1
    fi
    return 0
}

function lra_field()
{
    # Value of a "KEY: value" header line, $1 == key, $2 == report
    sed -n "s/^${1}: *//p" "${2}" | head -1 | tr -d '\r'
}

function lra_section()
{
    # Lines between "NAME:" and "END NAME", $1 == name, $2 == report
    awk -v b="${1}:" -v e="END ${1}" '
	{ sub(/\r$/, "") }
	$0 == e { on = 0 }
	on { print }
	$0 == b { on = 1 }' "${2}"
}

function lra_has_section()
{
    grep -q "^${1}:" "${2}"
}

function lra_kv()
{
    # Splits name=value lines on stdin into tab separated fields in the
    # order of the names given, for example
    #   lra_section "DISK USAGE" "${REPORT}" | lra_kv mount used_pct
    # Quoted values keep their spaces; tabs and newlines never appear.
    awk -v names="$*" '
	BEGIN { n = split(names, want, " ") }
	{
	    delete v
	    s = $0
	    while (match(s, /^[ ]*[A-Za-z0-9_]+=/)) {
		key = substr(s, RSTART, RLENGTH - 1)
		sub(/^[ ]*/, "", key)
		s = substr(s, RSTART + RLENGTH)
		if (substr(s, 1, 1) == "\"") {
		    val = ""
		    i = 2
		    while (i <= length(s)) {
			c = substr(s, i, 1)
			if (c == "\\") { val = val substr(s, i + 1, 1); i += 2; continue }
			if (c == "\"") break
			val = val c
			i++
		    }
		    s = substr(s, i + 1)
		}
		else {
		    match(s, /^[^ ]*/)
		    val = substr(s, 1, RLENGTH)
		    s = substr(s, RLENGTH + 1)
		}
		v[key] = val
	    }
	    out = ""
	    for (i = 1; i <= n; i++) out = out (i > 1 ? "\t" : "") v[want[i]]
	    print out
	}'
}

function lra_value()
{
    # Value of name in a section of single name=value lines,
    # $1 == section, $2 == name, $3 == report
    lra_section "${1}" "${3}" | sed -n "s/^${2}=//p" | head -1 | sed 's/^"\(.*\)"$/\1/'
}
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# *******************************
