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
