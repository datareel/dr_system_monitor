# ----------------------------------------------------------- 
# BASH Script
# Operating System(s): RHEL/CENTOS
# Run Level(s): 3, 5
# Shell: BASH shell
# Original Author(s): DataReel Software Development
# File Creation Date: 08/01/2008
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
# Include script used to text and email system or process alearts
#
# -----------------------------------------------------------
if [ "${BASEdir}" == "" ]; then export BASEdir="${HOME}/drsm"; fi

if [ ! -f ${BASEdir}/etc/drsm.sh ]; then
    echo "ERROR - Cannot find base config ${BASEdir}/etc/drsm.sh"
    exit 1
fi

source ${BASEdir}/etc/drsm.sh

if [ "${ALERTdir}" == "" ]; then export ALERTdir="${BASEdir}/etc"; fi
if [ "${LISTNAME}" == "" ]; then export LISTNAME="alert"; fi

# This is the timespan between email messages to prevent a flood of email messages.
# The default is 4 hours between messages for all callers. Any process can override 
# if the system or process needs to set more or less frequently.  
if [ "${TIMESPAN}" == "" ]; then export TIMESPAN="4"; fi
if [ "${TIMEFILE}" == "" ]; then export TIMEFILE="${VARdir}/email_alert.timefile"; fi
if [ "${INITFILE}" == "" ]; then export INITFILE="${VARdir}/email_alert.initfile"; fi

SENDALERT="TRUE"
if [ "${SENDEMAIL}" == "" ]; then export SENDEMAIL="TRUE"; fi
if [ "${SENDTEXT}" == "" ]; then export SENDTEXT="TRUE"; fi

if [ ! -e ${TIMEFILE} ]
    then
    date +%s > ${TIMEFILE}
    chmod 666 ${TIMEFILE}
fi

LASTTIME=$(cat ${TIMEFILE})
CURRTIME=$(date +%s)

TIMESPAN_SECS=$(echo "${TIMESPAN} * 3600" | bc)
ELAPSED_SECS=$(echo "${CURRTIME} - ${LASTTIME}" | bc)

HRS=$(echo "${ELAPSED_SECS} / 3600" | bc)
MIN=$(echo "${ELAPSED_SECS} % 3600 / 60" | bc)
SEC=$(echo "${ELAPSED_SECS} % 3600 % 60" | bc)

echo -n "Our last alert email was sent: "
if [ $HRS -gt 0 ]
    then
    echo -n "$HRS hours "
fi
if [ $MIN -gt 0 ]
    then
    echo -n "$MIN minutes "
fi
if [ $SEC -gt 0 ]
    then
    if [ $MIN -gt 0 ]
	then
	echo -n "and $SEC seconds "
    elif [ $HRS -gt 0 ]
	then
	echo -n "and $SEC  seconds "
    else
	echo -n "$SEC seconds "
    fi
fi
echo "ago." 

if [ ${ELAPSED_SECS} -lt ${TIMESPAN_SECS} ] && [ -e ${INITFILE} ]
    then
    echo "INFO - No alert message will be sent."
    echo "We are only sending alerts every ${TIMESPAN} hours."
    SENDALERT="FALSE"
else
    date +%s > ${INITFILE}
    chmod 666 ${INITFILE}
    echo "Sending alert email..."
    date +%s > ${TIMEFILE}
    chmod 666 ${TIMEFILE}
    SENDALERT="TRUE"
fi

# Setup the comma delimited the admins list from host-based config file
if [ "${EMAILlist}" == "" ]
    then 
    if [ -e $ALERTdir/${LISTNAME}.email.list ]
	then
	source $ALERTdir/${LISTNAME}.email.list
    else
	touch $ALERTdir/${LISTNAME}.email.list
	echo "# Set your comma delimited list here" >> $ALERTdir/${LISTNAME}.email.list
	echo 'export EMAILlist="root"' >> $ALERTdir/${LISTNAME}.email.list
	source $ALERTdir/${LISTNAME}.email.list
    fi
fi

# Set the comma delimited admin list here if not set above
if [ "${EMAILlist}" == "" ]; then export EMAILlist="root"; fi

function email_alert() {
    # Caller must provide SUBJECT and BODY aguments
    # 
    # SUBJECT="Error Message"
    # BODY="Short text string or file name"
    #
    # source ~/Desktop/meetings/email_alert.sh
    # email_alert "$SUBJECT" "$BODY"
    #
    # Caller can also provide an option email list as arg #3
    #
    # EMAILlist="root, sysadmins, backupusers"
    # email_logs "$SUBJECT" "$BODY" "$EMAILlist"

    if [ "${SENDALERT}" == "FALSE" ]; then return; fi

    SUBJECT="$1"
    BODY="$2"
    HOSTNAME=`hostname`
    PROC=`ps -ef | grep $$ | grep -v grep`

    if [ "$3" != "" ]
	then
	EMAILlist="$3"
    fi

    if [ "$SUBJECT" == "" ]
	then
	SUBJECT="[!ACTION!] Alert Message From $HOSTNAME"
    fi

    if [ "$BODY" == "" ]
	then
	cat /dev/null > ${VARdir}/body.$$
	echo "Alert message from process: " >> ${VARdir}/body.$$
 	echo "$PROC" >> ${VARdir}/body.$$
	BODY="${VARdir}/body.$$"
    fi

    if [ ! -e "$BODY" ]
	then
	cat /dev/null > ${VARdir}/body.$$
	echo "$BODY" >> ${VARdir}/body.$$
	BODY="${VARdir}/body.$$"
    fi

    if [ "$EMAILlist" != "" ] && [ "${SENDEMAIL}" == "TRUE" ]
    then
	echo "Emailing message to: $EMAILlist"
	/bin/mail -s "$SUBJECT" $EMAILlist < $BODY 
    fi

    if [ "$TEXTlist" != "" ]  && [ "${SENDTEXT}" == "TRUE" ]
    then
	echo "Text messaging to: $TEXTlist"
	/bin/mail -s "$SUBJECT" $TEXTlist < $BODY 
    fi
    
    # Remove any temp files
    if [ -e ${VARdir}/body.$$ ]
	then
	rm -f ${VARdir}/body.$$
    fi
}

# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
