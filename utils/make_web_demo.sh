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
# Builds a Web only copy of the DRSM dashboard that needs nothing but
# PHP 7.2 or higher, for shared hosting such as HostGator. The copy
# finds its own files, so it can be unpacked into any directory. Use
# it for a public live demo with made up sample reports (-s), or as
# the Web side of a site where reports are copied in from a monitor
# host.
#
# Usage: utils/make_web_demo.sh [-p /url/path] [-o outdir] [-t title] [-s] [-a]
#
#   -p  URL path the dashboard is served from, default /drsm/dashboard
#   -o  Output directory, default ./drsm_web
#   -t  Title in the page header, default "DRSM Live Demo" with -s,
#       otherwise "DR System Monitor"
#   -s  Add sample reports for made up hosts. Nothing from the machine
#       running this script goes into them.
#   -a  Turn on login for access from outside the internal networks,
#       and block the report folder so raw reports are only read
#       through the pages. Add accounts to config/drsm.php with
#       php utils/drsm_password.php before uploading.
#
# Writes <outdir>/dashboard/ and <outdir>/drsm_dashboard.zip. Upload
# the zip into the parent of the URL path (public_html/drsm for
# /drsm/dashboard) and extract it there.
#
# -----------------------------------------------------------
TOPdir=$(cd "$(dirname "$0")/.." && pwd)

vpath="/drsm/dashboard"
outdir="./drsm_web"
title=""
sample="0"
auth="0"
while getopts "p:o:t:sa" opt
do
    case ${opt} in
	p) vpath="${OPTARG%/}" ;;
	o) outdir="${OPTARG}" ;;
	t) title="${OPTARG}" ;;
	s) sample="1" ;;
	a) auth="1" ;;
	*) echo "Usage: $0 [-p /url/path] [-o outdir] [-t title] [-s] [-a]"; exit 1 ;;
    esac
done
if [ "${vpath:0:1}" != "/" ]; then vpath="/${vpath}"; fi
if [ "${title}" == "" ]; then
    if [ "${sample}" == "1" ]; then title="DRSM Live Demo"; else title="DR System Monitor"; fi
fi
if ! [[ "${vpath}" =~ ^[A-Za-z0-9/._-]+$ ]] || [[ "${title}" == *"'"* ]]; then
    echo "ERROR - URL path or title has characters that are not allowed"
    exit 1
fi

D="${outdir}/dashboard"
NOW=$(date +%s)
rm -rf "${D}" "${outdir}/drsm_dashboard.zip"
mkdir -p "${D}/config" "${D}/site" "${D}/reports/systems" "${D}/reports/archive"
cp -r "${TOPdir}/www/php" "${TOPdir}/www/css" "${TOPdir}/www/js" "${TOPdir}/www/images" "${D}/"

# Config that finds its own directory, so no server paths are needed
cat > "${D}/config/drsm.php" <<PHPCONF
<?php
// DRSM PHP config for a Web only install
// Built by utils/make_web_demo.sh
\$WWWdir = dirname(__DIR__);
\$WWWvpath = '${vpath}';
\$REPORTdir = \$WWWdir . '/reports';
\$REPORTvpath = \$WWWvpath . '/reports';
\$REPORTarchive = \$REPORTdir . '/archive';
\$REPORTarchivevpath = \$REPORTvpath . '/archive';
\$CONFIGdir = \$WWWdir . '/config';
\$SITEincludes = \$WWWdir . '/site';
\$SITEtitle = '${title}';
PHPCONF
if [ "${sample}" == "1" ]; then
    cat >> "${D}/config/drsm.php" <<PHPCONF
// Sample reports do not change, so show their times relative to now
\$DEMObuilt = ${NOW};
\$STALEminutes = 0;
\$REFRESHseconds = 300;
PHPCONF
fi
if [ "${auth}" == "1" ]; then
    cat >> "${D}/config/drsm.php" <<'PHPCONF'
// Login for access from outside the internal networks, see
// php/drsm_auth.php for every setting. Add a line for each account
// from: php utils/drsm_password.php <user>
$AUTHenable = 1;
$AUTHnetworks = array('127.0.0.1/32', '::1/128', '10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16');
$AUTHusers = array(
);
PHPCONF
fi
echo '?>' >> "${D}/config/drsm.php"

