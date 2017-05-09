#!/bin/bash
# ----------------------------------------------------------- 
# BASH Script
# Operating System(s): RHEL/CENTOS
# Run Level(s): 3, 5
# Shell: BASH shell
# Original Author(s): DataReel Software Development
# File Creation Date: 06/17/2013
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
# Postgres database check util
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

if [ "${1}" != "" ]; then export PGHOST="${1}"; fi
if [ "${2}" != "" ]; then export PGUSER="${2}"; fi
if [ "${3}" != "" ]; then export PGPASSWORD="${3}"; fi
if [ "${4}" != "" ]; then export emailstatusreport="${4}"; fi

function SavePGAuth {
    if [ ! -d ${DRSMHOME}/.auth ]; then mkdir -p ${DRSMHOME}/.auth; chmod 700 ${DRSMHOME}/.auth; fi
    cat /dev/null > ${DRSMHOME}/.auth/${PGHOST}.pg; chmod 600 ${DRSMHOME}/.auth/${PGHOST}.pg
    echo "" >> ${DRSMHOME}/.auth/${PGHOST}.pg
    echo -n "export PGHOST='" >> ${DRSMHOME}/.auth/${PGHOST}.pg; 
    echo -n "${PGHOST}" >> ${DRSMHOME}/.auth/${PGHOST}.pg; echo "'" >> ${DRSMHOME}/.auth/${PGHOST}.pg
    echo -n "export PGUSER='" >> ${DRSMHOME}/.auth/${PGHOST}.pg; 
    echo -n "${PGUSER}" >> ${DRSMHOME}/.auth/${PGHOST}.pg; echo "'" >> ${DRSMHOME}/.auth/${PGHOST}.pg
    echo -n "export PGPASSWORD='" >> ${DRSMHOME}/.auth/${PGHOST}.pg; 
    echo -n "${PGPASSWORD}" >> ${DRSMHOME}/.auth/${PGHOST}.pg; echo "'" >> ${DRSMHOME}/.auth/${PGHOST}.pg
    echo "" >> ${DRSMHOME}/.auth/${PGHOST}.pg
}

if [ "${PGHOST}" == "" ]; then echo -n "PG host: " ; read PGHOST; export PGHOST; fi
if [ -f ${DRSMHOME}/.auth/${PGHOST}.pg ]; then source ${DRSMHOME}/.auth/${PGHOST}.pg; fi
if [ "${PGUSER}" == "" ]; then echo -n "PG username: " ; read PGUSER; export PGUSER; fi
if [ "${PGPASSWORD}" == "" ]; then 
    echo -n "PG pass: " ; stty -echo ; read PGPASSWORD ; stty echo ; echo; 
    export PGPASSWORD
    echo -n "Do you want to save PG auth for ${PGHOST} (yes/no)> ";
    read prompt
    if [ "${prompt^^}" == "YES" ] || [ "${prompt^^}" == "Y" ]; then SavePGAuth; fi 
fi

if [ -z ${emailstatusreport} ]; then emailstatusreport="NO"; fi

if [ "${PSQL}" == "" ]; then export PSQL="psql"; fi
if [ "${PG_DUMP}" == "" ]; then export PG_DUMP="pg_dump"; fi
if [ "${VACUUMDB}" == "" ]; then export VACUUMDB="vacuumdb"; fi

OUTPUTdir="${VARdir}/db_checks.tmp"
logfile="${LOGdir}/${PGHOST}_db_checks.log"
PROGRAMname="$0"
LOCKfile="${VARdir}/${PGHOST}_db_checks.lck"
MINold="15"
errorfile="${OUTPUTdir}/${PGHOST}_errors.txt"
statusfile="${OUTPUTdir}/${PGHOST}_status.txt"
has_errors="0"
verbose="1"
DISPLAYHOST=$(hostname -s)
emailstatusreport=$(echo "${emailstatusreport}" | tr [:lower:] [:upper:])

if [ ! -e ${VARdir} ]; then mkdir -p ${VARdir}; fi
source ${DRSMHOME}/bin/process_lock.sh

LockFileCheck $MINold
CreateLockFile

