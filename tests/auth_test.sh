#!/bin/bash
# -----------------------------------------------------------
# BASH Script
# Operating System(s): RHEL/CENTOS
# Run Level(s): 3, 5
# Shell: BASH shell
# Original Author(s): DataReel Software Development
# File Creation Date: 10/24/2026
# Date Last Modified: 10/24/2026
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
# Tests for the dashboard login in www/php/drsm_auth.php. Checks the
# network matching functions, then builds a Web only package with
# login on, serves it with the PHP built in server, and logs in and
# out with curl.
#
# Usage: tests/auth_test.sh
#
# -----------------------------------------------------------
TOPdir=$(cd "$(dirname "$0")/.." && pwd)
T=$(mktemp -d)
SERVERpid=""
trap '[ -n "${SERVERpid}" ] && kill ${SERVERpid} 2> /dev/null; rm -rf "${T}"' EXIT
failures=0

function pass() { echo "PASS - $*"; }
function fail() { echo "FAIL - $*"; failures=$((failures + 1)); }

if ! command -v php > /dev/null 2>&1; then echo "SKIP - php is not installed"; exit 0; fi

echo "== Network matching"
cat > "${T}/unit.php" <<'PHPUNIT'
<?php
error_reporting(-1);
$CONFIGdir = sys_get_temp_dir();
$WWWvpath = "/drsm/dashboard";
function drsm_url($page, $args = array()) { global $WWWvpath; return "{$WWWvpath}/php/{$page}" . (count($args) ? "?" . http_build_query($args) : ""); }
require $argv[1];
$fails = 0;
function t($name, $got, $want) {
  global $fails;
  if($got === $want) { echo "PASS - {$name}\n"; }
  else { echo "FAIL - {$name}: got " . var_export($got, true) . "\n"; $fails++; }
}
t("ipv4 in /8", drsm_ip_in_cidr("10.1.2.3", "10.0.0.0/8"), true);
t("ipv4 outside /12", drsm_ip_in_cidr("172.32.0.1", "172.16.0.0/12"), false);
t("ipv4 edge of /12", drsm_ip_in_cidr("172.31.255.255", "172.16.0.0/12"), true);
t("ipv4 /0", drsm_ip_in_cidr("8.8.8.8", "0.0.0.0/0"), true);
t("single address", drsm_ip_in_cidr("203.0.113.7", "203.0.113.7"), true);
t("single address other", drsm_ip_in_cidr("203.0.113.8", "203.0.113.7"), false);
t("ipv6 in /32", drsm_ip_in_cidr("2001:db8::1", "2001:db8::/32"), true);
t("ipv6 outside", drsm_ip_in_cidr("2001:db9::1", "2001:db8::/32"), false);
t("ipv4 mapped ipv6", drsm_ip_in_cidr("::ffff:192.168.1.5", "192.168.0.0/16"), true);
t("ipv4 vs ipv6 net", drsm_ip_in_cidr("10.0.0.1", "::/0"), false);
t("bad bits", drsm_ip_in_cidr("10.0.0.1", "10.0.0.0/33"), false);
t("bad address", drsm_ip_in_cidr("10.0.0.300", "10.0.0.0/8"), false);
t("junk bits", drsm_ip_in_cidr("10.0.0.1", "10.0.0.0/8x"), false);

