#!/bin/bash
# ----------------------------------------------------------- 
# BASH Script
# Operating System(s): RHEL/CENTOS
# Run Level(s): 3, 5
# Shell: BASH shell
# Original Author(s): DataReel Software Development
# File Creation Date: 10/23/2026
# Date Last Modified: 10/23/2026
#
# Version control: 1.00
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
# DRSM plugin: disk space and inodes, ported from bin/disk_checks.sh.
# RAID checks moved to the storage/raid plugin.
#
# ----------------------------------------------------------- 
# shellcheck source=lib/drsm_plugin.sh
source "${DRSM_LIB:-$(dirname "$0")/../../../lib}/drsm_plugin.sh"

ALERT=$(drsm_setting WARN 90)
MAX=$(drsm_setting CRIT 99)
SKIPDIRS=$(drsm_setting SKIP "")
FSTYPES=$(drsm_setting FSTYPES "xfs ext2 ext3 ext4 btrfs zfs f2fs jfs reiserfs")
if drsm_is_none "${SKIPDIRS}"; then SKIPDIRS=""; fi

echo "Disk usage checks for ${HOST}"

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
    if [[ ! "${DISKSPACE}" =~ ^[0-9]+$ ]]; then continue; fi
    if [ "${DISKSPACE}" -ge "${ALERT}" ]
    then
	if [ "${DISKSPACE}" -ge "${MAX}" ]
	then
	    drsm_crit "${HOST}:${DIR} is full at ${DISKSPACE}% capacity."
	else
	    drsm_warn "${HOST}:${DIR} is at ${DISKSPACE}% capacity."
	fi
    else
	echo "${HOST}:${DIR} checks good at ${DISKSPACE}% capacity."
    fi
    drsm_metric disk_used_pct "${DISKSPACE}" "mount=\"${DIR}\""

    # Btrfs and ZFS do not use fixed inode tables and report "-"
    if [[ "${INODES}" =~ ^[0-9]+$ ]] && [ "${INODES}" -ge "${ALERT}" ]
    then
	if [ "${INODES}" -ge "${MAX}" ]
	then
	    drsm_crit "${HOST}:${DIR} is out of inodes at ${INODES}% inode usage."
	else
	    drsm_warn "${HOST}:${DIR} is at ${INODES}% inode usage."
	fi
    fi
done < <(df --output=fstype,pcent,ipcent,target 2> /dev/null | sed '1d' | sort -u -k4)

drsm_exit
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
