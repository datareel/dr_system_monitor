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
# Tests for lib/drsm_notify.sh push alerts, with a fake curl and mail:
# the fields each provider sends, secrets kept off the command line,
# the TEXTlist fallback, the email_alert hook in text_email_alert.sh,
# and the DEV and QA push hours.
#
# Usage: tests/notify_test.sh
#
# -----------------------------------------------------------
TOPdir=$(cd "$(dirname "$0")/.." && pwd)
failures=0

function pass() { echo "PASS - $*"; }
function fail() { echo "FAIL - $*"; failures=$((failures + 1)); }
function check() { if eval "${2}"; then pass "${1}"; else fail "${1}"; fi; }

T=$(mktemp -d)
trap 'rm -rf "${T}"' EXIT
mkdir -p "${T}/etc" "${T}/var" "${T}/log"

# Fake curl: saves its arguments, the -K config and any @ or < files
cat > "${T}/curl" <<'FAKE'
#!/bin/bash
n=$(ls "${FAKELOG}" | grep -c '^args')
n=$((n + 1))
printf '%s\n' "$@" > "${FAKELOG}/args.${n}"
prev=""
for a in "$@"; do
    if [ "${prev}" == "-K" ]; then cat "${a}" > "${FAKELOG}/cfg.${n}"; fi
    case "${a}" in
	message=\<*) cat "${a#message=<}" > "${FAKELOG}/msg.${n}" ;;
	@*) cat "${a#@}" > "${FAKELOG}/data.${n}" ;;
    esac
    prev="${a}"
done
echo -n "${FAKECODE:-200}"
FAKE
cat > "${T}/mail" <<'FAKE'
#!/bin/bash
printf '%s\n' "$@" > "${FAKELOG}/mail.args"
cat > "${FAKELOG}/mail.body"
FAKE
chmod 755 "${T}/curl" "${T}/mail"

export FAKELOG="${T}/log" DRSM_CURL="${T}/curl" MAILcmd="${T}/mail"
export ALERTdir="${T}/etc" VARdir="${T}/var" DRSMHOME="${TOPdir}"
# shellcheck source=lib/drsm_notify.sh
source "${TOPdir}/lib/drsm_notify.sh"

body="${T}/body"
printf 'ERROR - web1:/var is at 97%% capacity.\nERROR - web1:/var is at 97%% capacity.\nWARNING - web2 load is 12\n\nHOSTNAME: web1\n' > "${body}"

