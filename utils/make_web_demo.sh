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
#   -s  Add sample reports for made up hosts in two made up
#       organizations with two sites each, one of them with a monitor
#       host that stopped reporting. Nothing from the machine running
#       this script goes into them.
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
// \$LRAreportsDir is not set: OpenSCAP HTML reports from the Linux
// agent are only on the server that receives the agent uploads
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
# Reports of the site being filled, see sample_site
SR="${R}"
# Seconds added to the report age, for a site whose monitor host stopped
SITEAGE=0

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
    local et=$((NOW - (RANDOM % 240) - 30 - SITEAGE))
    local total=$((8192 * (cpus / 2 + 1)))
    local avail=$((total * (100 - mem) / 100))
    local swaptotal=4096
    local swapused=$((swaptotal * swap / 100))
    local la
    la=$(printf '%d.%02d' $((load / 100)) $((load % 100)))
    local hd="${SR}/systems/${h}"
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
	if [ "${SR}" != "${R}" ]; then echo "SITE:${SR#"${R}/orgs/"}"; fi
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

# 30 days of metrics history for the trends page: a daily cycle around
# the host's current use, slow disk growth, and a CPU spike on www2
function sample_history() {
    # $1 host, $2 cpu%, $3 mem%, $4 disk% of /var, $5 cpus, $6 spike yes/no
    awk -v now="${NOW}" -v cpu="$2" -v mem="$3" -v disk="$4" -v cpus="$5" -v spike="$6" -v seed="${#1}$2$3" 'BEGIN {
	srand(seed)
	total = 8192 * (int(cpus / 2) + 1); size = 512000
	start = now - 30 * 86400; ticks = 0; idle = 0; tx = 0; rx = 0; ops = 0; byt = 0
	for (t = start; t <= now - 900; t += 900) {
	    day = 0.5 + 0.5 * sin(((t % 86400) / 3600 - 9) / 24 * 6.2832)
	    c = cpu * (0.4 + 0.9 * day) + rand() * 4
	    if (spike == "yes" && t > now - 4 * 3600 && t <= now - 3 * 3600) c = 99
	    if (c > 100) c = 100
	    ticks += 90000 * cpus; idle += int(90000 * cpus * (1 - c / 100))
	    m = mem * (0.85 + 0.2 * day) + rand() * 2; if (m > 99) m = 99
	    used = size * (disk - 4 + 4 * (t - start) / (30 * 86400)) / 100
	    tx += int((300000 + 900000 * day) * 900 * (0.8 + rand() * 0.4)); rx += int((80000 + 200000 * day) * 900)
	    o = int((60 + 400 * day) * 900 * (0.8 + rand() * 0.4)); ops += o; byt += o * 12288
	    printf "%d\tcpu_used_pct=%d\tcpu_count=%d\tcpu_ticks_total=%d\tcpu_ticks_idle=%d\tcpu_ticks_steal=0", t, c, cpus, ticks, idle
	    printf "\tload_15m=%.2f\tmem_total_mb=%d\tmem_available_mb=%d\tswap_used_mb=0\tswap_total_mb=4096", c / 100 * cpus * 1.2, total, total * (100 - m) / 100
	    printf "\tdisk_used_pct{mount=\"/var\"}=%d\tdisk_size_mb{mount=\"/var\"}=%d\tdisk_used_mb{mount=\"/var\"}=%d", used / size * 100, size, used
	    printf "\tnic_rx_bytes{nic=\"eth0\"}=%d\tnic_tx_bytes{nic=\"eth0\"}=%d", rx, tx
	    printf "\tdiskio_read_ops{dev=\"sda\"}=%d\tdiskio_write_ops{dev=\"sda\"}=%d\tdiskio_read_bytes{dev=\"sda\"}=%d\tdiskio_write_bytes{dev=\"sda\"}=%d\n", ops / 3, ops - int(ops / 3), byt / 3, byt - int(byt / 3)
	}
    }' > "${SR}/systems/${1}/metrics_history.tsv"
}

function sample_site() {
    # Start filling site $1 (org/site): $2 org name, $3 site name,
    # $4 location, $5 monitor host, $6 minutes since it last reported
    SR="${R}/orgs/${1}"
    SITEAGE=$(( ${6} * 60 ))
    mkdir -p "${SR}/systems" "${SR}/archive"
    printf '{"org":"%s","name":"%s","contact":"","sites":[]}\n' "${1%%/*}" "${2}" > "${R}/orgs/${1%%/*}/org.json"
    SITEINFO+=("${1}|${2}|${3}|${4}|${5}|${6}")
}

