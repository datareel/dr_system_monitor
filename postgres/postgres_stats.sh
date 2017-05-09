#!/bin/bash
# ----------------------------------------------------------- 
# BASH Script
# Operating System(s): RHEL/CENTOS
# Run Level(s): 3, 5
# Shell: BASH shell
# Original Author(s): DataReel Software Development
# File Creation Date: 06/14/2013
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
# Postgres stat collection and warning program
#
# postgresql.conf setup:
#                                                    
# track_activities = on
# track_counts = on
#
# Postgres 9.2 and higher
# track_io_timing = on
# track_functions = all
# track_activity_query_size = 1024
# update_process_title = on
# stats_temp_directory = 'pg_stat_tmp'
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

if [ "${PSQL}" == "" ]; then export PSQL="psql"; fi
if [ "${PG_DUMP}" == "" ]; then export PG_DUMP="pg_dump"; fi
if [ "${VACUUMDB}" == "" ]; then export VACUUMDB="vacuumdb"; fi

REPORTdir="${REPORTdir}/postgres_servers"
OUTPUTdir="${VARdir}/postgres_stats.tmp"
logfile="${LOGdir}/${PGHOST}_postgres_stats.log"
PROGRAMname="$0"
LOCKfile="${VARdir}/${PGHOST}_postgres_stats.lck"
MINold="15"

DISPLAYHOST="${PGHOST}"
if [ "${DISPLAYHOST}" == "localhost" ]; then DISPLAYHOST=$(hostname -s); fi

if [ ! -e ${VARdir} ]; then mkdir -p ${VARdir}; fi
source ${DRSMHOME}/bin/process_lock.sh

LockFileCheck $MINold
CreateLockFile

if [ ! -e ${LOGdir} ]; then mkdir -p ${LOGdir}; fi
if [ ! -e ${OUTPUTdir}/${DISPLAYHOST} ]; then mkdir -p ${OUTPUTdir}/${DISPLAYHOST}; fi

cat /dev/null > ${logfile}

DATEEXT=$(date +%Y%m%d_%H%M%S)
ETIME=$(date +%s)
datetime=$(date)

echo "${DISPLAYHOST} postgresql stats, ${datetime}" | tee -a ${logfile}

if [ "${PGHOST}" == "localhost" ] 
then 
    DBLIST=$(${PSQL} -lt |awk '{ print $1}' |grep -vE '^-|:|^List|^Name|template[0|1]' | grep -v '|')
else
    DBLIST=$(${PSQL} --host=${PGHOST} -lt |awk '{ print $1}' |grep -vE '^-|:|^List|^Name|template[0|1]' | grep -v '|')
fi

for db in ${DBLIST}
do
    echo ""
    echo "Collecting stats for database: ${db}"

done

echo ""

unset PGHOST
unset PGUSER
unset PGPASSWORD

echo "${DISPLAYHOST} stats complete" | tee -a ${logfile}
RemoveLockFile
exit 0
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
