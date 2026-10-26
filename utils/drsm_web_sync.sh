#!/bin/bash
# -----------------------------------------------------------
# BASH Script
# Operating System(s): RHEL/CENTOS
# Run Level(s): 3, 5
# Shell: BASH shell
# Original Author(s): DataReel Software Development
# File Creation Date: 10/25/2026
# Date Last Modified: 10/25/2026
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
# Copies the reports from the monitor host to a Web only dashboard on
# another server, such as a shared hosting account built with
# utils/make_web_demo.sh. Only ${REPORTdir} is copied: the pages and
# config/drsm.php on the remote site, including its login settings,
# are never touched. Uses rsync over SSH, so the monitor host only
# makes outgoing connections and needs no static IP address.
#
# Usage: utils/drsm_web_sync.sh [--apply] [-d user@host:/path/reports]
#
#   --apply  Copy the files. Without it rsync only lists what it would
#            copy or delete (dry run).
#   -d       Destination, default ${WEBSYNC_DEST} from ~/.drsm.sh
#
# Settings, in ~/.drsm.sh:
#
#   WEBSYNC_DEST     host:/path to the remote dashboard's reports folder
#   WEBSYNC_RETRIES  Extra attempts after a failed copy, default 2
#   WEBSYNC_WAIT     Seconds between attempts, default 30
#   WEBSYNC_TIMEOUT  Seconds with no data before rsync gives up, default 120
#
# SSH uses ${SSH_OPTS}, so a port, user or key for the remote host goes
# in the SSH config file named there or in ~/.ssh/config. Files that
# are gone from ${REPORTdir} are deleted on the remote side, except the
# remote .htaccess files, which block direct access when login is on.
#
# Exit code: 0 copied (or dry run listed), 1 setup error, else the
# rsync exit code of the last attempt.
#
# -----------------------------------------------------------
if [ "${BASEdir}" == "" ]; then export BASEdir="${HOME}/drsm"; fi

if [ -f ${HOME}/.drsm.sh ]; then
    CONFIG_FILE=${HOME}/.drsm.sh
else
    CONFIG_FILE=${BASEdir}/etc/drsm.sh
fi

if [ ! -f ${CONFIG_FILE} ]; then
    echo "ERROR - Missing base config ${CONFIG_FILE}"
    exit 1
fi

source ${CONFIG_FILE}
source ${BASEdir}/bin/system_functions.sh

apply="0"
dest="${WEBSYNC_DEST}"
while [ $# -gt 0 ]
do
    case ${1} in
	--apply) apply="1" ;;
	-d) dest="${2}"; shift ;;
	*) echo "Usage: $0 [--apply] [-d user@host:/path/reports]"; exit 1 ;;
    esac
    shift
done

if [ "${dest}" == "" ]; then
    echo "ERROR - No destination, set WEBSYNC_DEST in ${CONFIG_FILE} or use -d"
    exit 1
fi
if [ ! -d "${REPORTdir}" ]; then
    echo "ERROR - Missing report directory ${REPORTdir}"
    exit 1
fi
if [ "${WEBSYNC_RETRIES}" == "" ]; then WEBSYNC_RETRIES=2; fi
if [ "${WEBSYNC_WAIT}" == "" ]; then WEBSYNC_WAIT=30; fi
if [ "${WEBSYNC_TIMEOUT}" == "" ]; then WEBSYNC_TIMEOUT=120; fi

# One copy at a time, a slow upload must not stack up behind cron
LOCKFILE="${VARdir}/drsm_web_sync.lock"
exec 9> "${LOCKFILE}"
if ! flock -n 9; then
    echo "INFO - Another drsm_web_sync.sh is running, skipping this run"
    exit 0
fi

opts=(-a --delete --timeout="${WEBSYNC_TIMEOUT}" --exclude=.htaccess --exclude="*~" --exclude=".*.tmp")
if [ "${apply}" == "1" ]; then
    opts+=(--stats)
else
    echo "INFO - Dry run, add --apply to copy"
    opts+=(-n -i)
fi

attempt=1
tries=$((WEBSYNC_RETRIES + 1))
while true; do
    echo "INFO - $(date '+%F %T') copying ${REPORTdir}/ to ${dest}/ (attempt ${attempt} of ${tries})"
    rsync "${opts[@]}" -e "ssh ${SSH_OPTS}" "${REPORTdir}/" "${dest}/"
    rc=$?
    # 24 is files that vanished during the copy, a report being rewritten
    if [ ${rc} -eq 0 ] || [ ${rc} -eq 24 ]; then
	echo "INFO - $(date '+%F %T') copy complete"
	exit 0
    fi
    if [ ${rc} -eq 1 ] || [ ${rc} -eq 2 ] || [ ${rc} -eq 4 ] || [ ${attempt} -ge ${tries} ]; then
	echo "ERROR - $(date '+%F %T') copy to ${dest} failed, rsync exit code ${rc}"
	exit ${rc}
    fi
    echo "WARNING - copy failed with rsync exit code ${rc}, retrying in ${WEBSYNC_WAIT}s"
    sleep ${WEBSYNC_WAIT}
    attempt=$((attempt + 1))
done
# -----------------------------------------------------------
# *******************************
# ********* End of File *********
# *******************************