$AUTHproxies = array();
t("no proxies ignores XFF", drsm_client_ip(array("REMOTE_ADDR" => "8.8.8.8", "HTTP_X_FORWARDED_FOR" => "10.0.0.1")), "8.8.8.8");
$AUTHproxies = array("192.0.2.0/24");
t("XFF from untrusted ignored", drsm_client_ip(array("REMOTE_ADDR" => "8.8.8.8", "HTTP_X_FORWARDED_FOR" => "10.0.0.1")), "8.8.8.8");
t("XFF from proxy", drsm_client_ip(array("REMOTE_ADDR" => "192.0.2.10", "HTTP_X_FORWARDED_FOR" => "198.51.100.4")), "198.51.100.4");
t("XFF spoofed left part ignored", drsm_client_ip(array("REMOTE_ADDR" => "192.0.2.10", "HTTP_X_FORWARDED_FOR" => "10.0.0.1, 198.51.100.4")), "198.51.100.4");
t("XFF proxy chain", drsm_client_ip(array("REMOTE_ADDR" => "192.0.2.10", "HTTP_X_FORWARDED_FOR" => "198.51.100.4, 192.0.2.11")), "198.51.100.4");
t("XFF junk stops", drsm_client_ip(array("REMOTE_ADDR" => "192.0.2.10", "HTTP_X_FORWARDED_FOR" => "10.0.0.1, junk")), "192.0.2.10");
t("bad REMOTE_ADDR", drsm_client_ip(array("REMOTE_ADDR" => "x")), "");

t("next keeps own page", drsm_auth_safe_next("/drsm/dashboard/php/heatmap.php?mode=metrics"), "/drsm/dashboard/php/heatmap.php?mode=metrics");
t("next refuses other host", drsm_auth_safe_next("//evil.example/x"), "/drsm/dashboard/php/index.php");
t("next refuses scheme", drsm_auth_safe_next("https://evil.example/drsm/dashboard/"), "/drsm/dashboard/php/index.php");
t("next refuses backslash", drsm_auth_safe_next("/\\evil.example"), "/drsm/dashboard/php/index.php");
t("next refuses other path", drsm_auth_safe_next("/other/app"), "/drsm/dashboard/php/index.php");
exit($fails ? 1 : 0);
PHPUNIT
php "${T}/unit.php" "${TOPdir}/www/php/drsm_auth.php" > "${T}/unit.out" 2>&1
cat "${T}/unit.out"
failures=$((failures + $(grep -c "^FAIL" "${T}/unit.out")))
if ! grep -q "^PASS" "${T}/unit.out"; then fail "network matching tests did not run"; fi

echo "== Login over HTTP"
bash "${TOPdir}/utils/make_web_demo.sh" -s -a -p /dashboard -o "${T}/site" > "${T}/demo.log" 2>&1
C="${T}/site/dashboard/config/drsm.php"
if grep -q '^\$AUTHenable = 1;' "${C}"; then pass "-a turns login on"; else fail "-a did not turn login on"; fi
if grep -q "Require all denied" "${T}/site/dashboard/reports/.htaccess"; then pass "-a blocks the report folder"; else fail "-a left the report folder open"; fi

HASH=$(printf 'correct horse battery\n' | php "${TOPdir}/utils/drsm_password.php" admin 2> /dev/null)
if [[ "${HASH}" == *"'admin' => '\$2y\$"* ]]; then pass "password helper prints a bcrypt line"; else fail "password helper output: ${HASH}"; fi
if printf 'short\n' | php "${TOPdir}/utils/drsm_password.php" admin > /dev/null 2>&1; then fail "short password accepted"; else pass "short password refused"; fi

# 127.0.0.1 is outside the internal network here, so the server's own
# requests need a login
function config() {
    # $1 == internal networks, $2 == proxies
    sed -i '/^?>$/d; /^\$AUTHnetworks/d; /^\$AUTHproxies/d; /^\$AUTHhttps/d; /^\$AUTHstatedir/d; /^\$AUTHsessiondir/d; /^\$AUTHmaxfails/d; /^\$AUTHscopes/d; /^\$AUTHusers\[/d' "${C}"
    sed -i "s|^\$AUTHusers = array($|\$AUTHusers = array(\n${HASH}|" "${C}"
    {
	echo "\$AUTHnetworks = array($1);"
	echo "\$AUTHproxies = array($2);"
	echo "\$AUTHhttps = 0;"
	echo "\$AUTHmaxfails = 3;"
	echo "\$AUTHstatedir = '${T}/state';"
	echo "\$AUTHsessiondir = '${T}/sessions';"
	echo "?>"
    } >> "${C}"
    HASH=""
}
mkdir -p "${T}/sessions"
config "'10.9.9.0/24'" ""
if ! php -l "${C}" > /dev/null; then fail "test config has errors"; cat "${C}"; fi

