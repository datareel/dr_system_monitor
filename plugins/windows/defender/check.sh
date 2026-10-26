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
# DRSM plugin: Microsoft Defender events from the last Windows
# Reporting Agent report. The agent sends one <Event> XML record per
# line from the Defender Operational log, levels critical to warning.
#
# ----------------------------------------------------------- 
# shellcheck source=lib/drsm_plugin.sh
source "${DRSM_LIB:-$(dirname "$0")/../../../lib}/drsm_plugin.sh"
# shellcheck source=plugins/windows/wra_report.sh
source "$(dirname "$0")/../wra_report.sh"

LOOKBACK_DAYS=$(drsm_setting LOOKBACK_DAYS 7)
CRIT_EVENTS=$(drsm_setting CRIT_EVENTS "1006 1015 1116 1118 1119 5001 5010 5012")
WARN_EVENTS=$(drsm_setting WARN_EVENTS "1117 2001 2003 2004 3002 5008")
DEFINITIONS_WARN_DAYS=$(drsm_setting DEFINITIONS_WARN_DAYS 7)
PROTECTION_LOOKBACK_DAYS=$(drsm_setting PROTECTION_LOOKBACK_DAYS 30)
PROTECTION_EVENTS=$(drsm_setting PROTECTION_EVENTS "5001 5010 5012")

wra_load_report || drsm_exit
echo "Microsoft Defender checks for ${WRA_HOST}"
if ! wra_has_section "WINDOWS DEFENDER ALERTS" "${REPORT}"; then
    drsm_unknown "${WRA_HOST} report has no Defender section"
    drsm_exit
fi

since=$(date -u -d "-${LOOKBACK_DAYS} days" +%Y-%m-%dT%H:%M:%S)
psince=$(date -u -d "-${PROTECTION_LOOKBACK_DAYS} days" +%Y-%m-%dT%H:%M:%S)

# One line per event: time|id|threat or detail, newest first as sent
events=$(wra_section "WINDOWS DEFENDER ALERTS" "${REPORT}" | awk '
    /<Event/ {
	id = ""; t = ""; d = ""
	if (match($0, /<EventID[^>]*>[0-9]+</)) { id = substr($0, RSTART, RLENGTH); gsub(/[^0-9]/, "", id) }
	if (match($0, /SystemTime=.[0-9T:.-]+/)) { t = substr($0, RSTART + 12, 19) }
	if (match($0, /Name=.Threat Name.>[^<]*/)) { d = substr($0, RSTART, RLENGTH); sub(/^[^>]*>/, "", d) }
	else if (match($0, /Name=.Error Description.>[^<]*/)) { d = substr($0, RSTART, RLENGTH); sub(/^[^>]*>/, "", d) }
	else if (match($0, /Name=.Path.>[^<]*/)) { d = substr($0, RSTART, RLENGTH); sub(/^[^>]*>/, "", d) }
	if (id != "") print t "|" id "|" d
    }')

function event_label()
{
    case "${1}" in
	1006|1116) echo "threat detected" ;;
	1015) echo "suspicious behavior detected" ;;
	1117) echo "threat removed or quarantined" ;;
	1118) echo "threat remediation failed" ;;
	1119) echo "threat remediation critical failure" ;;
	2001) echo "definition update failed" ;;
	2003) echo "engine update failed" ;;
	2004) echo "definitions reverted to last known good" ;;
	3002) echo "real-time protection feature failed" ;;
	5001) echo "real-time protection turned off" ;;
	5008) echo "engine stopped unexpectedly" ;;
	5010) echo "spyware scanning turned off" ;;
	5012) echo "virus scanning turned off" ;;
	*) echo "event ${1}" ;;
    esac
}

total=0
recent=0
threats=0
while IFS='|' read -r t id detail
do
    [ "${id}" == "" ] && continue
    total=$((total + 1))
    if [[ " ${PROTECTION_EVENTS} " == *" ${id} "* ]]; then
	if [[ "${t}" < "${psince}" ]]; then continue; fi
    elif [[ "${t}" < "${since}" ]]; then
	continue
    fi
    recent=$((recent + 1))
    msg="${WRA_HOST} Defender $(event_label "${id}") ${t}Z${detail:+ ${detail}}"
    if [[ " ${CRIT_EVENTS} " == *" ${id} "* ]]; then
	drsm_crit "${msg}"
	case "${id}" in 1006|1015|1116) threats=$((threats + 1)) ;; esac
    elif [[ " ${WARN_EVENTS} " == *" ${id} "* ]]; then
	drsm_warn "${msg}"
    fi
done <<< "${events}"

echo "Defender events in the report: ${total}, in the last ${LOOKBACK_DAYS} days: ${recent}"

# Newest Security Intelligence (definition) update in the patch history
if [ "${DEFINITIONS_WARN_DAYS}" != "0" ] && wra_has_section "INSTALLED WINDOWS PATCHES" "${REPORT}"; then
    last=$(wra_section "INSTALLED WINDOWS PATCHES" "${REPORT}" | awk '
	/^Date:/ { d = $2 }
	/Security Intelligence Update|Definition Update/ { print d }' | wra_newest_date)
    if [ "${last}" == "" ]; then
	echo "No Security Intelligence updates in the patch history"
    else
	age=$(( ( $(date +%s) - $(date -d "${last}" +%s) ) / 86400 ))
	if [ ${age} -gt "${DEFINITIONS_WARN_DAYS}" ]; then
	    drsm_warn "${WRA_HOST} Defender definitions are ${age} days old, last update ${last}"
	else
	    echo "Defender definitions updated ${last}"
	fi
	drsm_metric wra_defender_definitions_age_days "${age}"
    fi
fi

if [ "${DRSM_HAS_ERROR}" == "0" ] && [ "${DRSM_HAS_WARNING}" == "0" ]; then
    drsm_ok "${WRA_HOST} Defender checks good"
fi
drsm_metric wra_defender_events "${recent}"
drsm_metric wra_defender_threats "${threats}"
drsm_exit
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
