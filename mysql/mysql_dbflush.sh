#!/bin/bash
# ----------------------------------------------------------- 
# BASH Script
# Operating System(s): RHEL/CENTOS
# Run Level(s): 3, 5
# Shell: BASH shell
# Original Author(s): DataReel Software Development
# File Creation Date: 06/10/2013
# Date Last Modified: 05/08/2017
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

HOST="$1"
USER="$2"
PW="$3"

function SaveMySQLAuth {
    if [ ! -d ${DRSMHOME}/.auth ]; then mkdir -p ${DRSMHOME}/.auth; chmod 700 ${DRSMHOME}/.auth; fi
    cat /dev/null > ${DRSMHOME}/.auth/${HOST}.msql; chmod 600 ${DRSMHOME}/.auth/${HOST}.msql
    echo "" >> ${DRSMHOME}/.auth/${HOST}.msql
    echo -n "export HOST='" >> ${DRSMHOME}/.auth/${HOST}.msql; echo -n "${HOST}" >> ${DRSMHOME}/.auth/${HOST}.msql; echo "'" >> ${DRSMHOME}/.auth/${HOST}.msql
    echo -n "export USER='" >> ${DRSMHOME}/.auth/${HOST}.msql; echo -n "${USER}" >> ${DRSMHOME}/.auth/${HOST}.msql; echo "'" >> ${DRSMHOME}/.auth/${HOST}.msql
    echo -n "export PW='" >> ${DRSMHOME}/.auth/${HOST}.msql; echo -n "${PW}" >> ${DRSMHOME}/.auth/${HOST}.msql; echo "'" >> ${DRSMHOME}/.auth/${HOST}.msql
    echo "" >> ${DRSMHOME}/.auth/${HOST}.msql
}

if [ "$HOST" == "" ]; then echo -n "MySQL HOST: " ; read HOST; fi
if [ -f ${DRSMHOME}/.auth/${HOST}.msql ]; then source ${DRSMHOME}/.auth/${HOST}.msql; fi
if [ "$USER" == "" ]; then echo -n "MySQL USER: " ; read USER; fi
if [ "$PW" == "" ]; then 
    echo -n "MySQL PW: " ; stty -echo ; read PW ; stty echo ; echo; 
    echo -n "Do you want to save MySQL auth for ${HOST} (yes/no)> ";
    read prompt
    if [ "${prompt^^}" == "YES" ] || [ "${prompt^^}" == "Y" ]; then SaveMySQLAuth; fi 
fi

REPORTdir="${REPORTdir}/mysql_servers"
OUTPUTdir="${VARdir}/collect_mysql_stats.tmp"
logfile="${LOGdir}/mysql_dbflush_${HOST}.log"
PROGRAMname="$0"
LOCKfile="${VARdir}/mysql_dbflush_${HOST}.lck"
MINold="15"

if [ ! -e ${VARdir} ]; then mkdir -p ${VARdir}; fi
source ${DRSMHOME}/bin/process_lock.sh

LockFileCheck $MINold
CreateLockFile

if [ ! -e ${LOGdir} ]; then mkdir -p ${LOGdir}; fi
if [ ! -e ${OUTPUTdir}/${HOST} ]; then mkdir -p ${OUTPUTdir}/${HOST}; fi
if [ ! -e ${REPORTdir}/${HOST}/archive ]; then mkdir -p ${REPORTdir}/${HOST}/archive; fi

echo "Flushing QUERY CACHE"
mysql -h ${HOST} -u ${USER} -p"$PW" --execute='FLUSH QUERY CACHE'

echo "Flushing PRIVILEGES"
mysql -h ${HOST} -u ${USER} -p"$PW" --execute='FLUSH PRIVILEGES'

echo "Flushing TABLES"
mysql -h ${HOST} -u ${USER} -p"$PW" --execute='FLUSH TABLES'

echo "Flushing HOSTS"
mysql -h ${HOST} -u ${USER} -p"$PW" --execute='FLUSH HOSTS'

echo "Flushing LOGS"
mysql -h ${HOST} -u ${USER} -p"$PW" --execute='FLUSH LOGS'

echo "Flushing STATUS"
mysql -h ${HOST} -u ${USER} -p"$PW" --execute='FLUSH STATUS'

echo "Flushing USER_RESOURCES"
mysql -h ${HOST} -u ${USER} -p"$PW" --execute='FLUSH USER_RESOURCES'

##echo "Reset binary logs"
##mysql -h ${HOST} -u ${USER} -p"$PW" --execute='RESET MASTER'

unset HOST
unset USER
unset PW

RemoveLockFile
exit 0
# -----------------------------------------------------------
# *******************************
# ********* End of File *********
# *******************************
