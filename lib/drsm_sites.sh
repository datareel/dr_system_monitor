#!/bin/bash
# -----------------------------------------------------------
# BASH Script
# Operating System(s): RHEL/CENTOS
# Run Level(s): 3, 5
# Shell: BASH shell
# Original Author(s): DataReel Software Development
# File Creation Date: 10/27/2026
# Date Last Modified: 10/27/2026
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
# Organizations and sites. Every host belongs to one site, and every
# site to one organization: org > site > group > host. Site files:
#
#   ${SITESdir}/<org>.org          NAME, CONTACT
#   ${SITESdir}/<org>/<site>.site  NAME, LOCATION, TZ, ALERT_EMAIL,
#                                  ALERT_EMAIL_<TIER>, STALE_MINUTES,
#                                  COLLECTOR_ID, and any
#                                  host key or plugin setting as a
#                                  default for the site's hosts
#
# A host names its site with SITE=<org>/<site>. Hosts without one use
# DRSM_SITE from ~/.drsm.sh, else default/default. The default/default
# site keeps the reports where they have always been, in ${REPORTdir}.
# Every other site writes to ${REPORTdir}/orgs/<org>/<site>.
#
# Needs lib/drsm_conf.sh.
# -----------------------------------------------------------
DRSM_LEGACY_SITE="default/default"
# Keys that describe a site, every other key in a site file is a host
# default
DRSM_SITE_KEYS="NAME LOCATION TZ ALERT_EMAIL STALE_MINUTES COLLECTOR_ID"

function drsm_sites_dir()
{
    if [ "${SITESdir}" != "" ]; then echo "${SITESdir}"; else echo "${DRSMHOME}/etc/sites"; fi
}

function drsm_valid_id()
{
    # Org and site IDs: lower case letters, digits, _ and -
    [[ "${1}" =~ ^[a-z0-9][a-z0-9_-]*$ ]]
}

function drsm_valid_site()
{
    # $1 == org/site
    [[ "${1}" =~ ^[a-z0-9][a-z0-9_-]*/[a-z0-9][a-z0-9_-]*$ ]]
}

function drsm_default_site()
{
    local s="${DRSM_SITE:-${DRSM_LEGACY_SITE}}"
    s="${s,,}"
    if ! drsm_valid_site "${s}"; then
	echo "WARNING - DRSM_SITE=${DRSM_SITE} is not org/site, using ${DRSM_LEGACY_SITE}" >&2
	s="${DRSM_LEGACY_SITE}"
    fi
    echo "${s}"
}

function drsm_collector_id()
{
    if [ "${DRSM_COLLECTOR_ID}" != "" ]; then echo "${DRSM_COLLECTOR_ID}"; return 0; fi
    hostname -s 2> /dev/null || hostname
}

function drsm_site_root()
{
    # Report directory for site $1
    if [ "${1}" == "${DRSM_LEGACY_SITE}" ]; then
	echo "${REPORTdir}"
    else
	echo "${REPORTdir}/orgs/${1%%/*}/${1#*/}"
    fi
}

function drsm_site_file()
{
    echo "$(drsm_sites_dir)/${1%%/*}/${1#*/}.site"
}

function drsm_org_file()
{
    echo "$(drsm_sites_dir)/${1}.org"
}

function drsm_read_site()
{
    # Read site $1's file into associative array $2, nothing if the
    # site has no file
    local f
    f=$(drsm_site_file "${1}")
    if [ -f "${f}" ]; then drsm_read_conf "${f}" "${2}"; fi
    return 0
}

# Host groups are tiers: dev, qa and ops. ops is another name for
# production, the group that has always had no file suffix and sends
# texts, so ops hosts run and report with the production hosts.
function drsm_group_canon()
{
    # Group name $1 as drsm_run.sh uses it: lower case, ops is
    # production, empty is production
    local g="${1,,}"
    if [ "${g}" == "" ] || [ "${g}" == "ops" ]; then g="production"; fi
    echo "${g}"
}

function drsm_group_tier()
{
    # Tier label for group $1: OPS for production, else the group in
    # upper case (DEV, QA)
    local g
    g=$(drsm_group_canon "${1}")
    if [ "${g}" == "production" ]; then echo "OPS"; else echo "${g^^}"; fi
}

