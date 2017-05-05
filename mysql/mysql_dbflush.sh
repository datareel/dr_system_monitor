#!/bin/bash
# ----------------------------------------------------------- 
# BASH Script
# Operating System(s): RHEL/CENTOS
# Run Level(s): 3, 5
# Shell: BASH shell
# Original Author(s): DataReel Software Development
# File Creation Date: 06/10/2013
# Date Last Modified: 05/04/2017
#
# Version control: 1.14
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
# Reset the DB cache, logs, and tables
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

host="$1"
username="$2"
pass="$3"

if [ "$host" == "" ]; then echo -n "MySQL host: " ; read host; fi
if [ "$username" == "" ]; then echo -n "MySQL username: " ; read username; fi
if [ "$pass" == "" ]; then echo -n "MySQL pass: " ; stty -echo ; read pass ; stty echo ; echo; fi

REPORTdir="${REPORTdir}/mysql_servers"
OUTPUTdir="${VARdir}/collect_mysql_stats.tmp"
logfile="${LOGdir}/mysql_dbflush_${host}.log"
PROGRAMname="$0"
LOCKfile="${VARdir}/mysql_dbflush_${host}.lck"
MINold="15"

if [ ! -e ${VARdir} ]; then mkdir -p ${VARdir}; fi
source ${DRSMHOME}/bin/process_lock.sh

LockFileCheck $MINold
CreateLockFile

if [ ! -e ${LOGdir} ]; then mkdir -p ${LOGdir}; fi
if [ ! -e ${OUTPUTdir}/${host} ]; then mkdir -p ${OUTPUTdir}/${host}; fi
if [ ! -e ${REPORTdir}/${host}/archive ]; then mkdir -p ${REPORTdir}/${host}/archive; fi

echo "Flushing QUERY CACHE"
mysql -h ${host} -u ${username} -p"$pass" --execute='FLUSH QUERY CACHE'

echo "Flushing PRIVILEGES"
mysql -h ${host} -u ${username} -p"$pass" --execute='FLUSH PRIVILEGES'

echo "Flushing TABLES"
mysql -h ${host} -u ${username} -p"$pass" --execute='FLUSH TABLES'

echo "Flushing HOSTS"
mysql -h ${host} -u ${username} -p"$pass" --execute='FLUSH HOSTS'

echo "Flushing LOGS"
mysql -h ${host} -u ${username} -p"$pass" --execute='FLUSH LOGS'

echo "Flushing STATUS"
mysql -h ${host} -u ${username} -p"$pass" --execute='FLUSH STATUS'

echo "Flushing USER_RESOURCES"
mysql -h ${host} -u ${username} -p"$pass" --execute='FLUSH USER_RESOURCES'

##echo "Reset binary logs"
##mysql -h ${host} -u ${username} -p"$pass" --execute='RESET MASTER'

RemoveLockFile
exit 0
# -----------------------------------------------------------
# *******************************
# ********* End of File *********
# *******************************