if [ ! -e ${LOGdir} ]; then mkdir -p ${LOGdir}; fi
if [ ! -e ${OUTPUTdir}/${DISPLAYHOST} ]; then mkdir -p ${OUTPUTdir}/${DISPLAYHOST}; fi

cat /dev/null > ${logfile}

DATEEXT=$(date -u +%Y%m%d_%H%M%S)
ETIME=$(date +%s)
datetime=$(date -u)

echo "${DISPLAYHOST} postgresql DB checks, ${datetime}" | tee -a ${logfile}

cat /dev/null > ${errorfile}
cat /dev/null > ${statusfile}

${DRSMHOME}/postgres/postgres_stats.sh >> ${statusfile}
cat ${statusfile} >> ${logfile}

grep "ERROR - " ${statusfile} >> ${errorfile}
if [ "$?" == "0" ]
then
    has_errors="1"
fi

grep "CRITICAL - " ${statusfile} >> ${errorfile}
if [ "$?" == "0" ]
then
    has_errors="1"
fi

grep "WARNING - " ${statusfile} >> ${errorfile}
if [ "$?" == "0" ]
then
    has_warning="1"
fi

if [ "${has_errors}" == "1" ]
then
    echo "${DISPLAYHOST} postgresql DB checks reported errors, sending alert message" | tee -a ${logfile}
    SUBJECT="[!ALERT!] ${DISPLAYHOST} Postgresql DB Requires Optimization"
    cat ${errorfile} > ${VARdir}/db_checks.$$
    echo "" >> ${VARdir}/db_checks.$$
    cat ${statusfile} >> ${VARdir}/db_checks.$$
    BODY="${VARdir}/db_checks.$$"
    TIMESPAN="4"
    SENDEMAIL="TRUE"
    SENDTEXT="TRUE"
    source ${DRSMHOME}/bin/text_email_alert.sh
    email_alert "${SUBJECT}" "${BODY}"
    rm -f ${VARdir}/db_checks.$$
    RemoveLockFile
    unset PGHOST
    unset PGUSER
    unset PGPASSWORD
    exit 1
fi

if [ "${has_warning}" == "1" ]
then
    if [ "${emailstatusreport}" == "YES" ]
    then
	echo "${DISPLAYHOST} postgresql DB checks reported warnings, sending alert message" | tee -a ${logfile}
        SUBJECT="[!INFO!] ${DISPLAYHOST} Postgresql Checks Reported Warnings"
	cat ${errorfile} > ${VARdir}/db_checks.$$
        echo "" >> ${VARdir}/db_checks.$$
        cat ${statusfile} >> ${VARdir}/db_checks.$$
        BODY="${VARdir}/db_checks.$$"
        TIMESPAN="4"
        SENDEMAIL="TRUE"
        SENDTEXT="FALSE"
        source ${DRSMHOME}/bin/text_email_alert.sh
        email_alert "${SUBJECT}" "${BODY}"
        rm -f ${VARdir}/email_alert.*
        rm -f ${VARdir}/db_checks.$$
        RemoveLockFile
    else
        echo "${DISPLAYHOST} postgresql DB checks reported warnings, not sending any status messages" | tee -a ${logfile}
    fi
    RemoveLockFile
    unset PGHOST
    unset PGUSER
    unset PGPASSWORD
    exit 2
fi


if [ "${emailstatusreport}" == "YES" ]
then
    echo "${DISPLAYHOST} postgresql DB checks check good, sending status message, sening status message" | tee -a ${logfile}
    SUBJECT="[!INFO!] ${DISPLAYHOST} Postgresql DB Checks"
    BODY=${statusfile}
    TIMESPAN="4"
    SENDEMAIL="TRUE"
    SENDTEXT="FALSE"
    source ${DRSMHOME}/bin/text_email_alert.sh
    email_alert "${SUBJECT}" "${BODY}"
    rm -f ${VARdir}/email_alert.*
    RemoveLockFile
    unset PGHOST
    unset PGUSER
    unset PGPASSWORD
    exit 0
fi

echo "${DISPLAYHOST} DB checks complete" | tee -a ${logfile}

unset PGHOST
unset PGUSER
unset PGPASSWORD
RemoveLockFile
exit 0
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