function drsm_site_alert_email()
{
    # Alert addresses for group $2 from site array $1:
    # ALERT_EMAIL_<TIER>, else ALERT_EMAIL
    local -n __sa="${1}"
    local t
    t=$(drsm_group_tier "${2}")
    t="${t//[^A-Z0-9_]/_}"
    if [ "${__sa[ALERT_EMAIL_${t}]}" != "" ]; then echo "${__sa[ALERT_EMAIL_${t}]}"; else echo "${__sa[ALERT_EMAIL]}"; fi
}

function drsm_is_site_key()
{
    local k
    # Per tier alert addresses
    if [[ "${1}" == ALERT_EMAIL_* ]]; then return 0; fi
    for k in ${DRSM_SITE_KEYS}; do
	if [ "${1}" == "${k}" ]; then return 0; fi
    done
    return 1
}

function drsm_site_owned()
{
    # True when this collector runs site $1: the site has no
    # COLLECTOR_ID, or it matches ours
    local -A __s=()
    drsm_read_site "${1}" __s
    if [ "${__s[COLLECTOR_ID]}" == "" ] || [ "${__s[COLLECTOR_ID]}" == "$(drsm_collector_id)" ]; then return 0; fi
    return 1
}

function drsm_host_file_site()
{
    # Site of host file $1: its SITE= key, else the default site
    local -A __h=()
    local s
    drsm_read_conf "${1}" __h 2> /dev/null
    s="${__h[SITE],,}"
    if [ "${s}" == "" ]; then s=$(drsm_default_site); fi
    echo "${s}"
}

