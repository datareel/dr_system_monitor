# ----------------------------------------------------------- 
# BASH Script
# Operating System(s): RHEL/CENTOS
# Run Level(s): 3, 5
# Shell: BASH shell
# Original Author(s): DataReel Software Development
# File Creation Date: 05/25/2013
# Date Last Modified: 05/04/2017
#
# Version control: 1.13
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
# System health check reporting script 
#
# ----------------------------------------------------------- 
if [ "${BASEdir}" == "" ]; then export BASEdir="${HOME}/drsm"; fi

if [ -f ${HOME}/.drsm.sh ]; then
    echo "INFO - Using config override file ${HOME}/.drsm.sh"
    CONFIG_FILE=${HOME}/.drsm.sh
else
    echo "INFO - Using default config ${BASEdir}/etc/drsm.sh"
    CONFIG_FILE=${BASEdir}/etc/drsm.sh
fi

if [ ! -f ${CONFIG_FILE} ]; then
    echo "Missing base config ${CONFIG_FILE}"
    exit 1
fi

source ${CONFIG_FILE}
source ${DRSMHOME}/bin/system_functions.sh

HOST=$(hostname -s)
has_errors="0"
verbose="1"
sortnodes="0"
emailstatusreport="NO"
singletesthost=""
OUTPUTdir="${VARdir}/system_report.tmp"
errorfile="${OUTPUTdir}/errors.txt"
statusfile="${OUTPUTdir}/status.txt"
logfile="${LOGdir}/system_report.log"
PROGRAMname="$0"
LOCKfile="${VARdir}/system_report.lck"
MINold="30"
reporttype="PRODUCTION"
systemreportlistfile="systemreportlist"
systemhealthreportfile="system_health_report"

if [ "${1}" != "" ]; then emailstatusreport="${1}"; fi
emailstatusreport=$(echo "${emailstatusreport}" | tr [:lower:] [:upper:]) 

# Set our report type to PRODUCTION or DEV
dbfile="${CONFIGdir}/systems.dat"
if [ "${2}" != "" ]; then reporttype="${2}"; fi
if [ "${reporttype}" == "DEV" ]; 
then 
    dbfile="${CONFIGdir}/dev_systems.dat"
    OUTPUTdir="${VARdir}/system_report_dev.tmp"
    errorfile="${OUTPUTdir}/errors_dev.txt"
    statusfile="${OUTPUTdir}/status_dev.txt"
    logfile="${LOGdir}/system_report_dev.log"
    LOCKfile="${VARdir}/system_report_dev.lck"
    systemreportlistfile="systemreportlist_dev"
    systemhealthreportfile="system_health_report_dev"
fi

if [ "${3}" != "" ]; then singletesthost="${3}"; fi

if [ ! -e ${VARdir} ]; then mkdir -p ${VARdir}; fi
source ${DRSMHOME}/bin/process_lock.sh

LockFileCheck $MINold
CreateLockFile

if [ ! -e ${LOGdir} ]; then mkdir -p ${LOGdir}; fi
if [ ! -e ${OUTPUTdir} ]; then mkdir -p ${OUTPUTdir}; fi
if [ ! -e ${REPORTdir}/systems ]; then mkdir -p ${REPORTdir}/systems; fi
if [ ! -e ${REPORTdir}/archive ]; then mkdir -p ${REPORTdir}/archive; fi

cat /dev/null > ${errorfile}
cat /dev/null > ${statusfile}
cat /dev/null > ${logfile}

DATEEXT=$(date +%Y%m%d_%H%M%S)
ETIME=$(date +%s)
datetime=$(date)

echo "DRSM health check report, ${datetime} GMT" | tee -a ${statusfile}
echo "Our report type is set to: ${reporttype}" | tee -a ${statusfile}
if [ ! -e ${dbfile} ]
then
    has_errors="1"
    echo "ERROR - ${dbfile} not found"  >> ${errorfile}
    echo "ERROR - ${dbfile} not found"  | tee -a ${statusfile}
    RemoveLockFile
    exit 1
fi

cat /dev/null > ${VARdir}/${systemreportlistfile}.sh
echo "#!/bin/bash" >> ${VARdir}/${systemreportlistfile}.sh
echo -n 'export SYSTEMLIST="' >> ${VARdir}/${systemreportlistfile}.sh