# The pages load ../config/drsm.php from the php directory
cat > "${D}/index.php" <<'PHPINDEX'
<?php
chdir(__DIR__ . '/php');
include(__DIR__ . '/php/index.php');
?>
PHPINDEX

cat > "${D}/.htaccess" <<'HTACCESS'
# DRSM dashboard
DirectoryIndex index.php
Options -Indexes
<IfModule mod_headers.c>
  Header set X-Content-Type-Options "nosniff"
  Header set Referrer-Policy "same-origin"
</IfModule>
HTACCESS
for d in config site; do
    cat > "${D}/${d}/.htaccess" <<'HTACCESS'
# Not for browsers
<IfModule mod_authz_core.c>
  Require all denied
</IfModule>
<IfModule !mod_authz_core.c>
  Order deny,allow
  Deny from all
</IfModule>
HTACCESS
done
if [ "${auth}" == "1" ]; then
    # With login on, reports are read through the pages only
    cp "${D}/config/.htaccess" "${D}/reports/.htaccess"
else
    cat > "${D}/reports/.htaccess" <<'HTACCESS'
# Archived report lists
Options +Indexes
<FilesMatch "\.json$">
  <IfModule mod_authz_core.c>
    Require all denied
  </IfModule>
</FilesMatch>
HTACCESS
fi

# ------------------------------------------------------------
# Sample reports
# ------------------------------------------------------------

R="${D}/reports"

# Report sections, same format as bin/drsm_run.sh
function section() {
    # $1 == plugin, $2 == state, $3 == seconds, rest == lines
    local id="$1" state="$2" secs="$3"
    shift 3
    echo "=== ${id} [${state}] ${secs}s ==="
    printf '%s\n' "$@"
    echo ""
    PL+=("{\"id\":\"${id}\",\"state\":\"${state}\",\"secs\":${secs}}")
}