function drsm_list_sites()
{
    # Every site that has a site file or a host file naming it, one per
    # line, sorted. $1 == hosts directory.
    local f s d
    d=$(drsm_sites_dir)
    {
	shopt -s nullglob
	for f in "${d}"/*/*.site; do
	    s="$(basename "$(dirname "${f}")")/$(basename "${f}" .site)"
	    if drsm_valid_site "${s}"; then echo "${s}"; fi
	done
	for f in "${1}"/*.conf; do
	    if [ "$(basename "${f}" | cut -c1)" == "_" ]; then continue; fi
	    s=$(drsm_host_file_site "${f}")
	    if drsm_valid_site "${s}"; then echo "${s}"; fi
	done
	shopt -u nullglob
    } | sort -u
}

function drsm_dir_has_hosts()
{
    # True when report folder $1 has a host folder
    local d
    for d in "${1}"/*/; do
	d=$(basename "${d}")
	if [[ "${d}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then return 0; fi
    done
    return 1
}

function drsm_json_str()
{
    # JSON string for $1, with the quotes
    local s="${1}"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\t'/ }"
    s="${s//$'\r'/}"
    s="${s//$'\n'/ }"
    printf '"%s"' "${s}"
}

function drsm_host_state()
{
    # Worst state of host report directory $1, from its status.json and
    # report, STALE when it is older than $2 minutes. Prints
    # "<state> <epoch> <group>".
    local dir="${1}" stale="${2}" h json t g state="OK" s
    h=$(basename "${dir}")
    json=""
    if [ -f "${dir}/status.json" ]; then json=$(< "${dir}/status.json"); fi
    t=$(grep -o '"time":[0-9]*' <<< "${json}" | head -n 1 | cut -d: -f2)
    g=$(grep -o '"group":"[^"]*"' <<< "${json}" | head -n 1 | cut -d'"' -f4)
    if [ "${t}" == "" ] && [ -f "${dir}/${h}_report.txt" ]; then
	t=$(grep -m 1 '^ETIME:' "${dir}/${h}_report.txt" | cut -d: -f2)
    fi
    if [ "${g}" == "" ] && [ -f "${dir}/${h}_report.txt" ]; then
	g=$(grep -m 1 '^GROUP:' "${dir}/${h}_report.txt" | cut -d: -f2)
    fi
    if [[ ! "${t}" =~ ^[0-9]+$ ]]; then t=0; fi
    if [ "${g}" == "" ]; then g="production"; fi
    for s in $(grep -o '"state":"[A-Z]*"' <<< "${json}" | cut -d'"' -f4); do
	case "${s}" in
	    ERROR) state="ERROR" ;;
	    WARNING|UNKNOWN) if [ "${state}" == "OK" ]; then state="WARNING"; fi ;;
	esac
    done
    if [ -f "${dir}/${h}_report.txt" ]; then
	if grep -q '^ERROR - ' "${dir}/${h}_report.txt"; then
	    state="ERROR"
	elif grep -q '^WARNING - ' "${dir}/${h}_report.txt" && [ "${state}" == "OK" ]; then
	    state="WARNING"
	fi
    else
	state="ERROR"
    fi
    if [ "${stale:-0}" -gt 0 ] && [ "${t}" -gt 0 ] && [ $(( $(date +%s) - t )) -gt $(( stale * 60 )) ] && [ "${state}" != "ERROR" ]; then
	state="STALE"
    fi
    echo "${state} ${t} ${g}"
}

function drsm_write_site_json()
{
    # Write site.json for site $1 in its report directory: the site, the
    # collector that wrote it and the state of every host reporting there
    local site="${1}" root d h st t g sep="" tmp
    local -A sc=() oc=() n=([ok]=0 [warning]=0 [error]=0 [stale]=0)
    local hosts=""
    drsm_read_site "${site}" sc
    if [ -f "$(drsm_org_file "${site%%/*}")" ]; then drsm_read_conf "$(drsm_org_file "${site%%/*}")" oc; fi
    local stale="${sc[STALE_MINUTES]:-60}"
    if [[ ! "${stale}" =~ ^[0-9]+$ ]]; then stale=60; fi
    root=$(drsm_site_root "${site}")
    mkdir -p "${root}/systems"
    shopt -s nullglob
    for d in "${root}"/systems/*/; do
	d="${d%/}"
	h=$(basename "${d}")
	if [ "${h:0:1}" == "." ]; then continue; fi
	read -r st t g <<< "$(drsm_host_state "${d}" "${stale}")"
	case "${st}" in
	    OK) n[ok]=$((n[ok] + 1)) ;;
	    WARNING) n[warning]=$((n[warning] + 1)) ;;
	    STALE) n[stale]=$((n[stale] + 1)) ;;
	    *) n[error]=$((n[error] + 1)) ;;
	esac
	hosts+="${sep}{\"host\":$(drsm_json_str "${h}"),\"group\":$(drsm_json_str "${g}"),\"state\":\"${st}\",\"time\":${t}}"
	sep=","
    done
    shopt -u nullglob
    # Hidden temp name, drsm_web_sync.sh skips .*.tmp files
    tmp="${root}/.site.json.tmp"
    {
	printf '{"org":%s,"site":%s,' "$(drsm_json_str "${site%%/*}")" "$(drsm_json_str "${site#*/}")"
	printf '"name":%s,"location":%s,' "$(drsm_json_str "${sc[NAME]:-${site#*/}}")" "$(drsm_json_str "${sc[LOCATION]}")"
	# The org name too, for dashboards that only get this site's folder
	printf '"org_name":%s,"org_contact":%s,' "$(drsm_json_str "${oc[NAME]:-${site%%/*}}")" "$(drsm_json_str "${oc[CONTACT]}")"
	printf '"collector":%s,"time":%s,"stale_minutes":%s,' "$(drsm_json_str "$(drsm_collector_id)")" "$(date +%s)" "${stale}"
	printf '"counts":{"ok":%s,"warning":%s,"error":%s,"stale":%s},' "${n[ok]}" "${n[warning]}" "${n[error]}" "${n[stale]}"
	printf '"hosts":[%s]}\n' "${hosts}"
    } > "${tmp}" && mv -f "${tmp}" "${root}/site.json"
}

function drsm_write_org_json()
{
    # Write org.json for org $1: its name, contact and site IDs
    local org="${1}" f s sep="" sites="" dir tmp
    local -A oc=()
    f=$(drsm_org_file "${org}")
    if [ -f "${f}" ]; then drsm_read_conf "${f}" oc; fi
    shopt -s nullglob
    for f in "$(drsm_sites_dir)/${org}"/*.site; do
	s=$(basename "${f}" .site)
	if ! drsm_valid_id "${s}"; then continue; fi
	sites+="${sep}$(drsm_json_str "${s}")"
	sep=","
    done
    shopt -u nullglob
    dir="${REPORTdir}/orgs/${org}"
    mkdir -p "${dir}"
    tmp="${dir}/.org.json.tmp"
    printf '{"org":%s,"name":%s,"contact":%s,"sites":[%s]}\n' "$(drsm_json_str "${org}")" \
	"$(drsm_json_str "${oc[NAME]:-${org}}")" "$(drsm_json_str "${oc[CONTACT]}")" "${sites}" > "${tmp}" \
	&& mv -f "${tmp}" "${dir}/org.json"
}
# -----------------------------------------------------------
# *******************************
# ********* End of File *********
# *******************************
