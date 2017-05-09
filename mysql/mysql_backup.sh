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
# Script used to create MySQL backups
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
    cat /dev/null > ${DRSMHOME}/.auth/${HOST}.msql; chmod 600 ${DRSMHOME}/.auth/${HOST}.msql
    echo "" >> ${DRSMHOME}/.auth/${HOST}.msql
    echo -n "export HOST='" >> ${DRSMHOME}/.auth/${HOST}.msql; echo -n "${HOST}" >> ${DRSMHOME}/.auth/${HOST}.msql; echo "'" >> ${DRSMHOME}/.auth/${HOST}.msql
    echo -n "export USER='" >> ${DRSMHOME}/.auth/${HOST}.msql; echo -n "${USER}" >> ${DRSMHOME}/.auth/${HOST}.msql; echo "'" >> ${DRSMHOME}/.auth/${HOST}.msql
    echo -n "export PW='" >> ${DRSMHOME}/.auth/${HOST}.msql; echo -n "${PW}" >> ${DRSMHOME}/.auth/${HOST}.msql; echo "'" >> ${DRSMHOME}/.auth/${HOST}.msql
    echo "" >> ${DRSMHOME}/.auth/${HOST}.msql
}

if [ "${HOST}" == "" ]; then echo -n "MySQL host: " ; read HOST; fi
if [ -f ${DRSMHOME}/.auth/${HOST}.msql ]; then source ${DRSMHOME}/.auth/${HOST}.msql; fi
if [ "${USER}" == "" ]; then echo -n "MySQL username: " ; read USER; fi
if [ "${PW}" == "" ]; then 
    echo -n "MySQL pass: " ; stty -echo ; read PW ; stty echo ; echo; 
    echo -n "Do you want to save MySQL auth for ${HOST} (yes/no)> ";
    read prompt
    if [ "${prompt^^}" == "YES" ] || [ "${prompt^^}" == "Y" ]; then SaveMySQLAuth; fi 
fi

logfile="${LOGdir}/mysql_backup_${HOST}.log"
PROGRAMname="$0"
LOCKfile="${VARdir}/mysql_backup_${HOST}.lck"
MINold="30"

if [ ! -e ${VARdir} ]; then mkdir -p ${VARdir}; fi
source ${DRSMHOME}/bin/process_lock.sh

LockFileCheck $MINold
CreateLockFile

if [ ! -e ${LOGdir} ]; then mkdir -p ${LOGdir}; fi

cat /dev/null > ${logfile}

DATEEXT=$(date +%Y%m%d)
datetime=$(date)
echo "${HOST} MySQL backup, $(date)" | tee -a ${logfile}

DBLIST=$(mysql -h $HOST -u $USER -p"$PW" -NBe "SHOW DATABASES;" | grep -v 'lost+found')
if [ ! -d ${BACKUPdir}/mysql/${HOST}/${DATEEXT} ]; then 
    mkdir -pv ${BACKUPdir}/mysql/${HOST}/${DATEEXT} | tee -a ${logfile} 
fi 

MYSQLDUMP_ARGS="--lock-tables=false --events --log-error=${logfile}"
for DB in ${DBLIST} 
do
    echo "Backing up schema and SQL for ${DB}" | tee -a ${logfile}
    echo "mysqldump ${MYSQLDUMP_ARGS} -h ${HOST} -u ${USER} --databases ${DB} > ${BACKUPdir}/mysql/${HOST}/${DATEEXT}/${DB}.sql" | tee -a ${logfile} 
    mysqldump ${MYSQLDUMP_ARGS} --no-data -h ${HOST} -u ${USER} -p"${PW}" --databases ${DB} > ${BACKUPdir}/mysql/${HOST}/${DATEEXT}/${DB}.schema
    mysqldump ${MYSQLDUMP_ARGS} -h ${HOST} -u ${USER} -p"${PW}" --databases ${DB} > ${BACKUPdir}/mysql/${HOST}/${DATEEXT}/${DB}.sql
done

echo "${HOST} MySQL backup complete, $(date)" | tee -a ${logfile}
unset HOST
unset USER
unset PW
RemoveLockFile
exit 0
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
