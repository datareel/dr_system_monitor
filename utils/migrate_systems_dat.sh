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
# Convert systems.dat rows and their <host>_profile.sh scripts into
# host config files for bin/drsm_run.sh.
#
# Usage: migrate_systems_dat.sh [-f] [-o output dir] [dat file group] ...
#   -f  Overwrite host files that already exist
#   -o  Output directory, default ${DRSMHOME}/etc/hosts
# With no dat files, converts ${CONFIGdir}/systems.dat as group
# production and ${CONFIGdir}/dev_systems.dat as group dev.
#
# Custom arguments in a profile script, for example
# disk_checks.sh '/archive' 85 95, become plugin settings such as
# storage_disk_SKIP. Old files are left in place.
#
# ----------------------------------------------------------- 
if [ "${BASEdir}" == "" ]; then export BASEdir="${HOME}/drsm"; fi
if [ -f "${HOME}/.drsm.sh" ]; then CONFIG_FILE="${HOME}/.drsm.sh"; else CONFIG_FILE="${BASEdir}/etc/drsm.sh"; fi
if [ ! -f "${CONFIG_FILE}" ]; then echo "Missing base config ${CONFIG_FILE}"; exit 1; fi
# shellcheck source=etc/drsm.sh
source "${CONFIG_FILE}"
# shellcheck source=bin/system_functions.sh
source "${DRSMHOME}/bin/system_functions.sh"

force="0"
outdir="${HOSTSdir:-${DRSMHOME}/etc/hosts}"
while getopts "fo:h" opt; do
    case "${opt}" in
	f) force="1" ;;
	o) outdir="${OPTARG}" ;;
	*) sed -n '/^# Usage:/,/^# storage_disk_SKIP/p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

pairs=("$@")
if [ ${#pairs[@]} -eq 0 ]; then
    pairs=("${CONFIGdir}/systems.dat" production)
    if [ -f "${CONFIGdir}/dev_systems.dat" ]; then pairs+=("${CONFIGdir}/dev_systems.dat" dev); fi
fi
mkdir -p "${outdir}"

# Old check script, plugin ID, and the plugin setting for each
# positional argument
declare -A PLUGIN_OF=(
    [disk]="storage/disk" [cpu]="core/cpu" [load]="core/load"
    [memory]="core/memory" [network]="network/nics" [user]="core/users"
)
declare -A ARGS_OF=(
    [disk]="SKIP WARN CRIT" [cpu]="WARN CRIT NUMPROCS" [load]="WARN CRIT"
    [memory]="MIN_AVAIL_MB SWAP_WARN_MB NUMPROCS"
    [network]="NICS MAX_DROPPED MAX_COLLISIONS MAX_ERRORS SAMPLE_SECS"
    [user]="ERROR_USERS WARN_USERS"
)
ORDER="disk cpu load memory network user"

function profile_settings()
{
    # Print PLUGINS= and the settings found in profile script $1
    local profile="${1}" line check rest plugins="" prefix i names a
    local -A found=() argstr=()
    while IFS= read -r line
    do
	line="${line#"${line%%[![:space:]]*}"}"
	if [ "${line:0:1}" == "#" ]; then continue; fi
	if [[ "${line}" =~ ([a-z]+)_checks\.sh(.*)$ ]]; then
	    check="${BASH_REMATCH[1]}"
	    rest="${BASH_REMATCH[2]%%>*}"
	    rest="${rest#\"}"
	    rest="${rest%"${rest##*[![:space:]]}"}"
	    rest="${rest%\"}"
	    if [ "${PLUGIN_OF[${check}]}" == "" ]; then continue; fi
	    found[${check}]=1
	    argstr[${check}]="${rest}"
	fi
    done < "${profile}"

    for check in ${ORDER}; do
	if [ "${found[${check}]}" == "" ]; then continue; fi
	plugins="${plugins} ${PLUGIN_OF[${check}]}"
	if [ "${check}" == "disk" ]; then plugins="${plugins} storage/raid"; fi
    done
    echo "PLUGINS=\"${plugins# }\""

    for check in ${ORDER}; do
	if [ "${argstr[${check}]}" == "" ]; then continue; fi
	prefix="${PLUGIN_OF[${check}]//\//_}"
	read -ra names <<< "${ARGS_OF[${check}]}"
	i=0
	# xargs splits on spaces and honors quotes without running anything
	while IFS= read -r a; do
	    if [ "${names[${i}]}" == "" ]; then break; fi
	    if [ "${a^^}" == "NONE" ]; then a=""; fi
	    echo "${prefix}_${names[${i}]}=\"${a}\""
	    i=$((i + 1))
	done < <(echo "${argstr[${check}]}" | xargs -n 1 printf '%s\n' 2> /dev/null)
    done
}

count=0
for (( p=0; p < ${#pairs[@]}; p=p+2 ))
do
    dat="${pairs[${p}]}"
    grp="${pairs[$((p + 1))]:-production}"
    if ! LoadSystemList "${dat}" 0; then echo "WARNING - ${dat} not found, skipped"; continue; fi
    for entry in "${SYSTEMLIST[@]}"
    do
	ParseSystemEntry "${entry}"
	out="${outdir}/${host}.conf"
	if [ -f "${out}" ] && [ "${force}" == "0" ]; then
	    echo "INFO - ${out} exists, skipped (use -f to overwrite)"
	    continue
	fi
	probes=""
	if [ "${can_ping}" == "YES" ]; then probes="network/ping"; fi
	if [ "${is_web_server}" == "YES" ]; then
	    for w in ${WEBPROTOS}; do probes="${probes} network/${w,,}"; done
	fi
	platform="linux"
	if [ "${is_linux}" != "YES" ]; then platform="other"; fi
	collector="ssh"
	if [ "${can_ssh}" != "YES" ]; then collector="none"; fi
	{
	    echo "# Host file for drsm_run.sh, migrated from ${dat} on $(date +%Y-%m-%d)"
	    echo "# See etc/hosts/example.conf_example for every key"
	    echo "HOST=${host}"
	    echo "DESCRIPTION=\"${description}\""
	    echo "IMPACT=\"${impact}\""
	    echo "GROUP=${grp}"
	    echo "PLATFORM=${platform}"
	    echo "COLLECTOR=${collector}"
	    echo "PROBES=\"${probes# }\""
	    if [ "${is_cluser_ip}" == "YES" ]; then
		echo "# Cluster address, probes only"
		echo "PLUGINS=\"\""
	    elif [ "${platform}" != "linux" ]; then
		echo "# Not a Linux host, set PLATFORM and PLUGINS when a collector is available"
		echo "PLUGINS=\"\""
	    elif [ -f "${CONFIGdir}/${host}_profile.sh" ]; then
		echo "# Plugins and settings from ${CONFIGdir}/${host}_profile.sh"
		profile_settings "${CONFIGdir}/${host}_profile.sh"
	    else
		echo "# PLUGINS comes from _defaults.conf"
	    fi
	} > "${out}"
	echo "INFO - Wrote ${out}"
	count=$((count + 1))
    done
done
echo "Migrated ${count} host(s) to ${outdir}"
echo "Check the result with: ${DRSMHOME}/bin/drsm_run.sh -l"
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
