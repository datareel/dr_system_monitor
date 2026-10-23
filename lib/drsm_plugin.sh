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
# Helper functions for plugin check scripts. A plugin sources this file:
#
#   source "${DRSM_LIB:-$(dirname "$0")/../../../lib}/drsm_plugin.sh"
#
# then reports with drsm_ok, drsm_warn, drsm_crit, drsm_unknown and
# drsm_metric, and ends with drsm_exit. The exit code follows the
# Nagios plugin convention: 0 OK, 1 WARNING, 2 ERROR, 3 UNKNOWN.
#
# ----------------------------------------------------------- 
HOST=$(hostname -s 2> /dev/null || hostname)
DRSM_HAS_ERROR=0
DRSM_HAS_WARNING=0
DRSM_HAS_UNKNOWN=0

function drsm_info() { echo "INFO - $*"; }
function drsm_ok() { echo "INFO - $*"; }
function drsm_warn() { echo "WARNING - $*"; DRSM_HAS_WARNING=1; }
function drsm_crit() { echo "ERROR - $*"; DRSM_HAS_ERROR=1; }
function drsm_unknown() { echo "UNKNOWN - $*"; DRSM_HAS_UNKNOWN=1; }

function drsm_metric()
{
    # Machine readable value for graphs, for example:
    # drsm_metric disk_used_pct 92 'mount="/var"'
    # $1 == metric name, $2 == value, $3 == optional labels
    if [ "${3}" != "" ]; then
	echo "METRIC ${1}{${3}}=${2}"
    else
	echo "METRIC ${1}=${2}"
    fi
}

function drsm_setting()
{
    # Value of plugin setting $1 from DRSM_<NAME>, or default $2
    local v="DRSM_${1}"
    if [ "${!v+set}" == "set" ]; then echo "${!v}"; else echo "${2}"; fi
}

function drsm_is_none()
{
    # Empty and NONE both mean "no value" for list settings
    [ "${1}" == "" ] || [ "${1^^}" == "NONE" ]
}

function drsm_gt()
{
    # Floating point a > b, bc is not installed on many cloud images
    awk -v a="${1}" -v b="${2}" 'BEGIN { exit !(a > b) }'
}

function drsm_target()
{
    # Probe plugins run on the monitor host against DRSM_TARGET
    if [ "${DRSM_TARGET}" == "" ]; then
	echo "UNKNOWN - DRSM_TARGET is not set, run this probe as: DRSM_TARGET=<host> ${0}"
	exit 3
    fi
    echo "${DRSM_TARGET}"
}

function drsm_web_probe()
{
    # Connection test with curl for the http, https, and ftp probes.
    # The service is up if the server answers at all, an error or
    # redirect response still proves the service is listening. An
    # invalid HTTPS certificate counts as a failure.
    # $1 == URL, $2 == label such as HTTP, $3 == service words for the
    # IMPACT line such as "web service"
    local target="${DRSM_TARGET}" desc="${DRSM_HOST_DESCRIPTION}" impact="${DRSM_HOST_IMPACT}"
    local ctimeout mtime retries rv
    ctimeout=$(drsm_setting CONNECT_TIMEOUT 15)
    mtime=$(drsm_setting MAX_TIME 30)
    retries=$(drsm_setting RETRIES 2)
    curl -s -o /dev/null --connect-timeout "${ctimeout}" --max-time "${mtime}" --retry "${retries}" "${1}" &> /dev/null
    rv=$?
    if [ ${rv} -eq 0 ]; then
	drsm_ok "${2} connectivity test passed on ${target}, ${desc}"
	return 0
    fi
    drsm_crit "${2} connectivity failed on ${target}, ${desc}"
    echo "IMPACT - ${target} ${3} down, ${impact}"
    echo "${1} curl exit code ${rv}"
    return 1
}

function drsm_exit()
{
    if [ ${DRSM_HAS_ERROR} -eq 1 ]; then exit 2; fi
    if [ ${DRSM_HAS_WARNING} -eq 1 ]; then exit 1; fi
    if [ ${DRSM_HAS_UNKNOWN} -eq 1 ]; then exit 3; fi
    exit 0
}
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
