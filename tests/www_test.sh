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
# Tests for the Web pages. Posts reports with bin/drsm_run.sh and the
# local collector, then renders every page with the PHP command line
# and checks the output. Any PHP warning or notice fails the test.
#
# Usage: tests/www_test.sh
#
# ----------------------------------------------------------- 
TOPdir=$(cd "$(dirname "$0")/.." && pwd)
T=$(mktemp -d)
trap 'rm -rf "${T}"' EXIT
failures=0

function pass() { echo "PASS - $*"; }
function fail() { echo "FAIL - $*"; failures=$((failures + 1)); }

if ! command -v php > /dev/null 2>&1; then echo "SKIP - php is not installed"; exit 0; fi

W="${T}/www"
mkdir -p "${T}/home" "${W}/config" "${T}/hosts"
cp -r "${TOPdir}/www/php" "${TOPdir}/www/css" "${TOPdir}/www/js" "${TOPdir}/www/images" "${W}/"
cat > "${T}/home/.drsm.sh" <<CONF
export SITEID="DRSMTEST"
export WWWdir=${W}
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
printf 'PLUGINS="core/load core/memory storage/disk"\nPROBES=""\nCOLLECTOR=local\n' > "${T}/hosts/_defaults.conf"
printf 'DESCRIPTION="Web <one> & co"\n' > "${T}/hosts/web1.conf"
printf 'DESCRIPTION="Database"\ncore_load_CRIT=-1\n' > "${T}/hosts/db1.conf"
printf 'DESCRIPTION="Dev box"\nGROUP=dev\n' > "${T}/hosts/dev1.conf"
HOME="${T}/home" bash "${TOPdir}/bin/drsm_run.sh" -n > "${T}/run.log" 2>&1
HOME="${T}/home" bash "${TOPdir}/bin/drsm_run.sh" -n -g dev >> "${T}/run.log" 2>&1
# A host from the older system_report.sh, no plugin sections
mkdir -p "${W}/reports/systems/old1"
printf 'ETIME:%s\nDESCRIPTION:Old style: report\nWARNING - old1 disk is at 90%%\n' "$(date +%s)" > "${W}/reports/systems/old1/old1_report.txt"

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
function expect() {
    # $1 == description, $2 == fixed string that must be in the page
    if grep -qF -- "${2}" "${T}/page.html"; then pass "${1}"; else fail "${1}: '${2}' not in page"; fi
}
function reject() {
    if grep -qF -- "${2}" "${T}/page.html"; then fail "${1}: '${2}' in page"; else pass "${1}"; fi
}

render index.php ""
expect "overview headline" "need attention"
expect "error host listed" ">db1</strong>"
expect "links use the sub path" 'href="/drsm/dashboard/php/readreport.php?n=db1"'
expect "styles linked" '/drsm/dashboard/css/drsm.css'
expect "description escaped" "Web &lt;one&gt; &amp; co"
reject "no raw description" "Web <one>"
expect "legacy host card" 'data-state="WARNING" data-group="production" data-text="old1'
expect "dev group in filter" '<option value="dev">'

render heatmap.php ""
expect "plugin column" 'title="core/load"'
expect "error cell links to the plugin" 'readreport.php?n=db1#p-core-load'
render heatmap.php "mode=metrics"
expect "memory metric" 'Memory used'

render reports.php ""
expect "host table" 'id="host-table"'

render readreport.php "n=db1"
expect "plugin section" 'id="p-core-load"'
expect "error line styled" 'class="l-err"'
render readreport.php "n=old1"
expect "legacy report shown" 'old1 disk is at 90%'
render readreport.php "n=../../etc"
expect "path traversal refused" "Host not found"

render checks.php ""
expect "connectivity report" "Connectivity tests"
render checks.php "r=health&g=dev"
expect "dev health report" "Start of dev1"
render checks.php "g=../x"
expect "bad group falls back" "Production group"

echo ""
if [ ${failures} -eq 0 ]; then echo "All tests passed"; exit 0; fi
echo "${failures} test(s) failed"
exit 1
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