function reset() { rm -f "${FAKELOG}"/*; unset TEXTlist PUSH_PROVIDERS PUSH_CONF; }

# --- Nothing set up: no push, no mail ----------------------------
reset
out=$(drsm_push_alert "Subject" "${body}"); rv=$?
check "no providers sends nothing" '[ ${rv} -eq 0 ] && [ -z "$(ls "${FAKELOG}")" ]'

# --- Old setup: TEXTlist only, still mailed ------------------------
reset
export TEXTlist="5555555555@vtext.com"
out=$(drsm_push_alert "Subject" "${body}"); rv=$?
check "TEXTlist alone uses the email to text gateway" '[ ${rv} -eq 0 ] && grep -q "5555555555@vtext.com" "${FAKELOG}/mail.args"'
check "gateway text has each problem once" '[ "$(grep -c "web1:/var" "${FAKELOG}/mail.body")" -eq 1 ] && grep -q "WARNING - web2" "${FAKELOG}/mail.body"'
check "gateway text leaves out the report body" '! grep -q HOSTNAME "${FAKELOG}/mail.body"'

# --- Pushover ------------------------------------------------------
reset
cat > "${T}/etc/alert.push.conf" <<'CONF'
PUSH_PROVIDERS="pushover"
PUSH_URL="https://example.com/dashboard/"
PUSHOVER_TOKEN="atoken123secret"
PUSHOVER_USER="ukey456secret"
CONF
chmod 600 "${T}/etc/alert.push.conf"
export TEXTlist="5555555555@vtext.com"
out=$(drsm_push_alert "[!ALERT!] DRSM Health Checks Reported Errors" "${body}"); rv=$?
check "pushover returns 0" '[ ${rv} -eq 0 ]'
check "pushover logs the send" 'echo "${out}" | grep -q "Push alert sent with pushover (HTTP 200)"'
check "PUSH_PROVIDERS replaces the gateway" '[ ! -f "${FAKELOG}/mail.args" ]'
check "pushover API URL" 'grep -q "url = \"https://api.pushover.net/1/messages.json\"" "${FAKELOG}/cfg.1"'
check "pushover token and user in the config file" 'grep -q "token=atoken123secret" "${FAKELOG}/cfg.1" && grep -q "user=ukey456secret" "${FAKELOG}/cfg.1"'
check "pushover secrets not on the command line" '! grep -q secret "${FAKELOG}/args.1"'
check "pushover secrets not printed" '! echo "${out}" | grep -q secret'
check "pushover title" 'grep -qx "title=\[!ALERT!\] DRSM Health Checks Reported Errors" "${FAKELOG}/args.1"'
check "pushover default priority 1" 'grep -qx "priority=1" "${FAKELOG}/args.1"'
check "pushover dashboard link" 'grep -qx "url=https://example.com/dashboard/" "${FAKELOG}/args.1"'
check "pushover message" 'grep -q "ERROR - web1:/var is at 97% capacity." "${FAKELOG}/msg.1"'
check "temp files removed" '[ -z "$(ls -A "${T}/var")" ]'

reset
printf 'PUSH_PROVIDERS=pushover\nPUSHOVER_TOKEN=t\nPUSHOVER_USER=u\nPUSHOVER_PRIORITY=2\n' > "${T}/etc/alert.push.conf"
chmod 600 "${T}/etc/alert.push.conf"
drsm_push_alert "S" "${body}" > /dev/null
check "pushover emergency priority sets retry and expire" 'grep -qx "retry=300" "${FAKELOG}/args.1" && grep -qx "expire=3600" "${FAKELOG}/args.1"'

reset
export FAKECODE=400
out=$(drsm_push_alert "S" "${body}"); rv=$?
unset FAKECODE
check "pushover HTTP 400 fails with a warning" '[ ${rv} -eq 1 ] && echo "${out}" | grep -q "WARNING - Push alert with pushover failed (HTTP 400)"'

reset
printf 'PUSH_PROVIDERS=pushover\nPUSHOVER_TOKEN=t\n' > "${T}/etc/alert.push.conf"
chmod 644 "${T}/etc/alert.push.conf"
out=$(drsm_push_alert "S" "${body}"); rv=$?
check "pushover without a user key warns" '[ ${rv} -eq 1 ] && echo "${out}" | grep -q "WARNING - pushover needs PUSHOVER_TOKEN and PUSHOVER_USER"'
check "readable push conf warns" 'echo "${out}" | grep -q "can be read by other users"'

# --- ntfy, gotify, webhook, several providers -----------------------
reset
cat > "${T}/etc/alert.push.conf" <<'CONF'
PUSH_PROVIDERS="ntfy, gotify,webhook,bogus"
NTFY_URL="https://ntfy.example/topic"
NTFY_TOKEN="ntfysecret"
GOTIFY_URL="https://gotify.example/"
GOTIFY_TOKEN="gotifysecret"
WEBHOOK_URL="https://hooks.example/services/websecret"
CONF
chmod 600 "${T}/etc/alert.push.conf"
out=$(drsm_push_alert 'Say "hi"' "${body}"); rv=$?
check "unknown provider fails with a warning" '[ ${rv} -eq 1 ] && echo "${out}" | grep -q "WARNING - Unknown push provider bogus"'
check "three providers sent" '[ "$(echo "${out}" | grep -c "Push alert sent")" -eq 3 ]'
check "ntfy token header in the config file" 'grep -q "Authorization: Bearer ntfysecret" "${FAKELOG}/cfg.1" && grep -qx "Title: Say \"hi\"" "${FAKELOG}/args.1"'
check "gotify URL and key" 'grep -q "url = \"https://gotify.example/message\"" "${FAKELOG}/cfg.2" && grep -q "X-Gotify-Key: gotifysecret" "${FAKELOG}/cfg.2"'
check "webhook JSON escapes quotes" 'grep -q "\"title\":\"Say \\\\\"hi\\\\\"\"" "${FAKELOG}/data.3"'
check "no secret on any command line" '! cat "${FAKELOG}"/args.* | grep -q secret'
if command -v php > /dev/null; then
    check "webhook JSON is valid" 'php -r "exit(json_decode(file_get_contents(\"${FAKELOG}/data.3\")) === null ? 1 : 0);"'
fi

# --- email_alert hook ----------------------------------------------
reset
printf 'PUSH_PROVIDERS=pushover\nPUSHOVER_TOKEN=t\nPUSHOVER_USER=u\n' > "${T}/etc/alert.push.conf"
chmod 600 "${T}/etc/alert.push.conf"
printf 'export DRSMHOME=%s\nexport VARdir=%s\nexport ALERTdir=%s\nexport EMAILlist="ops@example.com"\n' "${TOPdir}" "${T}/var" "${T}/etc" > "${T}/drsm.sh"
out=$(DRSM_CONFIG="${T}/drsm.sh" TIMESPAN=0 SENDEMAIL=TRUE SENDTEXT=TRUE bash -c 'source "${DRSMHOME}/bin/text_email_alert.sh"; email_alert "Hook subject" "'"${body}"'"')
check "email_alert emails and pushes" 'grep -q "ops@example.com" "${FAKELOG}/mail.args" && echo "${out}" | grep -q "Push alert sent with pushover"'
reset
out=$(DRSM_CONFIG="${T}/drsm.sh" TIMESPAN=0 SENDEMAIL=TRUE SENDTEXT=FALSE bash -c 'source "${DRSMHOME}/bin/text_email_alert.sh"; email_alert "Hook subject" "'"${body}"'"')
check "SENDTEXT=FALSE sends no push" '! echo "${out}" | grep -q "Push alert" && [ ! -f "${FAKELOG}/args.1" ]'

# --- DEV and QA push hours ------------------------------------------
# Fixed times in a fixed zone: 2026-11-23 is a Monday
export TZ="America/New_York"
mon0759=$(date -d "2026-11-23 07:59" +%s); mon0800=$(date -d "2026-11-23 08:00" +%s)
mon1659=$(date -d "2026-11-23 16:59" +%s); mon1700=$(date -d "2026-11-23 17:00" +%s)
fri1200=$(date -d "2026-11-27 12:00" +%s); sat1200=$(date -d "2026-11-28 12:00" +%s)
sun2330=$(date -d "2026-11-29 23:30" +%s)
biz="Mon-Fri 08:00-17:00"
check "push hours: Mon 07:59 outside" '! drsm_push_in_hours "${biz}" ${mon0759}'
check "push hours: Mon 08:00 inside" 'drsm_push_in_hours "${biz}" ${mon0800}'
check "push hours: Mon 16:59 inside" 'drsm_push_in_hours "${biz}" ${mon1659}'
check "push hours: Mon 17:00 outside" '! drsm_push_in_hours "${biz}" ${mon1700}'
check "push hours: Fri noon inside" 'drsm_push_in_hours "${biz}" ${fri1200}'
check "push hours: Sat noon outside" '! drsm_push_in_hours "${biz}" ${sat1200}'
check "push hours: day list and ;" 'drsm_push_in_hours "Mon,Wed 09:00-10:00; Sat 10:00-14:00" ${sat1200} && ! drsm_push_in_hours "Mon,Wed 09:00-10:00" ${fri1200}'
check "push hours: wrapping days and midnight" 'drsm_push_in_hours "Fri-Mon 22:00-06:00" ${sun2330} && ! drsm_push_in_hours "Fri-Mon 22:00-06:00" ${sat1200}'
check "push hours: no days is daily" 'drsm_push_in_hours "11:00-13:00" ${sat1200}'
check "push hours: 8x5 and 24x7" 'drsm_push_in_hours 8x5 ${mon0800} && ! drsm_push_in_hours 8x5 ${sat1200} && drsm_push_in_hours 24x7 ${sat1200}'
check "push hours: always and never" 'drsm_push_in_hours always ${sat1200} && ! drsm_push_in_hours never ${mon0800} && ! drsm_push_in_hours "" ${mon0800}'
drsm_push_in_hours "Mon-Fri 8-17" ${mon0800} 2> /dev/null; rv=$?
check "push hours: bad time is not valid" '[ ${rv} -eq 2 ]'
drsm_push_in_hours "Mo-Fr 08:00-17:00" ${mon0800} 2> /dev/null; rv=$?
check "push hours: bad day is not valid" '[ ${rv} -eq 2 ]'

reset
printf 'PUSH_PROVIDERS=pushover\nPUSHOVER_TOKEN=t\nPUSHOVER_USER=u\nPUSH_DEV_HOURS="Mon-Fri 08:00-17:00" # office hours\n' > "${T}/etc/alert.push.conf"
chmod 600 "${T}/etc/alert.push.conf"
check "push hours read from alert.push.conf" '[ "$(drsm_push_hours_spec dev)" == "Mon-Fri 08:00-17:00" ] && [ "$(drsm_push_hours_spec QA)" == "" ]'
check "site push hours replace alert.push.conf" '[ "$(drsm_push_hours_spec DEV "always")" == "always" ]'
tf="${T}/var/push_alert_dev.timefile"
out=$(drsm_push_tier_alert "S" "${body}" DEV "always" "${tf}" 4)
check "tier push inside the hours sends" 'echo "${out}" | grep -q "Push alert sent with pushover" && [ -s "${tf}" ]'
reset
out=$(drsm_push_tier_alert "S" "${body}" DEV "always" "${tf}" 4)
check "tier push throttled for 4 hours" 'echo "${out}" | grep -q "INFO - DEV push alert sent 0 minutes ago" && [ ! -f "${FAKELOG}/args.1" ]'
echo 0 > "${tf}"
out=$(drsm_push_tier_alert "S" "${body}" DEV "never" "${tf}" 4)
check "tier push outside the hours sends nothing" 'echo "${out}" | grep -q "Outside DEV push hours" && [ ! -f "${FAKELOG}/args.1" ] && [ "$(cat "${tf}")" == "0" ]'
out=$(drsm_push_tier_alert "S" "${body}" DEV "weekdays" "${tf}" 4); rv=$?
check "tier push with bad hours warns" '[ ${rv} -eq 1 ] && echo "${out}" | grep -q "WARNING - Push hours" && [ ! -f "${FAKELOG}/args.1" ]'
rm -f "${tf}"
unset TZ

echo ""
if [ ${failures} -eq 0 ]; then echo "All notify tests passed"; exit 0; fi
echo "${failures} notify test(s) failed"
exit 1
