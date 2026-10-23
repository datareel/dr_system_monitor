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
# Create a new plugin from a template.
#
# Usage: new_plugin.sh <category>/<name> [probe]
#   probe  makes a probe that runs on the monitor host against each
#          host, the default is a check that runs on the host
#
# New plugins go in plugins/local/<name> when the category is local,
# which DRSM updates never overwrite. Example:
#   new_plugin.sh local/myapp
#
# ----------------------------------------------------------- 
if [ "${1}" == "" ] || [[ ! "${1}" =~ ^[a-z0-9_-]+/[a-z0-9_-]+$ ]]; then
    sed -n '/^# Usage:/,/^#   new_plugin.sh local/p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
fi

TOPdir=$(cd "$(dirname "$0")/.." && pwd)
id="${1}"
category="${id%/*}"
name="${id#*/}"
mode="remote"
entry="check.sh"
if [ "${2}" == "probe" ]; then mode="probe"; entry="probe.sh"; fi
dir="${TOPdir}/plugins/${id}"
prefix="${id//\//_}"
prefix="${prefix//-/_}"

if [ -e "${dir}" ]; then
    echo "ERROR - ${dir} already exists"
    exit 1
fi
mkdir -p "${dir}"

platforms="linux"
if [ "${mode}" == "probe" ]; then platforms="any"; fi
cat > "${dir}/plugin.conf" <<CONF
# DRSM plugin manifest, see PLUGINS.md
NAME=${name}
CATEGORY=${category}
DESCRIPTION="Describe what ${name} checks"
# linux, windows, or any
PLATFORMS="${platforms}"
# remote runs ${entry} on the host, probe runs it on the monitor host
MODE=${mode}
# Seconds before the runner stops the plugin
TIMEOUT=30
# Commands that must exist, the plugin is UNKNOWN without them
REQUIRES=""
NEEDS_SUDO=no

# Settings, override per host with ${prefix}_<SETTING>=value.
# Each one reaches ${entry} as DRSM_<SETTING>.
WARN=80
CRIT=90
CONF

target_lines=""
if [ "${mode}" == "probe" ]; then
    target_lines='
# The host being checked
target=$(drsm_target) || exit 3
echo "Checking ${target}"'
fi

cat > "${dir}/${entry}" <<SCRIPT
#!/bin/bash
# DRSM plugin ${id}
#
# Print what you find, use drsm_warn and drsm_crit for problems, and
# end with drsm_exit. Run it by hand to test:
#   DRSM_WARN=50 bash plugins/${id}/${entry}
# shellcheck source=lib/drsm_plugin.sh
source "\${DRSM_LIB:-\$(dirname "\$0")/../../../lib}/drsm_plugin.sh"
${target_lines}
WARN=\$(drsm_setting WARN 80)
CRIT=\$(drsm_setting CRIT 90)

# Replace this with the real check
value=42

if [ "\${value}" -ge "\${CRIT}" ]; then
    drsm_crit "\${HOST} ${name} is at \${value}, at or above \${CRIT}"
elif [ "\${value}" -ge "\${WARN}" ]; then
    drsm_warn "\${HOST} ${name} is at \${value}, at or above \${WARN}"
else
    drsm_ok "\${HOST} ${name} checks good at \${value}"
fi
drsm_metric ${prefix} "\${value}"

drsm_exit
SCRIPT
chmod 755 "${dir}/${entry}"

echo "Created ${dir}"
echo "Edit ${dir}/plugin.conf and ${dir}/${entry}, then add ${id} to"
if [ "${mode}" == "probe" ]; then
    echo "PROBES in a host file under etc/hosts"
else
    echo "PLUGINS in a host file under etc/hosts"
fi
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
