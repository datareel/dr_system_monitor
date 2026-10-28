#!/bin/bash
# -----------------------------------------------------------
# BASH Script
# Operating System(s): RHEL/CENTOS
# Run Level(s): 3, 5
# Shell: BASH shell
# Original Author(s): DataReel Software Development
# File Creation Date: 10/28/2026
# Date Last Modified: 10/28/2026
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
# List the hosts DRSM takes from the Ansible inventory (ANSIBLE_INVENTORY)
# or Ansible Tower / AWX (ANSIBLE_TOWER_URL), with their tier and group,
# to check ANSIBLE_TIERS. Reads only, changes nothing.
#
# Usage: drsm_ansible_hosts.sh [-f]
#   -f  Fetch from Tower now, not from the cached copy
#
# -----------------------------------------------------------
if [ "${BASEdir}" == "" ]; then export BASEdir="${HOME}/drsm"; fi
if [ -f "${DRSM_CONFIG:-${HOME}/.drsm.sh}" ]; then CONFIG_FILE="${DRSM_CONFIG:-${HOME}/.drsm.sh}"; else CONFIG_FILE="${BASEdir}/etc/drsm.sh"; fi
if [ ! -f "${CONFIG_FILE}" ]; then echo "Missing base config ${CONFIG_FILE}"; exit 1; fi
# shellcheck source=etc/drsm.sh
source "${CONFIG_FILE}"
# shellcheck source=lib/drsm_ansible.sh
source "${DRSMHOME}/lib/drsm_ansible.sh"

if [ "${1}" == "-f" ]; then ANSIBLE_TOWER_CACHE_MINUTES=0; fi
if [ "${ANSIBLE_TOWER_URL}" != "" ]; then
    ANSIBLE_INVENTORY=$(drsm_tower_inventory) || exit 1
    echo "Source: Ansible Tower ${ANSIBLE_TOWER_URL} inventory ${ANSIBLE_TOWER_INVENTORY} (copy ${ANSIBLE_INVENTORY})"
elif [ "${ANSIBLE_INVENTORY}" != "" ]; then
    echo "Source: ${ANSIBLE_INVENTORY}"
else
    echo "Neither ANSIBLE_INVENTORY nor ANSIBLE_TOWER_URL is set in ${CONFIG_FILE}"
    exit 1
fi
echo "Tiers: ${ANSIBLE_TIERS:-production=prod qa=qa dev=dev}"
echo ""
printf '%-40s %-12s %s\n' "HOST" "TIER" "GROUP"
drsm_ansible_hosts "${ANSIBLE_INVENTORY}" | while read -r h t g; do printf '%-40s %-12s %s\n' "${h}" "${t}" "${g}"; done
echo ""
for t in $(drsm_ansible_hosts "${ANSIBLE_INVENTORY}" | awk '{print $2}' | sort -u); do
    echo "${t}: $(drsm_ansible_hosts "${ANSIBLE_INVENTORY}" | awk -v t="${t}" '$2 == t' | wc -l) hosts"
done
exit 0
# -----------------------------------------------------------
# *******************************
# ********* End of File *********
# *******************************
