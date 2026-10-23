#!/bin/bash
# ----------------------------------------------------------- 
# BASH Script
# Operating System(s): RHEL/CENTOS
# Run Level(s): 3, 5
# Shell: BASH shell
# Original Author(s): DataReel Software Development
# File Creation Date: 05/25/2013
# Date Last Modified: 10/23/2026
#
# Version control: 1.10
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
# System check and reporting functions 
#
# ----------------------------------------------------------- 
# SSH options used for all keyed SSH/SCP sessions. BatchMode and
# ConnectTimeout keep cron runs from hanging on a host that is down or
# prompting for a password. StrictHostKeyChecking=accept-new trusts a
# host on first contact but refuses a changed host key. Override in
# your ~/.drsm.sh config if needed.
if [ "${SSH_OPTS}" == "" ]; then
    export SSH_OPTS="-q -x -o BatchMode=yes -o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new -o PasswordAuthentication=no"
fi

if [ "${SCP_OPTS}" == "" ]; then
    export SCP_OPTS="-q -o BatchMode=yes -o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new -o PasswordAuthentication=no"
fi

# Remote directory for the health check scripts. A relative path is
# relative to the remote login user's home directory, so this works
# when the remote SSH user differs from the local DRSM user.
if [ "${REMOTEdir}" == "" ]; then export REMOTEdir="drsm/health_check_scripts"; fi

function LoadSystemList()
{
    # Read a systems.dat CSV file into the SYSTEMLIST array, one entry
    # per system. Comments, blank lines, CR characters, and spaces
    # around commas are removed.
    # $1 == dat file, $2 == 1 to sort the list
    SYSTEMLIST=()
    local dat="${1}"
    if [ ! -f "${dat}" ]; then return 1; fi
    local line
    while IFS= read -r line || [ -n "${line}" ]
    do
	line="${line//$'\r'/}"
	line=$(echo "${line}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/[[:space:]]*,[[:space:]]*/,/g')
	if [ "${line}" == "" ] || [ "${line:0:1}" == "#" ]; then continue; fi
	SYSTEMLIST+=("${line}")
    done < <(if [ "${2}" == "1" ]; then sort "${dat}"; else cat "${dat}"; fi)
    return 0
}

function ParseSystemEntry()
{
    # Split one SYSTEMLIST entry into the per-host variables
    local system="${1}"
    host=$(echo "${system}" | awk -F, '{ print $1 }')
    description=$(echo "${system}" | awk -F, '{ print $2 }')
    impact=$(echo "${system}" | awk -F, '{ print $3 }')
    is_web_server=$(echo "${system}" | awk -F, '{ print $4 }')
    is_web_server="${is_web_server^^}"
    WEBPROTOS="HTTP"
    if [[ "${is_web_server}" == *:* ]]; then
	WEBPROTOS="${is_web_server#*:}"
	is_web_server="${is_web_server%%:*}"
    fi
    is_linux=$(echo "${system}" | awk -F, '{ print $5 }')
    is_linux="${is_linux^^}"
    is_cluser_ip=$(echo "${system}" | awk -F, '{ print $6 }')
    is_cluser_ip="${is_cluser_ip^^}"
    can_ping=$(echo "${system}" | awk -F, '{ print $7 }')
    can_ping="${can_ping^^}"
    can_ssh=$(echo "${system}" | awk -F, '{ print $8 }')
    can_ssh="${can_ssh^^}"
}

function MySQLOptionFile()
{
    # Write the MySQL credentials to a private option file so the
    # password is not visible in the process list. Sets MYCNF, the
    # file is removed when the calling script exits.
    # $1 == user, $2 == password
    MYCNF=$(mktemp ${VARdir}/mysql_auth.XXXXXX)
    chmod 600 ${MYCNF}
    local u="${1//\\/\\\\}"; u="${u//\"/\\\"}"
    local p="${2//\\/\\\\}"; p="${p//\"/\\\"}"
    printf '[client]\nuser="%s"\npassword="%s"\n' "${u}" "${p}" > ${MYCNF}
    trap 'rm -f ${MYCNF}' EXIT
}

function PingCheck()
{
    if [ "${verbose}" == "1" ]; then echo "Pinging host ${1}"; fi
    # Up to 3 tries so a single dropped packet does not raise an alert
    ping -c 3 -w 30 "${1}" &> /dev/null
    if [ $? -ne 0 ] 
    then
	if [ "${verbose}" == "1" ]; then echo "Ping test failed for ${1}"; fi
	return 1
    fi
    
    if [ "${verbose}" == "1" ]; then echo "Ping test passed for ${1}"; fi
    return 0
}

function WebCheck()
{
    # $1 == URL, $2 == label for messages
    # The service is up if the server answers at all. wget exits 8
    # when the server sends an error or redirect response, which
    # still proves the service is listening.
    wget --tries=3 --timeout=15 --max-redirect=0 -q -O /dev/null "${1}" &> /dev/null
    local rv=$?
    if [ ${rv} -eq 0 ] || [ ${rv} -eq 8 ]
    then
	if [ "${verbose}" == "1" ]; then echo "${2} test passed for ${1}"; fi
	return 0
    fi
    if [ "${verbose}" == "1" ]; then echo "${2} test failed for ${1}, wget exit code ${rv}"; fi
    return 1
}

function HTTPCheck()
{
    WebCheck "http://${1}" "HTTP"
}

function HTTPSCheck()
{
    WebCheck "https://${1}" "HTTPS"
}

function FTPCheck()
{
    wget --tries=3 --timeout=15 -q -O /dev/null "ftp://${1}" &> /dev/null
    if [ $? -ne 0 ] 
    then
	if [ "${verbose}" == "1" ]; then echo "FTP test failed for ${1}"; fi
	return 1
    fi
    
    if [ "${verbose}" == "1" ]; then echo "FTP test passed for ${1}"; fi
    return 0
}

function SSHCheck()
{
    if [ "${verbose}" == "1" ]; then echo "Checking keyed auth to host ${1}"; fi
    ssh ${SSH_OPTS} "${1}" "hostname -s" &> /dev/null
    if [ $? -ne 0 ] 
    then
	if [ "${verbose}" == "1" ]; then echo "SSH keyed auth test failed for ${1}"; fi
	return 1
    fi
    
    if [ "${verbose}" == "1" ]; then echo "SSH keyed auth test passed for ${1}"; fi
    return 0
}
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
