#!/bin/bash
# ----------------------------------------------------------- 
# BASH Script
# Operating System(s): RHEL/CENTOS
# Run Level(s): 3, 5
# Shell: BASH shell
# Original Author(s): DataReel Software Development
# File Creation Date: 10/24/2026
# Date Last Modified: 10/24/2026
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
# Tests for the HTML documentation in docs/. Every local link, image
# and #anchor must point at a file and id that exist, and no page may
# load anything from another site.
#
# Usage: tests/docs_test.sh
#
# ----------------------------------------------------------- 
TOPdir=$(cd "$(dirname "$0")/.." && pwd)
D="${TOPdir}/docs"
failures=0

function pass() { echo "PASS - $*"; }
function fail() { echo "FAIL - $*"; failures=$((failures + 1)); }

for page in "${D}"/*.html; do
    name=$(basename "${page}")
    bad=0
    # Remote scripts, styles or images would break the docs offline
    if grep -qiE '<(script|link|img)[^>]+(src|href)="(https?:)?//' "${page}"; then
	fail "${name} loads a file from another site"
	bad=1
    fi
    while read -r ref; do
	file="${ref%%#*}"
	anchor=""
	if [[ "${ref}" == *"#"* ]]; then anchor="${ref#*#}"; fi
	if [ "${file}" == "" ]; then file="${name}"; fi
	if [ ! -f "${D}/${file}" ]; then
	    fail "${name} links to missing ${file}"
	    bad=1
	elif [ "${anchor}" != "" ] && ! grep -q "id=\"${anchor}\"" "${D}/${file}"; then
	    fail "${name} links to missing anchor ${file}#${anchor}"
	    bad=1
	fi
    done < <(grep -oE '(href|src)="[^"]*"' "${page}" | sed -E 's/^(href|src)="//; s/"$//' | grep -vE '^(https?:|mailto:)')
    if [ "${bad}" == "0" ]; then pass "${name} links, images and anchors"; fi
done

if [ "${failures}" -gt 0 ]; then echo "${failures} test(s) failed"; exit 1; fi
echo "All docs tests passed"
exit 0
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# *******************************
