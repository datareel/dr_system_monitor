#!/bin/bash
# -----------------------------------------------------------
# BASH Script
# Operating System(s): RHEL/CENTOS
# Run Level(s): 3, 5
# Shell: BASH shell
# Original Author(s): DataReel Software Development
# File Creation Date: 11/18/2026
# Date Last Modified: 11/18/2026
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
# Read-only check of a DRSM monitor host, for a new install, before
# an upgrade and for support. It reads the DRSM config, the install,
# the dashboard folders, the host files, cron and the report ages, and
# prints OK, INFO, WARN and FAIL lines with a summary at the end.
#
# It changes nothing: no files are written, no host is contacted, no
# alert is sent. It prints counts, not host names, alert addresses or
# login settings, so the output can go into a support summary.
#
# Usage: drsm_preflight.sh [--source=DIR] [-h]
#   --source=DIR  a new DRSM release (unpacked source) to compare with
#                 the install before an upgrade
#
# The config is read like every DRSM script: $DRSM_CONFIG if set, else
# ~/.drsm.sh, else etc/drsm.sh next to this script.
#
# Exit code: 0 no FAIL lines, 1 one or more FAIL lines, 2 bad usage.
#
# -----------------------------------------------------------
SCRIPTbase=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
SOURCEdir=""

function usage() {
    echo "Usage: $(basename "$0") [--source=DIR] [-h]"
    echo "Read-only check of this DRSM install. Changes nothing."
    echo "  --source=DIR  compare the install with a new release before an upgrade"
}

for arg in "$@"; do
    case "${arg}" in
	--source=*) SOURCEdir="${arg#--source=}" ;;
	-h|--help) usage; exit 0 ;;
	*) usage; exit 2 ;;
    esac
done

NWARN=0
NFAIL=0
function ok()   { echo "OK    $*"; }
function info() { echo "INFO  $*"; }
function warn() { echo "WARN  $*"; NWARN=$((NWARN + 1)); }
function fail() { echo "FAIL  $*"; NFAIL=$((NFAIL + 1)); }

echo "DRSM pre-flight check (read-only) $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

# --- Config -------------------------------------------------------
if [ "${DRSM_CONFIG}" != "" ]; then
    CONFIG_FILE="${DRSM_CONFIG}"
elif [ -f "${HOME}/.drsm.sh" ]; then
    CONFIG_FILE="${HOME}/.drsm.sh"
else
    CONFIG_FILE="${SCRIPTbase}/etc/drsm.sh"
fi
if [ ! -f "${CONFIG_FILE}" ]; then
    fail "config file ${CONFIG_FILE} not found"
    echo ""
    echo "Summary: ${NFAIL} FAIL, ${NWARN} WARN"
    exit 1
fi
ok "config file ${CONFIG_FILE}"

# The config makes its temp folders when it is sourced. Read it in a
# subshell where mkdir does nothing, so this check writes nothing.
cfgvars="DRSMHOME WWWdir REPORTdir CONFIGdir LOGdir TEMPdir ALERTdir SYSADMIN_USERNAME SYSADMIN_GROUPNAME HOSTSdir PLUGINSdir"
cfgout=$(
    function mkdir() { return 0; }
    # shellcheck disable=SC1090
    source "${CONFIG_FILE}" > /dev/null 2>&1
    for v in ${cfgvars}; do printf '%s=%s\n' "${v}" "${!v}"; done
)
for v in ${cfgvars}; do
    val=$(echo "${cfgout}" | grep "^${v}=" | head -n 1)
    printf -v "${v}" '%s' "${val#*=}"
done
if [ "${HOSTSdir}" == "" ]; then HOSTSdir="${DRSMHOME}/etc/hosts"; fi
if [ "${PLUGINSdir}" == "" ]; then PLUGINSdir="${DRSMHOME}/plugins"; fi

for v in DRSMHOME WWWdir REPORTdir CONFIGdir SYSADMIN_USERNAME; do
    if [ "${!v}" == "" ]; then fail "${v} is not set in ${CONFIG_FILE}"; fi
done

me=$(whoami)
if [ "${me}" == "${SYSADMIN_USERNAME}" ]; then
    ok "running as the DRSM user ${me}"
