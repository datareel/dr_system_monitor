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
# Tests for bin/drsm_run.sh, the plugin framework, and the systems.dat
# migration. Runs without root, a Web server, or SSH: a fake ssh
# command runs the remote side in a temporary home directory.
#
# Usage: tests/drsm_run_test.sh
#
# ----------------------------------------------------------- 
TOPdir=$(cd "$(dirname "$0")/.." && pwd)
T=$(mktemp -d)
trap 'rm -rf "${T}"' EXIT
failures=0

function pass() { echo "PASS - $*"; }
function fail() { echo "FAIL - $*"; failures=$((failures + 1)); }
function expect() {
    # $1 == description, $2 == file, $3 == fixed string that must be in it
    if grep -qF -- "${3}" "${2}"; then pass "${1}"; else fail "${1}: '${3}' not in ${2}"; fi
}

mkdir -p "${T}/home" "${T}/remote" "${T}/www/config" "${T}/hosts"
cat > "${T}/home/.drsm.sh" <<CONF
export SITEID="DRSMTEST"
export WWWdir=${T}/www
export REPORTdir=\${WWWdir}/reports
export CONFIGdir=\${WWWdir}/config
export DRSMHOME=${TOPdir}
export ALERTdir=${T}
export TEMPdir=${T}/tmp
export LOGdir=\${TEMPdir}/logs
export VARdir=\${TEMPdir}/var
export HOSTSdir=${T}/hosts
export SITESdir=${T}/sites
export SYSADMIN_USERNAME=\$(whoami)
CONF

# ssh stand in: skips the options and the host name, runs the command
# in the fake remote home
cat > "${T}/fakessh" <<FAKE
#!/bin/bash
while [ "\${1:0:1}" == "-" ]; do if [ "\${1}" == "-o" ]; then shift; fi; shift; done
shift
cd "${T}/remote" && HOME="${T}/remote" bash -c "\$*"
FAKE
chmod 755 "${T}/fakessh"
export DRSM_SSH="${T}/fakessh"

function run() { HOME="${T}/home" bash "${TOPdir}/bin/drsm_run.sh" "$@" > "${T}/run.log" 2>&1; }
R="${T}/www/reports"

echo "== systems.dat fallback"
cat > "${T}/www/config/systems.dat" <<'DAT'
# test hosts
datbox,Dat test box,Testing,no,yes,no,no,yes
DAT
run -n
rc=$?
expect "systems.dat host gets a report" "${R}/systems/datbox/datbox_report.txt" "HOSTNAME:datbox"
expect "default plugin set runs over ssh" "${R}/systems/datbox/datbox_report.txt" "=== core/memory ["
expect "plugins were copied to the remote home" "${T}/remote/drsm_agent/.bundle_md5" ""
expect "health report written" "${R}/system_health_report.txt" "Start of datbox"
if [ ${rc} -le 2 ]; then pass "exit code ${rc} is 0, 1 or 2"; else fail "exit code ${rc}"; fi

echo "== host files, settings, timeouts, missing plugins"
cat > "${T}/hosts/_defaults.conf" <<'HOSTS'
PLUGINS="core/load core/memory"
PROBES=""
HOSTS
cat > "${T}/hosts/box1.conf" <<'HOSTS'
HOST=box1
DESCRIPTION="Box one"   # comment after a quoted value
COLLECTOR=ssh
PLUGINS="core/load storage/disk core/nosuch"
core_load_CRIT=-1
storage_disk_WARN=0
HOSTS
cat > "${T}/hosts/box2.conf" <<'HOSTS'
HOST=box2
COLLECTOR=local
GROUP=dev
HOSTS
run -n
rc=$?
B1="${R}/systems/box1/box1_report.txt"
expect "host file description parsed" "${B1}" "DESCRIPTION:Box one"
expect "host setting overrides manifest" "${B1}" "=== core/load [ERROR]"
expect "disk warning from WARN=0" "${B1}" "=== storage/disk [WARNING]"
expect "missing plugin reported" "${B1}" "Plugin core/nosuch for box1 is not installed"
expect "status.json written" "${R}/systems/box1/status.json" '{"id":"core/load","state":"ERROR"'
expect "errors file has the load error" "${R}/system_health_report_errors.txt" "15 minute load average"
if [ ${rc} -eq 2 ]; then pass "errors exit 2"; else fail "errors exit ${rc}, expected 2"; fi
if [ ! -f "${R}/systems/box2/box2_report.txt" ]; then pass "dev host skipped in production run"; else fail "dev host ran in production"; fi

run -n -g dev
expect "dev group uses the local collector" "${R}/systems/box2/box2_report.txt" "=== core/memory [OK]"
expect "dev group report name" "${R}/system_health_report_dev.txt" "Start of box2"

