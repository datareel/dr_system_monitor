#!/bin/bash

if [ "${BASEdir}" == "" ]; then export BASEdir="${HOME}/drsm"; fi

if [ -f ${HOME}/.drsm.sh ]; then
    echo "INFO - Using config override file ${HOME}/.drsm.sh"
    export CONFIG_FILE=${HOME}/.drsm.sh
else
    echo "INFO - Using default config ${BASEdir}/etc/drsm.sh"
    export CONFIG_FILE=${BASEdir}/etc/drsm.sh
fi

if [ ! -f ${CONFIG_FILE} ]; then
    echo "Missing base config ${CONFIG_FILE}"
    exit 1
fi

source ${CONFIG_FILE}
source ${DRSMHOME}/bin/system_functions.sh

export OUTPUTdir="${VARdir}/system_report.tmp"

if [ ! -e ${VARdir} ]; then mkdir -p ${VARdir}; fi
if [ ! -e ${LOGdir} ]; then mkdir -p ${LOGdir}; fi
if [ ! -e ${OUTPUTdir} ]; then mkdir -p ${OUTPUTdir}; fi

