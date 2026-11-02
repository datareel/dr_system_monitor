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
# DRSM plugin: the VULNERABILITIES and COMPLIANCE sections of the last
# DataReel Reporting Agent for Linux report. The agent scans once a day:
# OpenSCAP (oscap oval eval) against Red Hat's OVAL feed on RHEL 8 and
# 9; on RHEL 10, which has no OVAL feed, the report server's index of
# Red Hat's CSAF/VEX files (php/vex_sync.php), or dnf updateinfo. All
# list the Red Hat security advisories (RHSA) the installed packages
# still need. CSAF/VEX also lists the CVEs with no fix yet (unfixed).
#
# The Vulnerabilities page reads the "VULN kind|field|..." lines:
#   VULN summary|source|scan_etime|critical|important|moderate|low|unknown|total|cves|status|unfixed
#   VULN advisory|id|severity|issued|cves|packages|title
#   VULN unfixed|cve|severity|packages|state
#   VULN compliance|profile|score|pass|fail|scan_etime
#   VULN rule|rule|severity
#
# ----------------------------------------------------------- 
# shellcheck source=lib/drsm_plugin.sh
source "${DRSM_LIB:-$(dirname "$0")/../../../lib}/drsm_plugin.sh"
# shellcheck source=plugins/linux/lra_report.sh
source "$(dirname "$0")/../lra_report.sh"

CRIT_SEVERITY=$(drsm_setting CRIT_SEVERITY Critical)
WARN_SEVERITY=$(drsm_setting WARN_SEVERITY Important)
SCAN_MAX_AGE_DAYS=$(drsm_setting SCAN_MAX_AGE_DAYS 3)
MANUAL_SCAN_MAX_AGE_DAYS=$(drsm_setting MANUAL_SCAN_MAX_AGE_DAYS 0)
COMPLIANCE_MIN_SCORE=$(drsm_setting COMPLIANCE_MIN_SCORE "")
MAX_LIST=$(drsm_setting MAX_LIST 300)
UNFIXED_WARN_SEVERITY=$(drsm_setting UNFIXED_WARN_SEVERITY Critical)
if drsm_is_none "${COMPLIANCE_MIN_SCORE}"; then COMPLIANCE_MIN_SCORE=""; fi

function sev_rank()
{
    # 0 Critical .. 3 Low, 4 Unknown, 9 none
    case "${1,,}" in
	critical) echo 0 ;; important|high) echo 1 ;; moderate|medium) echo 2 ;; low) echo 3 ;;
	unknown) echo 4 ;; *) echo 9 ;;
    esac
}

lra_load_report || drsm_exit
if ! lra_has_section "VULNERABILITIES" "${REPORT}"; then
    drsm_unknown "${LRA_HOST} report has no VULNERABILITIES section, the agent needs version 1.0 or later"
    drsm_exit
fi
declare -A V
while IFS='=' read -r k v; do
    if [[ "${k}" =~ ^[a-z_]+$ ]]; then V[${k}]="${v}"; fi
done < <(lra_section "VULNERABILITIES" "${REPORT}" | grep -v ' ')
# The counts are one line of name=value pairs
counts=$(lra_section "VULNERABILITIES" "${REPORT}" | grep '^critical=' | head -1)
for kv in ${counts}; do V[${kv%%=*}]="${kv#*=}"; done

case "${V[status]}" in
    disabled)
	drsm_info "${LRA_HOST} has no vulnerability scan yet: run sudo drra scan on the host, or schedule scans with [scan] enabled=1 in /etc/drra/drra.ini"
	echo "VULN summary||||||||||disabled"
	drsm_exit ;;
    pending|"")
	drsm_info "${LRA_HOST} has not finished its first vulnerability scan"
	echo "VULN summary||||||||||pending"
	drsm_exit ;;
esac

src="${V[source]:-unknown}"
scan_etime="${V[scan_etime]}"
scan_age=""
if [[ "${scan_etime}" =~ ^[0-9]+$ ]]; then
    scan_age=$(( ($(date +%s) - scan_etime) / 86400 ))
    drsm_detail "Vulnerability scan" "$(date -d "@${scan_etime}" '+%Y-%m-%d %H:%M') (${src})"