echo "== probes"
cat > "${T}/hosts/box1.conf" <<'HOSTS'
HOST=box1
PROBES="network/http"
network_http_URL=http://127.0.0.1:9/
network_http_RETRIES=0
network_http_CONNECT_TIMEOUT=2
PLUGINS="core/load"
HOSTS
run -n -m probes
expect "failed probe in check report" "${R}/system_check_report.txt" "ERROR - HTTP connectivity failed on box1"
expect "failed probe in check errors" "${R}/system_check_report_errors.txt" "IMPACT - box1 web service down"

echo "== timeout"
mkdir -p "${TOPdir}/plugins/local/zz_test_slow"
printf 'MODE=remote\nTIMEOUT=1\n' > "${TOPdir}/plugins/local/zz_test_slow/plugin.conf"
printf 'sleep 5\n' > "${TOPdir}/plugins/local/zz_test_slow/check.sh"
printf 'HOST=box3\nCOLLECTOR=local\nPLUGINS="local/zz_test_slow"\n' > "${T}/hosts/box3.conf"
run -n -H box3
rm -rf "${TOPdir}/plugins/local/zz_test_slow"
expect "slow plugin is stopped" "${R}/systems/box3/box3_report.txt" "plugin local/zz_test_slow timed out after 1 seconds"

echo "== windows reporting agent"
rm -f "${T}/hosts/"*.conf
W="${T}/wra"
mkdir -p "${W}"
now=$(date +%s)
today=$(date -u +%Y-%m-%d)
# Report in the agent's format: $1 == host, $2 == ETIME, $3 == newest
# patch date, $4 == extra Defender event lines
function wra_fixture() {
    cat > "${W}/${1}_windows_report_agent.txt" <<REPORT
Windows report agent from host ${1}
VERSION: 3.2
HOSTNAME: ${1}
ETIME: ${2}
DATETIME: $(date -d "@${2}")

PERFORMANCE:
cpu_count=4
cpu_used_pct=12.5
cpu_sample_seconds=5
mem_total_mb=16000
mem_available_mb=9000
mem_used_pct=43.8
commit_limit_mb=20000
commit_used_mb=8000
process_count=180
thread_count=2000
uptime_seconds=90000
END PERFORMANCE
DISK USAGE:
drive=C: size_mb=500000 used_mb=475000 free_mb=25000 used_pct=95.0
drive=D: size_mb=100000 used_mb=10000 free_mb=90000 used_pct=10.0
END DISK USAGE
NETWORK:
adapter="Wi-Fi \\"Office\\"" if_index=12 speed_mbps=866 rx_bytes=123456789 tx_bytes=2345678 rx_packets=1000 tx_packets=900 rx_errors=0 tx_errors=0 rx_discards=3 tx_discards=0
END NETWORK

ALL INSTALLED PROGRAMS:
--- 64-bit / Default Hive ---
Name: 7-Zip 25.01 (x64) | Version: 25.01
Name: Mozilla Firefox (x64 en-US) | Version: 140.0
END ALL INSTALLED PROGRAMS

WINDOWS DEFENDER ALERTS:
<Event xmlns='x'><System><EventID>1002</EventID><TimeCreated SystemTime='${today}T01:00:00.0Z'/></System></Event>
${4}
END WINDOWS DEFENDER ALERTS

INSTALLED WINDOWS PATCHES:
Date:  ${today}
 Patch: Security Intelligence Update for Microsoft Defender Antivirus - KB2267602
Date:  ${3}
 Patch: 2026-09 Cumulative Update for Windows 11
END INSTALLED WINDOWS PATCHES

HOT FIXES:
Installed On:   9/9/2026
END HOT FIXES
REPORT
}
wra_fixture good1 "$((now - 600))" "$(date -d "-60 days" +%Y-%m-%d)" ""
old_day=$(date -u -d "-10 days" +%Y-%m-%d)
wra_fixture old1 "$((now - 20 * 86400))" "2026-1-5" "<Event><System><EventID>1116</EventID><TimeCreated SystemTime='${today}T02:00:00.0Z'/></System><EventData><Data Name='Threat Name'>Trojan:Win32/Fixture</Data></EventData></Event>
<Event><System><EventID>5001</EventID><TimeCreated SystemTime='${old_day}T03:00:00.0Z'/></System></Event>
<Event><System><EventID>1116</EventID><TimeCreated SystemTime='${old_day}T04:00:00.0Z'/></System><EventData><Data Name='Threat Name'>Old:Win32/Fixture</Data></EventData></Event>"
cat > "${T}/hosts/_defaults.conf" <<HOSTS
PLUGINS="core/load"
PROBES="network/ping"
WRA_REPORTS_DIR=${W}
windows_apps_FORBIDDEN="firefox"
HOSTS
HOME="${T}/home" bash "${TOPdir}/utils/wra_hosts.sh" > "${T}/wra.log" 2>&1
expect "wra_hosts.sh dry run lists hosts" "${T}/wra.log" "2 host files would be written"
if [ ! -f "${T}/hosts/good1.conf" ]; then pass "dry run writes nothing"; else fail "dry run wrote a host file"; fi
HOME="${T}/home" bash "${TOPdir}/utils/wra_hosts.sh" --apply > "${T}/wra.log" 2>&1
expect "wra_hosts.sh writes host files" "${T}/hosts/good1.conf" "COLLECTOR=wra"
printf 'HOST=never1\nPLATFORM=windows\nCOLLECTOR=wra\nPROBES=""\nPLUGINS="windows/checkin"\n' > "${T}/hosts/never1.conf"
run -n
G="${R}/systems/good1/good1_report.txt"
O="${R}/systems/old1/old1_report.txt"
expect "fresh report checks in" "${G}" "=== windows/checkin [OK]"
expect "linux plugins skipped on windows" "${G}" "PLATFORM:windows"
if ! grep -q "core/load\|network/ping" "${G}"; then pass "no ping or linux plugins for windows hosts"; else fail "ping or linux plugin ran on good1"; fi
expect "definition updates do not count as patches" "${G}" "=== windows/patches [WARNING]"
expect "routine Defender events ignored" "${G}" "=== windows/defender [OK]"
expect "forbidden program found" "${G}" "forbidden program installed: Mozilla Firefox"
expect "old report is an error" "${O}" "ERROR - old1 has not reported for 20 days"
expect "threat is an error" "${O}" "Defender threat detected ${today}T02:00:00Z Trojan:Win32/Fixture"
expect "protection off alerts past the 7 day window" "${O}" "Defender real-time protection turned off ${old_day}T03:00:00Z"
if ! grep -q "ERROR - .*Old:Win32/Fixture" "${O}"; then pass "threats older than 7 days do not alert"; else fail "old threat alerted"; fi
expect "old threat still listed" "${O}" "${old_day}T04:00:00Z  1116  threat detected  Old:Win32/Fixture"
expect "check in summary first" "${G}" "Agent 3.2 reported 10 minutes ago"
expect "host details from plugins" "${G}" "DETAIL Hardware=4 CPUs, 15.6 GB memory"
expect "program list" "${G}" "  Mozilla Firefox (x64 en-US) 140.0"
expect "hotfix list" "${G}" "  2026-09-09"
expect "uptime under a day in hours" "${G}" "up 1 day"
expect "old patches are an error" "${O}" "=== windows/patches [ERROR]"
expect "resources from the report" "${G}" "=== windows/resources [WARNING]"
expect "full drive warns" "${G}" "WARNING - good1:C: is at 95.0% capacity."
expect "linux disk metric name" "${G}" 'METRIC disk_used_pct{mount="D:"}=10.0'
expect "quoted adapter name" "${G}" "METRIC nic_rx_bytes{nic=\"Wi-Fi 'Office'\"}=123456789"
expect "sample time for rates" "${G}" "METRIC sample_etime="
expect "old report values not checked" "${O}" "resource use not checked"
expect "host with no report" "${R}/systems/never1/never1_report.txt" "never1 has never sent a Windows agent report"

