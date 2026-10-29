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
# Tests for Linux hosts that run the DataReel Reporting Agent for
# Linux: the lra collector, the linux/* plugins, utils/lra_hosts.sh,
# the Vulnerabilities page and the OpenSCAP report viewer. Runs
# drsm_run.sh on agent hosts made from the fixture report
# tests/fixtures/web1_linux_report_agent.txt. Needs no root, Web
# server or network.
#
# Usage: [KEEP=1] tests/lra_test.sh   (KEEP=1 keeps the temp tree)
#
# ----------------------------------------------------------- 
TOPdir=$(cd "$(dirname "$0")/.." && pwd)
T=$(mktemp -d)
# KEEP=1 keeps the temp tree, to look at the pages with php -S
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
RPT="${T}/lra_reports"
mkdir -p "${W}/config" "${T}/home" "${T}/hosts" "${RPT}"
cp -r "${D}/www/php" "${D}/www/css" "${D}/www/js" "${D}/www/images" "${W}/"
# web1: the fixture (dnf scan), db1: an OVAL scan with a compliance scan
now=$(date +%s)
sed "s/^ETIME: .*/ETIME: ${now}/" "${TOPdir}/tests/fixtures/web1_linux_report_agent.txt" > "${RPT}/web1_linux_report_agent.txt"
awk -v now="${now}" '
    /^ETIME: / { print "ETIME: " now; next }
    /^source=/ { print "source=oval"; next }
    /^feed=/ { print "feed=https://security.access.redhat.com/data/oval/v2/RHEL9/rhel-9.oval.xml.bz2"; next }
    /^critical=/ { print "critical=0 important=1 moderate=0 low=0 unknown=0 total=1 cves=1"; next }
    /^advisory / { if (!done) print "advisory id=RHSA-2026:77396 severity=Important issued=2026-10-08 cves=CVE-2026-84782 packages=openssl-libs<1:3.5.8-2.el9_8 title=\"RHSA-2026:77396: openssl security update (Important)\""; done = 1; next }
    /^END VULNERABILITIES/ { print; print ""; print "COMPLIANCE:"; print "profile=cis_server_l1"; print "scan_etime=" now; print "score=81.5"; print "pass=200 fail=2 notapplicable=10 notchecked=0 error=0"; print "fail rule=sshd_disable_root_login severity=medium"; print "fail rule=accounts_tmout severity=high"; print "END COMPLIANCE"; next }
    { gsub(/web1/, "db1"); print }' "${TOPdir}/tests/fixtures/web1_linux_report_agent.txt" > "${RPT}/db1_linux_report_agent.txt"
echo '<html><body><script>document.title="scan"</script>OpenSCAP report</body></html>' > "${RPT}/db1_linux_scap_report.html"
# app1: a CSAF/VEX scan with CVEs that have no fix yet
awk -v now="${now}" '
    /^ETIME: / { print "ETIME: " now; next }
    /^source=/ { print "source=csaf"; next }
    /^feed=/ { print "feed=https://reports.example.com/linux/upload/vex_index.php?rhel=10"; next }
    /^critical=/ { print "critical=0 important=0 moderate=1 low=0 unknown=0 total=1 cves=1 unfixed=2"; next }
    /^advisory / { if (!done) { print "advisory id=RHSA-2026:90328 severity=Moderate cves=CVE-2026-1111 packages=bind-libs<32:9.18.33-15.el10_2.13 title=\"Moderate: bind-libs security update\""; print "unfixed cve=CVE-2026-2222 severity=Critical packages=edk2-ovmf state=\"Affected\""; print "unfixed cve=CVE-2026-3333 severity=Low packages=firefox state=\"Will not fix\"" } done = 1; next }
    { gsub(/web1/, "app1"); print }' "${TOPdir}/tests/fixtures/web1_linux_report_agent.txt" > "${RPT}/app1_linux_report_agent.txt"

cat > "${T}/home/.drsm.sh" <<CONF
export SITEID="LRATEST"
export WWWdir=${W}
export REPORTdir=\${WWWdir}/reports
export CONFIGdir=\${WWWdir}/config
export DRSMHOME=${D}
export ALERTdir=${T}
export TEMPdir=${T}/tmp
export LOGdir=\${TEMPdir}/logs
export VARdir=\${TEMPdir}/var
export HOSTSdir=${T}/hosts
export SITESdir=${T}/sites
export SYSADMIN_USERNAME=\$(whoami)
CONF
printf 'LRA_REPORTS_DIR=%s\n' "${RPT}" > "${T}/hosts/_defaults.conf"
HOME="${T}/home" HOSTSdir="${T}/hosts" BASEdir="${D}" bash "${D}/utils/lra_hosts.sh" -o "${T}/hosts" -d "${RPT}" --apply > "${T}/hosts.log" 2>&1
expect "lra_hosts.sh made a host file" "${T}/hosts/web1.conf" "COLLECTOR=lra"
printf 'linux_security_FAILED_UNITS_SKIP="kdump.service"\n' >> "${T}/hosts/db1.conf"

