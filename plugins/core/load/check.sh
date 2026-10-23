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
# DRSM plugin: load average, ported from bin/load_checks.sh
#
# ----------------------------------------------------------- 
# shellcheck source=lib/drsm_plugin.sh
source "${DRSM_LIB:-$(dirname "$0")/../../../lib}/drsm_plugin.sh"

NUMCPUS=$(nproc 2> /dev/null || grep -c '^processor' /proc/cpuinfo)
THRESHOLD=$(drsm_setting WARN "")
MAX=$(drsm_setting CRIT "")
if [ "${THRESHOLD}" == "" ]; then THRESHOLD=$((NUMCPUS * 2)); fi
if [ "${MAX}" == "" ]; then MAX=$((NUMCPUS * 4)); fi

# 1, 5, and 15 minute load averages
read -r LA1M LA5M LA15M _ < /proc/loadavg

if drsm_gt "${LA15M}" "${MAX}"
then
    drsm_crit "${HOST} 15 minute load average ${LA15M} is above ${MAX}"
elif drsm_gt "${LA15M}" "${THRESHOLD}"
then
    drsm_warn "${HOST} 15 minute load average ${LA15M} is above ${THRESHOLD}"
fi

echo "Load averages for ${HOST}"
echo "Number of CPUs: ${NUMCPUS}"
echo "1 minute load:  ${LA1M}"
echo "5 minute load:  ${LA5M}"
echo "15 minute load: ${LA15M}"
drsm_metric load_15m "${LA15M}"

drsm_exit
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
