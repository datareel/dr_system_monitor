#!/bin/bash

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

# Force a send each time we run the script
TIMESPAN="0"

SUBJECT="[!ACTION!] Alert Test Message"
BODY="This is an alert test message"

source ${DRSMHOME}/bin/text_email_alert.sh
email_alert "${SUBJECT}" "${BODY}"

exit 0