function demo_links() {
    # LINK lines for sample site $1, or org $1 with no /, put through
    # drsm_links_json as a site file would be
    local f
    f=$(mktemp)
    case "${1}" in
	northwind) printf '%s\n' 'LINK="Help desk|https://help.example.com/"' 'LINK="Apps/Order portal|https://orders.example.com/"' \
	    'LINK="Apps/Order portal admin|https://orders.example.com/admin|ops"' 'LINK="Apps/Staging/Order portal|https://staging.orders.example.com/|qa"' \
	    'LINK="Runbooks/Database failover|https://wiki.example.com/runbooks/db-failover"' 'LINK="Runbooks/Network/VPN|https://wiki.example.com/runbooks/vpn"' > "${f}" ;;
	northwind/hq) printf '%s\n' 'LINK="Web cluster status|https://status.example.com/"' 'LINK="Grafana/Web|https://grafana.example.com/d/web"' \
	    'LINK="Grafana/Database|https://grafana.example.com/d/db"' 'LINK="Grafana/Cache/Redis|https://grafana.example.com/d/redis"' > "${f}" ;;
	northwind/warehouse) printf '%s\n' 'LINK="Inventory system|https://inventory.example.com/"' 'LINK="Backups/Last night|https://backup.example.com/jobs/latest"' > "${f}" ;;
	blueridge) printf '%s\n' 'LINK="Clinic intranet|https://intranet.example.org/"' 'LINK="Vendor support/EHR vendor|https://support.example.org/ehr"' > "${f}" ;;
	blueridge/main) printf '%s\n' 'LINK="Patient records|https://ehr.example.org/"' 'LINK="CI builds|https://ci.example.org/|dev"' \
	    'LINK="Test plans|https://qa.example.org/plans|qa"' > "${f}" ;;
	*) : > "${f}" ;;
    esac
    drsm_links_json "${f}"
    rm -f "${f}"
}

function sample_site_files() {
    # site.json for each sample site, and the group reports as
    # drsm_run.sh writes them
    local info site oname sname loc mon mins st t g hosts sep
    for info in "${SITEINFO[@]}"; do
	IFS="|" read -r site oname sname loc mon mins <<< "${info}"
	SR="${R}/orgs/${site}"
	hosts=""
	sep=""
	for d in "${SR}"/systems/*/; do
	    read -r st t g <<< "$(drsm_host_state "${d%/}" 0)"
	    hosts+="${sep}{\"host\":\"$(basename "${d}")\",\"group\":\"${g}\",\"state\":\"${st}\",\"time\":${t}}"
	    sep=","
	done
	printf '{"org":"%s","site":"%s","name":"%s","location":"%s","org_name":"%s","org_contact":"","collector":"%s","time":%s,"stale_minutes":30,"counts":{},"links":%s,"org_links":%s,"hosts":[%s]}\n' \
	    "${site%%/*}" "${site#*/}" "${sname}" "${loc}" "${oname}" "${mon}" "$((NOW - mins * 60 - 60))" \
	    "$(demo_links "${site}")" "$(demo_links "${site%%/*}")" "${hosts}" > "${SR}/site.json"
	group_reports
    done
}