# Sort by site ID                                                                                              
if [ "${sortnodes}" == "1" ]
then
    sort ${dbfile} > ${VARdir}/${systemreportlistfile}_sorted.dat
else
    cat ${dbfile} > ${VARdir}/${systemreportlistfile}_sorted.dat
fi

while read line
do
    DATLINE=$(echo $line | grep -v "^#")
    if [ "${DATLINE}" != "" ]
    then
	DATLINE=$(echo "${DATLINE}" | sed s/' '/'%20'/g)
	echo -n "${DATLINE} " >> ${VARdir}/${systemreportlistfile}.sh
    fi
done < ${VARdir}/${systemreportlistfile}_sorted.dat

echo -n '"' >> ${VARdir}/${systemreportlistfile}.sh
sed -i s/' "'/'"'/g ${VARdir}/${systemreportlistfile}.sh
sed -i s/' ,'/','/g ${VARdir}/${systemreportlistfile}.sh

source ${VARdir}/${systemreportlistfile}.sh

if [ "${singletesthost}" != "" ]
then
    echo "Running health check on single host ${singletesthost}" | tee -a ${logfile}
fi

found_single_host="0"

for system in ${SYSTEMLIST}
do
    host=$(echo "${system}" | awk -F, '{ print $1 }')

    # Single host report, for testing only
    if [ "${singletesthost}" != "" ]
	then
	if [ "${found_single_host}" == "1" ]; then break; fi
	if [ "${host}" != "${singletesthost}" ]
	    then
	    continue
	else
	    found_single_host="1"
	fi
    fi

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

    if [ "${is_cluser_ip}" == "YES" ] 
    then 
	echo "INFO - Skipping CLUSTER IP ${host} ${description}" | tee -a ${logfile}
	continue 
    fi
	    
    echo "Starting health checks on ${host} ${description}" | tee -a ${logfile}

    if [ ! -e ${OUTPUTdir}/${host} ];then mkdir -p ${OUTPUTdir}/${host}; fi
    if [ ! -e ${REPORTdir}/systems/${host}/archive ]; then mkdir -p ${REPORTdir}/systems/${host}/archive; fi
    cat /dev/null > ${OUTPUTdir}/${host}/${host}_report.txt
    echo "INFO - Start of ${host} system health check report" >> ${OUTPUTdir}/${host}/${host}_report.txt
    echo "REPORT_TIME:${datetime}" >> ${OUTPUTdir}/${host}/${host}_report.txt
    echo "ETIME:${ETIME}" >> ${OUTPUTdir}/${host}/${host}_report.txt
    echo "HOSTNAME:${host}" >> ${OUTPUTdir}/${host}/${host}_report.txt
    echo "DESCRIPTION:${description}" >> ${OUTPUTdir}/${host}/${host}_report.txt
    echo "IMPACT:${impact}" >> ${OUTPUTdir}/${host}/${host}_report.txt
    echo "IS_WEB_SERVER:${is_web_server}" >> ${OUTPUTdir}/${host}/${host}_report.txt
    echo "WEBPROTOS:${WEBPROTOS}" >> ${OUTPUTdir}/${host}/${host}_report.txt
    echo "IS_LINUX:${is_linux}" >> ${OUTPUTdir}/${host}/${host}_report.txt
    echo "IS_CLUSTER_IP:${is_cluser_ip}" >> ${OUTPUTdir}/${host}/${host}_report.txt
    echo "CAN_PING:${can_ping}" >> ${OUTPUTdir}/${host}/${host}_report.txt
    echo "CAN_SSH:${can_ssh}" >> ${OUTPUTdir}/${host}/${host}_report.txt
    echo "" >> ${OUTPUTdir}/${host}/${host}_report.txt

    if [ "${is_linux}" == "NO" ] 
    then 
	echo "INFO - Skipping NON-Linux system ${host} ${description}" | tee -a ${logfile}
	echo "INFO - Skipping NON-Linux system" >> ${OUTPUTdir}/${host}/${host}_report.txt
	echo "" >> ${OUTPUTdir}/${host}/${host}_report.txt
	echo "INFO - End of ${host} system health check report" >> ${OUTPUTdir}/${host}/${host}_report.txt
	echo "" >> ${OUTPUTdir}/${host}/${host}_report.txt
	cat ${OUTPUTdir}/${host}/${host}_report.txt > ${REPORTdir}/systems/${host}/${host}_report.txt
	cat ${OUTPUTdir}/${host}/${host}_report.txt > ${REPORTdir}/systems/${host}/archive/${host}_report_${DATEEXT}.txt
	continue 
    fi

    if [ ! -f ${CONFIGdir}/${host}_profile.sh ]
    then
	echo "INFO - Creating default profile script ${CONFIGdir}/${host}_profile.sh" | tee -a ${logfile}
	cat /dev/null > ${CONFIGdir}/${host}_profile.sh
	echo 'if [ "${host}" != "" ] && [ "${OUTPUTdir}" != "" ] && [ "${DRSMHOME}" != "" ]' >> ${CONFIGdir}/${host}_profile.sh
	echo 'then' >> ${CONFIGdir}/${host}_profile.sh
	echo '    # Run remote disk check, checks all local mounts by default:' >> ${CONFIGdir}/${host}_profile.sh
	echo "    # To skip some mounted DIRs: disk_checks.sh '/archive /usr1'" >> ${CONFIGdir}/${host}_profile.sh
	echo "    # To set custom alert level: disk_checks.sh NONE 90 99" >> ${CONFIGdir}/${host}_profile.sh
	echo '    # Where $1 == DIR list to skip or NONE' >> ${CONFIGdir}/${host}_profile.sh
	echo '    # Where $2 == Warning threshold' >> ${CONFIGdir}/${host}_profile.sh
	echo '    # Where $3 == Error threshold' >> ${CONFIGdir}/${host}_profile.sh
	echo '    ssh -q -x -o stricthostkeychecking=no -o PasswordAuthentication=no ${host} \' >> ${CONFIGdir}/${host}_profile.sh
	echo '	"${DRSMHOME}/health_check_scripts/disk_checks.sh" > ${OUTPUTdir}/${host}/disk.txt' >> ${CONFIGdir}/${host}_profile.sh
	echo "" >> ${CONFIGdir}/${host}_profile.sh
	echo '    # Run remote CPU check:' >> ${CONFIGdir}/${host}_profile.sh
	echo '    # To set custom alert level: cpu_checks.sh 85 95 100' >> ${CONFIGdir}/${host}_profile.sh
	echo '    # To include CPU temps must have lm_sensors package setup on host   ' >> ${CONFIGdir}/${host}_profile.sh
	echo '    # Where $1 == Warning threshold' >> ${CONFIGdir}/${host}_profile.sh
	echo '    # Where $2 == Error threshold' >> ${CONFIGdir}/${host}_profile.sh
	echo '    # Where $3 == Number of processes to list' >> ${CONFIGdir}/${host}_profile.sh
	echo '    ssh -q -x -o stricthostkeychecking=no -o PasswordAuthentication=no ${host} \' >> ${CONFIGdir}/${host}_profile.sh
	echo '	"${DRSMHOME}/health_check_scripts/cpu_checks.sh" > ${OUTPUTdir}/${host}/cpu.txt ' >> ${CONFIGdir}/${host}_profile.sh
	echo "" >> ${CONFIGdir}/${host}_profile.sh
	echo '    # Run remote load checks' >> ${CONFIGdir}/${host}_profile.sh
	echo '    # To set custom alert level: load_checks.sh 35 50' >> ${CONFIGdir}/${host}_profile.sh
	echo '    # Where $1 == Warning threshold' >> ${CONFIGdir}/${host}_profile.sh
	echo '    # Where $2 == Error threshold' >> ${CONFIGdir}/${host}_profile.sh
	echo '    ssh -q -x -o stricthostkeychecking=no -o PasswordAuthentication=no ${host} \' >> ${CONFIGdir}/${host}_profile.sh
	echo '	"${DRSMHOME}/health_check_scripts/load_checks.sh" > ${OUTPUTdir}/${host}/load.txt' >> ${CONFIGdir}/${host}_profile.sh
	echo "" >> ${CONFIGdir}/${host}_profile.sh
	echo '    # Run remote memory checks' >> ${CONFIGdir}/${host}_profile.sh
	echo '    # To set custom alert level: memory_checks.sh 256 1024 100' >> ${CONFIGdir}/${host}_profile.sh
	echo '    # Where $1 == Error if free memory is below value in MB' >> ${CONFIGdir}/${host}_profile.sh
	echo '    # Where $2 == Warning if using MB value or more of SWAP' >> ${CONFIGdir}/${host}_profile.sh
	echo '    # Where $3 == Number of processes to list' >> ${CONFIGdir}/${host}_profile.sh
	echo '    ssh -q -x -o stricthostkeychecking=no -o PasswordAuthentication=no ${host} \' >> ${CONFIGdir}/${host}_profile.sh
	echo '	"${DRSMHOME}/health_check_scripts/memory_checks.sh" > ${OUTPUTdir}/${host}/memory.txt' >> ${CONFIGdir}/${host}_profile.sh
	echo '' >> ${CONFIGdir}/${host}_profile.sh
	echo '    # Run remote network checks, checks all active NICs by default' >> ${CONFIGdir}/${host}_profile.sh
	echo "    # To set custom alert for specifed NICs: network_checks.sh 'eth0 eth1 eth2'" >> ${CONFIGdir}/${host}_profile.sh
	echo '    # Where $1 == Is a list of NICs to check' >> ${CONFIGdir}/${host}_profile.sh
	echo '    ssh -q -x -o stricthostkeychecking=no -o PasswordAuthentication=no ${host} \' >> ${CONFIGdir}/${host}_profile.sh
	echo '	"${DRSMHOME}/health_check_scripts/network_checks.sh" > ${OUTPUTdir}/${host}/network.txt' >> ${CONFIGdir}/${host}_profile.sh
	echo "" >> ${CONFIGdir}/${host}_profile.sh
	echo '    # Run remote user checks' >> ${CONFIGdir}/${host}_profile.sh
	echo "    # To set user alerts: user_checks.sh 'usr1 usr2' 'usr3 usr4'" >> ${CONFIGdir}/${host}_profile.sh
	echo '    # Where $1 == Report error for any user in list' >> ${CONFIGdir}/${host}_profile.sh
	echo '    # Where $2 == Report warning for any user in list' >> ${CONFIGdir}/${host}_profile.sh
	echo '    ssh -q -x -o stricthostkeychecking=no -o PasswordAuthentication=no ${host} \' >> ${CONFIGdir}/${host}_profile.sh
	echo '	"${DRSMHOME}/health_check_scripts/user_checks.sh" > ${OUTPUTdir}/${host}/user.txt' >> ${CONFIGdir}/${host}_profile.sh
	echo 'fi' >> ${CONFIGdir}/${host}_profile.sh
	echo "" >> ${CONFIGdir}/${host}_profile.sh
    fi

    if [ "${can_ping}" == "YES" ]
    then
	PingCheck ${host}
	if [ $? -ne 0 ] 
	then
	    echo "ERROR - Network connectivity failed on ${host}, ${description}" >> ${errorfile}
	    echo "IMPACT - ${host} down, ${impact}"
	    echo "ERROR - Network connectivity failed on ${host}" | tee -a ${statusfile}
	    has_errors="1"
            echo "ERROR - Network connectivity failed on ${host}" >> ${OUTPUTdir}/${host}/${host}_report.txt
            echo "" >> ${OUTPUTdir}/${host}/${host}_report.txt
            echo "INFO - End of ${host} system health check report" >> ${OUTPUTdir}/${host}/${host}_report.txt
            echo "" >> ${OUTPUTdir}/${host}/${host}_report.txt
	    cat ${OUTPUTdir}/${host}/${host}_report.txt > ${REPORTdir}/systems/${host}/${host}_report.txt
	    cat ${OUTPUTdir}/${host}/${host}_report.txt > ${REPORTdir}/systems/${host}/archive/${host}_report_${DATEEXT}.txt
	    continue
	fi
    else
	echo "INFO - Network connectivity skipped for ${host}, ${description}" | tee -a ${statusfile}
    fi

    if [ "${can_ssh}" == "NO" ]
    then
	echo "INFO - Skipping SSH system checks on ${host} ${description}" | tee -a ${logfile}
	echo "INFO - Skipping SSH system checks" >> ${OUTPUTdir}/${host}/${host}_report.txt
	echo "" >> ${OUTPUTdir}/${host}/${host}_report.txt
	echo "INFO - End of ${host} system health check report" >> ${OUTPUTdir}/${host}/${host}_report.txt
	echo "" >> ${OUTPUTdir}/${host}/${host}_report.txt
	cat ${OUTPUTdir}/${host}/${host}_report.txt > ${REPORTdir}/systems/${host}/${host}_report.txt
	cat ${OUTPUTdir}/${host}/${host}_report.txt > ${REPORTdir}/systems/${host}/archive/${host}_report_${DATEEXT}.txt
	continue 
    fi

    SSHCheck ${host} | tee -a ${logfile}
    if [ $? -ne 0 ] 
    then
	echo "ERROR - Sytem report script cannot SSH to ${host}, ${description}"  | tee -a ${logfile}
	has_errors="1"
        echo "ERROR - Sytem report script cannot SSH to ${host}, ${description}" >> ${OUTPUTdir}/${host}/${host}_report.txt
        echo "" >> ${OUTPUTdir}/${host}/${host}_report.txt
        echo "INFO - End of ${host} system health check report" >> ${OUTPUTdir}/${host}/${host}_report.txt
        echo "" >> ${OUTPUTdir}/${host}/${host}_report.txt
	cat ${OUTPUTdir}/${host}/${host}_report.txt > ${REPORTdir}/systems/${host}/${host}_report.txt
	cat ${OUTPUTdir}/${host}/${host}_report.txt > ${REPORTdir}/systems/${host}/archive/${host}_report_${DATEEXT}.txt
	continue
    fi

    ssh -q -x -o stricthostkeychecking=no -o PasswordAuthentication=no "${host}" mkdir -p ${DRSMHOME}/health_check_scripts
    scp -q -o stricthostkeychecking=no -o PasswordAuthentication=no -p ${DRSMHOME}/bin/disk_checks.sh \
	${DRSMHOME}/bin/cpu_checks.sh \
	${DRSMHOME}/bin/load_checks.sh \
	${DRSMHOME}/bin/memory_checks.sh \
	${DRSMHOME}/bin/network_checks.sh \
	${DRSMHOME}/bin/user_checks.sh \
	${DRSMHOME}/bin/read_cpu_temps.sh \
	${host}:${DRSMHOME}/health_check_scripts/.

    source ${CONFIGdir}/${host}_profile.sh
    cat ${OUTPUTdir}/${host}/disk.txt >> ${OUTPUTdir}/${host}/${host}_report.txt
    echo "" >> ${OUTPUTdir}/${host}/${host}_report.txt
    cat ${OUTPUTdir}/${host}/cpu.txt >> ${OUTPUTdir}/${host}/${host}_report.txt
    echo "" >> ${OUTPUTdir}/${host}/${host}_report.txt
    cat ${OUTPUTdir}/${host}/load.txt >> ${OUTPUTdir}/${host}/${host}_report.txt
    echo "" >> ${OUTPUTdir}/${host}/${host}_report.txt
    cat ${OUTPUTdir}/${host}/memory.txt >> ${OUTPUTdir}/${host}/${host}_report.txt
    echo "" >> ${OUTPUTdir}/${host}/${host}_report.txt
    cat ${OUTPUTdir}/${host}/network.txt >> ${OUTPUTdir}/${host}/${host}_report.txt
    echo "" >> ${OUTPUTdir}/${host}/${host}_report.txt
    cat ${OUTPUTdir}/${host}/user.txt >> ${OUTPUTdir}/${host}/${host}_report.txt
    echo "" >> ${OUTPUTdir}/${host}/${host}_report.txt
    echo "INFO - End of ${host} system health check report" >> ${OUTPUTdir}/${host}/${host}_report.txt
    echo "" >> ${OUTPUTdir}/${host}/${host}_report.txt

    cat ${OUTPUTdir}/${host}/${host}_report.txt > ${REPORTdir}/systems/${host}/${host}_report.txt
    cat ${OUTPUTdir}/${host}/${host}_report.txt > ${REPORTdir}/systems/${host}/archive/${host}_report_${DATEEXT}.txt
    cat ${OUTPUTdir}/${host}/${host}_report.txt >> ${statusfile}

    echo "Health checks complete on ${host} ${description}" | tee -a ${logfile}
