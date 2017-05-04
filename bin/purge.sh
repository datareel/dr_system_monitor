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
# DRSM purge script
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

# Age off $VARdir files
if [ -d ${VARdir} ]; then
    echo "Purging ${VARdir}"
    find ${VARdir} -type f -mmin +${TEMPfile_age} -print | xargs rm -fv &> ${LOGdir}/var_purge.log
fi

# Age off report files
if [ -d ${REPORTdir} ]; then
    echo "Purging ${REPORTdir}"
    find ${REPORTdir} -type f -mtime +${REPORTSfile_age} -print | xargs rm -fv &> ${LOGdir}/reports_purge.log
fi

# Age off files in our offline report archive
if [ -d ${OFFLINEarchive} ]; then
    echo "Purging ${OFFLINEarchive}"
    find ${OFFLINEarchive} -type f -mtime +${OFFLINEfile_age} -print | xargs rm -rfv &> ${LOGdir}/reports_purge.log
fi

exit 0
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
