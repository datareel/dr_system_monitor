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
# Plugin runner. Replaces the per-host loops in system_check.sh and
# system_report.sh. For each host it reads the host config, runs the
# probe plugins from this host, runs the remote plugins through the
# host's collector, and writes the same report files the web pages
# and alerts already use.
#
# Usage: drsm_run.sh [-g group] [-H host] [-m all|probes] [-e] [-n] [-l] [-v]
#   -g  Host group to run, default production
#   -H  Run a single host, for testing
#   -m  all (default) runs probes and plugins and writes the health
#       reports, probes runs connectivity probes only
#   -e  Email a status report even when every check passes
#   -n  Do not send alerts
#   -l  List the hosts and plugins that would run, then exit
#   -v  Verbose output
#
# ----------------------------------------------------------- 
if [ "${BASEdir}" == "" ]; then export BASEdir="${HOME}/drsm"; fi

if [ -f "${HOME}/.drsm.sh" ]; then
    CONFIG_FILE="${HOME}/.drsm.sh"
else
    CONFIG_FILE="${BASEdir}/etc/drsm.sh"
fi

if [ ! -f "${CONFIG_FILE}" ]; then
    echo "Missing base config ${CONFIG_FILE}"
    exit 1
fi

# shellcheck source=etc/drsm.sh
source "${CONFIG_FILE}"
# shellcheck source=bin/system_functions.sh
source "${DRSMHOME}/bin/system_functions.sh"
# shellcheck source=lib/drsm_conf.sh
source "${DRSMHOME}/lib/drsm_conf.sh"

if [ "${HOSTSdir}" == "" ]; then HOSTSdir="${DRSMHOME}/etc/hosts"; fi
if [ "${PLUGINSdir}" == "" ]; then PLUGINSdir="${DRSMHOME}/plugins"; fi
# Plugins used for hosts read from systems.dat, in the order of the
# old system_report.sh
if [ "${DRSM_DEFAULT_PLUGINS}" == "" ]; then
    DRSM_DEFAULT_PLUGINS="storage/disk storage/raid core/cpu core/load core/memory network/nics core/users"
fi

group="production"
singletesthost=""
mode="all"
emailstatusreport="NO"
sendalerts="1"
listonly="0"
verbose="0"

while getopts "g:H:m:enlvh" opt
do
    case "${opt}" in
	g) group="${OPTARG,,}" ;;
	H) singletesthost="${OPTARG}" ;;
	m) mode="${OPTARG,,}" ;;
	e) emailstatusreport="YES" ;;
	n) sendalerts="0" ;;
	l) listonly="1" ;;
	v) verbose="1" ;;
	*) sed -n '/^# Usage:/,/^#   -v/p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
    esac
done

if [ "${mode}" != "all" ] && [ "${mode}" != "probes" ]; then
    echo "ERROR - Unknown mode ${mode}, use all or probes"
    exit 1
fi

# Report file names. Production keeps the names the web pages and
# older cron jobs use, other groups add the group name.
sfx=""
if [ "${group}" != "production" ]; then sfx="_${group}"; fi
reportprefix="system_health_report${sfx}"
checkprefix="system_check${sfx}"

OUTPUTdir="${VARdir}/drsm_run${sfx}_${mode}.tmp"
LOCKfile="${VARdir}/drsm_run${sfx}_${mode}.lck"
logfile="${LOGdir}/drsm_run${sfx}_${mode}.log"
statusfile="${OUTPUTdir}/status.txt"
errorfile="${OUTPUTdir}/errors.txt"
checkfile="${OUTPUTdir}/check_status.txt"
checkerrors="${OUTPUTdir}/check_errors.txt"
PROGRAMname="$0"
MINold="30"
has_errors="0"
has_warning="0"
check_errors="0"

function log() { echo "$*" | tee -a "${logfile}"; }
function vlog() { if [ "${verbose}" == "1" ]; then echo "$*"; fi; }

# ------------------------------------------------------------
# Host inventory
# ------------------------------------------------------------

declare -A HCONF

