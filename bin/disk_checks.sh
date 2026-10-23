#!/bin/bash
# ----------------------------------------------------------- 
# BASH Script
# Operating System(s): RHEL/CENTOS
# Run Level(s): 3, 5
# Shell: BASH shell
# Original Author(s): DataReel Software Development
# File Creation Date: 05/25/2013
# Date Last Modified: 10/23/2026
#
# Version control: 1.15
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
# System monitoring script for disk space 
#
# ----------------------------------------------------------- 
SKIPDIRS=""
ALERT=90
MAX=99
HOST=$(hostname -s)
has_error="0"
has_warning="0"
# Local disk file system types to check
FSTYPES="xfs ext2 ext3 ext4 btrfs zfs f2fs jfs reiserfs"

echo "Disk usage checks for ${HOST}"

if [ "${1}" != "" ] && [ "${1^^}" != "NONE" ]; then SKIPDIRS="${1}"; fi
if [ "${2}" != "" ]; then ALERT="${2}"; fi
if [ "${3}" != "" ]; then MAX="${3}"; fi

# Check every mounted local file system, including mounts that are
# not listed in /etc/fstab (systemd mount units, cloud-init disks).
# Columns: type, use%, inode use%, mount point
while read -r FSTYPE PCENT IPCENT DIR
do
    match=0
    for t in ${FSTYPES}; do
	if [ "${FSTYPE}" == "${t}" ]; then match=1; break; fi
    done
    if [ ${match} -eq 0 ]; then continue; fi

    skip_check=0
    for d in ${SKIPDIRS}
    do
	if [ "${DIR}" == "${d}" ]; then
	    echo "Skipping DIR check on ${d}"
	    skip_check=1
	    break
	fi
    done
    if [ ${skip_check} -eq 1 ]; then continue; fi

    DISKSPACE="${PCENT%\%}"
    INODES="${IPCENT%\%}"
    if [ "${DISKSPACE}" == "-" ] || [ "${DISKSPACE}" == "" ]; then continue; fi
    if [ ${DISKSPACE} -ge ${ALERT} ] 
    then
	if [ ${DISKSPACE} -ge ${MAX} ]
	then
	    echo "ERROR - ${HOST}:${DIR} is full at ${DISKSPACE}% capacity."
	    has_error="1"
	else
	    echo "WARNING - ${HOST}:${DIR} is at ${DISKSPACE}% capacity."
	    has_warning="1"
	fi
    else 
	echo "${HOST}:${DIR} checks good at ${DISKSPACE}% capacity."
    fi

    # Btrfs and ZFS do not use fixed inode tables and report "-"
    if [[ "${INODES}" =~ ^[0-9]+$ ]] && [ ${INODES} -ge ${ALERT} ]
    then
	if [ ${INODES} -ge ${MAX} ]
	then
	    echo "ERROR - ${HOST}:${DIR} is out of inodes at ${INODES}% inode usage."
	    has_error="1"
	else
	    echo "WARNING - ${HOST}:${DIR} is at ${INODES}% inode usage."
	    has_warning="1"
	fi
    fi
done < <(df --output=fstype,pcent,ipcent,target 2> /dev/null | sed '1d' | sort -u -k4)

SCRIPTdir=$(dirname "$(readlink -f "$0")")
if [ -f ${SCRIPTdir}/raid_checks.sh ]; then
    echo ""
    bash ${SCRIPTdir}/raid_checks.sh
    raid_rv=$?
    if [ ${raid_rv} -eq 2 ]; then has_error=1; fi
    if [ ${raid_rv} -eq 1 ]; then has_warning=1; fi
fi

if [ "${has_error}" == "1" ]
then
    exit 2
fi

if [ "${has_warning}" == "1" ]
then
    exit 1
fi

exit 0
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