done

cat ${statusfile} > ${REPORTdir}/${systemhealthreportfile}.txt
cat ${statusfile} > ${REPORTdir}/archive/${systemhealthreportfile}_${DATEEXT}.txt

grep "ERROR - " ${statusfile} >> ${errorfile}
if [ "$?" == "0" ]
then
    has_errors="1"
fi

grep "WARNING - " ${statusfile} >> ${errorfile}
if [ "$?" == "0" ]
then
    has_warning="1"
fi

if [ "${has_errors}" == "0" ] && [ "${has_warning}" == "0" ]
    then
    echo "System health check did not report any WARNINGS or ERRORS" > ${errorfile}
fi

cat ${errorfile} > ${REPORTdir}/${systemhealthreportfile}_errors.txt
cat ${errorfile} > ${REPORTdir}/archive/${systemhealthreportfile}_errors_${DATEEXT}.txt

if [ "${has_errors}" == "1" ]
then
    echo "System health check reported errors, sending alert message" | tee -a ${logfile}
    SUBJECT="[!ALERT!] DRSM Health Checks Reported Errors"
    cat ${errorfile} > ${VARdir}/system_report_message.$$
    echo "" >> ${VARdir}/system_report_message.$$
    cat ${statusfile} >> ${VARdir}/system_report_message.$$
    BODY="${VARdir}/system_report_message.$$"
    TIMESPAN="4"
    SENDEMAIL="TRUE"
    SENDTEXT="TRUE"
    if [ "${reporttype}" == "DEV" ] 
    then 
	SENDTEXT="FALSE" 
	SUBJECT="[!ALERT!] DRSM Dev Systems Health Checks Reported Errors"
	TIMEFILE="${VARdir}/email_alert_dev.timefile"
	INITFILE="${VARdir}/email_alert_dev.initfile"
    fi
    source ${DRSMHOME}/bin/text_email_alert.sh
    email_alert "${SUBJECT}" "${BODY}"
    rm -f ${VARdir}/system_report_message.$$
    RemoveLockFile
    exit 1
