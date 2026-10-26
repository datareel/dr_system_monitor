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
# DRSM plugin: AWS EC2 instance facts from the instance metadata
# service (IMDSv2): instance type, region, zone, and the EBS volumes
# attached. The trends page shows them beside the measured use, so the
# instance and volume sizes being paid for can be compared with what
# the host needs. Prices, EBS volume types and provisioned IOPS are not
# in the metadata and need the AWS console or API.
#
# ----------------------------------------------------------- 
# shellcheck source=lib/drsm_plugin.sh
source "${DRSM_LIB:-$(dirname "$0")/../../../lib}/drsm_plugin.sh"

IMDS=$(drsm_setting IMDS_URL "http://169.254.169.254")
TIMEOUT=$(drsm_setting HTTP_TIMEOUT 3)

if ! command -v curl > /dev/null 2>&1; then
    drsm_unknown "${HOST} curl is not installed, cannot read EC2 metadata"
    drsm_exit
fi

TOKEN=$(curl -s -m "${TIMEOUT}" -X PUT "${IMDS}/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60" 2> /dev/null)

function imds()
{
    if [ "${TOKEN}" != "" ]; then
	curl -s -f -m "${TIMEOUT}" -H "X-aws-ec2-metadata-token: ${TOKEN}" "${IMDS}/latest/meta-data/${1}" 2> /dev/null
    else
	curl -s -f -m "${TIMEOUT}" "${IMDS}/latest/meta-data/${1}" 2> /dev/null
    fi
}

TYPE=$(imds instance-type)
if [ "${TYPE}" == "" ]; then
    drsm_unknown "${HOST} EC2 instance metadata is not reachable, not an EC2 instance or IMDS is off"
    drsm_exit
fi

echo "AWS EC2 instance facts for ${HOST}"
echo "Instance type: ${TYPE}"
echo "Instance ID: $(imds instance-id)"
echo "Availability zone: $(imds placement/availability-zone)"
echo "Region: $(imds placement/region)"
echo "Lifecycle: $(imds instance-life-cycle)"
echo "Public IPv4: $(imds public-ipv4)"

# EBS volumes as the guest sees them. On Nitro instances the NVMe
# serial is the EBS volume ID without its dash.
if command -v lsblk > /dev/null 2>&1; then
    echo "Volumes:"
    lsblk -b -d -n -o NAME,SIZE,SERIAL 2> /dev/null | while read -r name size serial
    do
	case "${name}" in loop*|ram*|zram*|sr*) continue ;; esac
	vol=""
	if [[ "${serial}" =~ ^vol([0-9a-f]+)$ ]]; then vol="vol-${BASH_REMATCH[1]}"; fi
	mounts=$(lsblk -n -o MOUNTPOINT "/dev/${name}" 2> /dev/null | awk 'NF { printf "%s%s", sep, $0; sep = ", " }')
	echo "Volume ${name}: $(( size / 1073741824 )) GiB ${vol}${mounts:+ mounted on ${mounts}}"
	drsm_metric ebs_volume_gib "$(( size / 1073741824 ))" "dev=\"${name}\""
    done
fi

drsm_exit
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