echo "== metrics history"
printf 'HOST=box1\nCOLLECTOR=local\nPROBES=""\nPLUGINS="core/memory core/cpu storage/disk"\ncore_cpu_SAMPLE_SECS=1\n' > "${T}/hosts/box1.conf"
H1="${R}/systems/box1/metrics_history.tsv"
rm -f "${H1}"
run -n -H box1
lines=$(wc -l < "${H1}")
expect "history has the run's metrics" "${H1}" "mem_available_mb="
expect "memory size metric" "${H1}" "mem_total_mb="
expect "cpu tick counters" "${H1}" "cpu_ticks_total="
expect "disk size metric" "${H1}" "disk_size_mb{mount="
sleep 1
run -n -H box1
if [ "$(wc -l < "${H1}")" -gt "${lines}" ]; then pass "each run adds a history line"; else fail "history did not grow"; fi
# Backfill from the archive: drop the history and rebuild it
archived=$(ls "${R}/systems/box1/archive/" | wc -l)
rm -f "${H1}"
HOME="${T}/home" bash "${TOPdir}/utils/drsm_metrics_backfill.sh" --no-offline box1 > "${T}/backfill.log" 2>&1
expect "backfill dry run says what it would add" "${T}/backfill.log" "box1: ${archived} archived reports, 0 lines in history, ${archived} to add"
if [ ! -f "${H1}" ]; then pass "backfill dry run writes nothing"; else fail "backfill dry run wrote ${H1}"; fi
HOME="${T}/home" bash "${TOPdir}/utils/drsm_metrics_backfill.sh" --apply --no-offline box1 > "${T}/backfill.log" 2>&1
if [ "$(wc -l < "${H1}")" -eq "${archived}" ]; then pass "backfill wrote one line per report"; else fail "backfill wrote $(wc -l < "${H1}") lines for ${archived} reports"; fi
HOME="${T}/home" bash "${TOPdir}/utils/drsm_metrics_backfill.sh" --apply --no-offline box1 > "${T}/backfill.log" 2>&1
expect "second backfill adds nothing" "${T}/backfill.log" "${archived} lines in history, 0 to add"
# Old lines age off
old=$(( $(date +%s) - 800 * 86400 ))
{ echo -e "${old}\tcpu_used_pct=1"; cat "${H1}"; } > "${T}/h.tmp" && cat "${T}/h.tmp" > "${H1}"
( source "${TOPdir}/lib/drsm_history.sh"; HISTORYdays=730 drsm_history_trim "${H1}" )
if grep -q "^${old}" "${H1}"; then fail "history older than HISTORYdays kept"; else pass "history older than HISTORYdays dropped"; fi
touch -d "10 days ago" "${H1}"
HOME="${T}/home" bash "${TOPdir}/bin/purge.sh" > /dev/null 2>&1
if [ -f "${H1}" ]; then pass "purge.sh keeps the metrics history"; else fail "purge.sh deleted the metrics history"; fi

