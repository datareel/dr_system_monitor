#!/bin/bash
# ----------------------------------------------------------- 
# BASH Script
# Operating System(s): RHEL/CENTOS
# Run Level(s): 3, 5
# Shell: BASH shell
# Original Author(s): DataReel Software Development
# File Creation Date: 05/25/2013
# Date Last Modified: 05/01/2017
#
# Version control: 1.09
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
function PingCheck()
{
    if [ "${verbose}" == "1" ]; then echo "Pinging host ${1}"; fi
    ping -c 1 -w 30 "${1}" &> /dev/null
    if [ $? -ne 0 ] 
    then
	if [ "${verbose}" == "1" ]; then echo "Ping test failed for ${1}"; fi
	return 1
    fi
    
    if [ "${verbose}" == "1" ]; then echo "Ping test passed for ${1}"; fi
    return 0
}

function HTTPCheck()
{
   if [ ! -e ${OUTPUTdir}/${1} ]; then mkdir -p ${OUTPUTdir}/${1}; fi
   cd ${OUTPUTdir}/${1}
    wget --tries=5 --timeout=15 --max-redirect=0 "${1}" &> /dev/null
    if [ $? -ne 0 ]
    then
	if [ $? -ne 8 ]; then
	    if [ "${verbose}" == "1" ]; then echo "HTTP test passed for ${1}"; fi
	    return 0
	fi 
	if [ "${verbose}" == "1" ]; then echo "HTTP test failed for ${1}"; fi
	return 1
    fi
    
    if [ "${verbose}" == "1" ]; then echo "HTTP test passed for ${1}"; fi
    return 0
}

function HTTPSCheck()
{
   if [ ! -e ${OUTPUTdir}/${1} ]; then mkdir -p ${OUTPUTdir}/${1}; fi
   cd ${OUTPUTdir}/${1}
    wget --tries=5 --timeout=15 "https://${1}" &> /dev/null
    if [ $? -ne 0 ] 
    then
	if [ "${verbose}" == "1" ]; then echo "HTTPS test failed for ${1}"; fi
	return 1
    fi
    
    if [ "${verbose}" == "1" ]; then echo "HTTPS test passed for ${1}"; fi
    return 0
}

function FTPCheck()
{
   if [ ! -e ${OUTPUTdir}/${1} ]; then mkdir -p ${OUTPUTdir}/${1}; fi
   cd ${OUTPUTdir}/${1}
    ##wget --tries=5 --timeout=15 --no-passive-ftp "ftp://${1}" &> /dev/null
    wget --tries=5 --timeout=15 "ftp://${1}" &> /dev/null
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
    ssh -q -x -o stricthostkeychecking=no -o PasswordAuthentication=no "${1}" "hostname -s" &> /dev/null
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
