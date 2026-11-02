#!/bin/bash
# ----------------------------------------------------------- 
# BASH Script
# Operating System(s): RHEL/CENTOS
# Run Level(s): 3, 5
# Shell: BASH shell
# Original Author(s): DataReel Software Development
# File Creation Date: 11/01/2026
# Date Last Modified: 11/01/2026
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
# DRSM plugin: the VULNERABILITIES section of the last DataReel
# Reporting Agent for Windows report (agent 3.5 and later). The agent
# asks the Windows Update Agent for the updates not installed yet
# (source=wua), by hand with "drra_svc.exe scan" unless [scan]
# enabled=1. Security updates are listed by KB number with their MSRC
# severity and CVEs; other updates (drivers, definitions) are counted.
#
# Prints the same "VULN kind|field|..." lines as linux/vulnerabilities
# for the Vulnerabilities page:
#   VULN summary|source|scan_etime|critical|important|moderate|low|unknown|total|cves|status|
#   VULN advisory|id|severity|issued|cves|products|title
#   VULN other|id|classification|issued|title
#
# ----------------------------------------------------------- 
# shellcheck source=lib/drsm_plugin.sh
source "${DRSM_LIB:-$(dirname "$0")/../../../lib}/drsm_plugin.sh"
# shellcheck source=plugins/windows/wra_report.sh
source "$(dirname "$0")/../wra_report.sh"

CRIT_SEVERITY=$(drsm_setting CRIT_SEVERITY Critical)
WARN_SEVERITY=$(drsm_setting WARN_SEVERITY Important)
UNRATED_SEVERITY=$(drsm_setting UNRATED_SEVERITY Important)
SCAN_MAX_AGE_DAYS=$(drsm_setting SCAN_MAX_AGE_DAYS 3)
MANUAL_SCAN_MAX_AGE_DAYS=$(drsm_setting MANUAL_SCAN_MAX_AGE_DAYS 0)
MAX_LIST=$(drsm_setting MAX_LIST 300)

function sev_rank()
{
    # 0 Critical .. 3 Low, 4 Unknown, 9 none
    case "${1,,}" in
	critical) echo 0 ;; important|high) echo 1 ;; moderate|medium) echo 2 ;; low) echo 3 ;;
	unknown) echo 4 ;; *) echo 9 ;;
    esac
}

wra_load_report || drsm_exit
if ! wra_has_section "VULNERABILITIES" "${REPORT}"; then
    drsm_unknown "${WRA_HOST} report has no VULNERABILITIES section, the agent needs version 3.5 or later"
    drsm_exit
fi
declare -A V
while IFS='=' read -r k v; do
    if [[ "${k}" =~ ^[a-z_]+$ ]]; then V[${k}]="${v}"; fi
done < <(wra_section "VULNERABILITIES" "${REPORT}" | grep -v '^[a-z]* ' | grep -v '^critical=')
# The counts are one line of name=value pairs
counts=$(wra_section "VULNERABILITIES" "${REPORT}" | grep '^critical=' | head -1)
for kv in ${counts}; do V[${kv%%=*}]="${kv#*=}"; done

case "${V[status]}" in
    disabled)
	drsm_info "${WRA_HOST} has no vulnerability scan yet: run drra_svc.exe scan from an administrator command prompt on the host, or schedule scans with [scan] enabled=1 in drra.ini"
	echo "VULN summary||||||||||disabled"
	drsm_exit ;;
    pending|"")
	drsm_info "${WRA_HOST} has not finished its first vulnerability scan"
	echo "VULN summary||||||||||pending"
	drsm_exit ;;
esac

src="${V[source]:-wua}"
scan_etime="${V[scan_etime]}"
scan_age=""
if [[ "${scan_etime}" =~ ^[0-9]+$ ]]; then
    scan_age=$(( ($(date +%s) - scan_etime) / 86400 ))
    drsm_detail "Vulnerability scan" "$(date -d "@${scan_etime}" '+%Y-%m-%d %H:%M') (${V[feed]:-${src}})"
fi
if [ "${V[status]}" == "failed" ]; then
    why=$(wra_section "VULNERABILITIES" "${REPORT}" | sed -n 's/^ERROR - //p' | head -1)
    drsm_warn "${WRA_HOST} vulnerability scan failed: ${why:-see the agent log}"
    echo "VULN summary|${src}|${scan_etime}||||||||failed"
    drsm_exit
fi
# Scans by hand (agent [scan] enabled=0, mode=manual) are as old as the
# admin lets them get, so they only warn with MANUAL_SCAN_MAX_AGE_DAYS
mode="${V[mode]:-auto}"
max_age="${SCAN_MAX_AGE_DAYS}"
if [ "${mode}" == "manual" ]; then
    max_age="${MANUAL_SCAN_MAX_AGE_DAYS}"
    echo "Scanned by hand (drra_svc.exe scan) ${scan_age:-?} days ago, the agent does not scan on a schedule"
