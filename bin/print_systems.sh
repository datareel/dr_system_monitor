#!/bin/bash
# ----------------------------------------------------------- 
# BASH Script
# Operating System(s): RHEL/CENTOS
# Run Level(s): 3, 5
# Shell: BASH shell
# Original Author(s): DataReel Software Development
# File Creation Date: 05/25/2013
# Date Last Modified: 05/05/2017
#
# Version control: 1.14
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
# DRSM util script used to print a list of systems for use
# as input to data call scripts.
#
# ----------------------------------------------------------- 
if [ "${BASEdir}" == "" ]; then export BASEdir="${HOME}/drsm"; fi

if [ -f ${HOME}/.drsm.sh ]; then
    CONFIG_FILE=${HOME}/.drsm.sh
else
    CONFIG_FILE=${BASEdir}/etc/drsm.sh
fi

if [ ! -f ${CONFIG_FILE} ]; then
    echo "Missing base config ${CONFIG_FILE}"
    exit 1
fi

source ${CONFIG_FILE}
source ${DRSMHOME}/bin/system_functions.sh

HOST=$(hostname -s)

cat ${CONFIGdir}/systems.dat > ${VARdir}/print_systems_linuxsystems.dat
cat ${CONFIGdir}/dev_systems.dat >> ${VARdir}/print_systems_linuxsystems.dat

dbfile="${VARdir}/print_systems_linuxsystems.dat"
PROGRAMname="$0"

if [ ! -e ${dbfile} ]
then
    has_errors="1"
    echo "ERROR - ${dbfile} not found"  >> ${errorfile}
    echo "ERROR - ${dbfile} not found"  | tee -a ${statusfile}
    exit 1
fi

cat /dev/null > ${VARdir}/printsystemslist.sh
echo "#!/bin/bash" >> ${VARdir}/printsystemslist.sh
echo -n 'export SYSTEMLIST="' >> ${VARdir}/printsystemslist.sh

sort ${dbfile} > ${VARdir}/printsystemslist_sorted.dat

while read line
do
    DATLINE=$(echo $line | grep -v "^#")
    if [ "${DATLINE}" != "" ]
    then
	DATLINE=$(echo "${DATLINE}" | sed s/' '/'%20'/g)
	echo -n "${DATLINE} " >> ${VARdir}/printsystemslist.sh
    fi
done < ${VARdir}/printsystemslist_sorted.dat

echo -n '"' >> ${VARdir}/printsystemslist.sh
sed -i s/' "'/'"'/g ${VARdir}/printsystemslist.sh
sed -i s/' ,'/','/g ${VARdir}/printsystemslist.sh

source ${VARdir}/printsystemslist.sh

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

    if [ "${is_cluser_ip}" == "YES" ] 
    then 
	continue 
    fi

    echo "$host"
done

exit 0
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
