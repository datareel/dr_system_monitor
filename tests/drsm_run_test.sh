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
if ! grep -q "Old:Win32/Fixture" "${O}"; then pass "threats older than 7 days do not alert"; else fail "old threat alerted"; fi
expect "old patches are an error" "${O}" "=== windows/patches [ERROR]"
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

echo ""
if [ ${failures} -eq 0 ]; then echo "All tests passed"; exit 0; fi
echo "${failures} test(s) failed"
exit 1
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
