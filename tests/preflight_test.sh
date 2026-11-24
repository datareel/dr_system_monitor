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
# Tests for utils/drsm_preflight.sh: it must write nothing, print no
# host names, and exit 0 (no FAIL), 1 (FAIL) or 2 (bad usage).
#
# Usage: tests/preflight_test.sh
#
# ----------------------------------------------------------- 
TOPdir=$(cd "$(dirname "$0")/.." && pwd)
P="${TOPdir}/utils/drsm_preflight.sh"
failures=0

function pass() { echo "PASS - $*"; }
function fail() { echo "FAIL - $*"; failures=$((failures + 1)); }

T=$(mktemp -d)
trap 'rm -rf "${T}"' EXIT
mkdir -p "${T}/drsm/bin" "${T}/drsm/lib" "${T}/drsm/collectors" "${T}/drsm/plugins/local" "${T}/drsm/utils" \
    "${T}/drsm/etc/hosts" "${T}/www/reports/systems" "${T}/www/config" "${T}/www/php"
cp "${TOPdir}/version.txt" "${T}/drsm/version.txt"
printf '#!/bin/bash\n' > "${T}/drsm/bin/drsm_run.sh"
chmod 755 "${T}/drsm/bin/drsm_run.sh"
echo 'COLLECTOR=ssh' > "${T}/drsm/etc/hosts/_defaults.conf"
printf 'HOST=secrethost1\nCOLLECTOR=ssh\n' > "${T}/drsm/etc/hosts/secrethost1.conf"
printf 'HOST=secrethost2\nCOLLECTOR=wra\nENABLED=no\n' > "${T}/drsm/etc/hosts/secrethost2.conf"
cat > "${T}/drsm.sh" <<CFG
export WWWdir=${T}/www
export REPORTdir=\${WWWdir}/reports
export CONFIGdir=\${WWWdir}/config
export SYSADMIN_USERNAME=$(whoami)
export DRSMHOME=${T}/drsm
export TEMPdir=${T}/tmp_made_by_config
export LOGdir=\${TEMPdir}/logs
if [ ! -d \${TEMPdir} ]; then mkdir -p \${TEMPdir}; fi
CFG

before=$(find "${T}" -printf '%p %s %T@\n' | sort)
out=$(DRSM_CONFIG="${T}/drsm.sh" bash "${P}" 2>&1)
rc=$?
after=$(find "${T}" -printf '%p %s %T@\n' | sort)

if [ "${before}" == "${after}" ]; then pass "writes nothing"; else fail "changed files under the test tree"; fi
if [ ! -d "${T}/tmp_made_by_config" ]; then pass "config mkdir not run"; else fail "config mkdir ran"; fi
if [ "${rc}" == "0" ]; then pass "exit 0 with no FAIL"; else fail "exit ${rc}: ${out}"; fi
if echo "${out}" | grep -q 'secrethost'; then fail "prints host names"; else pass "no host names in the output"; fi
if echo "${out}" | grep -q 'host files: 2 (1 disabled)'; then pass "counts host files"; else fail "host file count: ${out}"; fi
if echo "${out}" | grep -q '^Summary: 0 FAIL'; then pass "summary line"; else fail "no summary line"; fi

out=$(DRSM_CONFIG="${T}/drsm.sh" bash "${P}" --source="${T}/nothere" 2>&1)
rc=$?
if [ "${rc}" == "1" ] && echo "${out}" | grep -q 'is not a DRSM source folder'; then pass "bad --source fails"; else fail "bad --source: exit ${rc}"; fi

out=$(DRSM_CONFIG="${T}/drsm.sh" bash "${P}" --source="${TOPdir}" 2>&1)
rc=$?
if [ "${rc}" == "0" ] && echo "${out}" | grep -q 'kept by install.sh'; then pass "--source compare"; else fail "--source compare: exit ${rc}"; fi
after2=$(find "${T}" -printf '%p %s %T@\n' | sort)
if [ "${before}" == "${after2}" ]; then pass "--source writes nothing"; else fail "--source changed files"; fi

bash "${P}" --bogus > /dev/null 2>&1
rc=$?
if [ "${rc}" == "2" ]; then pass "bad option exits 2"; else fail "bad option exit ${rc}"; fi

out=$(DRSM_CONFIG="${T}/missing.sh" bash "${P}" 2>&1)
rc=$?
if [ "${rc}" == "1" ]; then pass "missing config fails"; else fail "missing config exit ${rc}"; fi

# Push hours are checked, the keys are not printed
cp "${TOPdir}/lib/drsm_conf.sh" "${TOPdir}/lib/drsm_notify.sh" "${T}/drsm/lib/"
printf 'PUSH_PROVIDERS="pushover"\nPUSHOVER_TOKEN="pftokensecret"\nPUSH_DEV_HOURS="Mon-Fri 08:00-17:00" # office\nPUSH_QA_HOURS=Mon-Fri 8-5\n' > "${T}/drsm/etc/alert.push.conf"
chmod 600 "${T}/drsm/etc/alert.push.conf"
out=$(DRSM_CONFIG="${T}/drsm.sh" bash "${P}" 2>&1)
if echo "${out}" | grep -q 'PUSH_DEV_HOURS: Mon-Fri 08:00-17:00$'; then pass "good push hours"; else fail "good push hours: ${out}"; fi
if echo "${out}" | grep -q 'PUSH_QA_HOURS="Mon-Fri 8-5" is not valid'; then pass "bad push hours warn"; else fail "bad push hours: ${out}"; fi
if ! echo "${out}" | grep -q 'pftokensecret'; then pass "push token not printed"; else fail "push token printed"; fi

if [ "${failures}" -gt 0 ]; then echo "${failures} test(s) failed"; exit 1; fi
echo "All pre-flight tests passed"
exit 0
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# *******************************