PORT=$((20000 + RANDOM % 20000))
# No opcache, the tests change the config between requests
php -d opcache.enable=0 -d opcache.enable_cli=0 -S "127.0.0.1:${PORT}" -t "${T}/site" > "${T}/server.log" 2>&1 &
SERVERpid=$!
B="http://127.0.0.1:${PORT}/dashboard/php"
for _ in $(seq 1 50); do curl -s -o /dev/null "${B}/login.php" && break; sleep 0.1; done

J="${T}/cookies"
function get() {
    # $1 == URL, rest == curl options, sets CODE and LOCATION
    local url="$1"
    shift
    CODE=$(curl -s -b "${J}" -c "${J}" -o "${T}/body" -D "${T}/head" -w '%{http_code}' "$@" "${url}")
    LOCATION=$(grep -i '^location:' "${T}/head" | tr -d '\r' | cut -d' ' -f2-)
}
function csrf() {
    sed -n 's/.*name="csrf" value="\([0-9a-f]*\)".*/\1/p' "${T}/body" | head -1
}
function expect() {
    if grep -qF -- "$2" "${T}/body"; then pass "$1"; else fail "$1: '$2' not in page"; fi
}

get "${B}/heatmap.php?mode=metrics"
if grep -qi '^set-cookie' "${T}/head"; then fail "session started before the login page"; else pass "no session until the login page"; fi
if [ "${CODE}" == "302" ] && [[ "${LOCATION}" == "/dashboard/php/login.php?next="*heatmap.php* ]]; then pass "outside request sent to login"; else fail "outside request: ${CODE} ${LOCATION}"; fi
if grep -q "mail1" "${T}/body"; then fail "dashboard shown before login"; else pass "no dashboard data before login"; fi

get "${B}/login.php?next=%2Fdashboard%2Fphp%2Fheatmap.php%3Fmode%3Dmetrics"
expect "login page" "Sign in"
expect "login page in dashboard style" "/dashboard/css/drsm.css"
if grep -qi '^x-frame-options: DENY' "${T}/head"; then pass "login page can not be framed"; else fail "login page missing X-Frame-Options"; fi
if grep -i '^set-cookie: DRSMSESSID' "${T}/head" | grep -qi 'httponly' && grep -i '^set-cookie: DRSMSESSID' "${T}/head" | grep -qi 'samesite=lax'; then
    pass "session cookie is HttpOnly and SameSite"
else
    fail "session cookie flags: $(grep -i '^set-cookie' "${T}/head")"
