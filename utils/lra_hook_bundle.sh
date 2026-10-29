#!/bin/bash
# ----------------------------------------------------------- 
# BASH Script
# Operating System(s): RHEL/CENTOS
# Run Level(s): 3, 5
# Shell: BASH shell
# Original Author(s): DataReel Software Development
# File Creation Date: 10/29/2026
# Date Last Modified: 10/29/2026
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
#
# Write a DRSM plugin as one self-contained report hook for the
# DataReel Reporting Agent for Linux. The hook goes in
# /etc/drra/report.d on the host; the agent runs it with every report
# and DRSM shows its output on COLLECTOR=lra hosts, as the plugin when
# its manifest sets LRA_HOOK, or in linux/hooks. The hook holds
# lib/drsm_plugin.sh, the plugin's check.sh and its settings: the
# manifest defaults, then <category>_<name>_<KEY> lines from the -f
# host files, then KEY=value arguments. It writes to standard output
# only.
#
# Usage: lra_hook_bundle.sh [-f host file]... plugin-id [KEY=value]...
#
#   $ ~/drsm/utils/lra_hook_bundle.sh -f ~/drsm/etc/hosts/node1.conf \
#         cluster/drcm TUNNEL_SERVICES=drcm-tunnel > drcm
#   $ scp drcm node1: ; ssh node1 sudo install -o root -g root -m 0755 drcm /etc/drra/report.d/drcm
#   $ ssh node1 sudo drra hooks
#
# The hook name is the file name (without .sh), the plugin's LRA_HOOK.
#
# ----------------------------------------------------------- 
TOPdir=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=lib/drsm_conf.sh
source "${TOPdir}/lib/drsm_conf.sh"

function usage()
{
    echo "Usage: ${0} [-f host file]... plugin-id [KEY=value]..." >&2
    exit 1
}

hostfiles=()
while [ "${1}" == "-f" ]; do
    if [ "${2}" == "" ] || [ ! -r "${2}" ]; then echo "ERROR - cannot read host file ${2}" >&2; exit 1; fi
    hostfiles+=("${2}")
    shift 2
done
id="${1}"
if [ "${id}" == "" ]; then usage; fi
shift
if [[ ! "${id}" =~ ^[A-Za-z0-9_-]+/[A-Za-z0-9_.-]+$ ]]; then echo "ERROR - ${id} is not a plugin ID such as cluster/drcm" >&2; exit 1; fi
dir="${TOPdir}/plugins/${id}"
if [ ! -f "${dir}/check.sh" ] || [ ! -f "${dir}/plugin.conf" ]; then echo "ERROR - no plugin ${id} with check.sh in ${TOPdir}/plugins" >&2; exit 1; fi
if grep -q 'lra_report.sh' "${dir}/check.sh"; then echo "ERROR - ${id} reads agent reports on the monitor, it cannot run on the host" >&2; exit 1; fi

declare -A MAN=()
drsm_read_conf "${dir}/plugin.conf" MAN
prefix=$(drsm_plugin_key "${id}")
declare -A SET=()
for k in "${!MAN[@]}"; do
    if drsm_is_manifest_key "${k}" || [ "${k}" == "LRA_HOOK" ]; then continue; fi
    SET["${k}"]="${MAN[${k}]}"
done
for f in "${hostfiles[@]}"; do
    declare -A H=()
    drsm_read_conf "${f}" H
    for k in "${!H[@]}"; do
	if [[ "${k}" == "${prefix}_"* ]]; then
	    k2="${k#"${prefix}_"}"
	    if [ "${k2}" == "TIMEOUT" ] || [ "${k2}" == "LRA_HOOK" ]; then continue; fi
	    SET["${k2}"]="${H[${k}]}"
	fi
    done
    unset H
done
for a in "$@"; do
    if [[ ! "${a}" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then echo "ERROR - ${a} is not KEY=value" >&2; exit 1; fi
    SET["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
done

echo "#!/bin/bash"
echo "# DataReel Reporting Agent for Linux report hook: DRSM plugin ${id}"
echo "# Made by DRSM utils/lra_hook_bundle.sh on $(date '+%F %T %Z') from"
echo "# ${dir}. Install as root, mode 0755, in /etc/drra/report.d."
echo "# Prints DRSM plugin lines and exits 0 OK, 1 WARNING, 2 ERROR, 3 UNKNOWN."
echo ""
echo "# Plugin settings"
for k in $(printf '%s\n' "${!SET[@]}" | sort); do
    printf 'export DRSM_%s=%q\n' "${k}" "${SET[${k}]}"
done
echo "unset DRSM_LRA_REPORT DRSM_LRA_HOOK"
echo ""
echo "# ----- lib/drsm_plugin.sh -----"
sed '1{/^#!/d}' "${TOPdir}/lib/drsm_plugin.sh"
echo ""
echo "# ----- plugins/${id}/check.sh -----"
# The plugin's own source line for the helpers is not needed here
sed -e '1{/^#!/d}' -e '/^source "${DRSM_LIB:-\$(dirname "\$0")\/..\/..\/..\/lib}\/drsm_plugin.sh"$/d' "${dir}/check.sh"
exit 0
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