echo "== migration"
rm -f "${T}/hosts/"*.conf
cat > "${T}/www/config/systems.dat" <<'DAT'
web1,Web server,Site down,yes:HTTP HTTPS,yes,no,yes,yes
DAT
cat > "${T}/www/config/web1_profile.sh" <<'PROFILE'
    ssh ${SSH_OPTS} ${host} \
	"${REMOTEdir}/disk_checks.sh '/archive /usr1' 85 95" > ${OUTPUTdir}/${host}/disk.txt
    ssh ${SSH_OPTS} ${host} "${REMOTEdir}/user_checks.sh" NONE 'bob alice' > ${OUTPUTdir}/${host}/user.txt
#    ssh ${SSH_OPTS} ${host} "${REMOTEdir}/load_checks.sh" > ${OUTPUTdir}/${host}/load.txt
PROFILE
HOME="${T}/home" bash "${TOPdir}/utils/migrate_systems_dat.sh" > "${T}/migrate.log" 2>&1
W="${T}/hosts/web1.conf"
expect "probes from web protocols" "${W}" 'PROBES="network/ping network/http network/https"'
expect "plugins from the profile" "${W}" 'PLUGINS="storage/disk storage/raid core/users"'
expect "quoted profile argument" "${W}" 'storage_disk_SKIP="/archive /usr1"'
expect "profile threshold" "${W}" 'storage_disk_CRIT="95"'
expect "NONE becomes empty" "${W}" 'core_users_ERROR_USERS=""'
HOME="${T}/home" bash "${TOPdir}/bin/drsm_run.sh" -l > "${T}/list.log" 2>&1
expect "migrated host lists" "${T}/list.log" "web1 (linux, collector ssh)"

echo "== remove host"
mkdir -p "${R}/systems/web1/archive" "${T}/remote/drsm_agent"
echo "x" > "${R}/systems/web1/web1_report.txt"
echo "x" > "${R}/systems/web1/metrics_history.csv"
function remove() { HOME="${T}/home" bash "${TOPdir}/utils/drsm_remove_host.sh" "$@" > "${T}/remove.log" 2>&1; }
remove web1
expect "remove dry run lists the host file" "${T}/remove.log" "remove ${T}/hosts/web1.conf"
expect "remove dry run lists the reports" "${T}/remove.log" "remove ${R}/systems/web1"
if [ -f "${W}" ] && [ -d "${R}/systems/web1" ] && grep -q "^web1," "${T}/www/config/systems.dat"; then pass "remove dry run changes nothing"; else fail "remove dry run changed files"; fi
remove --apply --remote web1
if [ ! -e "${W}" ] && ls "${T}/hosts/removed/web1.conf."* > /dev/null 2>&1; then pass "host file removed and saved"; else fail "host file not removed or not saved"; fi
if [ ! -e "${R}/systems/web1" ]; then pass "reports and metrics history removed"; else fail "web1 reports still there"; fi
if ! grep -q "^web1," "${T}/www/config/systems.dat" && [ ! -e "${T}/www/config/web1_profile.sh" ]; then pass "old systems.dat line and profile removed"; else fail "old setup still has web1"; fi
if [ ! -e "${T}/remote/drsm_agent" ]; then pass "remote plugin bundle removed"; else fail "remote drsm_agent still there"; fi
remove --apply good1
if [ ! -e "${R}/systems/good1" ]; then pass "reports removed for a host with no host file"; else fail "good1 reports still there"; fi
if remove ../web1; then fail "path accepted as a host name"; else pass "path refused as a host name"; fi
if remove nosuchhost; then fail "unknown host accepted"; else pass "unknown host is an error"; fi

