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
export SITESdir=${T}/sites
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
    # $1 == page, $2 == query string, $3 == optional cookie string,
    # output in ${T}/page.html
    (cd "${W}/php" && php -d error_reporting=-1 -d display_errors=stderr -r '
      parse_str($argv[2], $_GET);
      if(isset($argv[3])) parse_str($argv[3], $_COOKIE);
      include $argv[1];' "$1" "$2" ${3:+"$3"} > "${T}/page.html" 2> "${T}/page.err")
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
reject "no Organizations page with one site" "orgs.php"
reject "no site picker with one site" 'name="site"' 
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
# Status messages
cat > "${W}/config/messages.conf" <<'MSG'
# test messages
info | Maintenance tonight <b> | /maint.html | 2099-01-01 00:00 |
critical | Core switch down | | | pin
warning | Old notice | | 2000-01-01 00:00 |
info | Bad link | javascript:alert(1) | |
MSG
render index.php ""
expect "message bar on every page" 'class="msgbar msgbar-critical"'
expect "pinned critical message" '<div class="msg-pinned"><a class="msg msg-critical"'
expect "message text escaped" 'Maintenance tonight &lt;b&gt;'
expect "message link" 'href="/maint.html"'
reject "ended message hidden" 'Old notice'
reject "bad link dropped" 'javascript:alert'
expect "no link goes to the messages page" 'php/messages.php#m'
render messages.php ""
expect "messages page" "Core switch down"
expect "ended messages listed apart" "Ended messages (1)"
rm -f "${W}/config/messages.conf"
render index.php ""
reject "no bar without messages" 'class="msgbar'

render help.php ""
expect "users guide" "<h1>Users guide</h1>"
expect "admin guide tab" 'php/help.php?p=admin">Admin guide'
render help.php "p=admin"
expect "admin guide" "<h1>Admin guide</h1>"
expect "admin guide docs link" 'href="https://datareel.com/drsm/docs/changelog.html"'
expect "default footer help link" 'href="/drsm/dashboard/php/help.php">Help'
mkdir -p "${W}/reports/systems/new1"
render index.php ""
expect "new host waits for its first report" "Waiting for the first report"
rmdir "${W}/reports/systems/new1"
render readreport.php "n=old1"
expect "legacy report shown" 'old1 disk is at 90%'
mkdir -p "${W}/reports/systems/winrpt"
cat > "${W}/reports/systems/winrpt/winrpt_report.txt" <<RPT
HOSTNAME:winrpt
ETIME:$(date +%s)
PLATFORM:windows

=== windows/resources [OK] 0s ===
CPU 8.0%, memory 25.0% used, C: 20.0%
DETAIL Hardware=4 CPUs, 16.0 GB memory
DETAIL Up since=2026-10-26 16:31, 12 hours
METRIC cpu_used_pct=8.0
METRIC cpu_count=4
METRIC mem_available_mb=12000
METRIC mem_total_mb=16000
METRIC disk_used_pct{mount="C:"}=20.0
RPT
render readreport.php "n=winrpt"
expect "plugin details in the Details panel" "<dt>Hardware</dt><dd>4 CPUs, 16.0 GB memory</dd>"
expect "memory gauge from mem_total_mb" "Memory used: 12000 MB free of 16000 MB"
expect "summary skips DETAIL lines" "CPU 8.0%, memory 25.0% used, C: 20.0%</span>"
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

echo "== Clusters"
render index.php ""
reject "no Clusters menu without cluster hosts" "clusters.php"
reject "no clusters panel without cluster hosts" "keep alive drops"
render heatmap.php ""
reject "no clusters table without cluster hosts" 'class="heat clusters"'
render clusters.php ""
expect "clusters page without clusters" "No host reports a DRCM cluster yet"
# Two cluster nodes as cluster/drcm reports them, n2 with a dropout
# and a down period in its keep alive strip
now=$(date +%s)
sstart=$((now - 86400))
strip=$(printf 'o%.0s' $(seq 1 280))mmdddooo
for n in n1 n2; do
    if [ "${n}" == "n1" ]; then self=node1; peer=node2; else self=node2; peer=node1; fi
    mkdir -p "${W}/reports/systems/${n}"
    {
	printf 'HOSTNAME:%s\nETIME:%s\nGROUP:production\n=== cluster/drcm [WARNING] 1s ===\n' "${n}" "${now}"
	printf 'DRCM cluster|node1+node2\nDRCM self|%s\nDRCM cluster health on %s\n' "${self}" "${n}"
	printf 'DRCM node|node1|n1.example.com|Up|10.0.0.1\nDRCM node|node2|n2.example.com|Up|10.0.0.2\n'
	printf 'DRCM resource|Crontab|job1|n1.example.com|OK-Normal|Oct 27 20:36:56\nDRCM health|HEALTHY\nDRCM link|%s|OK\n' "${peer}"
	printf 'DRCM strip|%s|%s|300|%s\n' "${peer}" "${sstart}" "${strip}"
	printf 'DRCM event|%s|miss|Node %s failed keep alive check <b>\n' "$((now - 2000))" "${peer}"
	printf 'WARNING - %s 2 missed cluster keep alives in the last 30 minutes\n' "${n}"
	printf 'METRIC drcm_keepalive_missed{peer="%s"}=2\n' "${peer}"
    } > "${W}/reports/systems/${n}/${n}_report.txt"
    printf '{"host":"%s","group":"production","time":%s,"plugins":[{"id":"cluster/drcm","state":"WARNING","secs":1}]}\n' "${n}" "${now}" > "${W}/reports/systems/${n}/status.json"
    printf '%s\tdrcm_nodes_down=0\tdrcm_keepalive_ok{peer="%s"}=10\tdrcm_keepalive_missed{peer="%s"}=3\n' "$((now - 7200))" "${peer}" "${peer}" > "${W}/reports/systems/${n}/metrics_history.tsv"
done
render clusters.php ""
expect "clusters in the menu" 'href="/drsm/dashboard/php/clusters.php"'
expect "cluster diagram" 'class="cl-svg"'
expect "node box links to its host" 'readreport.php?n=n2#p-cluster-drcm'
expect "link drawn with the recent drops" 'class="cl-link err"'
expect "keep alive strip" 'class="cl-strip"'
expect "down period in the strip" 'class="s-down"'
expect "history bars" 'class="h-miss"'
expect "event listed and escaped" 'failed keep alive check &lt;b&gt;'
expect "resource owner" 'n1.example.com'
reject "no page data lines in the CM report" 'DRCM strip|'
# node2 goes into standby: n2 reports it, n1 sees it
for n in n1 n2; do
    sed -i 's/^DRCM node|node2|n2.example.com|Up|/DRCM node|node2|n2.example.com|Standby|/' "${W}/reports/systems/${n}/${n}_report.txt"
done
render clusters.php ""
expect "standby node badge" '<span class="dot"></span>Standby</span>'
expect "standby in the nodes KPI" 'node2 in standby'
render heatmap.php ""
expect "standby on the heat map" '<span class="hcell-text">1/2 up, 1 standby</span>'
for n in n1 n2; do
    sed -i 's/^DRCM node|node2|n2.example.com|Standby|/DRCM node|node2|n2.example.com|Up|/' "${W}/reports/systems/${n}/${n}_report.txt"
done
render clusters.php "c=../../etc&r=bogus"
expect "unknown cluster falls back to the first" "node1+node2"
render index.php ""
expect "cluster tag on the host card" 'class="tag cl-tag"'
expect "clusters panel on the overview" 'Nodes 2/2 up, 2 keep alive drops in 24 h, HEALTHY'
expect "overview cluster links to its page" 'clusters.php?c=node1%2Bnode2'
render heatmap.php ""
expect "clusters table on the heat map" 'class="heat clusters"'
expect "heat map link cell shows the drops" '<span class="hcell-text">2 links</span>'
expect "heat map drops cell" 'clusters.php?c=node1%2Bnode2#cl-strips'
render heatmap.php "mode=metrics"
expect "clusters table on resource use too" 'class="heat clusters"'
render readreport.php "n=n1"
reject "page data hidden on the host page" 'DRCM node|'
expect "host page links to the cluster page" 'Cluster diagram, keep alive timeline and events'
rm -rf "${W}/reports/systems/n1" "${W}/reports/systems/n2"

echo "== Organizations and sites"
mkdir -p "${T}/sites/acme" "${T}/sites/beta"
printf 'NAME="Acme Corp"\nCONTACT="ops@acme.test"\n' > "${T}/sites/acme.org"
printf 'NAME="Head office"\nLOCATION="Springfield"\n' > "${T}/sites/acme/hq.site"
printf 'NAME="Branch"\n' > "${T}/sites/acme/branch.site"
printf 'NAME="Beta Labs"\n' > "${T}/sites/beta.org"
printf 'NAME="Lab"\nSTALE_MINUTES=30\n' > "${T}/sites/beta/lab.site"
printf 'HOST=web1\nSITE=acme/hq\nDESCRIPTION="HQ web"\n' > "${T}/hosts/hq_web1.conf"
printf 'SITE=acme/branch\ncore_load_CRIT=-1\n' > "${T}/hosts/app1.conf"
printf 'SITE=beta/lab\n' > "${T}/hosts/lab1.conf"
# Tiers: a QA site that sets GROUP for its hosts, an OPS host
printf 'NAME="QA lab"\nGROUP=qa\n' > "${T}/sites/acme/qa.site"
# Site links: nested menus, a tier link, HTML in a name, org links
cat >> "${T}/sites/acme/hq.site" <<'LINKS'
LINK="Wiki <b>|https://wiki.acme.test/?a=1&b=2"
LINK="Apps/OSA/Admin|https://osa.acme.test/admin|ops"
LINK="Apps/OSA/QA build|https://qa.osa.acme.test/|qa"
LINKS
printf 'LINK="Help desk|https://help.acme.test/"\n' >> "${T}/sites/acme.org"
printf 'SITE=acme/qa\n' > "${T}/hosts/qa1.conf"
printf 'SITE=acme/hq\nGROUP=ops\n' > "${T}/hosts/ops1.conf"
HOME="${T}/home" bash "${TOPdir}/bin/drsm_run.sh" -n >> "${T}/run.log" 2>&1
HOME="${T}/home" bash "${TOPdir}/bin/drsm_run.sh" -n -g qa >> "${T}/run.log" 2>&1
# The lab collector stopped an hour ago
old=$(( $(date +%s) - 3600 ))
sed -i "s/\"time\":[0-9]*,\"stale_minutes\"/\"time\":${old},\"stale_minutes\"/" "${W}/reports/orgs/beta/lab/site.json"
for f in "${W}"/reports/orgs/beta/lab/systems/lab1/*_report.txt; do sed -i "s/^ETIME:.*/ETIME:${old}/" "${f}"; done
sed -i "s/\"time\":[0-9]*,\"plugins\"/\"time\":${old},\"plugins\"/" "${W}/reports/orgs/beta/lab/systems/lab1/status.json"

render orgs.php ""
expect "organization heading" "Acme Corp"
expect "second organization" "Beta Labs"
expect "site card" 'data-site="acme/hq"'
expect "default site shown with the others" 'data-site="default/default"'
expect "site location" "Springfield"
expect "tile links to the host in its site" 'readreport.php?n=app1&amp;site=acme%2Fbranch'
expect "stale collector banner" "Collector not reporting"
expect "Organizations in the menu" 'href="/drsm/dashboard/php/orgs.php?site=" title="Organizations" class="active"'
expect "site picker" '<option value="acme/hq">Head office</option>'
expect "org scope in the picker" '<option value="acme">Acme Corp, all sites</option>'
render orgs.php "mode=metrics"
expect "metric tiles" 'class="matrix tiles metric"'
render orgs.php "site=beta"
expect "org scope shows its sites" 'data-site="beta/lab"'
reject "org scope hides other orgs" 'data-site="acme/hq"'
expect "scoped view names its scope" 'Showing <strong>Beta Labs</strong> only.'
expect "scoped view offers all organizations" 'href="/drsm/dashboard/php/orgs.php?site=" data-show-all>Show all organizations</a>'
expect "mode switch keeps the scope" 'href="/drsm/dashboard/php/orgs.php?mode=metrics&amp;site=beta"'
render orgs.php "" "drsm_site=acme/hq"
expect "picker cookie scopes the page" 'data-site="acme/hq"'
reject "picker cookie hides other sites" 'data-site="beta/lab"'
expect "Organizations menu clears the scope" 'href="/drsm/dashboard/php/orgs.php?site=" title="Organizations" class="active"'
expect "brand clears the scope" 'class="brand" href="/drsm/dashboard/php/orgs.php?site="'
render orgs.php "site=" "drsm_site=acme/hq"
expect "Organizations link shows every org" 'data-site="beta/lab"'
expect "Organizations link shows every site" 'data-site="acme/branch"'
reject "no scope note on all organizations" 'data-show-all'
expect "picker back to All sites" '<option value="acme/hq">Head office</option>'
reject "no site selected in the picker" ' selected>'
render heatmap.php "" "drsm_site=acme/hq"
expect "Organizations menu clears the scope on other pages" 'href="/drsm/dashboard/php/orgs.php?site=" title="Organizations"><svg'
render index.php ""
expect "overview Organizations link clears the scope" 'href="/drsm/dashboard/php/orgs.php?site=">Organizations</a>'

echo "== Site links and menus"
# A bad URL put straight into site.json is dropped when shown
sed -i 's#"links":\[#"links":[{"path":"Evil","url":"javascript:alert(1)","tier":""},{"path":"Evil2","url":"https://x.test/\\"onmouseover=\\"x","tier":""},#' "${W}/reports/orgs/acme/hq/site.json"
render index.php "site=acme/hq&tier="
expect "Site links menu for one site" '<details class="menu links-menu" data-menu>'
expect "site links open in a new tab" 'href="https://osa.acme.test/admin" target="_blank" rel="noopener noreferrer">Admin'
expect "link URL escaped" 'href="https://wiki.acme.test/?a=1&amp;b=2"'
expect "link name escaped" '>Wiki &lt;b&gt;<svg'
reject "link name not raw" 'Wiki <b>'
expect "nested submenu" '<details class="menu-sub"><summary>Apps<svg'
expect "second submenu level" '<details class="menu-sub"><summary>OSA<svg'
expect "org links section" 'Org links &middot; Acme Corp'
expect "org link" 'href="https://help.acme.test/"'
expect "every tier with All" '>QA build<svg'
reject "javascript URL dropped" "javascript:"
reject "quote in URL dropped" "onmouseover"
render index.php "site=acme/hq&tier=qa"
expect "QA link with the QA filter" '>QA build<svg'
reject "OPS link hidden with the QA filter" '>Admin<svg'
expect "links without a tier always shown" '>Wiki &lt;b&gt;<svg'
render index.php "site=&tier="
expect "Org links menu for all sites" '<span class="menu-label">Org links</span>'
expect "all sites menu names every org" 'title="Links for all organizations"'
expect "all sites shows org links" 'href="https://help.acme.test/"'
reject "all sites hides site links" 'href="https://wiki.acme.test/'
reject "no section for an org without links" 'Org links &middot; Beta Labs'
render index.php "site=acme&tier="
expect "Org links menu for a whole org" 'title="Links for Acme Corp"'
expect "whole org shows its org links" 'Org links &middot; Acme Corp'
render index.php "site=beta&tier="
reject "no links menu for an org without links" 'class="menu links-menu"'
render orgs.php "site=&tier=" "drsm_site=acme/hq"
expect "Organizations link shows the org links menu" '<span class="menu-label">Org links</span>'
render orgs.php "site=&tier="
expect "site card links menu" '<details class="menu card-links" data-menu>'
expect "nav submenu for Organizations" '<li><a href="/drsm/dashboard/php/orgs.php?site=acme">Acme Corp</a></li>'
expect "nav submenu for the heat map" '<li><a href="/drsm/dashboard/php/heatmap.php?mode=metrics">Resource use</a></li>'
expect "nav submenu for connectivity" '<li><a href="/drsm/dashboard/php/checks.php?r=health">Health reports</a></li>'
render orgs.php "site=beta&tier="
reject "no card links menu without links" 'class="menu card-links"'

echo "== Tiers"
render orgs.php ""
expect "tier buttons" 'data-tier-filter><a href="/drsm/dashboard/php/orgs.php?site=&amp;tier=" class="active" aria-current="page">All</a>'
expect "tiers in DEV, QA, OPS order" '>DEV</a><a href="/drsm/dashboard/php/orgs.php?site=&amp;tier=qa">QA</a><a href="/drsm/dashboard/php/orgs.php?site=&amp;tier=ops">OPS</a>'
expect "tier counts on the site card" '<ul class="tier-counts" aria-label="Hosts by tier">'
expect "OPS count for the head office" '<span class="tier tier-ops">OPS</span>2</li>'
expect "tier in the tile tip" 'title="qa1 (QA) - '
render orgs.php "tier=qa"
expect "QA filter keeps qa1" 'title="qa1 (QA) - '
reject "QA filter hides OPS hosts" 'title="ops1 (OPS) - '
reject "QA filter hides sites with no QA hosts" 'data-site="beta/lab"'
expect "QA count marked active" '<li class="active"><span class="tier tier-qa">QA</span>1</li>'
render orgs.php "" "drsm_tier=dev"
expect "tier cookie filters" 'title="dev1 (DEV) - '
reject "tier cookie hides other tiers" 'title="qa1 (QA) - '
render orgs.php "tier=" "drsm_tier=dev"
expect "tier= clears the filter" 'title="qa1 (QA) - '
render orgs.php "tier=<b>"
reject "bad tier ignored" "<b>"
render orgs.php "" "drsm_tier=staging"
expect "unknown cookie tier still shown to clear" '>STAGING</a>'
expect "no hosts in the tier" "No STAGING hosts in these sites."
render heatmap.php "tier=dev"
expect "heat map tier badge" 'dev1<span class="tier tier-dev" title="Tier">DEV</span>'
reject "heat map tier filter" 'truncate">db1<'
expect "heat map tier link keeps the view" 'href="/drsm/dashboard/php/heatmap.php?mode=status&amp;sort=state&amp;tier=qa">QA</a>'
render reports.php "tier=ops"
expect "hosts tier column" '>Tier</th>'
expect "hosts tier badge" '<span class="tier tier-ops" title="Tier">OPS</span>'
expect "ops host listed" '>ops1</a>'
reject "dev host filtered out" '>dev1</a>'
render checks.php "r=health&g=ops"
expect "g=ops is the production report" "Start of db1"

render index.php ""
expect "per site table" 'id="site-table"'
expect "site host card tagged" 'Acme Corp / Head office'
expect "brand goes to Organizations" 'class="brand" href="/drsm/dashboard/php/orgs.php?site="'
render index.php "site=acme/hq"
expect "site scope shows its host" "HQ web"
reject "site scope hides other sites" ">app1</h3>"
reject "no site table for one site" 'id="site-table"'

render reports.php ""
expect "organization column" ">Organization</th>"
expect "site host link" 'readreport.php?n=web1&amp;site=acme%2Fhq'
expect "default site host link unchanged" 'readreport.php?n=db1"'

render heatmap.php "by=site"
expect "heat map by site" 'class="heat-site"'
expect "heat map site heading" "Acme Corp / Branch"
render heatmap.php ""
expect "heat map rows name the site" '<span class="site-tag">Acme Corp / Head office</span>'

render readreport.php "n=web1"
expect "same name in two sites asks for the site" "web1 is in more than one site"
expect "choice links name the site" 'readreport.php?n=web1&amp;site=acme%2Fhq'
render readreport.php "n=web1&site=acme/hq"
expect "host in its site" "SITE:acme/hq"
expect "site in the details" "<dt>Site</dt><dd>Acme Corp / Head office</dd>"
render readreport.php "n=acme/hq/web1"
expect "org/site/host name" "SITE:acme/hq"
render readreport.php "n=app1"
expect "unique name needs no site" "SITE:acme/branch"
render readreport.php "n=app1&site=acme/hq"
expect "host not in that site" "Host not found"
render readreport.php "n=web1&site=../../etc"
expect "bad site refused" "Host not found"
render readreport.php "n=web1&site=default/default"
reject "default site host by site" "SITE:"
expect "default site host by site" "Web &lt;one&gt;"

render host_status.php "n=web1"
expect "ambiguous host status" '"error":"ambiguous"'
expect "ambiguous host status lists sites" '"sites":["default\/default","acme\/hq"]'
render host_status.php "n=web1&site=acme/hq"
expect "host status with site" '"site":"acme\/hq"'
render host_status.php "n=lab1"
expect "host status of a stale site" '"stale":true'

render archive.php "h=app1"
expect "site host archive" "app1_report_"
render archive.php "site=acme/branch"
expect "site group archive" "system_check_report_"
render archive.php "h=web1&site=acme/hq"
expect "archive back link keeps the site" 'readreport.php?n=web1&amp;site=acme%2Fhq'

render checks.php "site=acme/branch"
expect "site connectivity report" "Acme Corp / Branch"
expect "site health report link" 'checks.php?r=health&amp;g=production&amp;site=acme%2Fbranch'
render checks.php "r=health&site=acme/branch"
expect "site health report" "Start of app1"

render trends.php "h=app1"
expect "site host trends" "app1 trends"
render trends.php "h=acme/branch/app1&r=7d"
expect "org/site/host trends" "app1 trends"
render trends.php "h=web1"
expect "ambiguous trends host" "web1 is in more than one site"
render trends.php ""
expect "trends grouped by site" 'class="site-row"'
expect "trends site totals" "Acme Corp / Branch total"

echo "== Web only demo package"
# Other script reports ($EXTreports), Site links on a one-site
# install, a logo and extra menu items ($SITElogo, $NAVextra)
printf 'ETIME:%s\nall backups good\n' "$(date +%s)" > "${T}/ext_ok.txt"
printf 'WARNING - cert expires in 20 days <b>\n' > "${T}/ext_warn.txt"
printf 'ETIME:1000000000\nok\n' > "${T}/ext_old.txt"
printf 'ERROR - blade fan\n' > "${T}/ext_err.txt"
printf 'REPORT_ETIME:1000000000\nall good\n' > "${T}/ext_rold.txt"
cat > "${W}/config/ext_reports.conf" <<EXT
# comment
[backup] Backups
Nightly backups | ${T}/ext_ok.txt | | 60
Certificates | ${T}/ext_warn.txt
Old report | ${T}/ext_old.txt | | 60
Old report 2 | ${T}/ext_rold.txt | | 60
Blades | ${T}/ext_ok.txt | /blades/ | | ${T}/ext_err.txt
[links] Links
Missing | ${T}/ext_missing.txt
Console | - | https://console.example.com/
Scan | ${T}/ext_warn.txt | | | -
EXT
cp "${W}/config/drsm.php" "${T}/drsm.php.saved"
sed -i '$d' "${W}/config/drsm.php"
cat >> "${W}/config/drsm.php" <<PHPCONF
\$EXTreports = '${W}/config/ext_reports.conf';
\$EXTtitle = 'Site reports';
\$METRICSskip = array("windows");
\$NAVhome = array("label" => "Status", "url" => "/status/", "icon" => "check");
\$NAVurl = array("hosts" => "/my/hosts.php");
\$NAVsub = array("heatmap" => array(array("Wall display", "/my/wall.php")));
\$SITEfooter = 'Example Ops Monitor';
\$SITEhelp = '/my/help.php';
\$SITElogo = '/img/logo.png';
\$NAVextra = array(array("label" => "Classic view", "url" => "/classic/", "icon" => "layout"),
                   array("label" => "Tools", "url" => "/tools/", "sub" => array(array("Time converter", "/tools/utc.php"))),
                   array("label" => ""));
?>
PHPCONF
# Only the default site for these
if [ -d "${W}/reports/orgs" ]; then mv "${W}/reports/orgs" "${T}/orgs.saved"; fi
mv "${T}/sites" "${T}/sites.saved"
mkdir -p "${T}/sites/default"
printf 'NAME="Head office"\nLINK="Consoles/Storage|https://storage.example.com/"\n' > "${T}/sites/default/default.site"
HOME="${T}/home" bash "${TOPdir}/bin/drsm_run.sh" -n -s default/default > "${T}/run.log" 2>&1
if [ -f "${W}/reports/site.json" ] && grep -q 'storage.example.com' "${W}/reports/site.json"; then pass "default site.json written with links"; else fail "default site.json not written"; fi
render index.php ""
expect "site reports panel" "Site reports"
expect "site reports section state" "4 of 5 need attention"
expect "site links on one site" 'https://storage.example.com/'
expect "logo" 'class="brand-logo" src="/img/logo.png"'
expect "extra menu item kept as is" 'href="/classic/"'
expect "extra submenu" 'href="/tools/utc.php"'
expect "wide top bar with extra items" 'class="topbar nav-wide"'
expect "NAVhome first in the menu" 'href="/status/" title="Status"'
expect "NAVhome is the brand link" '<a class="brand" href="/status/"'
expect "NAVurl sends a built in item elsewhere" 'href="/my/hosts.php" title="Hosts"'
expect "NAVsub replaces a submenu" 'href="/my/wall.php">Wall display'
reject "NAVsub drops the old submenu" 'mode=metrics">Resource use'
expect "SITEfooter" 'Example Ops Monitor'
expect "SITEhelp link" 'href="/my/help.php">Help'
render extreports.php "s=backup"
if [ "$(grep -c 'Report is older than 1 hour' "${T}/page.html")" -ge 2 ]; then pass "ext REPORT_ETIME read"; else fail "ext REPORT_ETIME not read"; fi
reject "one site still has no picker" 'name="site"'
render heatmap.php "mode=metrics"
reject "no metrics for skipped platforms on the heat map" '>winrpt<'
render trends.php ""
reject "no metrics for skipped platforms on trends" 'winrpt'
render extreports.php ""
expect "ext ok report" "Nightly backups"
expect "ext warning" '<span class="badge warn">'
expect "ext stale" "Report is older than 1 hour"
expect "ext status file error links to its page" 'href="/blades/"'
expect "ext missing file" "Report file is missing"
expect "ext plain link" 'href="https://console.example.com/"'
expect "ext no-state report" '<span class="muted">Report</span>'
render extreports.php "s=links"
reject "one section only" "Nightly backups"
render extreports.php "v=backup-1"
expect "ext report shown and escaped" 'cert expires in 20 days &lt;b&gt;'
render extreports.php "v=../../etc/passwd"
expect "ext only listed files" "No such report"
cp "${T}/drsm.php.saved" "${W}/config/drsm.php"
rm -f "${W}/reports/site.json"
rm -rf "${T}/sites"
mv "${T}/sites.saved" "${T}/sites"
if [ -d "${T}/orgs.saved" ]; then mv "${T}/orgs.saved" "${W}/reports/orgs"; fi

bash "${TOPdir}/utils/make_web_demo.sh" -s -o "${T}/demo" > "${T}/demo.log" 2>&1
W="${T}/demo/dashboard"
(cd "${W}" && php -d error_reporting=-1 -d display_errors=stderr index.php > "${T}/page.html" 2> "${T}/page.err")
if [ -s "${T}/page.err" ]; then fail "demo index.php PHP messages: $(head -3 "${T}/page.err")"; else pass "demo index.php renders without PHP messages"; fi
expect "demo title" "DRSM Live Demo"
expect "demo sample host" ">mail1</strong>"
expect "demo links use the URL path" 'href="/drsm/dashboard/php/heatmap.php"'
expect "demo sites table" 'id="site-table"'
render orgs.php ""
expect "demo organizations" "Northwind Traders"
expect "demo second organization" "Blue Ridge Clinics"
expect "demo stale collector" "Collector not reporting"
expect "demo four sites" 'data-site="blueridge/annex"'
render readreport.php "n=www1"
reject "demo hosts are not stale" "Last report is over"
render readreport.php "n=fw1"
expect "demo annex hosts are stale" "Last report is over"
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
