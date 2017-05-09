#!/bin/bash
# ----------------------------------------------------------- 
# BASH Script
# Operating System(s): RHEL/CENTOS
# Run Level(s): 3, 5
# Shell: BASH shell
# Original Author(s): DataReel Software Development
# File Creation Date: 06/10/2013
# Date Last Modified: 05/09/2017
#
# Version control: 1.16
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
# MySQL stat collection using PHP command line script
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

HOST="${1}"
USER="${2}"
PW="${3}"

function SaveMySQLAuth {
    if [ ! -d ${DRSMHOME}/.auth ]; then mkdir -p ${DRSMHOME}/.auth; chmod 700 ${DRSMHOME}/.auth; fi
    cat /dev/null > ${DRSMHOME}/.auth/${HOST}.mysql; chmod 600 ${DRSMHOME}/.auth/${HOST}.mysql
    echo "" >> ${DRSMHOME}/.auth/${HOST}.mysql
    echo -n "export HOST='" >> ${DRSMHOME}/.auth/${HOST}.mysql; echo -n "${HOST}" >> ${DRSMHOME}/.auth/${HOST}.mysql; echo "'" >> ${DRSMHOME}/.auth/${HOST}.mysql
    echo -n "export USER='" >> ${DRSMHOME}/.auth/${HOST}.mysql; echo -n "${USER}" >> ${DRSMHOME}/.auth/${HOST}.mysql; echo "'" >> ${DRSMHOME}/.auth/${HOST}.mysql
    echo -n "export PW='" >> ${DRSMHOME}/.auth/${HOST}.mysql; echo -n "${PW}" >> ${DRSMHOME}/.auth/${HOST}.mysql; echo "'" >> ${DRSMHOME}/.auth/${HOST}.mysql
    echo "" >> ${DRSMHOME}/.auth/${HOST}.mysql
}

if [ "${HOST}" == "" ]; then echo -n "MySQL host: " ; read HOST; fi
if [ -f ${DRSMHOME}/.auth/${HOST}.mysql ]; then source ${DRSMHOME}/.auth/${HOST}.mysql; fi
if [ "${USER}" == "" ]; then echo -n "MySQL username: " ; read USER; fi
if [ "${PW}" == "" ]; then 
    echo -n "MySQL pass: " ; stty -echo ; read PW ; stty echo ; echo; 
    echo -n "Do you want to save MySQL auth for ${HOST} (yes/no)> ";
    read prompt
    if [ "${prompt^^}" == "YES" ] || [ "${prompt^^}" == "Y" ]; then SaveMySQLAuth; fi 
fi

REPORTdir="${REPORTdir}/mysql_servers"
OUTPUTdir="${VARdir}/collect_mysql_stats.tmp"
logfile="${LOGdir}/collect_mysql_stats_${HOST}.log"
PROGRAMname="$0"
LOCKfile="${VARdir}/collect_mysql_stats_${HOST}.lck"
MINold="30"

if [ ! -e ${VARdir} ]; then mkdir -p ${VARdir}; fi
source ${DRSMHOME}/bin/process_lock.sh

LockFileCheck $MINold
CreateLockFile

if [ ! -e ${LOGdir} ]; then mkdir -p ${LOGdir}; fi
if [ ! -e ${OUTPUTdir}/${HOST} ]; then mkdir -p ${OUTPUTdir}/${HOST}; fi
if [ ! -e ${REPORTdir}/${HOST}/archive ]; then mkdir -p ${REPORTdir}/${HOST}/archive; fi

cat /dev/null > ${logfile}
cat /dev/null > ${OUTPUTdir}/${HOST}/${HOST}_mysql_stats.txt

DATEEXT=$(date +%Y%m%d_%H%M%S)
ETIME=$(date +%s)
datetime=$(date)
echo "${HOST} stats report, ${datetime}" | tee -a ${logfile}

echo "${HOST} stats report, ${datetime}" >> ${OUTPUTdir}/${HOST}/${HOST}_mysql_stats.txt
echo "" >> ${OUTPUTdir}/${HOST}/${HOST}_mysql_stats.txt

/usr/bin/php ${DRSMHOME}/mysql/collect_mysql_stats.php "${HOST}" "${USER}" "${PW}" ${DRSMHOME} ${VARdir} ${LOGdir} >> ${OUTPUTdir}/${HOST}/${HOST}_mysql_stats.txt
if [ "$?" != "0" ]
then
    echo "ERROR - collect_mysql_stats.php returned errors" | tee -a ${logfile}
    cat ${OUTPUTdir}/${HOST}/${HOST}_mysql_stats.txt >> ${logfile}
    RemoveLockFile
    unset HOST
    unset USER
    unset PW
    exit 1
fi

cat ${OUTPUTdir}/${HOST}/${HOST}_mysql_stats.txt > ${REPORTdir}/${HOST}/${HOST}_mysql_stats.txt
cat ${OUTPUTdir}/${HOST}/${HOST}_mysql_stats.txt > ${REPORTdir}/${HOST}/archive/${HOST}_mysql_stats_${ETIME}.txt

echo "${HOST} stats report complete" | tee -a ${logfile}
echo "Ouput file: ${REPORTdir}/${HOST}/${HOST}_mysql_stats.txt"

unset HOST
unset USER
unset PW

RemoveLockFile
exit 0
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
