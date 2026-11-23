#!/bin/bash

if [ "${BASEdir}" == "" ]; then export BASEdir="${HOME}/drsm"; fi

if [ -f ${DRSM_CONFIG:-${HOME}/.drsm.sh} ]; then
    echo "INFO - Using config override file ${DRSM_CONFIG:-${HOME}/.drsm.sh}"
    CONFIG_FILE=${DRSM_CONFIG:-${HOME}/.drsm.sh}
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

SUBJECT="[!ACTION!] ${SITEID} Alert Test Message"
BODY="This is an alert test message"

# Usage: test_alert.sh [all|email|push], all is the default
case "${1:-all}" in
    all) SENDEMAIL="TRUE"; SENDTEXT="TRUE" ;;
    email) SENDEMAIL="TRUE"; SENDTEXT="FALSE" ;;
    push|text) SENDEMAIL="FALSE"; SENDTEXT="TRUE" ;;
    *) echo "Usage: ${0} [all|email|push]"; exit 2 ;;
esac
export SENDEMAIL SENDTEXT

source ${DRSMHOME}/bin/text_email_alert.sh
email_alert "${SUBJECT}" "${BODY}"

exit 0
