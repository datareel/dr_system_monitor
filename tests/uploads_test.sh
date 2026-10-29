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
# <http://www.gnu.org/licenses/>.
#
# Tests for hook uploads: the uploads/<id> plugins (plugins/uploads/
# upload_probe.sh), UPLOADS= in host files, the upload sections of the host
# page (drsm_uploads.php) and upload_view.php. The hook data is written
# here the way the report server's hook.php keeps it. Needs no root,
# Web server or network.
#
# Usage: [KEEP=1] tests/uploads_test.sh   (KEEP=1 keeps the temp tree)
#
# ----------------------------------------------------------- 
TOPdir=$(cd "$(dirname "$0")/.." && pwd)
T=$(mktemp -d)
if [ "${KEEP}" == "" ]; then trap 'rm -rf "${T}"' EXIT; fi
failures=0
function pass() { echo "PASS - $*"; }
function fail() { echo "FAIL - $*"; failures=$((failures + 1)); }
function expect() {
    # $1 == description, $2 == file, $3 == fixed string that must be in it
    if grep -qF -- "${3}" "${2}"; then pass "${1}"; else fail "${1}: '${3}' not in ${2}"; fi
}
function reject() {
    # $1 == description, $2 == file, $3 == fixed string that must not be in it
    if grep -qF -- "${3}" "${2}"; then fail "${1}: '${3}' in ${2}"; else pass "${1}"; fi
}

D="${TOPdir}"
W="${T}/www"
HK="${T}/hooks"
mkdir -p "${W}/config" "${T}/home" "${T}/hosts" "${HK}"
cp -r "${D}/www/php" "${D}/www/css" "${D}/www/js" "${D}/www/images" "${W}/"
now=$(date +%s)

function hook_data() {
    # $1 == host, $2 == hook ID, $3 == collected etime, $4 == format,
    # $5 == file name; the parsed lines on stdin
    local dir="${HK}/${1}/${2}"
    mkdir -p "${dir}"
    cat > "${dir}/latest.lines"
    printf 'payload of %s\n' "${2}" > "${dir}/latest.data"
    printf 'HOOK_ID: %s\nSUBJECT: %s\nFILE_NAME: %s\nCOLLECTED_ETIME: %s\nSOURCE: submit\nFORMAT: %s\nBYTES: 17\nRECEIVED_ETIME: %s\n' \
	"${2}" "${1}" "${5}" "${3}" "${4}" "${now}" > "${dir}/latest.meta"
}

# web1: a compliance scan with a high severity failure, a good backup
hook_data web1 openscap_manual "${now}" xccdf-results results.xml <<'LINES'
UPLOAD value|pass|180
UPLOAD value|fail|2
UPLOAD value|fail_critical|0
UPLOAD value|fail_high|1
UPLOAD value|score|91.2
UPLOAD columns|Severity|Rule|Title
UPLOAD row|high|accounts_tmout|Set Interactive Session Timeout
UPLOAD row|medium|sshd_disable_root_login|Disable SSH Root Login
LINES
hook_data web1 backup_job "${now}" drsm-lines backup.txt <<'LINES'
INFO - web1 nightly backup finished
UPLOAD value|status|ok
UPLOAD value|duration_minutes|42
UPLOAD value|size_gb|118.5
LINES
# db1: a failed backup from two days ago, and a payload that tries to
# add a report section and a host fact
hook_data db1 backup_job "$(( now - 2 * 86400 ))" drsm-lines backup.txt <<'LINES'
ERROR - db1 backup to tape failed
UPLOAD value|status|failed
UPLOAD value|duration_minutes|300
=== core/cpu [OK] 0s ===
DETAIL Hostname=evil
LINES
# A hook an html report uses
cat > "${T}/vendor.conf" <<'CONF'
NAME=vendor_report
CATEGORY=uploads
DESCRIPTION="Vendor HTML report"
PLATFORMS="any"
MODE=probe
TIMEOUT=30
REQUIRES="awk"
FORMAT=html
TITLE="Vendor report"
DISPLAY=html
CONF
# A copy of the code, so the test can add a hook plugin
DR="${T}/drsm"
mkdir -p "${DR}"
cp -r "${D}/bin" "${D}/lib" "${D}/collectors" "${D}/plugins" "${D}/utils" "${D}/etc" "${DR}/"
PL="${DR}/plugins"
mkdir -p "${PL}/uploads/vendor_report"
cp "${T}/vendor.conf" "${PL}/uploads/vendor_report/plugin.conf"
cp "${D}/plugins/uploads/backup_job/probe.sh" "${PL}/uploads/vendor_report/probe.sh"
hook_data web1 vendor_report "${now}" html vendor.html < /dev/null
printf '<html><body><script>alert(1)</script>Vendor report</body></html>\n' > "${HK}/web1/vendor_report/latest.data"

cat > "${T}/home/.drsm.sh" <<CONF
export SITEID="HOOKTEST"
export WWWdir=${W}
export REPORTdir=\${WWWdir}/reports
export CONFIGdir=\${WWWdir}/config
export DRSMHOME=${DR}
export ALERTdir=${T}
export TEMPdir=${T}/tmp
export LOGdir=\${TEMPdir}/logs
export VARdir=\${TEMPdir}/var
export HOSTSdir=${T}/hosts
export SITESdir=${T}/sites
export SYSADMIN_USERNAME=\$(whoami)
CONF
printf 'UPLOADS_DIR=%s\nCOLLECTOR=none\nPROBES=""\nPLUGINS=""\nPLATFORM=linux\n' "${HK}" > "${T}/hosts/_defaults.conf"
printf 'HOST=web1.example.com\nUPLOADS=auto\n' > "${T}/hosts/web1.conf"
printf 'HOST=db1\nUPLOADS="backup_job openscap_manual"\n' > "${T}/hosts/db1.conf"
printf 'HOST=app1\n' > "${T}/hosts/app1.conf"