function host_report() {
    # $1 host, $2 description, $3 impact, $4 group, $5 cpu%, $6 mem%,
    # $7 disk%, $8 load*100, $9 cpus, ${10} swap%, ${11} web probes yes/no,
    # ${12} extra problem: none, nicerr, user, https, down
    local h="$1" desc="$2" impact="$3" group="$4" cpu="$5" mem="$6" disk="$7" load="$8" cpus="$9" swap="${10}" web="${11}" extra="${12}"
    local et=$((NOW - (RANDOM % 240) - 30))
    local total=$((8192 * (cpus / 2 + 1)))
    local avail=$((total * (100 - mem) / 100))
    local swaptotal=4096
    local swapused=$((swaptotal * swap / 100))
    local la
    la=$(printf '%d.%02d' $((load / 100)) $((load % 100)))
    local hd="${R}/systems/${h}"
    local probes="network/ping" plugins="core/cpu core/load core/memory storage/disk network/nics core/users"
    local st
    PL=()
    mkdir -p "${hd}/archive"
    if [ "${web}" == "yes" ]; then probes="network/ping network/https"; fi
    {
	echo "INFO - Start of ${h} system health check report"
	echo "REPORT_TIME:$(date -u -d "@${et}" 2>/dev/null || date -u -r "${et}")"
	echo "ETIME:${et}"
	echo "HOSTNAME:${h}"
	echo "DESCRIPTION:${desc}"
	echo "IMPACT:${impact}"
	echo "GROUP:${group}"
	echo "PLATFORM:linux"
	echo "COLLECTOR:ssh"
	echo "PROBES:${probes}"
	echo "PLUGINS:${plugins}"
	echo ""
	if [ "${extra}" == "down" ]; then
	    section network/ping ERROR 3 "ERROR - Network connectivity failed on ${h}, ${desc}" "IMPACT - ${impact}"
	    echo "ERROR - ${h} is down, remote plugins skipped"
	else
	    section network/ping OK 1 "INFO - Network connectivity test passed on ${h}, ${desc}"
	    if [ "${web}" == "yes" ]; then
		if [ "${extra}" == "https" ]; then
		    section network/https WARNING 2 "WARNING - HTTPS certificate for ${h}.example.com expires in 9 days" "INFO - HTTPS connectivity test passed on ${h}"
		else
		    section network/https OK 1 "INFO - HTTPS connectivity test passed on ${h}" "INFO - Certificate for ${h}.example.com is valid for 61 days"
		fi
	    fi
	    st=OK; local cpumsg="INFO - ${h} CPU checks good at ${cpu}% usage"
	    if [ "${cpu}" -ge 95 ]; then st=ERROR; cpumsg="ERROR - ${h} CPU usage is ${cpu}%, above 95%"
	    elif [ "${cpu}" -ge 85 ]; then st=WARNING; cpumsg="WARNING - ${h} CPU usage is ${cpu}%, above 85%"; fi
	    section core/cpu ${st} 2 "${cpumsg}" "Total CPU stats for ${h}" "Total CPUs: ${cpus}" "Total usage: ${cpu}%" "Total steal: 0%" \
		"METRIC cpu_used_pct=${cpu}" "METRIC cpu_steal_pct=0" "Process usage:" " %CPU %MEM     ELAPSED COMMAND" \
		"$(printf '%5s %4s %11s %s' "$((cpu / 2)).4" "6.1" "12-04:11:52" "/usr/sbin/httpd -DFOREGROUND")" \
		"$(printf '%5s %4s %11s %s' "$((cpu / 5)).1" "11.8" "30-17:02:09" "/usr/libexec/mysqld --basedir=/usr")"
	    st=OK; local loadmsg="INFO - ${h} load average checks good"
	    if [ "${load}" -gt $((cpus * 200)) ]; then st=ERROR; loadmsg="ERROR - ${h} 15 minute load average ${la} is above $((cpus * 2))"
	    elif [ "${load}" -gt $((cpus * 100)) ]; then st=WARNING; loadmsg="WARNING - ${h} 15 minute load average ${la} is above ${cpus}"; fi
	    section core/load ${st} 0 "${loadmsg}" "Load averages for ${h}" "Number of CPUs: ${cpus}" "1 minute load:  ${la}" "5 minute load:  ${la}" "15 minute load: ${la}" "METRIC load_15m=${la}"
	    st=OK; local memmsg="INFO - ${h} memory checks good"
	    if [ "${mem}" -ge 95 ]; then st=ERROR; memmsg="ERROR - ${h} available memory is ${avail} MB, below 5%"
	    elif [ "${mem}" -ge 90 ]; then st=WARNING; memmsg="WARNING - ${h} available memory is ${avail} MB, below 10%"; fi
	    section core/memory ${st} 0 "${memmsg}" "Memory stats for ${h}" "Total physical: ${total} MB" "Used physical:  $((total - avail)) MB" \
		"Physical Memory Available: ${avail} MB" "Total SWAP: ${swaptotal} MB" "Used SWAP:  ${swapused} MB" "Free SWAP:  $((swaptotal - swapused)) MB" \
		"METRIC mem_available_mb=${avail}" "METRIC swap_used_mb=${swapused}"
	    st=OK; local diskmsg="INFO - ${h}:/var checks good at ${disk}% capacity."
	    if [ "${disk}" -ge 95 ]; then st=ERROR; diskmsg="ERROR - ${h}:/var is full at ${disk}% capacity."
	    elif [ "${disk}" -ge 85 ]; then st=WARNING; diskmsg="WARNING - ${h}:/var is at ${disk}% capacity."; fi
	    section storage/disk ${st} 0 "Disk usage checks for ${h}" "INFO - ${h}:/ checks good at 38% capacity." "METRIC disk_used_pct{mount=\"/\"}=38" \
		"${diskmsg}" "METRIC disk_used_pct{mount=\"/var\"}=${disk}" "INFO - ${h}:/boot checks good at 21% capacity." "METRIC disk_used_pct{mount=\"/boot\"}=21"
	    if [ "${extra}" == "nicerr" ]; then
		section network/nics WARNING 5 "${h} eth0 Public network NIC stats" "WARNING - ${h} eth0 Public network has packet loss" "RX dropped: 1832" \
		    "METRIC nic_rx_bytes{nic=\"eth0\"}=918273645512" "METRIC nic_tx_bytes{nic=\"eth0\"}=228374651009"
	    else
		section network/nics OK 5 "${h} eth0 Public network NIC stats" "INFO - ${h} eth0 checks good" \
		    "METRIC nic_rx_bytes{nic=\"eth0\"}=$((RANDOM * 99991))" "METRIC nic_tx_bytes{nic=\"eth0\"}=$((RANDOM * 77003))"
	    fi
	    if [ "${extra}" == "user" ]; then
		section core/users WARNING 0 "Users logged in to ${h}" "WARNING - ${h} user contractor logged in" "METRIC user_sessions=2"
	    else
		section core/users OK 0 "Users logged in to ${h}" "INFO - ${h} 1 user session" "METRIC user_sessions=1"
	    fi
	fi
	echo "INFO - End of ${h} system health check report"
    } > "${hd}/${h}_report.txt"
    cp "${hd}/${h}_report.txt" "${hd}/archive/${h}_report_$(date -u -d "@$((et - 86400))" +%Y%m%d_%H%M%S 2>/dev/null || echo yesterday).txt"
    local IFS=","
    echo "{\"host\":\"${h}\",\"group\":\"${group}\",\"time\":${et},\"plugins\":[${PL[*]}]}" > "${hd}/status.json"
    touch -d "@${et}" "${hd}/${h}_report.txt" 2>/dev/null
}

