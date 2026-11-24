#!/bin/bash
# ----------------------------------------------------------- 
# BASH Script
# Operating System(s): RHEL/CENTOS
# Run Level(s): 3, 5
# Shell: BASH shell
# Original Author(s): DataReel Software Development
# File Creation Date: 11/23/2026
# Date Last Modified: 11/24/2026
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
# Push alerts, the replacement for the carriers' email to text (SMS)
# gateways. bin/text_email_alert.sh calls drsm_push_alert for every
# alert that would have sent a text: errors on production hosts.
# Errors on DEV and QA hosts push only inside their push hours,
# PUSH_DEV_HOURS and PUSH_QA_HOURS (drsm_push_tier_alert).
#
# Settings are KEY=value lines in ${ALERTdir}/alert.push.conf (or the
# file named by PUSH_CONF). The file holds API tokens: keep it mode 600.
# It is parsed, never sourced. See etc/alert.push.conf_example.
#
#   PUSH_PROVIDERS="pushover,ntfy"   providers to send to, comma delimited:
#                                    pushover, ntfy, gotify, webhook,
#                                    smsgateway (the old TEXTlist email)
#   PUSH_URL=https://...             link sent with the alert (dashboard)
#   PUSH_MAXCHARS=900                longest alert text sent
#   PUSH_DEV_HOURS="Mon-Fri 08:00-17:00"
#   PUSH_QA_HOURS="Mon-Fri 08:00-17:00"
#                                    when DEV and QA errors push, in the
#                                    site's time zone; unset: never
#
#   PUSHOVER_TOKEN, PUSHOVER_USER    application token, user or group key
#                                    (several user keys, comma delimited)
#   PUSHOVER_DEVICE, PUSHOVER_SOUND, PUSHOVER_PRIORITY (-2 to 2, default 1)
#   PUSHOVER_RETRY, PUSHOVER_EXPIRE  for priority 2 (defaults 300, 3600)
#   NTFY_URL=https://ntfy.sh/topic   NTFY_TOKEN, NTFY_PRIORITY (1-5, default 4)
#   GOTIFY_URL=https://gotify.host   GOTIFY_TOKEN (app token), GOTIFY_PRIORITY
#   WEBHOOK_URL=https://...          POST of {"title","text","message"}
#                                    JSON, Slack and Teams style webhooks
#
# With no PUSH_PROVIDERS and a TEXTlist in alert.email.list, texts still
# go to the email to text gateway as before (smsgateway).
#
# Tokens and webhook URLs go to curl in a mode 600 config file, never on
# the command line, and are never printed. DRSM_CURL replaces curl in
# the tests.
# -----------------------------------------------------------

if ! declare -F drsm_read_conf > /dev/null; then
    # shellcheck source=lib/drsm_conf.sh
    source "${DRSMHOME:-${BASEdir}}/lib/drsm_conf.sh"
fi

DRSM_PUSH_PROVIDERS_KNOWN="pushover ntfy gotify webhook smsgateway"

function drsm_push_q()
{
    # Quote $1 for a curl config file value
    local s="${1//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/}"
    echo "\"${s}\""
}

function drsm_push_json()
{
    # Escape $1 for a JSON string value
    local s="${1//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/}"
    s="${s//$'\t'/\\t}"
    echo -n "${s}"
}

function drsm_push_text()
{
    # Short alert text from body file $1: the ERROR and WARNING lines
    # first, else the start of the body, cut to $2 characters
    local body="${1}" max="${2:-900}" txt=""
    if [ -f "${body}" ]; then
	txt=$(grep -E '^(ERROR|WARNING) - ' "${body}" | awk '!seen[$0]++')
	if [ "${txt}" == "" ]; then txt=$(grep -v '^[[:space:]]*$' "${body}" | head -n 20); fi
    else
	txt="${body}"
    fi
    if [ "${#txt}" -gt "${max}" ]; then txt="${txt:0:$((max - 4))} ..."; fi
    echo "${txt}"
}

