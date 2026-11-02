#!/bin/bash
# ----------------------------------------------------------- 
# BASH Script
# Operating System(s): RHEL/CENTOS
# Run Level(s): 3, 5
# Shell: BASH shell
# Original Author(s): DataReel Software Development
# File Creation Date: 11/01/2026
# Date Last Modified: 11/01/2026
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
# Tests for the windows/vulnerabilities plugin (DataReel Reporting
# Agent for Windows 3.5 Windows Update scans) and the Windows hosts on
# the Vulnerabilities page. Runs drsm_run.sh on wra hosts made from the
# fixture report tests/fixtures/win1_windows_report_agent.txt. Needs no
# root, Web server or network.
#
# Usage: [KEEP=1] tests/wra_vuln_test.sh   (KEEP=1 keeps the temp tree)
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
RPT="${T}/wra_reports"
mkdir -p "${W}/config" "${T}/home" "${T}/hosts" "${RPT}"
cp -r "${D}/www/php" "${D}/www/css" "${D}/www/js" "${D}/www/images" "${W}/"
now=$(date +%s)
F="${TOPdir}/tests/fixtures/win1_windows_report_agent.txt"
# win1: the fixture, critical + important + an unrated security update
sed "s/^ETIME: .*/ETIME: ${now}/; s/^scan_etime=.*/scan_etime=${now}/" "${F}" > "${RPT}/win1_windows_report_agent.txt"
# win2: only the unrated .NET update, the way Windows Update reports it
awk -v now="${now}" '
    /^ETIME: / { print "ETIME: " now; next }
    /^scan_etime=/ { print "scan_etime=" now; next }
    /^critical=/ { print "critical=0 important=0 moderate=0 low=0 unknown=1 total=1 cves=0 other=0"; next }
    /^advisory id=KB50/ || /^other / { next }
    { gsub(/win1/, "win2"); print }' "${F}" > "${RPT}/win2_windows_report_agent.txt"
# win3: agent 3.5 with no scan yet; win4: the scan failed; win5: agent 3.4
awk -v now="${now}" '
    /^ETIME: / { print "ETIME: " now; next }
    /^VULNERABILITIES:/ { print; print "mode=manual"; print "status=disabled"; skip = 1; next }
    /^END VULNERABILITIES/ { skip = 0 }
    skip { next }
    { gsub(/win1/, "win3"); print }' "${F}" > "${RPT}/win3_windows_report_agent.txt"
awk -v now="${now}" '
    /^ETIME: / { print "ETIME: " now; next }
    /^status=ok/ { print "status=failed"; print "ERROR - Windows Update search failed: 0x8024402C"; skip = 1; next }
    /^END VULNERABILITIES/ { skip = 0 }
    skip { next }
    { gsub(/win1/, "win4"); print }' "${F}" > "${RPT}/win4_windows_report_agent.txt"
awk -v now="${now}" '
    /^ETIME: / { print "ETIME: " now; next }
    /^VULNERABILITIES:/ { skip = 1; next }
    /^END VULNERABILITIES/ { skip = 0; next }
    skip { next }
    { gsub(/win1/, "win5"); print }' "${F}" > "${RPT}/win5_windows_report_agent.txt"

cat > "${T}/home/.drsm.sh" <<CONF
export SITEID="WRATEST"
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
for h in win1 win2 win3 win4 win5; do
    printf 'HOST=%s\nPLATFORM=windows\nCOLLECTOR=wra\nWRA_REPORTS_DIR=%s\nPROBES=""\nPLUGINS="windows/vulnerabilities"\n' "${h}" "${RPT}" > "${T}/hosts/${h}.conf"
done
printf 'windows_vulnerabilities_UNRATED_SEVERITY=none\n' >> "${T}/hosts/win2.conf"

HOME="${T}/home" bash "${D}/bin/drsm_run.sh" -n > "${T}/run.log" 2>&1
R="${W}/reports/systems"
expect "win1 critical update is an error" "${R}/win1/win1_report.txt" "=== windows/vulnerabilities [ERROR]"
expect "win1 summary line" "${R}/win1/win1_report.txt" "VULN summary|wua|"
expect "win1 counts" "${R}/win1/win1_report.txt" "|1|1|0|0|1|3|3|ok|"
expect "win1 advisory line" "${R}/win1/win1_report.txt" "VULN advisory|KB5066835|Critical|2026-10-14|CVE-2026-1001,CVE-2026-1002|Windows 11|2026-10 Cumulative Update"
expect "win1 title pipes replaced" "${R}/win1/win1_report.txt" "Security Update for Microsoft Edge / test (KB5066131)"
expect "win1 other update line" "${R}/win1/win1_report.txt" "VULN other|KB5127936|Updates|2026-10-28|"
expect "win1 unrated update warns" "${R}/win1/win1_report.txt" "needs security updates: 1 important, 1 not rated updates"
expect "win1 manual scan is noted" "${R}/win1/win1_report.txt" "Scanned by hand (drra_svc.exe scan)"
expect "win2 unrated update can be turned off" "${R}/win2/win2_report.txt" "=== windows/vulnerabilities [OK]"
expect "win3 scan off is OK" "${R}/win3/win3_report.txt" "=== windows/vulnerabilities [OK]"
expect "win3 scan off message" "${R}/win3/win3_report.txt" "run drra_svc.exe scan from an administrator command prompt"
expect "win4 failed scan warns" "${R}/win4/win4_report.txt" "vulnerability scan failed: Windows Update search failed: 0x8024402C"
expect "win5 old agent is unknown" "${R}/win5/win5_report.txt" "the agent needs version 3.5 or later"

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
expect_page "fleet page lists win1" ">win1</strong>"
expect_page "built in menu item for Windows hosts" 'href="/drsm/dashboard/php/vulnerabilities.php"'
expect_page "fleet page links the KB article" "https://support.microsoft.com/help/5066835"
expect_page "fleet page says there is no scan yet" "No vulnerability scan yet on 1 host: win3"
expect_page "fleet page has the Windows command" "drra_svc.exe scan"
reject_page "no Linux command for Windows hosts" "sudo drra scan"
expect_page "Windows Update source" "Windows Update"
render vulnerabilities.php "n=win1"
expect_page "host page links CVEs to MSRC" "https://msrc.microsoft.com/update-guide/vulnerability/CVE-2026-1001"
expect_page "host page products column" "Products"
expect_page "host page lists other updates" "KB5127936"
expect_page "host page Windows install hint" "Install the updates with Windows Update"
reject_page "host page has no dnf hint" "dnf update"
expect_page "host report link" "#p-windows-vulnerabilities"
render vulnerabilities.php "n=win3"
expect_page "host page says there is no scan yet" "No vulnerability scan yet on this host. Run <code>drra_svc.exe scan</code>"

if [ ${failures} -eq 0 ]; then echo "All tests passed"; else echo "${failures} tests failed"; fi
[ ${failures} -eq 0 ]