if [ "${sample}" == "1" ]; then
    #          host     description                  impact                     group       cpu mem disk load cpus swap web extra
    host_report www1    "Public web server 1"        "Website is degraded"      production  34  58  61  120  4   3  yes none
    host_report www2    "Public web server 2"        "Website is degraded"      production  88  71  64  410  4   9  yes none
    host_report www     "Website cluster address"    "Website is down"          production  21  44  52   60  4   0  yes https
    host_report db1     "MySQL primary database"     "All applications down"    production  46  92  78  280  8  22  no  none
    host_report db2     "MySQL replica"              "Reporting is delayed"     production  12  63  80   90  8   4  no  none
    host_report app1    "Order API node 1"           "Orders are delayed"       production  27  49  44  110  4   0  no  none
    host_report app2    "Order API node 2"           "Orders are delayed"       production  31  52  45  130  4   0  no  nicerr
    host_report cache1  "Redis cache"                "Pages load slowly"        production   6  81  33   20  2   0  no  none
    host_report mail1   "Mail relay"                 "Email is not delivered"   production   4  37  97   15  2   1  no  none
    host_report files1  "File and backup server"     "Backups stop"             production   9  41  86   40  4   2  no  none
    host_report vpn1    "Site to site VPN gateway"   "Branch offices offline"   production   2  18  29    5  2   0  no  down
    host_report mon1    "DRSM monitor host"          "Monitoring stops"         production   7  33  41   30  2   0  no  none
    host_report build1  "CI build server"            "Builds stop"              dev         73  66  58  350  8  12  no  user
    host_report dev1    "Development web server"     "Developers blocked"       dev         15  40  49   45  4   0  yes none
    host_report test1   "QA test server"             "Testing is blocked"       dev         11  35  38   25  4   0  no  none

    # Group reports from the same host reports, as drsm_run.sh writes them
    for g in production dev; do
	if [ "${g}" == "production" ]; then hp="system_health_report"; cp_="system_check_report"; else hp="system_health_report_${g}"; cp_="system_check_${g}_report"; fi
	{
	    echo "DRSM health check report, $(date -u)"
	    echo "Our report type is set to: ${g^^}"
	    for f in "${R}"/systems/*/*_report.txt; do
		if grep -q "^GROUP:${g}\$" "${f}"; then cat "${f}"; fi
	    done
	} > "${R}/${hp}.txt"
	grep "ERROR - \|WARNING - " "${R}/${hp}.txt" > "${R}/${hp}_errors.txt"
	{
	    echo "DRSM status report, $(date -u)"
	    echo "Our report type is set to: ${g^^}"
	    for f in "${R}"/systems/*/*_report.txt; do
		if ! grep -q "^GROUP:${g}\$" "${f}"; then continue; fi
		awk '/^=== network\// { p = 1 } /^=== / && !/^=== network\/(ping|https)/ { p = 0 } p' "${f}"
	    done
	} > "${R}/${cp_}.txt"
	cp "${R}/${hp}.txt" "${R}/archive/${hp}_$(date -u +%Y%m%d_%H%M%S).txt"
	cp "${R}/${cp_}.txt" "${R}/archive/${cp_}_$(date -u +%Y%m%d_%H%M%S).txt"
    done
fi

if command -v zip > /dev/null 2>&1; then
    (cd "${outdir}" && zip -qr drsm_dashboard.zip dashboard)
    echo "Built ${D} and ${outdir}/drsm_dashboard.zip for ${vpath}"
else
    echo "Built ${D} for ${vpath} (install zip to also build drsm_dashboard.zip)"
fi
exit 0
# -----------------------------------------------------------
# *******************************
# ********* End of File *********
# *******************************
