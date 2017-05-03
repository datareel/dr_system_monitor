#!/bin/bash
# ----------------------------------------------------------- 
# BASH Script
# Operating System(s): RHEL/CENTOS
# Run Level(s): 3, 5
# Shell: BASH shell
# Original Author(s): DataReel Software Development
# File Creation Date: 05/25/2013
# Date Last Modified: 05/02/2017
#
# Version control: 1.11
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
# System connectivity monitoring script 
#
# ----------------------------------------------------------- 
if [ "${BASEdir}" == "" ]; then export BASEdir="${HOME}/drsm"; fi

if [ ! -f ${BASEdir}/etc/drsm.sh ]; then
    echo "ERROR - Cannot find base config ${BASEdir}/etc/drsm.sh"
    exit 1
fi

source ${BASEdir}/etc/drsm.sh
source ${BASEdir}/bin/system_functions.sh

HOST=$(hostname -s)
has_errors="0"
verbose="0"
sortnodes="0"
emailstatusreport="NO"
RUNdir="${BASEdir}/bin"
OUTPUTdir="${VARdir}/system_check.tmp"
errorfile="${OUTPUTdir}/errors.txt"
statusfile="${OUTPUTdir}/status.txt"
PROGRAMname="$0"
LOCKfile="${VARdir}/system_check.lck"
MINold="30"
reporttype="PRODUCTION"
systemlistfile="systemlist"
systemcheckfile="system_check"

if [ "${1}" != "" ]; then emailstatusreport="${1}"; fi
emailstatusreport=$(echo "${emailstatusreport}" | tr [:lower:] [:upper:]) 

# Set our report type to PRODUCTION or DEV
dbfile="${CONFIGdir}/systems.dat"
if [ "${2}" != "" ]; then reporttype="${2}"; fi
if [ "${reporttype}" == "DEV" ] 
then 
    dbfile="${CONFIGdir}/dev_systems.dat" 
    OUTPUTdir="${VARdir}/system_check_dev.tmp"
    errorfile="${OUTPUTdir}/errors_dev.txt"
    statusfile="${OUTPUTdir}/status_dev.txt"
    systemlistfile="systemlist_dev"
    systemcheckfile="system_check_dev"
    PROGRAMname="$0"
    LOCKfile="${VARdir}/system_check_dev.lck"
fi

if [ ! -e ${VARdir} ]; then mkdir -p ${VARdir}; fi
source ${RUNdir}/process_lock.sh

LockFileCheck $MINold
CreateLockFile

if [ ! -d ${LOGdir} ]; then mkdir -p ${LOGdir}; fi
if [ ! -d ${OUTPUTdir} ]; then mkdir -p ${OUTPUTdir}; fi
if [ ! -d ${REPORTdir} ]; then mkdir -p ${REPORTdir}; fi
if [ ! -d ${REPORTdir}/archive ]; then mkdir -p ${REPORTdir}/archive; fi

cat /dev/null > ${errorfile}
cat /dev/null > ${statusfile}

DATEEXT=$(date -u +%Y%m%d_%H%M%S)
ETIME=$(date +%s)
datetime=$(date -u)

echo "DRSM status report, ${datetime} GMT" | tee -a ${statusfile}
echo "Our report type is set to: ${reporttype}" | tee -a ${statusfile}
if [ ! -e ${dbfile} ]
then
    has_errors="1"
    echo "ERROR - ${dbfile} not found"  >> ${errorfile}
    echo "ERROR - ${dbfile} not found"  | tee -a ${statusfile}
    RemoveLockFile
    exit 1
fi


cat /dev/null > ${VARdir}/${systemlistfile}.sh
echo "#!/bin/bash" >> ${VARdir}/${systemlistfile}.sh
echo -n 'export SYSTEMLIST="' >> ${VARdir}/${systemlistfile}.sh

# Sort by site ID                                                                                              
if [ "${sortnodes}" == "1" ]
then
    sort ${dbfile} > ${VARdir}/${systemlistfile}_sorted.dat
else
    cat ${dbfile} > ${VARdir}/${systemlistfile}_sorted.dat
fi

while read line
do
    DATLINE=$(echo $line | grep -v "^#")
    if [ "${DATLINE}" != "" ]
    then
	DATLINE=$(echo "${DATLINE}" | sed s/' '/'%20'/g)
	echo -n "${DATLINE} " >> ${VARdir}/${systemlistfile}.sh
    fi
done < ${VARdir}/${systemlistfile}_sorted.dat

echo -n '"' >> ${VARdir}/${systemlistfile}.sh
sed -i s/' "'/'"'/g ${VARdir}/${systemlistfile}.sh
sed -i s/' ,'/','/g ${VARdir}/${systemlistfile}.sh

source ${VARdir}/${systemlistfile}.sh