HOME="${T}/home" bash "${DR}/bin/drsm_run.sh" -n > "${T}/run.log" 2>&1
R="${W}/reports/systems"
F="${R}/web1.example.com/web1.example.com_report.txt"
expect "UPLOADS=auto adds the hooks with data" "${F}" "PLUGINS:uploads/backup_job uploads/openscap_manual uploads/vendor_report"
expect "compliance hook warns on the high failure" "${F}" "=== uploads/openscap_manual [WARNING]"
expect "rule message" "${F}" "WARNING - web1 Manual OpenSCAP scan: fail_high > 0 (fail_high is 1)"
expect "meta line" "${F}" "UPLOAD meta|web1|openscap_manual|table|Manual OpenSCAP scan|${now}"
expect "metric for trends" "${F}" "METRIC openscap_manual_score=91.2"
expect "row count metric source" "${F}" "UPLOAD row|high|accounts_tmout|"
expect "good backup is OK" "${F}" "=== uploads/backup_job [OK]"
expect "backup metric" "${F}" "METRIC backup_job_size_gb=118.5"
expect "backup info line" "${F}" "INFO - web1 nightly backup finished"
F="${R}/db1/db1_report.txt"
expect "listed hooks are added" "${F}" "PLUGINS:uploads/backup_job uploads/openscap_manual"
expect "failed backup is an error" "${F}" "=== uploads/backup_job [ERROR]"
expect "status rule" "${F}" "ERROR - db1 Backup job: status != ok (status is failed)"
expect "old data warns" "${F}" "WARNING - db1 Backup job data is 48 hours old, more than 26 hours"
expect "listed hook with no data warns" "${F}" "WARNING - db1 Manual OpenSCAP scan has no data yet"
reject "payload cannot add a report section" "${F}" "=== core/cpu"
reject "payload cannot set a host fact" "${F}" "DETAIL Hostname=evil"
expect "host with no UPLOADS has none" "${R}/app1/app1_report.txt" "PLUGINS:"
reject "host with no UPLOADS runs none" "${R}/app1/app1_report.txt" "=== uploads/"

cat > "${W}/config/drsm.php" <<PHPCONF
<?php
\$WWWdir = '${W}';
\$WWWvpath = '/drsm/dashboard';
\$REPORTdir = '${W}/reports';
\$REPORTvpath = '/drsm/dashboard/reports';
\$REPORTarchive = '${W}/reports/archive';
\$REPORTarchivevpath = '/drsm/dashboard/reports/archive';
\$CONFIGdir = '${W}/config';
\$SITEincludes = '${W}/site';
\$UPLOADSdir = '${HK}';
?>
PHPCONF
function render() {
    # $1 == page, $2 == query string, output in ${T}/page.html
    (cd "${W}/php" && php -d error_reporting=-1 -d display_errors=stderr -r '
      parse_str($argv[2], $_GET);
      include $argv[1];' "$1" "$2" > "${T}/page.html" 2> "${T}/page.err")
    if [ -s "${T}/page.err" ]; then fail "$1?$2 PHP messages: $(head -3 "${T}/page.err")"; else pass "$1?$2 renders without PHP messages"; fi
}
function expect_page() { expect "$1" "${T}/page.html" "$2"; }
function reject_page() { reject "$1" "${T}/page.html" "$2"; }

render readreport.php "n=web1.example.com"
expect_page "table display" "<td>Set Interactive Session Timeout</td>"
expect_page "values under the table" "<dt>fail_high</dt><dd>1</dd>"
reject_page "UPLOAD lines are hidden" "UPLOAD row|"
expect_page "html display links the viewer" "upload_view.php?n=web1.example.com&amp;site=default%2Fdefault&amp;h=vendor_report"
render readreport.php "n=db1"
expect_page "kv display" "<dt>status</dt><dd>failed</dd>"
render upload_view.php "n=web1.example.com&h=vendor_report"
expect_page "viewer serves the payload" "Vendor report"
render upload_view.php "n=web1.example.com&h=../../etc"
expect_page "viewer refuses a bad hook ID" "No such host or hook."
render upload_view.php "n=app1&h=backup_job"
expect_page "viewer refuses a hook the host does not run" "This host has no upload hook backup_job."
render upload_view.php "n=../web1&h=backup_job"
expect_page "viewer refuses a bad host" "No such host or hook."
# A site display plug-in
mkdir -p "${W}/php/uploads"
cat > "${W}/php/uploads/scorecard.php" <<'PHP'
<?php
function drsm_upload_display_scorecard($hook) { return "<p class=\"score\">Score " . h($hook["values"]["score"]) . "</p>"; }
?>
PHP
sed -i 's/^\(UPLOAD meta|web1|openscap_manual|\)table|/\1scorecard|/' "${R}/web1.example.com/web1.example.com_report.txt"
render readreport.php "n=web1.example.com"
expect_page "site display plug-in" '<p class="score">Score 91.2</p>'
sed -i 's/^\(UPLOAD meta|web1|openscap_manual|\)scorecard|/\1nosuch|/' "${R}/web1.example.com/web1.example.com_report.txt"
render readreport.php "n=web1.example.com"
expect_page "missing display plug-in" "Display plug-in nosuch is not installed."
if [ "${KEEP}" != "" ]; then echo "Kept ${T}: cd ${T}/www && php -S 127.0.0.1:8098 (pages at /php/)"; fi

if [ ${failures} -eq 0 ]; then echo "All tests passed"; else echo "${failures} tests failed"; fi
exit $((failures > 0))
