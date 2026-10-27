#!/bin/bash
# -----------------------------------------------------------
# BASH Script
# Operating System(s): RHEL/CENTOS
# Run Level(s): 3, 5
# Shell: BASH shell
# Original Author(s): DataReel Software Development
# File Creation Date: 10/27/2026
# Date Last Modified: 10/27/2026
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
# Print the setup for a monitor host that runs one site and copies it
# to a hosted dashboard. The dashboard limits the monitor host's SSH key
# with rrsync to that site's folder, so a monitor host at one customer
# can not read or change another customer's reports. Changes nothing,
# it only prints what to do on each side.
# Usage: drsm_add_collector.sh [-u user@dashboard] [-r reports dir] [-k key file]
#                              [-c collector ID] [-R rrsync] org/site
#   -u  SSH login on the dashboard server, default the host part of
#       ${WEBSYNC_DEST}
#   -r  Dashboard reports folder, default the path part of
#       ${WEBSYNC_DEST}
#   -k  Public key of the monitor host, default ~/.ssh/id_ed25519.pub
#   -c  COLLECTOR_ID of the monitor host, default its short host name
#   -R  rrsync on the dashboard server, default /usr/bin/rrsync from
#       the rsync-rrsync package. On shared hosting copy rrsync from
#       /usr/share/doc/rsync/support/ into your home folder.
#   org/site  The site the monitor host runs
# -----------------------------------------------------------
if [ "${BASEdir}" == "" ]; then export BASEdir="${HOME}/drsm"; fi
if [ -f "${HOME}/.drsm.sh" ]; then CONFIG_FILE="${HOME}/.drsm.sh"; else CONFIG_FILE="${BASEdir}/etc/drsm.sh"; fi
if [ ! -f "${CONFIG_FILE}" ]; then echo "ERROR - Missing base config ${CONFIG_FILE}"; exit 1; fi
# shellcheck source=etc/drsm.sh
source "${CONFIG_FILE}"
# shellcheck source=lib/drsm_conf.sh
source "${DRSMHOME}/lib/drsm_conf.sh"
# shellcheck source=lib/drsm_sites.sh
source "${DRSMHOME}/lib/drsm_sites.sh"

login=""
rdir=""
if [[ "${WEBSYNC_DEST}" == *:* ]]; then
    login="${WEBSYNC_DEST%%:*}"
    rdir="${WEBSYNC_DEST#*:}"
fi
keyfile="${HOME}/.ssh/id_ed25519.pub"
collector=""
rrsync="/usr/bin/rrsync"
site=""
function usage() { sed -n '/^# Usage:/,/^#   org\/site  The site/p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
while [ $# -gt 0 ]; do
    case "${1}" in
	-u) login="${2}"; shift ;;
	-r) rdir="${2}"; shift ;;
	-k) keyfile="${2}"; shift ;;
	-c) collector="${2}"; shift ;;
	-R) rrsync="${2}"; shift ;;
	-*) usage ;;
	*) if [ "${site}" != "" ]; then usage; fi; site="${1,,}" ;;
    esac
    shift
done
if [ "${site}" == "" ]; then usage; fi
if ! drsm_valid_site "${site}" || [ "${site}" == "${DRSM_LEGACY_SITE}" ]; then
    echo "ERROR - Not a site: ${site}, use org/site, not ${DRSM_LEGACY_SITE}"
    exit 1
fi
if [ "${collector}" == "" ]; then collector=$(drsm_collector_id); fi
rdir="${rdir%/}"
# These go into an authorized_keys option, so plain paths and names only
if ! [[ "${rdir}" =~ ^/[A-Za-z0-9._/-]+$ ]] || [[ "${rdir}" == *..* ]]; then
    echo "ERROR - Give the dashboard reports folder as an absolute path with -r, not '${rdir}'"
    exit 1
fi
if ! [[ "${rrsync}" =~ ^/[A-Za-z0-9._/-]+$ ]]; then
    echo "ERROR - Give rrsync as an absolute path with -R"
    exit 1
fi
if ! [[ "${login}" =~ ^([A-Za-z0-9._-]+@)?[A-Za-z0-9._-]+$ ]]; then
    echo "ERROR - Give the dashboard login as user@host with -u"
    exit 1
fi
if ! [[ "${collector}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
    echo "ERROR - Not a collector ID: ${collector}"
    exit 1
fi
key=""
if [ -f "${keyfile}" ]; then key=$(head -n 1 "${keyfile}"); fi
keyre='^(ssh-[a-z0-9-]+|ecdsa-sha2-[a-z0-9-]+|sk-[a-z0-9@.-]+) [A-Za-z0-9+/=]+( [^"]*)?$'
if ! [[ "${key}" =~ ${keyre} ]]; then
    echo "WARNING - No usable public key in ${keyfile}, make one on the monitor host with:"
    echo "  ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519"
    echo ""
    key="ssh-ed25519 AAAA...your-key... drsm@${collector}"
fi
sitedir="${rdir}/orgs/${site}"

cat <<SETUP
Setup for monitor host ${collector} running site ${site}

1. On the dashboard server (${login}), create the site folder:

   mkdir -p ${sitedir}

2. Add this line to ~/.ssh/authorized_keys of ${login%@*} on the dashboard
   server. The key can then only copy files into ${sitedir}:

command="${rrsync} ${sitedir}",restrict ${key}

3. In ~/.drsm.sh on monitor host ${collector}:

   export DRSM_COLLECTOR_ID=${collector}
   export DRSM_SITE=${site}
   export WEBSYNC_DEST="${login}:"
   export WEBSYNC_RRSYNC=1

4. In $(drsm_site_file "${site}") on monitor host ${collector}:

   COLLECTOR_ID=${collector}

Then check with utils/drsm_web_sync.sh, a dry run, and add --apply.
The dashboard reads the organization name from the site's site.json,
so no org.json is needed on the dashboard.
SETUP
exit 0
# -----------------------------------------------------------
# *******************************
# ********* End of File *********
# *******************************
