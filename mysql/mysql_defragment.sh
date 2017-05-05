#!/bin/bash
# ----------------------------------------------------------- 
# BASH Script
# Operating System(s): RHEL/CENTOS
# Run Level(s): 3, 5
# Shell: BASH shell
# Original Author(s): DataReel Software Development
# File Creation Date: 06/10/2013
# Date Last Modified: 05/04/2017
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
# Collect my SQL table stats and defrag if auto dfrag is enabled
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

host="$1"
username="$2"
pass="$3"
autodefrag="$4"

if [ "$host" == "" ]; then echo -n "MySQL host: " ; read host; fi
if [ "$username" == "" ]; then echo -n "MySQL username: " ; read username; fi
if [ "$pass" == "" ]; then echo -n "MySQL pass: " ; stty -echo ; read pass ; stty echo ; echo; fi
if [ "$autodefrag" == "" ]; then echo -n "Auto Defrag (YES/NO): "; read autodefrag; fi
if [ "$autodefrag" != "YES" ]; then autodefrag="NO"; fi

REPORTdir="${REPORTdir}/mysql_servers"
OUTPUTdir="${VARdir}/collect_mysql_stats.tmp"
logfile="${LOGdir}/mysql_defrag_${host}.log"
PROGRAMname="$0"
LOCKfile="${VARdir}/mysql_defrag_${host}.lck"
MINold="15"
verbose="false"

if [ ! -e ${VARdir} ]; then mkdir -p ${VARdir}; fi
source ${DRSMHOME}/bin/process_lock.sh

LockFileCheck $MINold
CreateLockFile

if [ ! -e ${LOGdir} ]; then mkdir -p ${LOGdir}; fi
if [ ! -e ${OUTPUTdir}/${host}/table_stats ]; then mkdir -p ${OUTPUTdir}/${host}/table_stats; fi
if [ ! -e ${REPORTdir}/${host}/archive ]; then mkdir -p ${REPORTdir}/${host}/archive; fi

PROCdir="${OUTPUTdir}/${host}"

if [ "${verbose}" == "true" ]; then echo "Writing table stats to ${PROCdir}/table_stats"; fi
cat /dev/null > ${PROCdir}/table_stats/fraglist.txt

mysql -h $host -u $username -p"$pass" -NBe "SHOW DATABASES;" | grep -v 'lost+found' | while read database ; do
    mysql -h $host -u $username -p"$pass" -NBe "SHOW TABLE STATUS;" $database | while read name engine version rowformat rows avgrowlength datalength maxdatalength indexlength datafree autoincrement createtime updatetime checktime collation checksum createoptions comment ; do

	fname="${PROCdir}/table_stats/${database}_${name}.txt"
	cat /dev/null > ${fname}
	echo "database: $database" >> ${fname}
	echo "name: $name " >> ${fname}
	echo "engine: $engine " >> ${fname}
	echo "version: $version " >> ${fname}
	echo "rowformat: $rowformat " >> ${fname}
	echo "rows: $rows " >> ${fname}
	echo "avgrowlength: $avgrowlength " >> ${fname}
	echo "datalength: $datalength " >> ${fname}
	echo "maxdatalength: $maxdatalength " >> ${fname}
	echo "indexlength: $indexlength " >> ${fname}
	echo "datafree: $datafree " >> ${fname}
	echo "autoincrement: $autoincrement " >> ${fname}
	echo "createtime: $createtime " >> ${fname}
	echo "updatetime: $updatetime " >> ${fname}
	echo "checktime: $checktime " >> ${fname}
	echo "collation: $collation " >> ${fname}
	echo "checksum: $checksum " >> ${fname}
	echo "createoptions: $createoptions " >> ${fname}
	echo "comment: $comment" >> ${fname}

	if [ -z ${datafree} ]; then datafree=0; fi
	if [ ${datafree} == NULL ] || [ "${datafree}" == "NULL" ]; then datafree=0; fi

	if [ $datafree -gt 0 ] ; then
	    fragmentation=$(($datafree * 100 / $datalength))
	    echo "$database.$name is $fragmentation% fragmented." | tee -a ${PROCdir}/table_stats/fraglist.txt
	    if [ "$autodefrag" == "YES" ]
		then 
		cat /dev/null > "${PROCdir}/table_stats/${database}_${name}_defrag.txt"
		echo "Defragmenting $database DB $name TABLE" | tee -a ${PROCdir}/table_stats/${database}_${name}_defrag.txt
		mysql -h $host -u "$username" -p"$pass" -NBe "OPTIMIZE TABLE $name;" "$database" | tee -a ${PROCdir}/table_stats/${database}_${name}_defrag.txt
	    fi
	fi
    done
done

cat ${PROCdir}/table_stats/fraglist.txt | wc -l > ${PROCdir}/table_stats/numfrag.txt

RemoveLockFile
exit 0
# -----------------------------------------------------------
# *******************************
# ********* End of File *********
# *******************************