else
    warn "running as ${me}, the DRSM user is ${SYSADMIN_USERNAME}: run this check as the DRSM user"
fi

# --- Commands -----------------------------------------------------
echo ""
info "bash ${BASH_VERSION}"
if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then fail "bash 4 or higher is needed"; fi
for c in ssh curl ping crontab; do
    if command -v "${c}" > /dev/null 2>&1; then ok "command ${c}"; else fail "command ${c} not found"; fi
done
if command -v ssh > /dev/null 2>&1; then info "$(ssh -V 2>&1 | head -n 1)"; fi
mailcmd=""
for c in mail mailx s-nail; do
    if command -v "${c}" > /dev/null 2>&1; then mailcmd="${c}"; break; fi
done
if [ "${mailcmd}" != "" ]; then ok "mail command ${mailcmd}"; else warn "no mail command (s-nail, mailx or bsd-mailx): no email alerts"; fi
if command -v php > /dev/null 2>&1; then
    phpver=$(php -r 'echo PHP_VERSION;' 2>/dev/null)
    if php -r 'exit(version_compare(PHP_VERSION, "7.2.0", ">=") ? 0 : 1);' 2>/dev/null; then
	ok "php ${phpver}"
    else
	fail "php ${phpver} is older than 7.2"
    fi
else
    warn "php command not found (the dashboard needs PHP 7.2 or later on the web server)"
fi

# --- Install ------------------------------------------------------
echo ""
if [ -d "${DRSMHOME}" ]; then
    ok "install folder ${DRSMHOME}"
    if [ -f "${DRSMHOME}/version.txt" ]; then
	info "installed DRSM version $(head -n 1 "${DRSMHOME}/version.txt")"
    else
	warn "no ${DRSMHOME}/version.txt (a release older than 1.30, or not installed with utils/install.sh)"
    fi
    for d in bin lib collectors plugins utils; do
	if [ ! -d "${DRSMHOME}/${d}" ]; then warn "${DRSMHOME}/${d} missing"; fi
    done
    if [ -x "${DRSMHOME}/bin/drsm_run.sh" ]; then
	ok "runner ${DRSMHOME}/bin/drsm_run.sh"
    elif [ -f "${DRSMHOME}/bin/system_check.sh" ]; then
	warn "no bin/drsm_run.sh: an old system_check.sh setup (see the upgrade guide)"
    else
	fail "no runner in ${DRSMHOME}/bin"
    fi
else
    info "install folder ${DRSMHOME} not found (expected before a new install)"
fi

# --- Dashboard folders --------------------------------------------
for v in WWWdir REPORTdir CONFIGdir; do
    d="${!v}"
    if [ "${d}" == "" ]; then continue; fi
    if [ ! -d "${d}" ]; then
	warn "${v} ${d} not found"
    elif [ ! -w "${d}" ]; then
	fail "${v} ${d} is not writable by ${me}"
    else
	ok "${v} ${d}"
    fi
done
if [ -f "${CONFIGdir}/drsm.php" ]; then
    ok "dashboard settings ${CONFIGdir}/drsm.php"
    if php -l "${CONFIGdir}/drsm.php" > /dev/null 2>&1 || ! command -v php > /dev/null 2>&1; then
	:
    else
	fail "${CONFIGdir}/drsm.php has a PHP syntax error (php -l)"
    fi
else
    info "no ${CONFIGdir}/drsm.php yet"
fi
if [ -f "${CONFIGdir}/drsm.php_install_new" ]; then
    warn "${CONFIGdir}/drsm.php_install_new exists: compare it with drsm.php for new settings"
fi

# --- Hosts and sites ----------------------------------------------
echo ""
if [ -d "${HOSTSdir}" ]; then
    nhosts=0
    ndisabled=0
    declare -A coll
    for f in "${HOSTSdir}"/*.conf; do
	[ -f "${f}" ] || continue
	if [ "$(basename "${f}")" == "_defaults.conf" ]; then continue; fi
	nhosts=$((nhosts + 1))
	if grep -qiE '^ENABLED="?no' "${f}"; then ndisabled=$((ndisabled + 1)); fi
	c=$(grep -E '^COLLECTOR=' "${f}" | tail -n 1 | sed -E 's/^COLLECTOR="?([^"]*)"?.*/\1/')
	if [ "${c}" == "" ]; then c="default"; fi
	coll[${c}]=$(( ${coll[${c}]:-0} + 1 ))
    done
    info "host files: ${nhosts} (${ndisabled} disabled)"
    for c in "${!coll[@]}"; do info "  collector ${c}: ${coll[${c}]}"; done
    if [ -f "${HOSTSdir}/_defaults.conf" ]; then ok "${HOSTSdir}/_defaults.conf"; else warn "no ${HOSTSdir}/_defaults.conf"; fi