HOME="${T}/home" bash "${D}/bin/drsm_run.sh" -n > "${T}/run.log" 2>&1
R="${W}/reports/systems"
expect "web1 checkin ran" "${R}/web1/web1_report.txt" "=== linux/checkin [OK]"
expect "web1 resources ran" "${R}/web1/web1_report.txt" "=== linux/resources [OK]"
expect "web1 resources metric" "${R}/web1/web1_report.txt" 'METRIC disk_used_pct{mount="/"}=45.8'
expect "web1 updates ran" "${R}/web1/web1_report.txt" "=== linux/updates [OK]"
expect "web1 failed unit warns" "${R}/web1/web1_report.txt" "=== linux/security [WARNING]"
expect "web1 critical advisory is an error" "${R}/web1/web1_report.txt" "=== linux/vulnerabilities [ERROR]"
expect "web1 summary line" "${R}/web1/web1_report.txt" "VULN summary|dnf|"
expect "db1 important advisory warns" "${R}/db1/db1_report.txt" "=== linux/vulnerabilities [WARNING]"
expect "db1 compliance line" "${R}/db1/db1_report.txt" "VULN compliance|cis_server_l1|81.5|200|2|"
expect "db1 skipped failed unit" "${R}/db1/db1_report.txt" "=== linux/security [OK]"
expect "app1 unfixed critical warns" "${R}/app1/app1_report.txt" "has 1 Critical or worse CVEs with no fix yet"
expect "app1 unfixed line" "${R}/app1/app1_report.txt" "VULN unfixed|CVE-2026-3333|Low|firefox|Will not fix"
expect "app1 summary has the unfixed count" "${R}/app1/app1_report.txt" "|ok|2"
expect "app1 resources metric for trends" "${R}/app1/app1_report.txt" "METRIC cpu_used_pct="

# A host with no report yet is an error from linux/checkin only
printf 'HOST=new1\nPLATFORM=linux\nCOLLECTOR=lra\nPROBES=""\nPLUGINS="linux/checkin linux/vulnerabilities"\n' > "${T}/hosts/new1.conf"
HOME="${T}/home" bash "${D}/bin/drsm_run.sh" -n -H new1 > "${T}/run_new1.log" 2>&1
expect "missing report is an error" "${R}/new1/new1_report.txt" "=== linux/checkin [ERROR]"
expect "other plugins wait for a report" "${R}/new1/new1_report.txt" "=== linux/vulnerabilities [UNKNOWN]"
rm -f "${T}/hosts/new1.conf"
rm -rf "${R}/new1"
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
\$LRAreportsDir = '${RPT}';
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

render vulnerabilities.php ""
expect_page "fleet page lists web1" ">web1</strong>"
expect_page "fleet page lists the critical advisory" "https://access.redhat.com/errata/RHSA-2026:88455"
expect_page "built in menu item" 'href="/drsm/dashboard/php/vulnerabilities.php"'
render vulnerabilities.php "sev=Important"
expect_page "severity filter" "RHSA-2026:77396"
render vulnerabilities.php "n=db1"
expect_page "host page compliance" "accounts_tmout"
expect_page "host page links the HTML report" "scap_report.php?n=db1&amp;site=default%2Fdefault&amp;kind=scap"
render vulnerabilities.php "n=app1"
expect_page "host page lists unfixed CVEs" "CVE-2026-2222"
expect_page "host page names the CSAF source" "CSAF/VEX"
render vulnerabilities.php "n=web1"
expect_page "host page packages" "ca-certificates-"
render scap_report.php "n=db1&site=default/default&kind=scap"
expect_page "report viewer serves the HTML" "OpenSCAP report"
render scap_report.php "n=db1&kind=scap"
expect_page "report viewer without a site" "OpenSCAP report"
render scap_report.php "n=../db1&kind=scap"
expect_page "report viewer refuses a bad name" "No OpenSCAP report"
render scap_report.php "n=db1&kind=../../etc/passwd"
expect_page "report viewer refuses a bad kind" "No OpenSCAP report"
# A report file for a host DRSM does not report on is not served
cp "${RPT}/db1_linux_scap_report.html" "${RPT}/other1_linux_scap_report.html"
render scap_report.php "n=other1&kind=scap"
expect_page "report viewer refuses a host DRSM does not know" "No OpenSCAP report"
render readreport.php "n=web1"
expect_page "host page shows the scan summary" "54 security advisories apply"
reject_page "host page hides the VULN lines" "VULN advisory|"
render index.php ""
expect_page "menu item on other pages" 'href="/drsm/dashboard/php/vulnerabilities.php"'
# An older site config with its own $NAVextra entry gets one menu item
sed -i 's#^?>$#$NAVextra = array(array("label" => "Vulnerabilities", "url" => "/drsm/dashboard/php/vulnerabilities.php", "icon" => "lock"));\n?>#' "${W}/config/drsm.php"
render index.php ""
if [ "$(grep -c 'href="/drsm/dashboard/php/vulnerabilities.php"' "${T}/page.html")" == "1" ]; then pass "no second menu item from \$NAVextra"; else fail "Vulnerabilities menu item listed more than once"; fi
# No Linux agent hosts, no menu item
rm -rf "${R}/web1" "${R}/db1" "${R}/app1"
sed -i '/^\$NAVextra/d' "${W}/config/drsm.php"
render index.php ""
reject_page "no menu item without agent hosts" "vulnerabilities.php"
render vulnerabilities.php ""
if [ "${KEEP}" != "" ]; then echo "Kept ${T}: cd ${T}/www && php -S 127.0.0.1:8098 (pages at /php/)"; fi

if [ ${failures} -eq 0 ]; then echo "All tests passed"; else echo "${failures} tests failed"; fi
exit $((failures > 0))