function drsm_push_curl()
{
    # Run curl with config file $1 (url and secrets) and more options,
    # print the HTTP status, return 0 on 2xx
    local cfg="${1}" code
    shift
    code=$(${DRSM_CURL:-curl} -sS --max-time "${PUSH_TIMEOUT:-20}" --retry 1 -o /dev/null -w '%{http_code}' -K "${cfg}" "$@" 2> /dev/null)
    echo "${code:-000}"
    [[ "${code}" =~ ^2[0-9][0-9]$ ]]
}

function drsm_push_pushover()
{
    # $1 == title, $2 == text file, $3 == config file to fill
    local -n __pc="${PUSH_CONF_ARRAY}"
    if [ "${__pc[PUSHOVER_TOKEN]}" == "" ] || [ "${__pc[PUSHOVER_USER]}" == "" ]; then
	echo "WARNING - pushover needs PUSHOVER_TOKEN and PUSHOVER_USER in ${PUSH_CONF}"
	return 1
    fi
    local pri="${__pc[PUSHOVER_PRIORITY]:-1}"
    {
	echo "url = $(drsm_push_q "${__pc[PUSHOVER_API]:-https://api.pushover.net/1/messages.json}")"
	echo "form-string = $(drsm_push_q "token=${__pc[PUSHOVER_TOKEN]}")"
	echo "form-string = $(drsm_push_q "user=${__pc[PUSHOVER_USER]}")"
    } > "${3}"
    local opts=(--form-string "title=${1:0:250}" -F "message=<${2}" --form-string "priority=${pri}")
    if [ "${pri}" == "2" ]; then
	opts+=(--form-string "retry=${__pc[PUSHOVER_RETRY]:-300}" --form-string "expire=${__pc[PUSHOVER_EXPIRE]:-3600}")
    fi
    if [ "${__pc[PUSHOVER_DEVICE]}" != "" ]; then opts+=(--form-string "device=${__pc[PUSHOVER_DEVICE]}"); fi
    if [ "${__pc[PUSHOVER_SOUND]}" != "" ]; then opts+=(--form-string "sound=${__pc[PUSHOVER_SOUND]}"); fi
    if [ "${PUSH_LINK}" != "" ]; then opts+=(--form-string "url=${PUSH_LINK}" --form-string "url_title=DRSM dashboard"); fi
    drsm_push_curl "${3}" "${opts[@]}"
}

function drsm_push_ntfy()
{
    local -n __pc="${PUSH_CONF_ARRAY}"
    if [ "${__pc[NTFY_URL]}" == "" ]; then
	echo "WARNING - ntfy needs NTFY_URL in ${PUSH_CONF}"
	return 1
    fi
    {
	echo "url = $(drsm_push_q "${__pc[NTFY_URL]}")"
	if [ "${__pc[NTFY_TOKEN]}" != "" ]; then
	    echo "header = $(drsm_push_q "Authorization: Bearer ${__pc[NTFY_TOKEN]}")"
	fi
    } > "${3}"
    local opts=(-H "Title: ${1//[$'\r\n']/ }" -H "Priority: ${__pc[NTFY_PRIORITY]:-4}" -H "Tags: rotating_light" --data-binary "@${2}")
    if [ "${PUSH_LINK}" != "" ]; then opts+=(-H "Click: ${PUSH_LINK}"); fi
    drsm_push_curl "${3}" "${opts[@]}"
}

function drsm_push_gotify()
{
    local -n __pc="${PUSH_CONF_ARRAY}"
    if [ "${__pc[GOTIFY_URL]}" == "" ] || [ "${__pc[GOTIFY_TOKEN]}" == "" ]; then
	echo "WARNING - gotify needs GOTIFY_URL and GOTIFY_TOKEN in ${PUSH_CONF}"
	return 1
    fi
    {
	echo "url = $(drsm_push_q "${__pc[GOTIFY_URL]%/}/message")"
	echo "header = $(drsm_push_q "X-Gotify-Key: ${__pc[GOTIFY_TOKEN]}")"
    } > "${3}"
    drsm_push_curl "${3}" --form-string "title=${1}" -F "message=<${2}" --form-string "priority=${__pc[GOTIFY_PRIORITY]:-8}"
}

function drsm_push_webhook()
{
    local -n __pc="${PUSH_CONF_ARRAY}"
    if [ "${__pc[WEBHOOK_URL]}" == "" ]; then
	echo "WARNING - webhook needs WEBHOOK_URL in ${PUSH_CONF}"
	return 1
    fi
    local t m json
    t=$(drsm_push_json "${1}")
    m=$(drsm_push_json "$(cat "${2}")")
    if [ "${PUSH_LINK}" != "" ]; then m="${m}\\n$(drsm_push_json "${PUSH_LINK}")"; fi
    json="${3}.json"
    printf '{"title":"%s","text":"*%s*\\n%s","message":"%s"}\n' "${t}" "${t}" "${m}" "${m}" > "${json}"
    echo "url = $(drsm_push_q "${__pc[WEBHOOK_URL]}")" > "${3}"
    drsm_push_curl "${3}" -H "Content-Type: application/json" --data-binary "@${json}"
}

function drsm_push_smsgateway()
{
    # The old email to text gateway: mail the short text to TEXTlist
    if [ "${TEXTlist}" == "" ]; then
	echo "WARNING - smsgateway needs TEXTlist in ${ALERTdir}/alert.email.list"
	return 1
    fi
    if [ "${MAILcmd}" == "" ]; then MAILcmd=$(command -v mail || command -v mailx || command -v s-nail); fi
    if [ "${MAILcmd}" == "" ]; then
	echo "ERROR - No mail command found, install the s-nail, mailx, or bsd-mailx package"
	return 1
    fi
    ${MAILcmd} -s "${1}" ${TEXTlist//,/ } < "${2}"
}

function drsm_push_providers()
{
    # Print the providers to use, one per line
    local -n __pc="${PUSH_CONF_ARRAY}"
    local list="${PUSH_PROVIDERS:-${__pc[PUSH_PROVIDERS]}}"
    if [ "${list}" == "" ] && [ "${TEXTlist}" != "" ]; then list="smsgateway"; fi
    list="${list//,/ }"
    local p
    for p in ${list}; do echo "${p,,}"; done | awk '!seen[$0]++'
}

function drsm_push_alert()
{
    # Send alert $1 (subject) with body $2 (a file or text) to every
    # provider in PUSH_PROVIDERS. Returns 0 when all of them took it.
    local subject="${1}" body="${2}"
    if [ "${ALERTdir}" == "" ]; then ALERTdir="${DRSMHOME}/etc"; fi
    PUSH_CONF="${PUSH_CONF:-${ALERTdir}/alert.push.conf}"
    declare -gA DRSM_PUSH_CONF=()
    PUSH_CONF_ARRAY=DRSM_PUSH_CONF
    if [ -f "${PUSH_CONF}" ]; then
	if [ -n "$(find "${PUSH_CONF}" -maxdepth 0 -perm /077 2> /dev/null)" ]; then
	    echo "WARNING - ${PUSH_CONF} holds API tokens and can be read by other users, run: chmod 600 ${PUSH_CONF}"
	fi
	drsm_read_conf "${PUSH_CONF}" DRSM_PUSH_CONF
    fi
    PUSH_LINK="${DRSM_PUSH_CONF[PUSH_URL]}"
    local providers
    providers=$(drsm_push_providers)
    if [ "${providers}" == "" ]; then return 0; fi

    local tmp txt cfg p code rv=0 n=0
    tmp=$(mktemp -d "${VARdir:-/tmp}/.drsm_push.XXXXXX") || return 1
    chmod 700 "${tmp}"
    txt="${tmp}/text"
    drsm_push_text "${body}" "${DRSM_PUSH_CONF[PUSH_MAXCHARS]:-900}" > "${txt}"
    for p in ${providers}
    do
	if [[ " ${DRSM_PUSH_PROVIDERS_KNOWN} " != *" ${p} "* ]]; then
	    echo "WARNING - Unknown push provider ${p}, use one of: ${DRSM_PUSH_PROVIDERS_KNOWN}"
	    rv=1
	    continue
	fi
	n=$((n + 1))
	cfg="${tmp}/curl.${p}"
	( umask 077; : > "${cfg}" )
	if [ "${p}" == "smsgateway" ]; then
	    echo "Text messaging to: ${TEXTlist}"
	    drsm_push_smsgateway "${subject}" "${txt}" || rv=1
	    continue
	fi
	code=$("drsm_push_${p}" "${subject}" "${txt}" "${cfg}")
	if [ $? -eq 0 ]; then
	    echo "Push alert sent with ${p} (HTTP ${code})"
	else
	    echo "${code}" | grep -E '^(WARNING|ERROR) - '
	    echo "${code}" | grep -qE '^(WARNING|ERROR) - ' || echo "WARNING - Push alert with ${p} failed (HTTP ${code##*$'\n'})"
	    rv=1
	fi
    done
    rm -rf "${tmp}"
    return ${rv}
}
function drsm_push_day()
{
    # Day number of day name $1, 1 (Mon) to 7 (Sun) as date +%u
    case "${1,,}" in
	mon|monday) echo 1 ;; tue|tues|tuesday) echo 2 ;; wed|wednesday) echo 3 ;;
	thu|thur|thurs|thursday) echo 4 ;; fri|friday) echo 5 ;;
	sat|saturday) echo 6 ;; sun|sunday) echo 7 ;;
	*) return 1 ;;
    esac
}