elif [ -f "${CONFIGdir}/systems.dat" ]; then
    warn "no host files, systems.dat is used (utils/migrate_systems_dat.sh converts it)"
else
    info "no host files yet"
fi
if [ -d "${DRSMHOME}/etc/sites" ]; then
    info "organization files: $(find "${DRSMHOME}/etc/sites" -maxdepth 1 -name '*.org' | wc -l), site files: $(find "${DRSMHOME}/etc/sites" -name '*.site' | wc -l)"
fi
if [ -d "${PLUGINSdir}/local" ]; then
    info "site plugins in plugins/local: $(find "${PLUGINSdir}/local" -mindepth 1 -maxdepth 1 -type d | wc -l)"
fi
# Same default as bin/text_email_alert.sh; the addresses are not printed
if [ "${ALERTdir}" == "" ]; then ALERTdir="${DRSMHOME}/etc"; fi
if [ -f "${ALERTdir}/alert.email.list" ]; then
    ok "alert list ${ALERTdir}/alert.email.list"
else
    info "no ${ALERTdir}/alert.email.list yet: the first alert makes one that mails root"
fi
# Push alerts (lib/drsm_notify.sh): the providers are named, the keys
# and URLs are not printed
pconf="${PUSH_CONF:-${ALERTdir}/alert.push.conf}"
if [ -f "${pconf}" ]; then
    pprov=$(grep -E '^[[:space:]]*(export[[:space:]]+)?PUSH_PROVIDERS=' "${pconf}" | tail -n 1 | sed -E 's/^[^=]*=//; s/[" '"'"']//g')
    if [ "${pprov}" != "" ]; then ok "push alerts with ${pprov} (${pconf})"; else info "${pconf} sets no PUSH_PROVIDERS: no push alerts"; fi
    if [ -n "$(find "${pconf}" -maxdepth 0 -perm /077 2> /dev/null)" ]; then
	warn "${pconf} holds API tokens and can be read by other users: chmod 600 it"
    fi
    if [ "${pprov}" != "" ] && [ "${pprov}" != "smsgateway" ] && ! command -v curl > /dev/null 2>&1; then
	warn "push alerts need curl, curl not found"
    fi
else
    info "no ${pconf}: no push alerts (see etc/alert.push.conf_example)"
fi

# --- Cron ---------------------------------------------------------
echo ""
pat='drsm|system_check|system_report'
ncron=$(crontab -l 2>/dev/null | grep -v '^[[:space:]]*#' | grep -cE "${pat}")
if [ "${ncron}" -gt 0 ]; then
    ok "${ncron} DRSM line(s) in the crontab of ${me}:"
    crontab -l 2>/dev/null | grep -v '^[[:space:]]*#' | grep -E "${pat}" | sed 's/^/      /'
