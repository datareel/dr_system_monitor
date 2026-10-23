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
# DRSM plugin: logged in users, ported from bin/user_checks.sh
#
# ----------------------------------------------------------- 
# shellcheck source=lib/drsm_plugin.sh
source "${DRSM_LIB:-$(dirname "$0")/../../../lib}/drsm_plugin.sh"

BLACKLIST=$(drsm_setting ERROR_USERS "")
WARNLIST=$(drsm_setting WARN_USERS "")
if drsm_is_none "${BLACKLIST}"; then BLACKLIST=""; fi
if drsm_is_none "${WARNLIST}"; then WARNLIST=""; fi

# Unique list of logged in user names
LOGGEDIN=$(who 2> /dev/null | awk '{ print $1 }' | sort -u)

for u in ${BLACKLIST}
do
    if echo "${LOGGEDIN}" | grep -qx "${u}"; then
	drsm_crit "${HOST} black listed user ${u} logged in"
    fi
done

for u in ${WARNLIST}
do
    if echo "${LOGGEDIN}" | grep -qx "${u}"; then
	drsm_warn "${HOST} user ${u} logged in"
    fi
done

echo "User information for ${HOST}"
NUM=$(who 2> /dev/null | wc -l)
echo "Number of user sessions logged in: ${NUM}"
w -h 2> /dev/null
drsm_metric user_sessions "${NUM}"

drsm_exit
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
