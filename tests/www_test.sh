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

render host_status.php "n=db1"
expect "host status JSON" '"host":"db1"'
expect "host status age" '"age_secs":'
render host_status.php "n=../../etc"
expect "host status path traversal refused" '"error":"not found"'

render checks.php ""
expect "connectivity report" "Connectivity tests"
render checks.php "r=health&g=dev"
expect "dev health report" "Start of dev1"
render checks.php "g=../x"
expect "bad group falls back" "Production group"

echo "== Trends"
if [ -s "${W}/reports/systems/web1/metrics_history.tsv" ] && grep -q "mem_total_mb=" "${W}/reports/systems/web1/metrics_history.tsv"; then
    pass "drsm_run.sh writes the metrics history"
else
    fail "drsm_run.sh writes the metrics history"
fi
# Ten days of history for db1: a daily CPU cycle, disk growth, NIC and
# disk I/O counters, and one CPU spike that must be flagged
HIST="${W}/reports/systems/db1/metrics_history.tsv"
awk -v now="$(date +%s)" 'BEGIN {
    start = now - 10 * 86400; tot = 0; idle = 0; tx = 0; io = 0
    for (t = start; t < now; t += 900) {
        h = (t % 86400) / 3600
        cpu = 20 + 15 * sin(h / 24 * 6.283) + (t % 7)
        if (t >= now - 3 * 3600 && t < now - 3 * 3600 + 900) cpu = 99
        tot += 180000; idle += int(180000 * (1 - cpu / 100)); tx += 50000000; io += 90000
        printf "%d\tcpu_used_pct=%d\tcpu_count=2\tcpu_ticks_total=%d\tcpu_ticks_idle=%d\tload_15m=0.5", t, cpu, tot, idle
        printf "\tmem_total_mb=8000\tmem_available_mb=%d\tswap_used_mb=0\tswap_total_mb=2048", 5000 + (t % 300)
        printf "\tdisk_used_pct{mount=\"/\"}=%d\tdisk_size_mb{mount=\"/\"}=100000\tdisk_used_mb{mount=\"/\"}=%d", 40 + (t - start) / 86400, 40000 + (t - start) / 86.4
        printf "\tnic_tx_bytes{nic=\"eth0\"}=%d\tnic_rx_bytes{nic=\"eth0\"}=%d", tx, tx / 2
        printf "\tdiskio_read_ops{dev=\"vda\"}=%d\tdiskio_write_ops{dev=\"vda\"}=%d\tdiskio_read_bytes{dev=\"vda\"}=%d\tdiskio_write_bytes{dev=\"vda\"}=%d\n", io, io, io * 4096, io * 4096
    }
}' > "${HIST}"
render trends.php ""
expect "trends in the menu" 'href="/drsm/dashboard/php/trends.php"'
expect "fleet capacity table" "Capacity by host"
expect "host with history links" 'trends.php?h=db1'
expect "host without history" "No metrics history yet"
render trends.php "h=db1&r=7d"
expect "capacity table" "Capacity and sizing"
expect "cpu row" '<th scope="row">CPU</th>'
expect "disk growth, 1000 MB a day" "Growth 29.3 GB a month"
expect "network per 30 days" "Network out"
expect "disk iops" "Disk IOPS vda"
expect "hourly baseline" "normal by hour of day"
expect "spike flagged" "Above normal"
expect "chart drawn" 'class="trend-plot"'
reject "no cloud panel without aws plugin" "AWS: what you pay for"
# Windows agent history: drsm_run.sh every 15 minutes, the agent
# every 30, so each report is seen twice. 1 MB/s in, timed by report.
WHIST="${W}/reports/systems/win1/metrics_history.tsv"
mkdir -p "$(dirname "${WHIST}")"
awk -v now="$(date +%s)" 'BEGIN {
    start = now - 3 * 86400
    for (t = start; t < now; t += 900) {
        st = start + int((t - start) / 1800) * 1800 - 300
        printf "%d\tsample_etime=%d\tcpu_used_pct=10\tcpu_count=4\tmem_total_mb=16000\tmem_available_mb=12000", t, st
        printf "\tnic_rx_bytes{nic=\"Wi-Fi\"}=%d\tnic_tx_bytes{nic=\"Wi-Fi\"}=%d\n", (st - start) * 1048576, (st - start) * 1024
    }
}' > "${WHIST}"
(cd "${W}/php" && php -d error_reporting=-1 -r 'require_once("../config/drsm.php");
    require_once("{$WWWdir}/php/drsm_lib.php"); require_once("{$WWWdir}/php/trends_lib.php");
    $d = drsm_trend_load("win1", 0); $rx = $d["series"]["rx"]["v"];
    printf("%d %d %d\n", count($rx), min($rx), max($rx));' > "${T}/win.txt" 2>&1)
if [ "$(cat "${T}/win.txt")" == "143 1048576 1048576" ]; then pass "Windows rates timed by report"; else fail "Windows rates timed by report: $(head -3 "${T}/win.txt")"; fi
render trends.php "h=../../etc"
expect "bad host falls back to all hosts" "Capacity by host"
render trends.php "h=old1&r=bogus"
expect "no history message" "utils/drsm_metrics_backfill.sh --apply"

echo "== Web only demo package"
bash "${TOPdir}/utils/make_web_demo.sh" -s -o "${T}/demo" > "${T}/demo.log" 2>&1
W="${T}/demo/dashboard"
(cd "${W}" && php -d error_reporting=-1 -d display_errors=stderr index.php > "${T}/page.html" 2> "${T}/page.err")
if [ -s "${T}/page.err" ]; then fail "demo index.php PHP messages: $(head -3 "${T}/page.err")"; else pass "demo index.php renders without PHP messages"; fi
expect "demo title" "DRSM Live Demo"
expect "demo sample host" ">mail1</strong>"
expect "demo links use the URL path" 'href="/drsm/dashboard/php/heatmap.php"'
reject "demo hosts are not stale" "Last report is over"
render heatmap.php "mode=metrics"
expect "demo metrics" 'Memory used'
render trends.php "h=www2&r=7d"
expect "demo trends" "Capacity and sizing"
expect "demo spike flagged" "Above normal"
if grep -rq "$(hostname)" "${W}/reports"; then fail "demo reports name this machine"; else pass "demo reports do not name this machine"; fi

echo ""
if [ ${failures} -eq 0 ]; then echo "All tests passed"; exit 0; fi
echo "${failures} test(s) failed"
exit 1
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