fi
if [ "${scan_age}" != "" ] && [ "${max_age}" -gt 0 ] && [ "${scan_age}" -gt "${max_age}" ]; then
    drsm_warn "${WRA_HOST} last vulnerability scan is ${scan_age} days old"
fi

crit=${V[critical]:-0}; imp=${V[important]:-0}; mod=${V[moderate]:-0}; low=${V[low]:-0}; unk=${V[unknown]:-0}
total=${V[total]:-0}; cves=${V[cves]:-0}; other=${V[other]:-0}
summary="${total} security updates to install: ${crit} critical, ${imp} important, ${mod} moderate, ${low} low"
if [ "${unk}" -gt 0 ]; then summary="${summary}, ${unk} not rated"; fi
summary="${summary}, ${cves} CVEs (Windows Update scan, ${V[feed]:-Windows Update})"
echo "${summary}"
if [ "${other}" -gt 0 ]; then echo "${other} other updates waiting (drivers, definitions, feature and preview updates)"; fi
unrated=""
if [ "${unk}" -gt 0 ]; then unrated=", ${unk} not rated"; fi
drsm_detail "Vulnerabilities" "${crit} critical, ${imp} important, ${mod} moderate, ${low} low${unrated}"
echo "VULN summary|${src}|${scan_etime}|${crit}|${imp}|${mod}|${low}|${unk}|${total}|${cves}|ok|"

crank=$(sev_rank "${CRIT_SEVERITY}")
wrank=$(sev_rank "${WARN_SEVERITY}")
urank=$(sev_rank "${UNRATED_SEVERITY}")
declare -A N=([0]=${crit} [1]=${imp} [2]=${mod} [3]=${low})
names=(critical important moderate low)
err_n=0; warn_n=0; err_txt=""; warn_txt=""
for r in 0 1 2 3 4; do
    if [ ${r} -eq 4 ]; then
	# Security updates with no MSRC rating count as UNRATED_SEVERITY
	n=${unk}; name="not rated"; rr=${urank}
	[ ${rr} -lt 9 ] || continue
    else
	n=${N[$r]}; name=${names[$r]}; rr=${r}
    fi
    [ "${n}" -gt 0 ] || continue
    if [ ${rr} -le ${crank} ]; then err_n=$((err_n + n)); err_txt="${err_txt}, ${n} ${name}";
    elif [ ${rr} -le ${wrank} ]; then warn_n=$((warn_n + n)); warn_txt="${warn_txt}, ${n} ${name}"; fi
done
function plural() { if [ "${1}" -eq 1 ]; then echo "update"; else echo "updates"; fi; }
if [ ${err_n} -gt 0 ]; then
    drsm_crit "${WRA_HOST} needs security updates: ${err_txt#, } $(plural ${err_n})"
    echo "IMPACT - ${WRA_HOST} has known vulnerabilities with fixes available, install them with Windows Update"
fi
if [ ${warn_n} -gt 0 ]; then
    drsm_warn "${WRA_HOST} needs security updates: ${warn_txt#, } $(plural ${warn_n})"
fi
if [ ${err_n} -eq 0 ] && [ ${warn_n} -eq 0 ]; then
    drsm_ok "${WRA_HOST} has no ${WARN_SEVERITY} or worse security updates pending"
fi

# Update lines for the page and the report, most severe first
echo ""
wra_section "VULNERABILITIES" "${REPORT}" | sed -n 's/^advisory //p' | wra_kv id severity issued cves packages title | head -n "${MAX_LIST}" |
    awk -F'\t' '{ gsub(/\|/, "/", $5); gsub(/\|/, "/", $6); printf "VULN advisory|%s|%s|%s|%s|%s|%s\n", $1, $2, $3, $4, $5, $6 }'
if [ "${total}" -gt "${MAX_LIST}" ]; then echo "Only the first ${MAX_LIST} of ${total} security updates are listed"; fi
wra_section "VULNERABILITIES" "${REPORT}" | sed -n 's/^other //p' | wra_kv id classification issued title | head -n "${MAX_LIST}" |
    awk -F'\t' '{ gsub(/\|/, "/", $2); gsub(/\|/, "/", $4); printf "VULN other|%s|%s|%s|%s\n", $1, $2, $3, $4 }'

drsm_metric vuln_critical "${crit}"
drsm_metric vuln_important "${imp}"
drsm_metric vuln_moderate "${mod}"
drsm_metric vuln_low "${low}"
drsm_metric vuln_total "${total}"
drsm_metric vuln_cves "${cves}"
drsm_metric updates_other "${other}"
drsm_exit
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# *******************************
