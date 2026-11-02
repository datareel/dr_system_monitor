#!/bin/bash
# ----------------------------------------------------------- 
# BASH Script
# Operating System(s): RHEL/CENTOS
# Run Level(s): 3, 5
# Shell: BASH shell
# Original Author(s): DataReel Software Development
# File Creation Date: 10/25/2026
# Date Last Modified: 10/25/2026
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
# Shared functions for the windows/* plugins, which read the last
# report the DataReel Reporting Agent sent for a host. The wra
# collector sets DRSM_WRA_REPORT. To run a plugin by hand:
#
#   DRSM_TARGET=laptop1 DRSM_WRA_REPORT=/path/laptop1_windows_report_agent.txt \
#       bash ~/drsm/plugins/windows/checkin/check.sh
#
# ----------------------------------------------------------- 
WRA_HOST="${DRSM_TARGET:-${HOST}}"

# DRSM 1.31 has no drsm_detail, the agent's drsm/install.sh supports it
if ! declare -F drsm_detail > /dev/null; then
    function drsm_detail() { echo "DETAIL ${1}=${2}"; }
fi

function wra_load_report()
{
    # Sets REPORT to the report path. Without a report it prints
    # UNKNOWN and returns 1, call it as: wra_load_report || drsm_exit
    # windows/checkin turns a missing report into an ERROR itself.
    REPORT="${DRSM_WRA_REPORT}"
    if [ "${REPORT}" == "" ]; then
	drsm_unknown "${WRA_HOST} DRSM_WRA_REPORT is not set, use COLLECTOR=wra for Windows hosts"
	return 1
    fi
    if [ ! -s "${REPORT}" ]; then
	drsm_unknown "${WRA_HOST} has no Windows agent report, see windows/checkin"
	return 1
    fi
    return 0
}

function wra_field()
{
    # Value of a "KEY: value" header line, $1 == key, $2 == report
    sed -n "s/^${1}: *//p" "${2}" | head -1 | tr -d '\r'
}

function wra_section()
{
    # Lines between "NAME:" and "END NAME", $1 == name, $2 == report
    awk -v b="${1}:" -v e="END ${1}" '
	{ sub(/\r$/, "") }
	$0 == e { on = 0 }
	on { print }
	$0 == b { on = 1 }' "${2}"
}

function wra_has_section()
{
    grep -q "^${1}:" "${2}"
}

function wra_kv()
{
    # Splits name=value lines on stdin into tab separated fields in the
    # order of the names given, for example
    #   wra_section "VULNERABILITIES" "${REPORT}" | sed -n 's/^advisory //p' | wra_kv id severity
    # Quoted values ("..." with \" and \\ escapes) keep their spaces.
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

function wra_newest_date()
{
    # Newest of the dates on stdin as YYYY-MM-DD. Takes the agent's
    # patch dates (2026-10-5) and hotfix dates (10/5/2026).
    awk '
	/^[0-9]+-[0-9]+-[0-9]+$/ { split($0, a, "-"); printf "%04d-%02d-%02d\n", a[1], a[2], a[3]; next }
	/^[0-9]+\/[0-9]+\/[0-9]+$/ { split($0, a, "/"); printf "%04d-%02d-%02d\n", a[3], a[1], a[2] }' | sort | tail -1
}
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
