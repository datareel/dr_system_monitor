#!/bin/bash
# DRSM master configuration file

export RUNdir=${HOME}/drsm

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
export APACHE_USERNAME=apache
export APACHE_GROUPNAME=apache

# Setup for the username, uid, and gid for the sysadmin account
export SYSADMIN_USERNAME=sysadmin
export SYSADMIN_GROUPNAME=sysadmin
export SYSADMIN_UID=2890
export SYSADMIN_GID=2890

# Set DIRs for logs, temp and spool files
export LOGdir="/tmp/${SYSADMIN_USERNAME}/drsm/logs"
export VARdir="/tmp/${SYSADMIN_USERNAME}/drsm/var"
export SPOOLdir="/tmp/${SYSADMIN_USERNAME}/drsm/spool"

# Optional custom overrrides configuration for testing
if [ -f ${HOME}/.drsm.sh ]; then source ${HOME}/.drsm.sh; fi

if [ ! -d ${LOGdir} ]; then mkdir -p ${LOGdir}; fi
if [ ! -d ${VARdir} ]; then mkdir -p ${VARdir}; fi
if [ ! -d ${SPOOLdir} ]; then mkdir -p ${SPOOLdir}; fi