function drsm_push_hhmm()
{
    # HH:MM $1 as a number HHMM, 0000 to 2400
    if [[ ! "${1}" =~ ^([0-9]{1,2}):([0-9]{2})$ ]]; then return 1; fi
    local h=$((10#${BASH_REMATCH[1]})) m=$((10#${BASH_REMATCH[2]}))
    if [ ${m} -gt 59 ] || [ ${h} -gt 24 ] || { [ ${h} -eq 24 ] && [ ${m} -gt 0 ]; }; then return 1; fi
    echo $((h * 100 + m))
}

function drsm_push_in_hours()
{
    # Is time $2 (epoch seconds, default now) inside push hours $1?
    # $1 is "always", "never", or windows separated by ";", each
    # "[DAYS] HH:MM-HH:MM" in the local time zone (TZ). DAYS is a comma
    # list of days and day ranges (Mon-Fri, Sat,Sun, Mon-Wed,Fri) or
    # daily, the default. The end time is not included: 08:00-17:00 is
    # 8 AM up to 5 PM. An end before the start runs past midnight.
    # Returns 0 inside, 1 outside, 2 when $1 is not valid.
    local spec="${1}" now="${2:-$(date +%s)}"
    case "${spec,,}" in
	always) return 0 ;;
	""|never|off|none) return 1 ;;
    esac
    local dow hm w days range extra s e d a b dayok parts wins rv=1
    dow=$(date -d "@${now}" +%u)
    hm=$((10#$(date -d "@${now}" +%H%M)))
    IFS=';' read -ra wins <<< "${spec}"
    for w in "${wins[@]}"
    do
	read -r days range extra <<< "${w}"
	if [ "${days}" == "" ]; then continue; fi
	if [ "${range}" == "" ]; then range="${days}"; days="daily"; fi
	if [ "${extra}" != "" ] || [[ ! "${range}" =~ ^([^-]+)-([^-]+)$ ]] || \
	   ! s=$(drsm_push_hhmm "${BASH_REMATCH[1]}") || ! e=$(drsm_push_hhmm "${BASH_REMATCH[2]}"); then
	    echo "WARNING - Push hours \"${spec}\" not valid, use for example \"Mon-Fri 08:00-17:00\"" >&2
	    return 2
	fi
	dayok=1
	if [[ "${days,,}" =~ ^(daily|all|every|\*)$ ]]; then
	    dayok=0
	else
	    IFS=',' read -ra parts <<< "${days}"
	    for d in "${parts[@]}"
	    do
		if [[ "${d}" == *-* ]]; then
		    a=$(drsm_push_day "${d%%-*}") && b=$(drsm_push_day "${d#*-}") || { a=""; }
		else
		    a=$(drsm_push_day "${d}") && b="${a}" || { a=""; }
		fi
		if [ "${a}" == "" ]; then
		    echo "WARNING - Push hours \"${spec}\" has a bad day \"${d}\", use Mon to Sun" >&2
		    return 2
		fi
		if { [ ${a} -le ${b} ] && [ ${dow} -ge ${a} ] && [ ${dow} -le ${b} ]; } || \
		   { [ ${a} -gt ${b} ] && { [ ${dow} -ge ${a} ] || [ ${dow} -le ${b} ]; }; }; then
		    dayok=0
		fi
	    done
	fi
	if [ ${dayok} -ne 0 ]; then continue; fi
	if { [ ${s} -lt ${e} ] && [ ${hm} -ge ${s} ] && [ ${hm} -lt ${e} ]; } || \
	   { [ ${s} -gt ${e} ] && { [ ${hm} -ge ${s} ] || [ ${hm} -lt ${e} ]; }; } || \
	   [ ${s} -eq ${e} ]; then
	    rv=0
	fi
    done
    return ${rv}
}

function drsm_push_hours_spec()
{
    # Push hours for tier $1 (DEV, QA): $2 when set (a site file's
    # PUSH_<TIER>_HOURS), else PUSH_<TIER>_HOURS in alert.push.conf
    local tier="${1^^}" spec="${2}"
    tier="${tier//[^A-Z0-9_]/_}"
    if [ "${spec}" == "" ]; then
	if [ "${ALERTdir}" == "" ]; then ALERTdir="${DRSMHOME}/etc"; fi
	local -A __phconf=()
	drsm_read_conf "${PUSH_CONF:-${ALERTdir}/alert.push.conf}" __phconf 2> /dev/null
	spec="${__phconf[PUSH_${tier}_HOURS]}"
    fi
    echo "${spec}"
}

function drsm_push_tier_alert()
{
    # Push alert $1 (subject) with body $2 for errors on tier $3 (DEV,
    # QA) hosts: only inside push hours $4, and at most once every $6
    # hours (default 4) with time file $5. It has its own throttle so
    # an error that starts before the hours pushes when they start,
    # even though its email went out less than 4 hours ago.
    local subject="${1}" body="${2}" tier="${3}" spec="${4}" tf="${5}" span="${6:-4}" now last
    now=$(date +%s)
    drsm_push_in_hours "${spec}" "${now}" 2>&1
    case $? in
	1) echo "Outside ${tier} push hours (${spec}), no push alert"; return 0 ;;
	2) return 1 ;;
    esac
    last=0
    if [ -f "${tf}" ]; then last=$(cat "${tf}"); fi
    if ! [[ "${last}" =~ ^[0-9]+$ ]]; then last=0; fi
    if [ $((now - last)) -lt $((span * 3600)) ]; then
	echo "INFO - ${tier} push alert sent $(( (now - last) / 60 )) minutes ago, we only push every ${span} hours"
	return 0
    fi
    echo "${now}" > "${tf}"
    chmod 664 "${tf}" 2> /dev/null
    echo "Inside ${tier} push hours (${spec}), sending push alert"
    drsm_push_alert "${subject}" "${body}"
}
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