for system in ${SYSTEMLIST}
do
    host=$(echo "${system}" | awk -F, '{ print $1 }')
    description=$(echo "${system}" | awk -F, '{ print $2 }' | sed s/'%20'/' '/g)
    impact=$(echo "${system}" | awk -F, '{ print $3 }'  | sed s/'%20'/' '/g)
    is_web_server=$(echo "${system}" | awk -F, '{ print $4 }' | tr [:lower:] [:upper:])
    WEBPROTOS="HTTP"

    echo "${is_web_server}" | grep ':' &> /dev/null
    if [ "$?" == "0" ] 
	then
	WEBPROTOS=$(echo "${is_web_server}" | awk -F: '{ print $2 }' | tr [:lower:] [:upper:])
	is_web_server=$(echo "${is_web_server}" | awk -F: '{ print $1 }' | tr [:lower:] [:upper:])
    fi

    is_linux=$(echo "${system}" | awk -F, '{ print $5 }' | tr [:lower:] [:upper:])
    is_cluser_ip=$(echo "${system}" | awk -F, '{ print $6 }' | tr [:lower:] [:upper:])
    can_ping=$(echo "${system}" | awk -F, '{ print $7 }' | tr [:lower:] [:upper:])
    can_ssh=$(echo "${system}" | awk -F, '{ print $8 }' | tr [:lower:] [:upper:])

    if [ "${can_ping}" == "YES" ]
    then
	PingCheck ${host}
	if [ $? -ne 0 ] 
	then
	    echo "ERROR - Network connectivity failed on ${host}, ${description}" >> ${errorfile}
	    echo "IMPACT - ${host} down, ${impact}"
	    echo "ERROR - Network connectivity failed on ${host}" | tee -a ${statusfile}
	    has_errors="1"
	else
	    echo "INFO - Network connectivity test passed on ${host}, ${description}" | tee -a ${statusfile}
	fi
    else
	echo "INFO - Network connectivity skipped for ${host}, ${description}" | tee -a ${statusfile}
    fi

    if [ "${is_web_server}" == "YES" ]
    then

	for p in ${WEBPROTOS}
	do
	    if [ "${p}" == "HTTP" ]
	    then
		HTTPCheck ${host}
		if [ $? -ne 0 ]
		then
		    echo "ERROR - HTTP connectivity failed on ${host}, ${description}" >> ${errorfile}
		    echo "IMPACT - ${host} web service down, ${impact}"
		    echo "ERROR - HTTP connectivity failed on ${host}, ${description}" | tee -a ${statusfile}
		    echo "IMPACT - ${host} web service down, ${impact}" | tee -a ${statusfile}
		    has_errors="1"
		else
		    echo "INFO - HTTP connectivity test passed on ${host}, ${description}" | tee -a ${statusfile}
		fi
	    fi

	    if [ "${p}" == "FTP" ]
	    then
		FTPCheck ${host}
		if [ $? -ne 0 ]
		then
		    echo "ERROR - FTP connectivity failed on ${host}, ${description}" >> ${errorfile}
		    echo "IMPACT - ${host} ftp service down, ${impact}"
		    echo "ERROR - FTP connectivity failed on ${host}, ${description}" | tee -a ${statusfile}
		    echo "IMPACT - ${host} FTP service down, ${impact}" | tee -a ${statusfile}
		    has_errors="1"
		else
		    echo "INFO - FTP connectivity test passed on ${host}, ${description}" | tee -a ${statusfile}
		fi
	    fi

	    if [ "${p}" == "HTTPS" ]
	    then
		HTTPSCheck ${host}
		if [ $? -ne 0 ]
		then
		    echo "ERROR - HTTPS connectivity failed on ${host}, ${description}" >> ${errorfile}
		    echo "IMPACT - ${host} secure web service down, ${impact}"
		    echo "ERROR - HTTPS connectivity failed on ${host}, ${description}" | tee -a ${statusfile}
		    echo "IMPACT - ${host} HTTPS service down, ${impact}" | tee -a ${statusfile}
		    has_errors="1"
		else
		    echo "INFO - HTTPS connectivity test passed on ${host}, ${description}" | tee -a ${statusfile}
		fi
	    fi
	done
    fi

done

cat ${statusfile} > ${REPORTdir}/${systemcheckfile}_report.txt
cat ${statusfile} > ${REPORTdir}/archive/${systemcheckfile}_report_${DATEEXT}.txt

if [ "${has_errors}" == "0" ]
    then
    echo "System check did not report any ERRORS" > ${errorfile}
fi

cat ${errorfile} > ${REPORTdir}/${systemcheckfile}_report_errors.txt
cat ${errorfile} > ${REPORTdir}/archive/${systemcheckfile}_report_errors_${DATEEXT}.txt

if [ "${has_errors}" == "1" ]
then
    echo "System checks reported connection errors, sending alert message"
    SUBJECT="[!ALERT!] DRSM Connection Checks Reported Errors"
    BODY="${errorfile}"
    TIMESPAN="4"
    SENDEMAIL="TRUE"
    SENDTEXT="TRUE"
    if [ "${reporttype}" == "DEV" ] 
    then 
	SENDTEXT="FALSE" 
	SUBJECT="[!ALERT!] DRSM Dev Systems Connection Checks Reported Errors"
	TIMEFILE="${VARdir}/email_alert_dev.timefile"
	INITFILE="${VARdir}/email_alert_dev.initfile"
    fi
    source ${RUNdir}/text_email_alert.sh
    email_alert "${SUBJECT}" "${BODY}"
    RemoveLockFile
    exit 1
fi

if [ "${emailstatusreport}" == "YES" ] 
then 
    echo "All systems check good, sending status message"
    SUBJECT="[!INFO!] DRSM Connections Check Status Report"
    BODY=${statusfile}
    TIMESPAN="4"
    SENDTEXT="FALSE"
    if [ "${reporttype}" == "DEV" ] 
    then 
	SUBJECT="[!INFO!] DRSM Dev Systems Connections Check Status Report"
	TIMEFILE="${VARdir}/email_alert_dev.timefile"
	INITFILE="${VARdir}/email_alert_dev.initfile"
    fi
    source ${RUNdir}/text_email_alert.sh
    email_alert "${SUBJECT}" "${BODY}"
    rm -f ${VARdir}/email_alert.*
    RemoveLockFile
    exit 0
fi

echo "All systems check good, not sending any status messages"
RemoveLockFile
exit 0
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