function group_reports() {
    # Group reports from the host reports of the site in ${SR}
    local g hp cp_ f
    for g in production dev qa; do
	if ! grep -qs "^GROUP:${g}\$" "${SR}"/systems/*/*_report.txt; then continue; fi
	if [ "${g}" == "production" ]; then hp="system_health_report"; cp_="system_check_report"; else hp="system_health_report_${g}"; cp_="system_check_${g}_report"; fi
	{
	    echo "DRSM health check report, $(date -u)"
	    echo "Our report type is set to: ${g^^}"
	    for f in "${SR}"/systems/*/*_report.txt; do
		if grep -q "^GROUP:${g}\$" "${f}"; then cat "${f}"; fi
	    done
	} > "${SR}/${hp}.txt"
	grep "ERROR - \|WARNING - " "${SR}/${hp}.txt" > "${SR}/${hp}_errors.txt"
	{
	    echo "DRSM status report, $(date -u)"
	    echo "Our report type is set to: ${g^^}"
	    for f in "${SR}"/systems/*/*_report.txt; do
		if ! grep -q "^GROUP:${g}\$" "${f}"; then continue; fi
		awk '/^=== network\// { p = 1 } /^=== / && !/^=== network\/(ping|https)/ { p = 0 } p' "${f}"
	    done
	} > "${SR}/${cp_}.txt"
	mkdir -p "${SR}/archive"
	cp "${SR}/${hp}.txt" "${SR}/archive/${hp}_$(date -u +%Y%m%d_%H%M%S).txt"
	cp "${SR}/${cp_}.txt" "${SR}/archive/${cp_}_$(date -u +%Y%m%d_%H%M%S).txt"
    done
}

if [ "${sample}" == "1" ]; then
    # shellcheck source=lib/drsm_sites.sh
    source "${TOPdir}/lib/drsm_sites.sh"
    SITEINFO=()
    rmdir "${R}/systems" "${R}/archive" 2> /dev/null
    # Two made up organizations with two sites each. The annex monitor
    # host stopped reporting two hours ago.
    sample_site northwind/hq "Northwind Traders" "Head office" "Chicago, IL" mon1 1
    #          host     description                  impact                     group       cpu mem disk load cpus swap web extra
    host_report www1    "Public web server 1"        "Website is degraded"      production  34  58  61  120  4   3  yes none
    host_report www2    "Public web server 2"        "Website is degraded"      production  88  71  64  410  4   9  yes none
    host_report www     "Website cluster address"    "Website is down"          production  21  44  52   60  4   0  yes https
    host_report db1     "MySQL primary database"     "All applications down"    production  46  92  78  280  8  22  no  none
    host_report db2     "MySQL replica"              "Reporting is delayed"     production  12  63  80   90  8   4  no  none
    host_report app1    "Order API node 1"           "Orders are delayed"       production  27  49  44  110  4   0  no  none
    host_report app2    "Order API node 2"           "Orders are delayed"       production  31  52  45  130  4   0  no  nicerr
    host_report cache1  "Redis cache"                "Pages load slowly"        production   6  81  33   20  2   0  no  none
    sample_history www1 34 58 61 4 no
    sample_history www2 70 71 64 4 yes
    sample_history db1 46 88 78 8 no
    sample_history db2 12 63 80 8 no
    sample_history app1 27 49 44 4 no
    sample_history cache1 6 81 33 2 no

    sample_site northwind/warehouse "Northwind Traders" "Warehouse" "Joliet, IL" mon2 2
    host_report mail1   "Mail relay"                 "Email is not delivered"   production   4  37  97   15  2   1  no  none
    host_report files1  "File and backup server"     "Backups stop"             production   9  41  86   40  4   2  no  none
    host_report vpn1    "Site to site VPN gateway"   "Branch offices offline"   production   2  18  29    5  2   0  no  down
    host_report mon2    "DRSM monitor host"          "Monitoring stops"         production   7  33  41   30  2   0  no  none
    sample_history files1 9 41 86 4 no

    sample_site blueridge/main "Blue Ridge Clinics" "Main clinic" "Asheville, NC" mon3 1
    host_report ehr1    "Patient records server"     "Charts unavailable"       production  38  67  72  160  8   5  yes none
    host_report pacs1   "Imaging archive"            "Scans unavailable"        production  22  54  88   70  8   2  no  none
    host_report build1  "CI build server"            "Builds stop"              dev         73  66  58  350  8  12  no  user
    host_report dev1    "Development web server"     "Developers blocked"       dev         15  40  49   45  4   0  yes none
    host_report test1   "QA test server"             "Testing is blocked"       qa          11  35  38   25  4   0  no  none
    sample_history ehr1 38 67 72 8 no
    sample_history build1 60 66 58 8 no

    sample_site blueridge/annex "Blue Ridge Clinics" "North annex" "Weaverville, NC" mon4 120
    host_report fw1     "Firewall"                   "Annex offline"            production   3  22  19   10  2   0  no  none
    host_report nas1    "Annex file share"           "Shared files unavailable" production   5  31  57   20  2   0  no  none
    SITEAGE=0

    sample_site_files

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