function load_host_file()
{
    # Merge _defaults.conf and a host file into HCONF
    HCONF=()
    if [ -f "${HOSTSdir}/_defaults.conf" ]; then drsm_read_conf "${HOSTSdir}/_defaults.conf" HCONF; fi
    drsm_read_conf "${1}" HCONF
    if [ "${HCONF[HOST]}" == "" ]; then HCONF[HOST]=$(basename "${1}" .conf); fi
    if [ "${HCONF[GROUP]}" == "" ]; then HCONF[GROUP]="production"; fi
    if [ "${HCONF[PLATFORM]}" == "" ]; then HCONF[PLATFORM]="linux"; fi
    if [ "${HCONF[COLLECTOR]}" == "" ]; then HCONF[COLLECTOR]="ssh"; fi
    HCONF[SOURCE]="${1}"
}

function load_host_entry()
{
    # Map one systems.dat entry to HCONF, used until the hosts are
    # migrated with utils/migrate_systems_dat.sh
    HCONF=()
    if [ -f "${HOSTSdir}/_defaults.conf" ]; then drsm_read_conf "${HOSTSdir}/_defaults.conf" HCONF; fi
    ParseSystemEntry "${1}"
    HCONF[HOST]="${host}"
    HCONF[DESCRIPTION]="${description}"
    HCONF[IMPACT]="${impact}"
    HCONF[GROUP]="${group}"
    HCONF[PLATFORM]="other"
    if [ "${is_linux}" == "YES" ]; then HCONF[PLATFORM]="linux"; fi
    HCONF[COLLECTOR]="none"
    if [ "${can_ssh}" == "YES" ]; then HCONF[COLLECTOR]="ssh"; fi
    local probes="" p
    if [ "${can_ping}" == "YES" ]; then probes="network/ping"; fi
    if [ "${is_web_server}" == "YES" ]; then
	for p in ${WEBPROTOS}; do probes="${probes} network/${p,,}"; done
    fi
    HCONF[PROBES]="${probes# }"
    HCONF[PLUGINS]="${HCONF[PLUGINS]:-${DRSM_DEFAULT_PLUGINS}}"
    # Cluster addresses move between hosts, only probe them
    if [ "${is_cluser_ip}" == "YES" ]; then HCONF[PLUGINS]=""; fi
    HCONF[SOURCE]="${dbfile}"
}