fi
if [ "${V[status]}" == "failed" ]; then
    why=$(lra_section "VULNERABILITIES" "${REPORT}" | sed -n 's/^ERROR - //p' | head -1)
    drsm_warn "${LRA_HOST} vulnerability scan failed: ${why:-see the agent log}"
    echo "VULN summary|${src}|${scan_etime}||||||||failed"
    drsm_exit
fi
# Scans by hand (agent [scan] enabled=0, mode=manual) are as old as the
# admin lets them get, so they only warn with MANUAL_SCAN_MAX_AGE_DAYS
mode="${V[mode]:-auto}"
max_age="${SCAN_MAX_AGE_DAYS}"
if [ "${mode}" == "manual" ]; then
    max_age="${MANUAL_SCAN_MAX_AGE_DAYS}"
    echo "Scanned by hand (drra scan) ${scan_age:-?} days ago, the agent does not scan on a schedule"
fi
if [ "${scan_age}" != "" ] && [ "${max_age}" -gt 0 ] && [ "${scan_age}" -gt "${max_age}" ]; then
    drsm_warn "${LRA_HOST} last vulnerability scan is ${scan_age} days old"
fi

crit=${V[critical]:-0}; imp=${V[important]:-0}; mod=${V[moderate]:-0}; low=${V[low]:-0}; unk=${V[unknown]:-0}
total=${V[total]:-0}; cves=${V[cves]:-0}; unfixed=${V[unfixed]:-}
summary="${total} security advisories apply: ${crit} critical, ${imp} important, ${mod} moderate, ${low} low, ${cves} CVEs (${src} scan)"
declare -A UC
ucounts=$(lra_section "VULNERABILITIES" "${REPORT}" | sed -n 's/^unfixed_counts //p' | head -1)
for kv in ${ucounts}; do UC[${kv%%=*}]="${kv#*=}"; done
if [ "${unfixed}" != "" ]; then
    summary="${summary}, ${unfixed} CVEs with no fix yet"
    if [ "${ucounts}" != "" ]; then summary="${summary} (${UC[critical]:-0} critical, ${UC[important]:-0} important)"; fi
fi
echo "${summary}"
drsm_detail "Vulnerabilities" "${crit} critical, ${imp} important, ${mod} moderate, ${low} low${unfixed:+, ${unfixed} unfixed}"
echo "VULN summary|${src}|${scan_etime}|${crit}|${imp}|${mod}|${low}|${unk}|${total}|${cves}|ok|${unfixed}"

crank=$(sev_rank "${CRIT_SEVERITY}")
wrank=$(sev_rank "${WARN_SEVERITY}")
declare -A N=([0]=${crit} [1]=${imp} [2]=${mod} [3]=${low})
names=(critical important moderate low)
err_n=0; warn_n=0; err_txt=""; warn_txt=""
for r in 0 1 2 3; do
    n=${N[$r]}
    [ "${n}" -gt 0 ] || continue
    if [ ${r} -le ${crank} ]; then err_n=$((err_n + n)); err_txt="${err_txt}, ${n} ${names[$r]}";
    elif [ ${r} -le ${wrank} ]; then warn_n=$((warn_n + n)); warn_txt="${warn_txt}, ${n} ${names[$r]}"; fi
done
function plural() { if [ "${1}" -eq 1 ]; then echo "advisory"; else echo "advisories"; fi; }
if [ ${err_n} -gt 0 ]; then
    drsm_crit "${LRA_HOST} needs security updates: ${err_txt#, } $(plural ${err_n})"
    echo "IMPACT - ${LRA_HOST} has known vulnerabilities with fixes available, run dnf update"
fi
if [ ${warn_n} -gt 0 ]; then
    drsm_warn "${LRA_HOST} needs security updates: ${warn_txt#, } $(plural ${warn_n})"
fi
if [ ${err_n} -eq 0 ] && [ ${warn_n} -eq 0 ]; then
    drsm_ok "${LRA_HOST} has no ${WARN_SEVERITY} or worse security advisories pending"
fi

