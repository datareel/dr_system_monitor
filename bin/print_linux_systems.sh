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
# Version control: 1.15
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
# DRSM util script used to print a list of systems for use
# as input to data call scripts.
#
# ----------------------------------------------------------- 
if [ "${BASEdir}" == "" ]; then export BASEdir="${HOME}/drsm"; fi

if [ -f ${HOME}/.drsm.sh ]; then
    CONFIG_FILE=${HOME}/.drsm.sh
else
    CONFIG_FILE=${BASEdir}/etc/drsm.sh
fi

if [ ! -f ${CONFIG_FILE} ]; then
    echo "Missing base config ${CONFIG_FILE}"
    exit 1
fi

source ${CONFIG_FILE}
source ${DRSMHOME}/bin/system_functions.sh

HOST=$(hostname -s)

dbfile="${VARdir}/print_systems_linuxsystems.dat"
cat /dev/null > ${dbfile}
for f in ${CONFIGdir}/systems.dat ${CONFIGdir}/dev_systems.dat; do
    if [ -f ${f} ]; then cat ${f} >> ${dbfile}; echo "" >> ${dbfile}; fi
done

LoadSystemList "${dbfile}" "1"

for system in "${SYSTEMLIST[@]}"
do
    ParseSystemEntry "${system}"

    if [ "${is_cluser_ip}" == "YES" ] 
    then 
	continue 
    fi

    if [ "${is_linux}" != "YES" ]; then
	continue
    fi

    echo "$host"
done

exit 0
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
