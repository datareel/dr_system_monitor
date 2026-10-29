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
# <http://www.gnu.org/licenses/>.
#
# Shared probe for hook uploads: reports from other sources (a manual
# scan, a custom application, a backup job) that a DataReel Reporting
# Agent sends to hook.php on the report server. Each upload hook is a
# plugin folder plugins/uploads/<id>/ with a plugin.conf manifest and a probe.sh
# that sources this file. hook.php has already turned the payload into
# lines (latest.lines); this probe checks the data's age, applies the
# manifest rules and prints the lines for the dashboard.
#
# Runs on the monitor host. drsm_run.sh sets DRSM_UPLOADS_DIR (UPLOADS_DIR
# in the host file), DRSM_UPLOAD_NAME and DRSM_UPLOAD_ID. The data is in
#
#   ${DRSM_UPLOADS_DIR}/<name>/<id>/latest.{data,lines,meta}
#
# Manifest settings (override per host with uploads_<id>_<SETTING>=value):
#   TITLE          name on the dashboard
#   DISPLAY        table, kv, text or html (www/php/drsm_uploads.php), or
#                  the name of a site display plug-in
#   MAX_AGE_HOURS  warning when the data is older, 0 = no check
#   WARN_IF        rules, for example 'fail_high > 0 or score < 80'
#   CRIT_IF        same, an ERROR when one matches
#   METRICS        values kept for the trends page, as <id>_<name>
#   MAX_LINES      most lines printed
#
# A rule is <value name> <op> <number or word>, op one of > >= < <= ==
# !=, several joined with " or ". Names are the UPLOAD value|<name>| and
# METRIC <name> lines of the data; "rows" is the row count of a table.
#
# -----------------------------------------------------------
# shellcheck source=lib/drsm_plugin.sh
source "${DRSM_LIB:-$(dirname "$0")/../../../lib}/drsm_plugin.sh"

function upload_meta()
{
    # Value of "KEY: value" line $1 in meta file $2
    sed -n "s/^${1}: //p" "${2}" | head -1
}

function upload_rules()
{
    # Print each rule in $2 that matches the values in file $1, as
    # "<rule> (<name> is <value>)"
    awk -v rules="${2}" '
	function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
	function isnum(s) { return s ~ /^-?[0-9]+(\.[0-9]+)?$/ }
	{
	    if ($0 ~ /^UPLOAD value\|/) {
		line = substr($0, 14)
		p = index(line, "|")
		if (p > 0) val[substr(line, 1, p - 1)] = substr(line, p + 1)
	    } else if ($0 ~ /^UPLOAD row\|/) {
		nrows++
	    } else if ($0 ~ /^METRIC [A-Za-z0-9_.]+=/) {
		line = substr($0, 8)
		p = index(line, "=")
		val[substr(line, 1, p - 1)] = substr(line, p + 1)
	    }
	}
	END {
	    if (!("rows" in val)) val["rows"] = nrows + 0
	    n = split(rules, parts, / or /)
	    for (i = 1; i <= n; i++) {
		r = trim(parts[i])
		if (r == "") continue
		if (match(r, /(>=|<=|==|!=|>|<)/) == 0) { print "BAD|" r; continue }
		name = trim(substr(r, 1, RSTART - 1))
		op = substr(r, RSTART, RLENGTH)
		want = trim(substr(r, RSTART + RLENGTH))
		gsub(/^["\047]|["\047]$/, "", want)
		if (!(name in val)) continue
		have = val[name]
		if (isnum(have) && isnum(want)) { a = have + 0; b = want + 0 } else { a = have ""; b = want "" }
		hit = 0
		if (op == ">" && a > b) hit = 1
		else if (op == ">=" && a >= b) hit = 1
		else if (op == "<" && a < b) hit = 1
		else if (op == "<=" && a <= b) hit = 1
		else if (op == "==" && a == b) hit = 1
		else if (op == "!=" && a != b) hit = 1
		if (hit) print "HIT|" r " (" name " is " have ")"
	    }
	}' "${1}"
}