echo "== organizations and sites"
rm -f "${T}/hosts/"*.conf
mkdir -p "${T}/sites/acme" "${T}/sites/beta" "${TOPdir}/plugins/local/zz_test_site"
printf 'MODE=remote\nPLATFORMS=any\n' > "${TOPdir}/plugins/local/zz_test_site/plugin.conf"
printf 'echo "INFO - site ${DRSM_ORG}/${DRSM_SITE}"\n' > "${TOPdir}/plugins/local/zz_test_site/check.sh"
printf 'PLUGINS="core/memory"\nPROBES=""\n' > "${T}/hosts/_defaults.conf"
printf 'NAME="Acme Corp"\nCONTACT="ops@acme.test"\n' > "${T}/sites/acme.org"
printf 'NAME="Head office"\nLOCATION="Springfield"\n' > "${T}/sites/acme/hq.site"
printf 'NAME="Branch"\nPLUGINS="core/load"\nSTALE_MINUTES=30\n' > "${T}/sites/acme/branch.site"
printf 'NAME="Lab"\nCOLLECTOR_ID=othermon\n' > "${T}/sites/beta/lab.site"
printf 'HOST=web\nCOLLECTOR=local\nSITE=acme/hq\nPLUGINS="core/memory local/zz_test_site"\n' > "${T}/hosts/web_hq.conf"
printf 'HOST=web\nCOLLECTOR=local\nSITE=acme/branch\n' > "${T}/hosts/web_branch.conf"
printf 'HOST=lab1\nCOLLECTOR=local\nSITE=beta/lab\n' > "${T}/hosts/lab1.conf"
printf 'HOST=legacy1\nCOLLECTOR=local\n' > "${T}/hosts/legacy1.conf"
rm -rf "${R}/systems" "${R}"/system_*.txt
run -n
HQ="${R}/orgs/acme/hq"
BR="${R}/orgs/acme/branch"
expect "default site keeps the flat layout" "${R}/systems/legacy1/legacy1_report.txt" "HOSTNAME:legacy1"
if ! grep -q "^SITE:" "${R}/systems/legacy1/legacy1_report.txt"; then pass "default site report has no SITE line"; else fail "default site report has a SITE line"; fi
expect "site host report" "${HQ}/systems/web/web_report.txt" "SITE:acme/hq"
expect "plugins get the org and site" "${HQ}/systems/web/web_report.txt" "INFO - site acme/hq"
expect "same host name in a second site" "${BR}/systems/web/web_report.txt" "SITE:acme/branch"
expect "site file sets host defaults" "${BR}/systems/web/web_report.txt" "=== core/load ["
if ! grep -q "=== core/memory" "${BR}/systems/web/web_report.txt"; then pass "site default replaces _defaults.conf"; else fail "branch ran the _defaults.conf plugins"; fi
expect "site group report" "${HQ}/system_health_report.txt" "Start of web"
expect "site group report names the site" "${HQ}/system_check_report.txt" "Site: acme/hq Head office"
if ! grep -q "Start of web" "${R}/system_health_report.txt"; then pass "default site report has only its hosts"; else fail "site host in the default site report"; fi
expect "site.json names the site" "${HQ}/site.json" '"org":"acme","site":"hq","name":"Head office","location":"Springfield"'
expect "site.json lists the host" "${HQ}/site.json" '"host":"web","group":"production"'
expect "site.json stale limit" "${BR}/site.json" '"stale_minutes":30'
expect "org.json" "${R}/orgs/acme/org.json" '{"org":"acme","name":"Acme Corp","contact":"ops@acme.test","sites":["branch","hq"]}'
if [ ! -d "${R}/orgs/beta/lab" ]; then pass "another collector's site is skipped"; else fail "beta/lab ran on this collector"; fi
if [ -f "${T}/tmp/logs/drsm_run_acme_hq_all.log" ] && [ -f "${T}/tmp/logs/drsm_run_all.log" ]; then pass "log file per site"; else fail "no per site log files"; fi
if run -n -H web; then fail "ambiguous host name accepted"; else pass "ambiguous host name refused"; fi
expect "ambiguous host lists the sites" "${T}/run.log" "acme/branch/web"
rm -rf "${BR}/systems/web"
run -n -H acme/branch/web
expect "org/site/host runs one host" "${BR}/systems/web/web_report.txt" "HOSTNAME:web"
if run -n -s beta/lab; then fail "ran a site of another collector"; else pass "site of another collector refused"; fi
expect "refusal names the collector" "${T}/run.log" "run by collector othermon"
DRSM_COLLECTOR_ID=othermon run -n -s beta/lab
expect "collector ID runs its site" "${R}/orgs/beta/lab/systems/lab1/lab1_report.txt" "SITE:beta/lab"
HOME="${T}/home" bash "${TOPdir}/bin/drsm_run.sh" -l > "${T}/list.log" 2>&1
expect "list shows the site" "${T}/list.log" "site:    acme/hq"
expect "list shows the owner" "${T}/list.log" "site:    beta/lab, run by another collector"
touch -d "10 days ago" "${HQ}/site.json" "${R}/orgs/acme/org.json"
HOME="${T}/home" bash "${TOPdir}/bin/purge.sh" > /dev/null 2>&1
if [ -f "${HQ}/site.json" ] && [ -f "${R}/orgs/acme/org.json" ]; then pass "purge.sh keeps site.json and org.json"; else fail "purge.sh deleted site.json or org.json"; fi
rm -rf "${TOPdir}/plugins/local/zz_test_site"

