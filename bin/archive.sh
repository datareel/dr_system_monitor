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

echo "Archiving reports to ${OFFLINEarchive}"
date

if [ ! -d ${OFFLINEarchive} ]
then
    echo "ERROR - Cannot access ${OFFLINEarchive}"
    exit 1
fi

YEAR=$(date +%Y)
MONTH=$(date +%m)
DAY=$(date +%d)

mkdir -p ${OFFLINEarchive}/${YEAR}/${MONTH}

# Keep DIR names for at lease ${OFFLINEfile_age}
touch ${OFFLINEarchive}
touch ${OFFLINEarchive}/${YEAR}
touch ${OFFLINEarchive}/${YEAR}/${MONTH}

if [ ! -d ${OFFLINEarchive}/${YEAR}/${MONTH} ]
then
    echo "ERROR - Cannot create ${OFFLINEarchive}/${YEAR}/${MONTH}"
    exit 1
fi

ARCHFILE="${OFFLINEarchive}/${YEAR}/${MONTH}/${OFFLINEprefix}_${YEAR}${MONTH}${DAY}.tar.gz"
if [ -e ${ARCHFILE} ]; then rm -f ${ARCHFILE}; fi

tar cvfz ${ARCHFILE} ${REPORTdir}

# Keep *.gz files for at lease ${OFFLINEfile_age}
touch ${OFFLINEarchive}/${YEAR}/${MONTH}/*.gz

date -u
echo "End of offline report archive"

exit 0
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
