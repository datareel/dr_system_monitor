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
# Collector for the monitor host itself. Plugins run in place from
# DRSMHOME, nothing is copied and no SSH session is needed.
#
# Every collector defines the same three functions, called by
# drsm_run.sh with the host name as $1:
#   collector_check  - can we reach the host, 0 == yes
#   collector_sync   - install the plugins, $2.. == plugin IDs
#   collector_exec   - run the job script $2, output on stdout
# and sets COLLECTOR_BASE, the DRSM_BASE used in the job script.
#
# ----------------------------------------------------------- 
COLLECTOR_BASE="${DRSMHOME}"

function collector_check() { return 0; }

function collector_sync() { return 0; }

function collector_exec()
{
    bash "${2}"
}
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
