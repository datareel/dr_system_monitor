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
# DRSM probe: network connectivity, ported from PingCheck in
# bin/system_functions.sh. Runs on the monitor host. A failed ping
# marks the host as down and its remote plugins are skipped.
#
# ----------------------------------------------------------- 
# shellcheck source=lib/drsm_plugin.sh
source "${DRSM_LIB:-$(dirname "$0")/../../../lib}/drsm_plugin.sh"

target=$(drsm_target) || exit 3
COUNT=$(drsm_setting COUNT 3)
DEADLINE=$(drsm_setting DEADLINE 30)

# Up to COUNT tries so a single dropped packet does not raise an alert
if ping -c "${COUNT}" -w "${DEADLINE}" "${target}" &> /dev/null
then
    drsm_ok "Network connectivity test passed on ${target}, ${DRSM_HOST_DESCRIPTION}"
else
    drsm_crit "Network connectivity failed on ${target}, ${DRSM_HOST_DESCRIPTION}"
    echo "IMPACT - ${target} down, ${DRSM_HOST_IMPACT}"
fi

drsm_exit
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