echo "== migrate to sites"
function migrate() { HOME="${T}/home" bash "${TOPdir}/utils/drsm_migrate_sites.sh" "$@" > "${T}/migrate.log" 2>&1; }
run -n
migrate -n "New site" -c "$(hostname -s)" acme/new
expect "migrate dry run lists the host" "${T}/migrate.log" "legacy1: set SITE=acme/new"
expect "migrate dry run lists the reports" "${T}/migrate.log" "legacy1: move ${R}/systems/legacy1"
if [ ! -f "${T}/sites/acme/new.site" ] && [ -d "${R}/systems/legacy1" ] && ! grep -q SITE= "${T}/hosts/legacy1.conf"; then pass "migrate dry run changes nothing"; else fail "migrate dry run changed files"; fi
migrate --apply -n "New site" -c "$(hostname -s)" acme/new
expect "migrate writes the site file" "${T}/sites/acme/new.site" 'NAME="New site"'
expect "migrate sets SITE" "${T}/hosts/legacy1.conf" "SITE=acme/new"
if [ -f "${R}/orgs/acme/new/systems/legacy1/legacy1_report.txt" ] && [ ! -e "${R}/systems/legacy1" ]; then pass "migrate moves the reports"; else fail "reports not moved"; fi
if [ -f "${R}/orgs/acme/new/system_health_report.txt" ] && [ ! -e "${R}/system_health_report.txt" ]; then pass "migrate moves the group reports"; else fail "group reports not moved"; fi
if grep -q "web_hq.conf" "${T}/migrate.log"; then fail "migrate touched a host in another site"; else pass "hosts in other sites left alone"; fi
run -n
expect "migrated host runs in its site" "${R}/orgs/acme/new/systems/legacy1/legacy1_report.txt" "SITE:acme/new"
if [ ! -e "${R}/systems/legacy1" ]; then pass "migrated host no longer in the default site"; else fail "migrated host written to the default site"; fi
if migrate --apply default/default; then fail "migrate to default/default accepted"; else pass "migrate to default/default refused"; fi

echo "== sites: web sync, collectors, remove"
D="${T}/dash"
function websync() { HOME="${T}/home" bash "${TOPdir}/utils/drsm_web_sync.sh" -d "${D}" "$@" > "${T}/sync.log" 2>&1; }
websync
rc=$?
if [ ${rc} -eq 0 ]; then pass "web sync dry run to a new dashboard exit 0"; else fail "web sync dry run exit ${rc}: $(grep -m 2 'ERROR\|rsync' "${T}/sync.log")"; fi
if [ ! -e "${D}/orgs" ]; then pass "web sync dry run copies nothing"; else fail "web sync dry run wrote ${D}"; fi
mkdir -p "${D}/orgs/other/x" "${D}/orgs/acme/hq" "${D}/orgs/acme/zz"
echo '{}' > "${D}/orgs/other/x/site.json"
echo '{}' > "${D}/orgs/acme/zz/site.json"
echo old > "${D}/orgs/acme/hq/junk.txt"
echo old > "${D}/system_health_report.txt"
websync --apply
rc=$?
if [ ${rc} -eq 0 ]; then pass "web sync exit 0"; else fail "web sync exit ${rc}: $(tail -3 "${T}/sync.log")"; fi
expect "site copied" "${D}/orgs/acme/hq/systems/web/web_report.txt" "SITE:acme/hq"
expect "new site folder created" "${D}/orgs/acme/new/site.json" '"site":"new"'
expect "org.json copied" "${D}/orgs/acme/org.json" '"name":"Acme Corp"'
if [ ! -e "${D}/orgs/acme/hq/junk.txt" ]; then pass "files gone from the site are deleted"; else fail "old file left in the site copy"; fi
if [ -f "${D}/orgs/other/x/site.json" ] && [ -f "${D}/orgs/acme/zz/site.json" ]; then pass "other monitor hosts' sites are kept"; else fail "web sync deleted another site"; fi
if [ ! -e "${D}/orgs/beta/lab" ]; then pass "another collector's site is not copied"; else fail "beta/lab copied"; fi
expect "skip names the other collector's site" "${T}/sync.log" "Skipping beta/lab"
if [ -f "${D}/system_health_report.txt" ]; then pass "default site files kept with no default site hosts here"; else fail "default site files deleted"; fi
WEBSYNC_RRSYNC=1 websync
expect "rrsync mode needs one site" "${T}/sync.log" "WEBSYNC_RRSYNC=1 copies one site"

