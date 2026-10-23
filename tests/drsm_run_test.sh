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

echo ""
if [ ${failures} -eq 0 ]; then echo "All tests passed"; exit 0; fi
echo "${failures} test(s) failed"
exit 1
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
