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
# Config file reader for plugin manifests and host files. The files are
# plain KEY=value lines. They are parsed, never sourced, so a config
# file cannot run commands on the monitor host.
#
# ----------------------------------------------------------- 
# Keys DRSM reads from a plugin.conf manifest. Every other key in a
# manifest is a plugin setting, passed to the plugin as DRSM_<KEY>.
DRSM_MANIFEST_KEYS="NAME CATEGORY DESCRIPTION PLATFORMS MODE TIMEOUT REQUIRES NEEDS_SUDO"

function drsm_read_conf()
{
    # Read a KEY=value file into an associative array. Later files
    # override earlier ones when called more than once.
    # $1 == config file, $2 == name of an associative array
    local file="${1}"
    local -n __drsm_conf_ref="${2}"
    local line key val n=0
    if [ ! -r "${file}" ]; then return 1; fi
    while IFS= read -r line || [ -n "${line}" ]
    do
	n=$((n + 1))
	line="${line%$'\r'}"
	line="${line#"${line%%[![:space:]]*}"}"
	if [ "${line}" == "" ] || [ "${line:0:1}" == "#" ]; then continue; fi
	line="${line#export }"
	if [[ ! "${line}" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
	    echo "WARNING - ${file} line ${n} is not KEY=value, ignored" >&2
	    continue
	fi
	key="${BASH_REMATCH[1]}"
	val="${BASH_REMATCH[2]}"
	# Quoted values keep everything inside the quotes, unquoted
	# values end at a space followed by a # comment
	if [[ "${val}" =~ ^\"([^\"]*)\"[[:space:]]*(#.*)?$ ]]; then
	    val="${BASH_REMATCH[1]}"
	elif [[ "${val}" =~ ^\'([^\']*)\'[[:space:]]*(#.*)?$ ]]; then
	    val="${BASH_REMATCH[1]}"
	else
	    val="${val%%[[:space:]]#*}"
	    val="${val%"${val##*[![:space:]]}"}"
	fi
	__drsm_conf_ref["${key}"]="${val}"
    done < "${file}"
    return 0
}

function drsm_plugin_key()
{
    # Settings prefix for a plugin ID, storage/disk becomes storage_disk
    local id="${1//\//_}"
    id="${id//-/_}"
    echo "${id//./_}"
}

function drsm_is_manifest_key()
{
    local k
    for k in ${DRSM_MANIFEST_KEYS}; do
	if [ "${1}" == "${k}" ]; then return 0; fi
    done
    return 1
}
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
