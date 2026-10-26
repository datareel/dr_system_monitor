#!/bin/bash
# ----------------------------------------------------------- 
# BASH Script
# Operating System(s): RHEL/CENTOS
# Run Level(s): 3, 5
# Shell: BASH shell
# Original Author(s): DataReel Software Development
# File Creation Date: 10/26/2026
# Date Last Modified: 10/26/2026
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
# DRSM plugin: disk I/O counters for capacity planning. Reads
# /proc/diskstats for whole disks and reports the read and write
# operations and bytes since boot. The trends page turns the change
# between runs into average IOPS and throughput, which is what cloud
# block storage (AWS EBS gp3 IOPS and MB/s) is sized and billed on.
# A short sample also gives the current rate as a rough peak.
#
# ----------------------------------------------------------- 
# shellcheck source=lib/drsm_plugin.sh
source "${DRSM_LIB:-$(dirname "$0")/../../../lib}/drsm_plugin.sh"

DEVICES=$(drsm_setting DEVICES "")
SAMPLE_SECS=$(drsm_setting SAMPLE_SECS 5)
if drsm_is_none "${DEVICES}"; then DEVICES=""; fi

if [ ! -r /proc/diskstats ]; then
    drsm_unknown "${HOST} has no /proc/diskstats"
    drsm_exit
fi

# Whole disks only, partitions are already counted in their disk.
# Fields: major minor name reads merged sectors_read ms writes merged
# sectors_written, sectors are always 512 bytes in /proc/diskstats.
function diskstats()
{
    awk -v devs=" ${DEVICES} " '
	{
	    n = $3
	    if (devs != "  ") { if (index(devs, " " n " ") == 0) next }
	    else if (n !~ /^(nvme[0-9]+n[0-9]+|[shv]d[a-z]+|xvd[a-z]+|mmcblk[0-9]+)$/) next
	    print n, $4, $6 * 512, $8, $10 * 512
	}' /proc/diskstats
}

declare -A r_ops r_bytes w_ops w_bytes
while read -r dev rops rbytes wops wbytes
do
    r_ops[$dev]=${rops}; r_bytes[$dev]=${rbytes}
    w_ops[$dev]=${wops}; w_bytes[$dev]=${wbytes}
done < <(diskstats)

if [ ${#r_ops[@]} -eq 0 ]; then
    drsm_unknown "${HOST} no disks found in /proc/diskstats"
    drsm_exit
fi

sleep "${SAMPLE_SECS}"
if [ "${SAMPLE_SECS}" -le 0 ]; then SAMPLE_SECS=1; fi

echo "Disk I/O for ${HOST}, current rate over ${SAMPLE_SECS} seconds"
while read -r dev rops rbytes wops wbytes
do
    if [ "${r_ops[$dev]}" == "" ]; then continue; fi
    iops=$(( (rops - r_ops[$dev] + wops - w_ops[$dev]) / SAMPLE_SECS ))
    kbps=$(( (rbytes - r_bytes[$dev] + wbytes - w_bytes[$dev]) / 1024 / SAMPLE_SECS ))
    echo "${dev}: ${iops} IOPS, ${kbps} KB/s"
    lbl="dev=\"${dev}\""
    drsm_metric diskio_read_ops "${rops}" "${lbl}"
    drsm_metric diskio_write_ops "${wops}" "${lbl}"
    drsm_metric diskio_read_bytes "${rbytes}" "${lbl}"
    drsm_metric diskio_write_bytes "${wbytes}" "${lbl}"
    drsm_metric diskio_sample_iops "${iops}" "${lbl}"
    drsm_metric diskio_sample_kbps "${kbps}" "${lbl}"
done < <(diskstats)

drsm_exit
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
