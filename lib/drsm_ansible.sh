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
# Ansible inventory as the DRSM host list. Settings in ~/.drsm.sh:
#
#   ANSIBLE_INVENTORY=/etc/ansible/hosts   # INI inventory, off when empty
#   ANSIBLE_TIERS="production=prod qa=qa dev=dev"
#       tier=group[,group...]: hosts in the group, or in any group under
#       it through :children, get that tier (GROUP). A host in more than
#       one tier goes to the first one listed.
#   ANSIBLE_DEFAULT_TIER=""                # tier for the other hosts,
#                                          # empty leaves them out
#   ANSIBLE_SHORT_NAMES=yes                # web1.example.com -> web1
#
# Every listed host is a Linux host checked over SSH with the
# _defaults.conf plugins. A host file with the same name (short or
# full) adds or changes settings for it, but the tier always comes
# from Ansible. Host files for hosts Ansible does not list (Windows,
# network devices) work as before. INI inventories only: [group],
# [group:children], [group:vars] (skipped), host variables after the
# name (skipped) and numeric ranges such as web[01:03].
#
# -----------------------------------------------------------

function drsm_ansible_hosts()
{
    # Print "host tier leafgroup" for each host of inventory $1 in a
    # tier from ANSIBLE_TIERS
    local inv="${1:-${ANSIBLE_INVENTORY}}"
    if [ "${inv}" == "" ] || [ ! -r "${inv}" ]; then return 1; fi
    awk -v tiers="${ANSIBLE_TIERS:-production=prod qa=qa dev=dev}" \
	-v deftier="${ANSIBLE_DEFAULT_TIER}" \
	-v short="${ANSIBLE_SHORT_NAMES:-yes}" '
      function hname(h) { if(tolower(short) != "no") sub(/\..*/, "", h); return tolower(h) }
      # web[01:03].x -> web01.x web02.x web03.x
      function expand(h,   pre, post, r, lo, hi, w, i, out, m) {
        if(!match(h, /\[[0-9]+:[0-9]+\]/)) return h
        pre = substr(h, 1, RSTART - 1); post = substr(h, RSTART + RLENGTH)
        r = substr(h, RSTART + 1, RLENGTH - 2); split(r, m, ":")
        w = length(m[1]); lo = m[1] + 0; hi = m[2] + 0; out = ""
        for(i = lo; i <= hi; i++) out = out " " pre sprintf("%0" w "d", i) post
        return out
      }
      BEGIN {
        n = split(tiers, ts, " ")
        for(i = 1; i <= n; i++) {
          split(ts[i], kv, "="); ng = split(kv[2], gs, ",")
          for(j = 1; j <= ng; j++) { tierof[gs[j]] = kv[1]; order[gs[j]] = i }
        }
      }
      /^[ \t]*[#;]/ || /^[ \t]*$/ { next }
      /^[ \t]*\[/ {
        g = $0; gsub(/^[ \t]*\[|\][ \t]*$/, "", g)
        mode = "hosts"
        if(g ~ /:children$/) { mode = "children"; sub(/:children$/, "", g) }
        else if(g ~ /:vars$/) mode = "vars"
        next
      }
      mode == "vars" { next }
      mode == "children" { parent[$1] = parent[$1] " " g; next }
      {
        e = expand($1); m = split(e, hs, " ")
        for(i = 1; i <= m; i++) { h = hname(hs[i]); if(!(h in leaf)) leaf[h] = g; member[h] = member[h] " " g }
      }
      # Best tier of group g and its parents
      function besttier(g, depth,   p, n, i, t, b, bo, tt) {
        b = ""; bo = 99999
        if(g in tierof) { b = tierof[g]; bo = order[g] }
        if(depth > 20) return b SUBSEP bo
        n = split(parent[g], p, " ")
        for(i = 1; i <= n; i++) {
          t = besttier(p[i], depth + 1); split(t, tt, SUBSEP)
          if(tt[1] != "" && tt[2] + 0 < bo) { b = tt[1]; bo = tt[2] + 0 }
        }
        return b SUBSEP bo
      }
      END {
        for(h in member) {
          b = ""; bo = 99999
          n = split(member[h], gs, " ")
          for(i = 1; i <= n; i++) {
            t = besttier(gs[i], 0); split(t, tt, SUBSEP)
            if(tt[1] != "" && tt[2] + 0 < bo) { b = tt[1]; bo = tt[2] + 0 }
          }
          if(b == "") b = deftier
          if(b != "") print h, b, leaf[h]
        }
      }' "${inv}" | sort
}

# -----------------------------------------------------------
# Ansible Tower / AWX inventory. Settings in ~/.drsm.sh:
#
#   ANSIBLE_TOWER_URL=https://tower.example.com    # off when empty
#   ANSIBLE_TOWER_INVENTORY=12                     # inventory ID or name
#   ANSIBLE_TOWER_TOKEN_FILE=~/.drsm_tower_token   # OAuth2 token, mode 600
#   ANSIBLE_TOWER_CA_FILE=""                       # CA bundle for a private CA
#   ANSIBLE_TOWER_CACHE_MINUTES=15                 # reuse a fetched copy
#
# The inventory is read from the Tower API (/api/v2/inventories/<id>/
# script/), turned into an INI file in ${VARdir} and read like a local
# inventory, with ANSIBLE_TIERS. When Tower cannot be reached the last
# good copy is used, with a warning. Needs curl and jq. The token is
# sent from a header file, never on the command line.
# -----------------------------------------------------------

function drsm_tower_get()
{
    # GET Tower API URL $1 into file $2
    local hdr rc
    hdr=$(mktemp "${VARdir:-/tmp}/.drsm_tower_hdr.XXXXXX") || return 1
    chmod 600 "${hdr}"
    printf 'Authorization: Bearer %s\n' "$(tr -d '[:space:]' < "${ANSIBLE_TOWER_TOKEN_FILE}")" > "${hdr}"
    local ca=()
    if [ "${ANSIBLE_TOWER_CA_FILE}" != "" ]; then ca=(--cacert "${ANSIBLE_TOWER_CA_FILE}"); fi
    ${DRSM_CURL:-curl} -sS --fail --max-time 60 "${ca[@]}" -H "@${hdr}" -H "Accept: application/json" -o "${2}" "${1}"
    rc=$?
    rm -f "${hdr}"
    return ${rc}
}

function drsm_tower_inventory()
{
    # Print the path of an INI copy of the Tower inventory, fetching it
    # when the cached copy is older than ANSIBLE_TOWER_CACHE_MINUTES
    local base="${ANSIBLE_TOWER_URL%/}" inv="${ANSIBLE_TOWER_INVENTORY}" id
    local cache="${VARdir:-/tmp}/ansible_tower_inventory.ini" json tmp
    local age="${ANSIBLE_TOWER_CACHE_MINUTES:-15}"
    if [ "${base}" == "" ] || [ "${inv}" == "" ]; then
	echo "ERROR - set ANSIBLE_TOWER_URL and ANSIBLE_TOWER_INVENTORY" >&2; return 1
    fi
    if [ -s "${cache}" ] && [ -n "$(find "${cache}" -mmin "-${age}" 2> /dev/null)" ]; then echo "${cache}"; return 0; fi
    if ! command -v jq > /dev/null 2>&1; then echo "ERROR - jq is needed to read the Ansible Tower inventory" >&2; return 1; fi
    if [ ! -r "${ANSIBLE_TOWER_TOKEN_FILE}" ]; then echo "ERROR - Ansible Tower token file ${ANSIBLE_TOWER_TOKEN_FILE} not found" >&2; return 1; fi
    mkdir -p "$(dirname "${cache}")"
    json=$(mktemp "${cache}.json.XXXXXX") || return 1
    tmp="${cache}.tmp"
    id="${inv}"
    if [[ ! "${inv}" =~ ^[0-9]+$ ]]; then
	# Inventory name to ID
	if drsm_tower_get "${base}/api/v2/inventories/?name=$(jq -rn --arg v "${inv}" '$v|@uri')" "${json}"; then
	    id=$(jq -r '.results[0].id // empty' "${json}")
	else
	    id=""
	fi
    fi
    if [ "${id}" != "" ] && drsm_tower_get "${base}/api/v2/inventories/${id}/script/?hostvars=0" "${json}" \
	&& jq -r 'to_entries[] | select(.key != "_meta" and .key != "all")
		  | ("[" + .key + "]"), ((.value.hosts // [])[]),
		    (if ((.value.children // []) | length) > 0 then ("[" + .key + ":children]"), (.value.children[]) else empty end)' \
		  "${json}" > "${tmp}" 2> /dev/null && [ -s "${tmp}" ]; then
	mv -f "${tmp}" "${cache}"
	rm -f "${json}"
	echo "${cache}"
	return 0
    fi
    rm -f "${json}" "${tmp}"
    if [ -s "${cache}" ]; then
	echo "WARNING - Ansible Tower inventory ${inv} could not be read from ${base}, using the copy from $(date -r "${cache}")" >&2
	echo "${cache}"
	return 0
    fi
    echo "ERROR - Ansible Tower inventory ${inv} could not be read from ${base}" >&2
    return 1
}