ssh-keygen -q -t ed25519 -N "" -C "drsm@mon2" -f "${T}/key" > /dev/null 2>&1
function addcol() { HOME="${T}/home" bash "${TOPdir}/utils/drsm_add_collector.sh" "$@" > "${T}/add.log" 2>&1; }
addcol -u dash@web.example -r /srv/dash/reports -k "${T}/key.pub" -c mon2 acme/hq
expect "rrsync key line" "${T}/add.log" "command=\"/usr/bin/rrsync /srv/dash/reports/orgs/acme/hq\",restrict ssh-ed25519 "
expect "collector settings" "${T}/add.log" "export WEBSYNC_RRSYNC=1"
expect "site file setting" "${T}/add.log" "COLLECTOR_ID=mon2"
if addcol -u dash@web.example -r 'reports",no-pty' acme/hq; then fail "unsafe reports folder accepted"; else pass "unsafe reports folder refused"; fi
printf 'ssh-ed25519 AAAA x",command="sh\n' > "${T}/bad.pub"
addcol -u dash@web.example -r /srv/dash/reports -k "${T}/bad.pub" acme/hq
if grep -q 'command="sh' "${T}/add.log"; then fail "key with options copied into the line"; else pass "key with options refused"; fi

if remove web; then fail "ambiguous host removed"; else pass "ambiguous host name refused"; fi
expect "ambiguous remove lists the sites" "${T}/remove.log" "acme/branch/web"
remove acme/branch/web
expect "site host dry run lists its reports" "${T}/remove.log" "remove ${R}/orgs/acme/branch/systems/web"
expect "site host dry run lists its host file" "${T}/remove.log" "remove ${T}/hosts/web_branch.conf"
remove --apply acme/branch/web
if [ ! -e "${R}/orgs/acme/branch/systems/web" ] && [ ! -e "${T}/hosts/web_branch.conf" ]; then pass "site host removed"; else fail "site host not removed"; fi
if [ -d "${R}/orgs/acme/hq/systems/web" ]; then pass "same name in another site kept"; else fail "removed web from the wrong site"; fi

function rmsite() { HOME="${T}/home" bash "${TOPdir}/utils/drsm_remove_site.sh" "$@" > "${T}/rmsite.log" 2>&1; }
rmsite acme/hq
expect "remove site dry run lists the site file" "${T}/rmsite.log" "remove ${T}/sites/acme/hq.site"
expect "remove site dry run lists the reports" "${T}/rmsite.log" "remove ${R}/orgs/acme/hq"
expect "remove site dry run lists the hosts" "${T}/rmsite.log" "Host web:"
if [ -f "${T}/sites/acme/hq.site" ] && [ -d "${R}/orgs/acme/hq" ] && [ -f "${T}/hosts/web_hq.conf" ]; then pass "remove site dry run changes nothing"; else fail "remove site dry run changed files"; fi
rmsite --apply acme/hq
if [ ! -e "${T}/sites/acme/hq.site" ] && ls "${T}/sites/removed/acme_hq.site."* > /dev/null 2>&1; then pass "site file removed and saved"; else fail "site file not removed or not saved"; fi
if [ ! -e "${R}/orgs/acme/hq" ] && [ ! -e "${T}/hosts/web_hq.conf" ]; then pass "site hosts and reports removed"; else fail "site hosts or reports left"; fi
if [ -f "${R}/orgs/acme/org.json" ]; then pass "org kept while it has other sites"; else fail "org.json removed with sites left"; fi
if rmsite default/default; then fail "default site removal accepted"; else pass "default site removal refused"; fi

NEWH="${R}/orgs/acme/new/systems/legacy1"
narch=$(ls "${NEWH}/archive" | wc -l)
rm -f "${NEWH}/metrics_history.tsv"
HOME="${T}/home" bash "${TOPdir}/utils/drsm_metrics_backfill.sh" --no-offline -s acme/new > "${T}/backfill.log" 2>&1
expect "backfill -s finds the site's hosts" "${T}/backfill.log" "legacy1: ${narch} archived reports, 0 lines in history, ${narch} to add"
HOME="${T}/home" bash "${TOPdir}/utils/drsm_metrics_backfill.sh" --apply --no-offline -s acme/new legacy1 > "${T}/backfill.log" 2>&1
if [ "$(wc -l < "${NEWH}/metrics_history.tsv")" -eq "${narch}" ]; then pass "backfill -s writes the site host's history"; else fail "backfill -s history: $(cat "${T}/backfill.log")"; fi