# Advisory lines for the page and the report, most severe first
echo ""
lra_section "VULNERABILITIES" "${REPORT}" | sed -n 's/^advisory //p' | lra_kv id severity issued cves packages title | head -n "${MAX_LIST}" |
    awk -F'\t' '{ gsub(/\|/, "/", $6); printf "VULN advisory|%s|%s|%s|%s|%s|%s\n", $1, $2, $3, $4, $5, $6 }'
if [ "${total}" -gt "${MAX_LIST}" ]; then echo "Only the first ${MAX_LIST} of ${total} advisories are listed"; fi

# CVEs Red Hat lists as affecting installed packages with no update
# yet. Nothing to install, so at most a warning, for the worst ones.
if [ "${unfixed:-0}" -gt 0 ]; then
    urank=$(sev_rank "${UNFIXED_WARN_SEVERITY}")
    worst=$(lra_section "VULNERABILITIES" "${REPORT}" | sed -n 's/^unfixed //p' | lra_kv severity |
	awk -v r="${urank}" '
	    { s = tolower($1); k = (s == "critical") ? 0 : (s == "important") ? 1 : (s == "moderate") ? 2 : (s == "low") ? 3 : 4
	      if (k <= r) n++ }
	    END { print n + 0 }')
    echo ""
    echo "${unfixed} CVEs affect installed packages and have no fix from Red Hat yet: ${UC[critical]:-?} critical, ${UC[important]:-?} important, ${UC[moderate]:-?} moderate, ${UC[low]:-?} low"
    if [ "${urank}" -lt 9 ] && [ "${worst}" -gt 0 ]; then
	drsm_warn "${LRA_HOST} has ${worst} ${UNFIXED_WARN_SEVERITY} or worse CVEs with no fix yet"
    fi
    lra_section "VULNERABILITIES" "${REPORT}" | sed -n 's/^unfixed //p' | lra_kv cve severity packages state | head -n "${MAX_LIST}" |
	awk -F'\t' '{ gsub(/\|/, "/", $4); printf "VULN unfixed|%s|%s|%s|%s\n", $1, $2, $3, $4 }'
    drsm_metric vuln_unfixed "${unfixed}"
fi

# Compliance scan, when the agent runs one
if lra_has_section "COMPLIANCE" "${REPORT}"; then
    profile=$(lra_value COMPLIANCE profile "${REPORT}")
    score=$(lra_value COMPLIANCE score "${REPORT}")
    cetime=$(lra_value COMPLIANCE scan_etime "${REPORT}")
    line=$(lra_section "COMPLIANCE" "${REPORT}" | grep '^pass=' | head -1)
    declare -A C
    for kv in ${line}; do C[${kv%%=*}]="${kv#*=}"; done
    echo ""
    echo "Compliance (${profile}): score ${score:-?}, ${C[pass]:-0} rules pass, ${C[fail]:-0} fail"
    drsm_detail "Compliance" "${profile} score ${score:-?}, ${C[fail]:-0} rules fail"
    echo "VULN compliance|${profile}|${score}|${C[pass]:-0}|${C[fail]:-0}|${cetime}"
    if [ "${COMPLIANCE_MIN_SCORE}" != "" ] && [ "${score}" != "" ] && ! drsm_gt "${score}" "${COMPLIANCE_MIN_SCORE}"; then
	drsm_warn "${LRA_HOST} ${profile} compliance score ${score} is below ${COMPLIANCE_MIN_SCORE}"
    fi
    lra_section "COMPLIANCE" "${REPORT}" | sed -n 's/^fail //p' | lra_kv rule severity | head -n "${MAX_LIST}" |
	awk -F'\t' '{ printf "VULN rule|%s|%s\n", $1, $2 }'
    if [ "${score}" != "" ]; then drsm_metric compliance_score "${score}"; fi
    drsm_metric compliance_fail "${C[fail]:-0}"
fi

drsm_metric vuln_critical "${crit}"
drsm_metric vuln_important "${imp}"
drsm_metric vuln_moderate "${mod}"
drsm_metric vuln_low "${low}"
drsm_metric vuln_total "${total}"
drsm_metric vuln_cves "${cves}"
drsm_exit
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# *******************************