fi
TOKEN=$(csrf)
if [ ${#TOKEN} -eq 64 ]; then pass "login form has a CSRF token"; else fail "no CSRF token"; fi

get "${B}/login.php" --data-urlencode "action=login" --data-urlencode "user=admin" --data-urlencode "password=correct horse battery" --data-urlencode "csrf=bad"
expect "login without the CSRF token refused" "login form expired"

get "${B}/login.php" --data-urlencode "action=login" --data-urlencode "user=admin" --data-urlencode "password=wrong" --data-urlencode "csrf=${TOKEN}"
expect "wrong password refused" "Wrong user name or password"
get "${B}/login.php" --data-urlencode "action=login" --data-urlencode "user=nobody" --data-urlencode "password=wrong" --data-urlencode "csrf=${TOKEN}"
expect "unknown user gets the same message" "Wrong user name or password"

SID1=$(grep DRSMSESSID "${J}" | awk '{print $7}')
get "${B}/login.php" --data-urlencode "action=login" --data-urlencode "user=admin" --data-urlencode "password=correct horse battery" --data-urlencode "csrf=${TOKEN}" --data-urlencode "next=/dashboard/php/heatmap.php?mode=metrics"
if [ "${CODE}" == "303" ] && [ "${LOCATION}" == "/dashboard/php/heatmap.php?mode=metrics" ]; then pass "login goes back to the page asked for"; else fail "login: ${CODE} ${LOCATION}"; fi
SID2=$(grep DRSMSESSID "${J}" | awk '{print $7}')
if [ -n "${SID2}" ] && [ "${SID1}" != "${SID2}" ]; then pass "new session id at login"; else fail "session id not changed at login"; fi

get "${B}/heatmap.php?mode=metrics"
if [ "${CODE}" == "200" ]; then pass "signed in page loads"; else fail "signed in page: ${CODE}"; fi
expect "signed in page shows data" "Memory used"
expect "sign out button" 'name="action" value="logout"'
TOKEN=$(csrf)

get "${B}/readreport.php?n=db1"
expect "archive button goes through PHP" 'href="/dashboard/php/archive.php?h=db1&amp;site=northwind%2Fhq"'
get "${B}/archive.php?h=db1&site=northwind/hq"
expect "host archive listed" "db1_report_"
FILE=$(grep -o 'archive.php?h=db1&amp;f=[A-Za-z0-9._-]*&amp;site=northwind%2Fhq' "${T}/body" | head -1 | sed 's/&amp;/\&/g')
get "${B}/${FILE}"
expect "archived report shown" "Start of db1 system health check report"
get "${B}/archive.php?h=db1&site=northwind/hq&f=..%2F..%2F..%2Fconfig%2Fdrsm.php"
reject_out=$(grep -c "AUTHusers" "${T}/body")
if [ "${reject_out}" == "0" ]; then pass "archive path traversal refused"; else fail "archive served the config"; fi
get "${B}/checks.php"
expect "group archive goes through PHP" 'href="/dashboard/php/archive.php?p=system_check_report_&amp;site='

get "${B}/login.php" --data-urlencode "action=logout" --data-urlencode "csrf=bad"
get "${B}/index.php"
if [ "${CODE}" == "200" ]; then pass "sign out without the CSRF token ignored"; else fail "sign out without a token worked: ${CODE}"; fi

get "${B}/login.php" --data-urlencode "action=logout" --data-urlencode "csrf=${TOKEN}"
expect "signed out" "You are signed out"
get "${B}/index.php"
if [ "${CODE}" == "302" ]; then pass "signed out user sent to login"; else fail "after sign out: ${CODE}"; fi

get "${B}/login.php?next=//evil.example/"
TOKEN=$(csrf)
get "${B}/login.php" --data-urlencode "action=login" --data-urlencode "user=admin" --data-urlencode "password=correct horse battery" --data-urlencode "csrf=${TOKEN}" --data-urlencode "next=//evil.example/"
if [ "${LOCATION}" == "/dashboard/php/index.php" ]; then pass "no redirect to another site"; else fail "login redirected to ${LOCATION}"; fi

echo "== Failed login limit"
rm -f "${J}"
get "${B}/login.php"
TOKEN=$(csrf)
for _ in 1 2 3; do
    get "${B}/login.php" --data-urlencode "action=login" --data-urlencode "user=admin" --data-urlencode "password=wrong" --data-urlencode "csrf=${TOKEN}"
done
get "${B}/login.php" --data-urlencode "action=login" --data-urlencode "user=admin" --data-urlencode "password=correct horse battery" --data-urlencode "csrf=${TOKEN}"
expect "locked after too many failures, even with the right password" "Too many failed logins"
if ls "${T}/state"/fail_*.json > /dev/null 2>&1; then pass "failures stored in the state folder"; else fail "no failure files"; fi
rm -f "${T}/state"/fail_*.json

echo "== Internal networks and proxies"
rm -f "${J}"
config "'127.0.0.0/8'" ""
get "${B}/index.php"
if [ "${CODE}" == "200" ] && grep -q "mail1" "${T}/body"; then pass "internal address gets straight in"; else fail "internal address: ${CODE}"; fi
if grep -q 'value="logout"' "${T}/body"; then fail "sign out shown on the internal network"; else pass "no sign out on the internal network"; fi
get "${B}/login.php"
if [ "${CODE}" == "303" ]; then pass "login page skipped on the internal network"; else fail "internal login page: ${CODE}"; fi

config "'10.9.9.0/24'" ""
get "${B}/index.php" -H "X-Forwarded-For: 10.9.9.5"
if [ "${CODE}" == "302" ]; then pass "forged X-Forwarded-For ignored with no proxies"; else fail "forged X-Forwarded-For let in: ${CODE}"; fi

config "'10.9.9.0/24'" "'127.0.0.1/32'"
get "${B}/index.php" -H "X-Forwarded-For: 10.9.9.5"
if [ "${CODE}" == "200" ]; then pass "X-Forwarded-For used from a listed proxy"; else fail "listed proxy: ${CODE}"; fi
get "${B}/index.php" -H "X-Forwarded-For: 10.9.9.5, 198.51.100.4"
if [ "${CODE}" == "302" ]; then pass "forged address left of the client ignored"; else fail "forged chain let in: ${CODE}"; fi

echo "== Organizations and sites"
# Two sites next to the demo hosts, which are in the default site
R="${T}/site/dashboard/reports"
now=$(date +%s)
function site_fixture() {
    # $1 == org/site, $2 == host, $3 == word only that site's files have
    local d="${R}/orgs/${1}"
    mkdir -p "${d}/systems/${2}/archive" "${d}/archive"
    printf '{"org":"%s","name":"%s"}\n' "${1%%/*}" "${1%%/*} name" > "${R}/orgs/${1%%/*}/org.json"
    printf '{"org":"%s","site":"%s","name":"%s site","location":"","collector":"mon","time":%s,"stale_minutes":60,"counts":{},"hosts":[]}\n' "${1%%/*}" "${1#*/}" "${3}" "${now}" > "${d}/site.json"
    printf 'ETIME:%s\nHOSTNAME:%s\nDESCRIPTION:%s host\nSITE:%s\n' "${now}" "${2}" "${3}" "${1}" > "${d}/systems/${2}/${2}_report.txt"
    cp "${d}/systems/${2}/${2}_report.txt" "${d}/systems/${2}/archive/${2}_report_20260101_000000.txt"
    printf 'INFO - %s connectivity\n' "${3}" > "${d}/system_check_report.txt"
    printf 'INFO - %s archive\n' "${3}" > "${d}/archive/system_check_report_${3}.txt"
    printf '%s\tcpu_used_pct=5\n' "${now}" > "${d}/systems/${2}/metrics_history.tsv"
}
site_fixture acme/hq hq1 HQSECRET
site_fixture beta/lab lab1 LABSECRET
TECH=$(printf 'tech password here\n' | php "${TOPdir}/utils/drsm_password.php" tech 2> /dev/null)
function scopes() {
    # $1 == PHP lines for the site limits
    sed -i '/^?>$/d; /^\$AUTHscopes/d; /^\$AUTHnetworkscopes/d; /^\$AUTHusers\[/d' "${C}"
    {
	echo "\$AUTHusers['tech'] = '$(echo "${TECH}" | sed "s/.*=> '\(.*\)',*/\1/")';"
	echo "${1}"
	echo "?>"
    } >> "${C}"
    if ! php -l "${C}" > /dev/null; then fail "site limit config has errors"; cat "${C}"; fi
}
function login() {
    # $1 == user, $2 == password
    rm -f "${J}"
    get "${B}/login.php"
    TOKEN=$(csrf)
    get "${B}/login.php" --data-urlencode "action=login" --data-urlencode "user=${1}" --data-urlencode "password=${2}" --data-urlencode "csrf=${TOKEN}"
}
function reject() {
    if grep -qF -- "$2" "${T}/body"; then fail "$1: '$2' in page"; else pass "$1"; fi
}

config "'10.9.9.0/24'" ""
scopes "\$AUTHscopes = array('admin' => array('*'), 'tech' => array('acme/hq'));"
login admin "correct horse battery"
get "${B}/orgs.php"
expect "'*' sees every site" "LABSECRET site"
expect "'*' sees the demo sites" "Northwind Traders"

login tech "tech password here"
if [ "${CODE}" == "303" ]; then pass "limited user signs in"; else fail "limited user login: ${CODE}"; fi
get "${B}/index.php"
expect "limited user sees their site" "HQSECRET host"
reject "limited user does not see other sites" "LABSECRET"
reject "limited user does not see the demo sites" "mail1"
reject "one visible site, no Organizations page" "orgs.php"
get "${B}/orgs.php"
reject "Organizations page shows only their site" "LABSECRET"
get "${B}/readreport.php?n=lab1&site=beta/lab"
if [ "${CODE}" == "404" ]; then pass "other site's host report refused"; else fail "other site's host report: ${CODE}"; fi
reject "other site's host report has no data" "LABSECRET"
get "${B}/readreport.php?n=beta/lab/lab1"
reject "other site's host by org/site/host refused" "LABSECRET"
get "${B}/readreport.php?n=mail1"
if [ "${CODE}" == "404" ]; then pass "demo site host refused"; else fail "demo site host: ${CODE}"; fi
get "${B}/readreport.php?n=hq1"
expect "own host by plain name" "HQSECRET host"
get "${B}/host_status.php?n=lab1&site=beta/lab"
if [ "${CODE}" == "404" ]; then pass "other site's host status refused"; else fail "other site's host status: ${CODE}"; fi
get "${B}/archive.php?h=lab1&site=beta/lab"
reject "other site's host archive refused" "lab1_report_"
get "${B}/archive.php?site=beta/lab"
reject "other site's group archive refused" "LABSECRET"
get "${B}/archive.php?site=acme/hq"
expect "own group archive" "system_check_report_HQSECRET.txt"
get "${B}/archive.php?site=beta/lab&f=system_check_report_LABSECRET.txt"
reject "other site's archived file refused" "LABSECRET archive"
get "${B}/checks.php?site=beta/lab"
reject "other site's connectivity report refused" "LABSECRET"
get "${B}/trends.php?h=lab1&site=beta/lab"
reject "other site's trends refused" "lab1"
get "${B}/heatmap.php?site=beta"
reject "other org as scope refused" "LABSECRET"
get "${B}/reports.php"
expect "host list shows own site" "hq1"
reject "host list hides other sites" "lab1"

scopes "\$AUTHscopes = array('tech' => array('acme'));"
login admin "correct horse battery"
get "${B}/index.php"
reject "user missing from \$AUTHscopes sees no hosts" "mail1"
reject "user missing from \$AUTHscopes sees no sites" "HQSECRET"
login tech "tech password here"
get "${B}/index.php"
expect "org scope covers its sites" "HQSECRET host"

rm -f "${J}"
config "'127.0.0.0/8'" ""
scopes "\$AUTHnetworkscopes = array('127.0.0.0/8' => array('beta/lab'));"
get "${B}/index.php"
expect "network scope shows its site" "LABSECRET host"
reject "network scope hides other sites" "HQSECRET"
reject "network scope hides the demo sites" "mail1"
get "${B}/host_status.php?n=lab1"
expect "network scope host status" '"host":"lab1"'
scopes "\$AUTHnetworkscopes = array('10.0.0.0/8' => array('*'));"
get "${B}/index.php"
reject "address in no scoped network sees nothing" "mail1"
scopes ""
get "${B}/orgs.php"
expect "internal network sees every site without limits" "LABSECRET site"

if grep -q "PHP \(Warning\|Notice\|Deprecated\|Fatal\)" "${T}/server.log"; then fail "PHP messages: $(grep "PHP " "${T}/server.log" | head -3)"; else pass "no PHP messages"; fi

echo ""
if [ ${failures} -eq 0 ]; then echo "All tests passed"; exit 0; fi
echo "${failures} test(s) failed"
exit 1
# -----------------------------------------------------------
# *******************************
# ********* End of File *********
# *******************************
