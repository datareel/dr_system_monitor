#!/bin/bash
# DRSM master configuration file

# Internal Web server setup
# UNIX path of our Web directory
export WWWdir=/var/www/html/sysadmin
# Web path
export WWWvpath="/$(basename $WWWdir)" 
export REPORTdir=${WWWdir}/reports
export REPORTvpath=${WWWvpath}/reports
export REPORTarchive=${WWWdir}/reports/archive
export REPORTarchivevpath=${WWWvpath}/reports/archive
export CONFIGdir=${WWWdir}/config
export SITEincludes=${WWWdir}/site

# Setup umask, user name, and group name for the sysadmin account
umask 0002
export SYSADMIN_USERNAME=sysadmin
export SYSADMIN_GROUPNAME=sysadmin

# Set the timezone
export TZ=UTC

# Purge and archive settings
# Age off $VARdir files in minutes
export TEMPfile_age=60
# Age off report files in days
export REPORTSfile_age=3
# Age off offline report files in days
export OFFLINEfile_age=30

# Our DRSM home directory
export DRSMHOME=${HOME}/drsm
if [ "$(whoami)" != "${SYSADMIN_USERNAME}" ]; then
    export DRSMHOME=/home/${SYSADMIN_USERNAME}/drsm
fi

# Offline permanent archive location, to keep offline report backups
export OFFLINEarchive=${DRSMHOME}/report_archives
if [ ! -d ${OFFLINEarchive} ]; then mkdir -p ${OFFLINEarchive}; fi

# Offline report name prefix
export OFFLINEprefix="drsm_report_archive"

# Set DIRs for logs, temp and spool files
export TEMPdir="/tmp/${SYSADMIN_USERNAME}/drsm"
export LOGdir="${TEMPdir}/logs"
export VARdir="${TEMPdir}/var"
export SPOOLdir="${TEMPdir}/spool"

if [ ! -d ${TEMPdir} ]; then mkdir -p ${TEMPdir}; fi
if [ ! -d ${LOGdir} ]; then mkdir -p ${LOGdir}; fi
if [ ! -d ${VARdir} ]; then mkdir -p ${VARdir}; fi
if [ ! -d ${SPOOLdir} ]; then mkdir -p ${SPOOLdir}; fi

if [ "$(whoami)" != "${SYSADMIN_USERNAME}" ]; then
    for d in ${TEMPdir} ${LOGdir} ${VARdir} ${SPOOLdir} ${OFFLINEarchive}; do
	chown ${SYSADMIN_USERNAME}:${SYSADMIN_GROUPNAME} ${d}
    done 
fi