fi
# System cron files (root owned /etc/cron.d), read only
ncrond=0
for f in /etc/cron.d/*; do
    [ -f "${f}" ] && [ -r "${f}" ] || continue
    n=$(grep -v '^[[:space:]]*#' "${f}" | grep -cE "${pat}")
    off=$(grep -E '^[[:space:]]*#.*[*0-9].*[[:space:]](\S*drsm\S*|\S*system_(check|report)\S*)' "${f}" | grep -cE "${pat}")
    if [ "${n}" -gt 0 ]; then
	ok "${n} DRSM line(s) in ${f}:"
	grep -v '^[[:space:]]*#' "${f}" | grep -E "${pat}" | sed 's/^/      /'
	ncrond=$((ncrond + n))
    elif [ "${off}" -gt 0 ]; then
	warn "${f} has ${off} DRSM cron line(s), all commented out"
    fi
done
if [ "${ncron}" -eq 0 ] && [ "${ncrond}" -eq 0 ]; then
    warn "no active DRSM cron lines (crontab -l of ${me}, /etc/cron.d): no runs on this host"
fi

# --- Reports ------------------------------------------------------
# Group reports are in REPORTdir and, with organizations and sites, in
# REPORTdir/orgs/<org>/<site>; host reports in .../systems/<host>
if [ -d "${REPORTdir}" ]; then
    newest=$(find "${REPORTdir}" -maxdepth 4 -path '*/archive' -prune -o -name 'system_health_report*.txt' -printf '%T@\n' 2>/dev/null | sort -n | tail -n 1)
    if [ "${newest}" != "" ]; then
	age=$(( ($(date +%s) - ${newest%.*}) / 60 ))
	if [ "${age}" -gt 120 ]; then warn "newest health report in ${REPORTdir} is ${age} minutes old"; else ok "newest health report in ${REPORTdir} is ${age} minutes old"; fi
    else
	info "no health reports in ${REPORTdir} yet"
    fi
    nrep=$(find "${REPORTdir}" -maxdepth 7 -path '*/archive' -prune -o -path '*/systems/*' -name '*_report.txt' -print 2>/dev/null | wc -l)
    nold=$(find "${REPORTdir}" -maxdepth 7 -path '*/archive' -prune -o -path '*/systems/*' -name '*_report.txt' -mmin +120 -print 2>/dev/null | wc -l)
    info "host reports: ${nrep}, older than 120 minutes: ${nold}"
fi
if [ "${LOGdir}" != "" ] && [ -d "${LOGdir}" ]; then
    lastlog=$(find "${LOGdir}" -maxdepth 1 -name 'drsm_run*.log' -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -n 1 | cut -d' ' -f2-)
    if [ "${lastlog}" != "" ]; then
	nerr=$(grep -c -E '^ERROR - ' "${lastlog}")
	info "last run log ${lastlog} (${nerr} ERROR lines)"
    fi
fi

# --- Upgrade compare ----------------------------------------------
if [ "${SOURCEdir}" != "" ]; then
    echo ""
    if [ ! -d "${SOURCEdir}/bin" ] || [ ! -d "${SOURCEdir}/www" ] || [ ! -f "${SOURCEdir}/version.txt" ]; then
	fail "${SOURCEdir} is not a DRSM source folder"
    else
	info "new release ${SOURCEdir} version $(head -n 1 "${SOURCEdir}/version.txt")"
	if [ -d "${DRSMHOME}" ]; then
	    for d in bin lib collectors utils; do
		n=$(diff -rq "${DRSMHOME}/${d}" "${SOURCEdir}/${d}" 2>/dev/null | wc -l)
		info "  ${d}: ${n} file(s) differ"
	    done
	    n=$(diff -rq -x local "${DRSMHOME}/plugins" "${SOURCEdir}/plugins" 2>/dev/null | wc -l)
	    info "  plugins (not plugins/local): ${n} file(s) differ"
	    if [ -d "${WWWdir}/php" ]; then
		n=$(diff -rq "${WWWdir}/php" "${SOURCEdir}/www/php" 2>/dev/null | wc -l)
		info "  dashboard php: ${n} file(s) differ"
	    fi
	    # Edited release files are replaced by install.sh: list them
	    for f in "${DRSMHOME}"/plugins/*/*/plugin.conf; do
		[ -f "${f}" ] || continue
		rel="${f#"${DRSMHOME}"/}"
		case "${rel}" in plugins/local/*) continue ;; esac
		if [ -f "${SOURCEdir}/${rel}" ] && ! cmp -s "${f}" "${SOURCEdir}/${rel}"; then
		    warn "  ${rel} differs from the new release; install.sh replaces it (keep site settings in host files)"
		fi
	    done
	fi
	ok "kept by install.sh: etc/hosts, etc/sites, plugins/local, config/drsm.php, ${WWWdir}/site"
    fi
fi

echo ""
echo "Summary: ${NFAIL} FAIL, ${NWARN} WARN"
if [ "${NFAIL}" -gt 0 ]; then exit 1; fi
exit 0
# -----------------------------------------------------------
# *******************************
# ********* End of File *********
# *******************************