# Build the list of host sources: host files when any exist, else
# the systems.dat rows for this group
HOSTSOURCES=()
shopt -s nullglob
for f in "${HOSTSdir}"/*.conf
do
    if [ "$(basename "${f}" | cut -c1)" == "_" ]; then continue; fi
    HOSTSOURCES+=("file:${f}")
done
shopt -u nullglob

if [ ${#HOSTSOURCES[@]} -eq 0 ]
then
    dbfile="${CONFIGdir}/systems.dat"
    if [ "${group}" != "production" ]; then dbfile="${CONFIGdir}/${group}_systems.dat"; fi
    if ! LoadSystemList "${dbfile}" 0; then
	echo "ERROR - No host files in ${HOSTSdir} and ${dbfile} not found"
	exit 1
    fi
    for entry in "${SYSTEMLIST[@]}"; do HOSTSOURCES+=("dat:${entry}"); done
fi

function load_host()
{
    case "${1}" in
	file:*) load_host_file "${1#file:}" ;;
	dat:*) load_host_entry "${1#dat:}" ;;
    esac
}

# ------------------------------------------------------------
# Plugins
# ------------------------------------------------------------

declare -A MANIFEST

function load_manifest()
{
    # $1 == plugin ID, fills MANIFEST, returns 1 if not installed
    MANIFEST=()
    if [ ! -f "${PLUGINSdir}/${1}/plugin.conf" ]; then return 1; fi
    drsm_read_conf "${PLUGINSdir}/${1}/plugin.conf" MANIFEST
    if [ "${MANIFEST[MODE]}" == "" ]; then MANIFEST[MODE]="remote"; fi
    if [ "${MANIFEST[TIMEOUT]}" == "" ]; then MANIFEST[TIMEOUT]="60"; fi
    if [ "${MANIFEST[PLATFORMS]}" == "" ]; then MANIFEST[PLATFORMS]="linux"; fi
    return 0
}

function platform_ok()
{
    local p
    for p in ${MANIFEST[PLATFORMS]}; do
	if [ "${p}" == "any" ] || [ "${p}" == "${HCONF[PLATFORM]}" ]; then return 0; fi
    done
    return 1
}

function job_line()
{
    # Print the drsm_job_plugin call for plugin $1 on the current host,
    # with manifest defaults overridden by <prefix>_<KEY> host settings
    local id="${1}" entry="${2}" prefix k t args=()
    prefix=$(drsm_plugin_key "${id}")
    t="${HCONF[${prefix}_TIMEOUT]:-${MANIFEST[TIMEOUT]}}"
    for k in "${!MANIFEST[@]}"; do
	if drsm_is_manifest_key "${k}"; then continue; fi
	args+=("DRSM_${k}=${HCONF[${prefix}_${k}]-${MANIFEST[${k}]}}")
    done
    # Host settings for keys the manifest does not list
    for k in "${!HCONF[@]}"; do
	if [[ "${k}" == "${prefix}_"* ]]; then
	    k="${k#"${prefix}_"}"
	    if [ "${k}" == "TIMEOUT" ] || [ "${MANIFEST[${k}]+set}" == "set" ]; then continue; fi
	    args+=("DRSM_${k}=${HCONF[${prefix}_${k}]}")
	fi
    done
    args+=("DRSM_TARGET=${HCONF[HOST]}" "DRSM_HOST_DESCRIPTION=${HCONF[DESCRIPTION]}" "DRSM_HOST_IMPACT=${HCONF[IMPACT]}")
    printf 'drsm_job_plugin %q %q %q %q' "${id}" "${t}" "${entry}" "${MANIFEST[REQUIRES]}"
    printf ' %q' "${args[@]}"
    echo ""
}

function job_start()
{
    # $1 == job file, $2 == DRSM_BASE on the target
    cat "${DRSMHOME}/lib/drsm_job.sh" > "${1}"
    printf 'DRSM_BASE=%q\ndrsm_job_base\n' "${2}" >> "${1}"
}

declare -A PSTATE PSECS
PLIST=()

function parse_job()
{
    # Turn the framed job output in $1 into report sections in $2.
    # The state of each plugin is its exit code, raised to WARNING or
    # ERROR when its output has those lines. $3.. == expected IDs, an
    # expected plugin with no result is an ERROR.
    local out="${1}" rpt="${2}"
    shift 2
    local line id="" rc secs state body="" e
    local -A seen=()
    while IFS= read -r line || [ -n "${line}" ]
    do
	if [[ "${line}" == "@@DRSM_BEGIN "* ]]; then
	    id="${line#@@DRSM_BEGIN }"
	    body=""
	    continue
	fi
	if [[ "${line}" == "@@DRSM_END "* ]]; then
	    read -r id rc secs <<< "${line#@@DRSM_END }"
	    case "${rc}" in
		0) state="OK" ;;
		1) state="WARNING" ;;
		2) state="ERROR" ;;
		*) state="UNKNOWN" ;;
	    esac
	    if [[ "${body}" == *"ERROR - "* ]]; then
		state="ERROR"
	    elif [[ "${body}" == *"WARNING - "* ]] && [ "${state}" != "ERROR" ]; then
		state="WARNING"
	    fi
	    record_section "${rpt}" "${id}" "${state}" "${secs}" "${body}"
	    seen[${id}]=1
	    id=""
	    continue
	fi
	if [ "${id}" != "" ]; then body+="${line}"$'\n'; fi
    done < "${out}"
    for e in "$@"; do
	if [ "${seen[${e}]}" == "" ]; then
	    record_section "${rpt}" "${e}" "ERROR" "0" "ERROR - ${HCONF[HOST]} plugin ${e} returned no result"$'\n'
	fi
    done
}

function record_section()
{
    # $1 == report file, $2 == ID, $3 == state, $4 == seconds, $5 == output
    {
	echo "=== ${2} [${3}] ${4}s ==="
	printf '%s' "${5}"
	echo ""
    } >> "${1}"
    PSTATE[${2}]="${3}"
    PSECS[${2}]="${4}"
    PLIST+=("${2}")
}

function write_status_json()
{
    # Per host plugin states for the web pages, $1 == output file
    local id sep=""
    {
	printf '{"host":"%s","group":"%s","time":%s,"plugins":[' "${HCONF[HOST]}" "${HCONF[GROUP]}" "${ETIME}"
	for id in "${PLIST[@]}"; do
	    printf '%s{"id":"%s","state":"%s","secs":%s}' "${sep}" "${id}" "${PSTATE[${id}]}" "${PSECS[${id}]:-0}"
	    sep=","
	done
	echo "]}"
    } > "${1}"
}

function list_hosts()
{
    local src id
    for src in "${HOSTSOURCES[@]}"
    do
	load_host "${src}"
	if [ "${HCONF[GROUP]}" != "${group}" ]; then continue; fi
	echo "${HCONF[HOST]} (${HCONF[PLATFORM]}, collector ${HCONF[COLLECTOR]}) from ${HCONF[SOURCE]}"
	echo "  probes:  ${HCONF[PROBES]:-none}"
	echo "  plugins: ${HCONF[PLUGINS]:-none}"
	for id in ${HCONF[PROBES]} ${HCONF[PLUGINS]}; do
	    if ! load_manifest "${id}"; then echo "  WARNING - plugin ${id} is not installed in ${PLUGINSdir}"; fi
	done
    done
}

if [ "${listonly}" == "1" ]; then list_hosts; exit 0; fi

# ------------------------------------------------------------
# Run
# ------------------------------------------------------------

mkdir -p "${VARdir}" "${LOGdir}" "${OUTPUTdir}" "${REPORTdir}/systems" "${REPORTdir}/archive"
# shellcheck source=bin/process_lock.sh
source "${DRSMHOME}/bin/process_lock.sh"
LockFileCheck ${MINold}
CreateLockFile

: > "${statusfile}"
: > "${errorfile}"
: > "${checkfile}"
: > "${checkerrors}"
: > "${logfile}"

DATEEXT=$(date +%Y%m%d_%H%M%S)
ETIME=$(date +%s)
datetime=$(date)

if [ "${mode}" == "all" ]; then
    echo "DRSM health check report, ${datetime}" | tee -a "${statusfile}"
    echo "Our report type is set to: ${group^^}" | tee -a "${statusfile}"
fi
echo "DRSM status report, ${datetime}" >> "${checkfile}"
echo "Our report type is set to: ${group^^}" >> "${checkfile}"

found_host="0"
for src in "${HOSTSOURCES[@]}"
do
    load_host "${src}"
    if [ "${HCONF[GROUP]}" != "${group}" ]; then continue; fi
    host="${HCONF[HOST]}"
    if [ "${singletesthost}" != "" ] && [ "${host}" != "${singletesthost}" ]; then continue; fi
    found_host="1"
    if [ "${HCONF[ENABLED],,}" == "no" ]; then log "INFO - ${host} is disabled, skipping"; continue; fi

    log "Starting checks on ${host} ${HCONF[DESCRIPTION]}"
    hostdir="${OUTPUTdir}/${host}"
    mkdir -p "${hostdir}"
    report="${hostdir}/${host}_report.txt"
    PSTATE=()
    PSECS=()
    PLIST=()
    {
	echo "INFO - Start of ${host} system health check report"
	echo "REPORT_TIME:${datetime}"
	echo "ETIME:${ETIME}"
	echo "HOSTNAME:${host}"
	echo "DESCRIPTION:${HCONF[DESCRIPTION]}"
	echo "IMPACT:${HCONF[IMPACT]}"
	echo "GROUP:${HCONF[GROUP]}"
	echo "PLATFORM:${HCONF[PLATFORM]}"
	echo "COLLECTOR:${HCONF[COLLECTOR]}"
	echo "PROBES:${HCONF[PROBES]}"
	echo "PLUGINS:${HCONF[PLUGINS]}"
	echo ""
    } > "${report}"

    # Sort the listed plugins by where they run
    probes=()
    remotes=()
    for id in ${HCONF[PROBES]} ${HCONF[PLUGINS]}
    do
	if ! load_manifest "${id}"; then
	    record_section "${report}" "${id}" "WARNING" "0" "WARNING - Plugin ${id} for ${host} is not installed in ${PLUGINSdir}"$'\n'
	    continue
	fi
	if ! platform_ok; then
	    vlog "Skipping ${id} on ${host}, it does not support platform ${HCONF[PLATFORM]}"
	    continue
	fi
	if [ "${MANIFEST[MODE]}" == "probe" ]; then probes+=("${id}"); else remotes+=("${id}"); fi
    done

    # Probes run here, against the host
    host_down="0"
    if [ ${#probes[@]} -gt 0 ]
    then
	job="${hostdir}/probe_job.sh"
	job_start "${job}" "${DRSMHOME}"
	for id in "${probes[@]}"; do load_manifest "${id}"; job_line "${id}" probe.sh >> "${job}"; done
	bash "${job}" > "${hostdir}/probe_out.txt" 2>&1
	before=$(wc -l < "${report}")
	parse_job "${hostdir}/probe_out.txt" "${report}" "${probes[@]}"
	tail -n +$((before + 1)) "${report}" >> "${checkfile}"
	if [ "${PSTATE[network/ping]}" == "ERROR" ]; then host_down="1"; fi
	for id in "${probes[@]}"; do
	    if [ "${PSTATE[${id}]}" == "ERROR" ]; then
		check_errors="1"
		grep -h "^ERROR - \|^IMPACT - " "${hostdir}/probe_out.txt" >> "${checkerrors}"
		break
	    fi
	done
    else
	echo "INFO - Network connectivity skipped for ${host}, ${HCONF[DESCRIPTION]}" >> "${checkfile}"
    fi

    if [ "${mode}" == "probes" ]; then continue; fi

    # Remote plugins run on the host through its collector
    if [ ${#remotes[@]} -eq 0 ]; then
	:
    elif [ "${host_down}" == "1" ]; then
	echo "INFO - Skipping plugins, ${host} did not answer ping" >> "${report}"
    elif [ "${HCONF[COLLECTOR]}" == "none" ]; then
	echo "INFO - Skipping SSH system checks" >> "${report}"
    else
	collector="${HCONF[COLLECTOR]}"
	if [ "${collector}" == "ssh" ]; then collector="ssh-${HCONF[PLATFORM]}"; fi
	if [ ! -f "${DRSMHOME}/collectors/${collector}.sh" ]; then
	    echo "INFO - No ${collector} collector yet, skipping plugins on ${host}" >> "${report}"
	else
	    # shellcheck source=collectors/local.sh
	    source "${DRSMHOME}/collectors/${collector}.sh"
	    if ! collector_check "${host}"; then
		echo "ERROR - System report script cannot connect to ${host} with collector ${collector}, ${HCONF[DESCRIPTION]}" | tee -a "${report}" "${logfile}"
		has_errors="1"
	    else
		if ! collector_sync "${host}" "${remotes[@]}"; then
		    echo "WARNING - Cannot copy plugins to ${host} with collector ${collector}" >> "${report}"
		fi
		job="${hostdir}/remote_job.sh"
		job_start "${job}" "${COLLECTOR_BASE}"
		for id in "${remotes[@]}"; do load_manifest "${id}"; job_line "${id}" check.sh >> "${job}"; done
		collector_exec "${host}" "${job}" > "${hostdir}/remote_out.txt" 2>&1
		parse_job "${hostdir}/remote_out.txt" "${report}" "${remotes[@]}"
	    fi
	fi
    fi

    {
	echo "INFO - End of ${host} system health check report"
	echo ""
    } >> "${report}"

    mkdir -p "${REPORTdir}/systems/${host}/archive"
    cat "${report}" > "${REPORTdir}/systems/${host}/${host}_report.txt"
    cat "${report}" > "${REPORTdir}/systems/${host}/archive/${host}_report_${DATEEXT}.txt"
    write_status_json "${REPORTdir}/systems/${host}/status.json"
    cat "${report}" >> "${statusfile}"
    log "Checks complete on ${host}"
done

if [ "${singletesthost}" != "" ] && [ "${found_host}" == "0" ]; then
    echo "ERROR - Host ${singletesthost} not found in group ${group}"
fi

# Connectivity reports, the same files system_check.sh writes
if [ "${check_errors}" == "0" ]; then echo "System check did not report any ERRORS" > "${checkerrors}"; fi
cat "${checkfile}" > "${REPORTdir}/${checkprefix}_report.txt"
cat "${checkfile}" > "${REPORTdir}/archive/${checkprefix}_report_${DATEEXT}.txt"
cat "${checkerrors}" > "${REPORTdir}/${checkprefix}_report_errors.txt"
cat "${checkerrors}" > "${REPORTdir}/archive/${checkprefix}_report_errors_${DATEEXT}.txt"

# Health reports, the same files system_report.sh writes
if [ "${mode}" == "all" ]
then
    if grep "ERROR - " "${statusfile}" >> "${errorfile}"; then has_errors="1"; fi
    if grep "WARNING - " "${statusfile}" >> "${errorfile}"; then has_warning="1"; fi
    if [ "${has_errors}" == "0" ] && [ "${has_warning}" == "0" ]; then
	echo "System health check did not report any WARNINGS or ERRORS" > "${errorfile}"
    fi
    cat "${statusfile}" > "${REPORTdir}/${reportprefix}.txt"
    cat "${statusfile}" > "${REPORTdir}/archive/${reportprefix}_${DATEEXT}.txt"
    cat "${errorfile}" > "${REPORTdir}/${reportprefix}_errors.txt"
    cat "${errorfile}" > "${REPORTdir}/archive/${reportprefix}_errors_${DATEEXT}.txt"
else
    has_errors="${check_errors}"
    cat "${checkerrors}" > "${errorfile}"
    cat "${checkfile}" > "${statusfile}"
fi

function send_alert()
{
    # $1 == subject, $2 == body file, $3 == TRUE to also send texts
    if [ "${sendalerts}" == "0" ]; then log "Alerts are off, not sending: ${1}"; return 0; fi
    SUBJECT="${1}"
    BODY="${2}"
    TIMESPAN="4"
    SENDEMAIL="TRUE"
    SENDTEXT="${3}"
    if [ "${group}" != "production" ]; then
	SENDTEXT="FALSE"
	TIMEFILE="${VARdir}/email_alert${sfx}.timefile"
	INITFILE="${VARdir}/email_alert${sfx}.initfile"
    fi
    export SUBJECT BODY TIMESPAN SENDEMAIL SENDTEXT TIMEFILE INITFILE
    # shellcheck source=bin/text_email_alert.sh
    source "${DRSMHOME}/bin/text_email_alert.sh"
    email_alert "${SUBJECT}" "${BODY}"
}

what="Health Checks"
if [ "${mode}" == "probes" ]; then what="Connection Checks"; fi
groupname=""
if [ "${group}" != "production" ]; then groupname="${group^} Systems "; fi
message="${VARdir}/drsm_run_message.$$"
{ cat "${errorfile}"; echo ""; cat "${statusfile}"; } > "${message}"

rv=0
if [ "${has_errors}" == "1" ]
then
    log "${what} reported errors, sending alert message"
    send_alert "[!ALERT!] ${SITEID} ${groupname}${what} Reported Errors" "${message}" "TRUE"
    rv=2
elif [ "${has_warning}" == "1" ]
then
    if [ "${emailstatusreport}" == "YES" ]; then
	log "${what} reported warnings, sending status message"
	send_alert "[!INFO!] ${SITEID} ${groupname}${what} Reported Warnings" "${message}" "FALSE"
    else
	log "${what} reported warnings, not sending any status messages"
    fi
    rv=1
elif [ "${emailstatusreport}" == "YES" ]
then
    log "All systems check good, sending status message"
    send_alert "[!INFO!] ${SITEID} ${groupname}${what} Status Report" "${statusfile}" "FALSE"
else
    log "All systems check good, not sending any status messages"
fi

rm -f "${message}"
RemoveLockFile
exit ${rv}
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