fi

if [ "${has_warning}" == "1" ]
then
    if [ "${emailstatusreport}" == "YES" ] 
    then 
	echo "System health check reported warnings, sending status message" | tee -a ${logfile}
	SUBJECT="[!INFO!] DRSM System Health Checks Reported Warnings"
	cat ${errorfile} > ${VARdir}/system_report_message.$$
	echo "" >> ${VARdir}/system_report_message.$$
	cat ${statusfile} >> ${VARdir}/system_report_message.$$
	BODY="${VARdir}/system_report_message.$$"
	TIMESPAN="4"
	SENDEMAIL="TRUE"
	SENDTEXT="FALSE"
	if [ "${reporttype}" == "DEV" ] 
	then 
	    SUBJECT="[!INFO!] DRSM Dev Systems Health Checks Reported Warnings"
	    TIMEFILE="${VARdir}/email_alert_dev.timefile"
	    INITFILE="${VARdir}/email_alert_dev.initfile"
	fi
	source ${DRSMHOME}/bin/text_email_alert.sh
	email_alert "${SUBJECT}" "${BODY}"
	rm -f ${VARdir}/email_alert.*
	rm -f ${VARdir}/system_report_message.$$
	RemoveLockFile
    else
	echo "System health check reported warnings, not sending any status messages" | tee -a ${logfile}
    fi	
    RemoveLockFile
    exit 2
fi

if [ "${emailstatusreport}" == "YES" ] 
then 
    echo "All systems check good, sending status message, sening status message" | tee -a ${logfile}
    SUBJECT="[!INFO!] DRSM Systems Health Check Report"
    BODY=${statusfile}
    TIMESPAN="4"
    SENDEMAIL="TRUE"
    SENDTEXT="FALSE"
    if [ "${reporttype}" == "DEV" ] 
    then 
	SUBJECT="[!INFO!] DRSM Dev Systems Systems Health Check Report"
	TIMEFILE="${VARdir}/email_alert_dev.timefile"
	INITFILE="${VARdir}/email_alert_dev.initfile"
    fi
    source ${DRSMHOME}/bin/text_email_alert.sh
    email_alert "${SUBJECT}" "${BODY}"
    rm -f ${VARdir}/email_alert.*
    RemoveLockFile
    exit 0
fi

echo "All systems health check good, not sending any status messages" | tee -a ${logfile}
RemoveLockFile
exit 0
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