function upload_probe()
{
    local id="${DRSM_UPLOAD_ID:-$(basename "$(pwd)")}"
    local name="${DRSM_UPLOAD_NAME:-$(drsm_target | tr '[:upper:]' '[:lower:]')}"
    local title display maxage maxlines dir meta lines now t age hours m r metrics
    name="${name%%.*}"
    title=$(drsm_setting TITLE "${id}")
    display=$(drsm_setting DISPLAY text)
    maxage=$(drsm_setting MAX_AGE_HOURS 0)
    maxlines=$(drsm_setting MAX_LINES 2000)
    metrics=$(drsm_setting METRICS "")

    if [ "${DRSM_UPLOADS_DIR}" == "" ]; then
	drsm_unknown "${name} upload ${id}: set UPLOADS_DIR in the host file (the report server's [hooks] dir)"
	drsm_exit
    fi
    dir="${DRSM_UPLOADS_DIR%/}/${name}/${id}"
    meta="${dir}/latest.meta"
    lines="${dir}/latest.lines"
    if [ ! -f "${meta}" ]; then
	drsm_warn "${name} ${title} has no data yet, nothing received in ${dir}"
	echo "UPLOAD meta|${name}|${id}|${display}|${title}|0"
	drsm_exit
    fi

    now=$(date +%s)
    t=$(upload_meta COLLECTED_ETIME "${meta}")
    if ! [[ "${t}" =~ ^[0-9]+$ ]]; then t=$(upload_meta RECEIVED_ETIME "${meta}"); fi
    if ! [[ "${t}" =~ ^[0-9]+$ ]]; then t=$(stat -c %Y "${meta}"); fi
    age=$(( now - t ))
    hours=$(( age / 3600 ))

    echo "UPLOAD meta|${name}|${id}|${display}|${title}|${t}"
    drsm_info "${name} ${title}: $(upload_meta FILE_NAME "${meta}") ($(upload_meta BYTES "${meta}") bytes, $(upload_meta FORMAT "${meta}")) from $(upload_meta SOURCE "${meta}"), collected $(date -d "@${t}" '+%Y-%m-%d %H:%M %Z')"
    if [[ "${maxage}" =~ ^[0-9]+$ ]] && [ "${maxage}" -gt 0 ] && [ "${age}" -gt $(( maxage * 3600 )) ]; then
	drsm_warn "${name} ${title} data is ${hours} hours old, more than ${maxage} hours"
    fi

    # The parsed data: only DRSM line kinds, so a payload cannot add
    # report sections or host facts
    if [ -f "${lines}" ]; then
	grep -E '^((INFO|WARNING|ERROR|UNKNOWN) - |UPLOAD (columns|row|value)\|)' "${lines}" | head -n "${maxlines}"
	if grep -q '^ERROR - ' "${lines}"; then DRSM_HAS_ERROR=1; fi
	if grep -q '^WARNING - ' "${lines}"; then DRSM_HAS_WARNING=1; fi
	if grep -q '^UNKNOWN - ' "${lines}"; then DRSM_HAS_UNKNOWN=1; fi

	while IFS= read -r r; do
	    case "${r}" in
		BAD\|*) drsm_unknown "${name} ${title}: rule '${r#BAD|}' has no operator" ;;
		HIT\|*) drsm_crit "${name} ${title}: ${r#HIT|}" ;;
	    esac
	done < <(upload_rules "${lines}" "$(drsm_setting CRIT_IF "")")
	while IFS= read -r r; do
	    case "${r}" in
		BAD\|*) drsm_unknown "${name} ${title}: rule '${r#BAD|}' has no operator" ;;
		HIT\|*) drsm_warn "${name} ${title}: ${r#HIT|}" ;;
	    esac
	done < <(upload_rules "${lines}" "$(drsm_setting WARN_IF "")")

	# Values for the trends page, named <id>_<value name>
	for m in ${metrics}; do
	    r=$(awk -v n="${m}" '
		index($0, "UPLOAD value|" n "|") == 1 { v = substr($0, length("UPLOAD value|" n "|") + 1) }
		index($0, "METRIC " n "=") == 1 { v = substr($0, length("METRIC " n "=") + 1) }
		/^UPLOAD row\|/ { rows++ }
		END { if (v == "" && n == "rows") v = rows + 0; print v }' "${lines}")
	    if [[ "${r}" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
		drsm_metric "${id}_$(echo "${m}" | tr -c 'A-Za-z0-9_\n' '_')" "${r}"
	    fi
	done
    fi
    drsm_exit
}
# -----------------------------------------------------------
# *******************************
# ********* End of File *********
# *******************************