HOME="${T}/home" bash "${TOPdir}/utils/wra_hosts.sh" --apply -s beta/lab -d "${T}/wra" > "${T}/wra.log" 2>&1
expect "wra_hosts.sh -s names the site" "${T}/hosts/beta_lab_good1.conf" "SITE=beta/lab"
HOME="${T}/home" bash "${TOPdir}/bin/drsm_run.sh" -l > "${T}/list.log" 2>&1
expect "Windows host lists in its site" "${T}/list.log" "site:    beta/lab"

echo "== tiers"
rm -f "${T}/hosts/"*.conf
rm -rf "${R}/orgs/acme/qa"
printf 'PLUGINS="core/memory"\nPROBES=""\nCOLLECTOR=local\n' > "${T}/hosts/_defaults.conf"
printf 'NAME="QA lab"\nGROUP=qa\nALERT_EMAIL="all@acme.test"\nALERT_EMAIL_QA="qa@acme.test"\n' > "${T}/sites/acme/qa.site"
printf 'HOST=qa1\nSITE=acme/qa\n' > "${T}/hosts/qa1.conf"
printf 'HOST=ops1\nSITE=acme/qa\nGROUP=OPS\n' > "${T}/hosts/ops1.conf"
run -n
QA="${R}/orgs/acme/qa"
expect "GROUP=OPS runs with production" "${QA}/systems/ops1/ops1_report.txt" "GROUP:production"
if [ ! -f "${QA}/systems/qa1/qa1_report.txt" ]; then pass "site GROUP=qa default keeps qa1 out of production"; else fail "qa1 ran in the production run"; fi
if ! ls "${QA}"/*ops* > /dev/null 2>&1; then pass "ops writes the production file names"; else fail "ops report files: $(ls "${QA}")"; fi
run -n -g QA
expect "site GROUP default puts qa1 in qa" "${QA}/systems/qa1/qa1_report.txt" "GROUP:qa"
expect "qa group report name" "${QA}/system_health_report_qa.txt" "Start of qa1"
expect "qa in site.json" "${QA}/site.json" '"host":"qa1","group":"qa"'
run -n -g ops
expect "-g ops is the production run" "${QA}/system_health_report.txt" "Start of ops1"
echo "== site links"
cat >> "${T}/sites/acme/qa.site" <<'LINKS'
LINK="Wiki|https://wiki.acme.test/qa"
LINK="Apps / OSA / Admin|https://osa.acme.test/admin|QA"
LINK="Bad|javascript:alert(1)"
LINK="Apps//Empty|https://x.acme.test/"
LINKS
printf 'LINK="Help desk|https://help.acme.test/"\n' >> "${T}/sites/acme.org"
run -n -g qa
expect "site links in site.json" "${QA}/site.json" '"links":[{"path":"Wiki","url":"https://wiki.acme.test/qa","tier":""},{"path":"Apps/OSA/Admin","url":"https://osa.acme.test/admin","tier":"qa"}]'
expect "org links in site.json" "${QA}/site.json" '"org_links":[{"path":"Help desk","url":"https://help.acme.test/","tier":""}]'
expect "non http link reported" "${T}/run.log" "LINK Bad is not an http or https URL, skipped"
expect "empty menu level reported" "${T}/run.log" "Menu/Name with no empty level, skipped"
if ! grep -q "javascript" "${QA}/site.json"; then pass "javascript link left out"; else fail "javascript link in site.json"; fi

out=$(cd "${TOPdir}" && bash -c 'source lib/drsm_conf.sh; source lib/drsm_sites.sh
  declare -A S=([ALERT_EMAIL]="all@x" [ALERT_EMAIL_DEV]="dev@x" [ALERT_EMAIL_OPS]="ops@x")
  echo "$(drsm_group_tier Production) $(drsm_group_tier ops) $(drsm_group_tier qa) $(drsm_group_canon OPS)"
  echo "$(drsm_site_alert_email S dev) $(drsm_site_alert_email S production) $(drsm_site_alert_email S qa)"
  drsm_is_site_key ALERT_EMAIL_QA && echo sitekey' 2>&1)
if [ "${out}" == $'OPS OPS QA production\ndev@x ops@x all@x\nsitekey' ]; then pass "tier names and ALERT_EMAIL_<TIER> fallback"; else fail "tier helpers: ${out}"; fi

echo ""
if [ ${failures} -eq 0 ]; then echo "All tests passed"; exit 0; fi
echo "${failures} test(s) failed"
exit 1
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
