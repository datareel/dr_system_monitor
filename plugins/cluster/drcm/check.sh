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
# DRSM plugin: health of a DataReel Cluster Manager (DRCM) node and the
# cluster it belongs to. Runs on each cluster node, so every node gives
# its own view, which is what shows a split cluster:
#
# - drcm_server and any tunnel units are running
# - cm_stat: every node Up, every resource on its normal owner, no
#   resource owned by two nodes, no missing resources
# - each peer's keep_alive_ip:tcpport accepts a connection (the cluster
#   link, through the tunnel when there is one)
# - the cluster log: missed keep alives, stale keep alives, failovers,
#   failbacks, isolation and resource script errors in the last
#   EVENT_MINUTES, and whether this node is isolated now
#
# Reads only. Never starts, stops or changes anything in the cluster.
#
# For the Clusters page it also prints "DRCM kind|field|..." lines: the
# cluster name, this node, each node, resource and link, the health
# line, a keep alive strip per peer for the last STRIP_HOURS in
# STRIP_STEP second steps (o keep alive, m missed, d peer down, i this
# node isolated, s this node in standby, . nothing logged) and the
# cluster log events.
#
# -----------------------------------------------------------
# shellcheck source=lib/drsm_plugin.sh
source "${DRSM_LIB:-$(dirname "$0")/../../../lib}/drsm_plugin.sh"

CM_CONFIG=$(drsm_setting CM_CONFIG /etc/drcm/cm.cfg)
DRCM_SERVER=$(drsm_setting DRCM_SERVER /usr/sbin/drcm_server)
SERVICE=$(drsm_setting SERVICE drcm_server)
TUNNEL_SERVICES=$(drsm_setting TUNNEL_SERVICES NONE)
LINK_CHECK=$(drsm_setting LINK_CHECK yes)
LINK_TIMEOUT=$(drsm_setting LINK_TIMEOUT 5)
STAT_TIMEOUT=$(drsm_setting STAT_TIMEOUT 30)
LOG_FILE=$(drsm_setting LOG_FILE "")
EVENT_MINUTES=$(drsm_setting EVENT_MINUTES 30)
KEEPALIVE_WARN=$(drsm_setting KEEPALIVE_WARN 3)
KEEPALIVE_STALE=$(drsm_setting KEEPALIVE_STALE 300)
FAILOVER_STATE=$(drsm_setting FAILOVER_STATE WARNING)
STANDBY_STATE=$(drsm_setting STANDBY_STATE WARNING)
CLUSTER_NAME=$(drsm_setting CLUSTER_NAME "")
INTERVAL_MINUTES=$(drsm_setting INTERVAL_MINUTES 15)
STRIP_HOURS=$(drsm_setting STRIP_HOURS 24)
STRIP_STEP=$(drsm_setting STRIP_STEP 300)

function failover_report()
{
    if [ "${FAILOVER_STATE^^}" == "ERROR" ]; then drsm_crit "$@"; else drsm_warn "$@"; fi
}

function standby_report()
{
    # A node in standby (DRCM 1.43) is planned, not a failure
    case "${STANDBY_STATE^^}" in
	ERROR) drsm_crit "$@" ;;
	INFO|OK) drsm_info "$@" ;;
	*) drsm_warn "$@" ;;
    esac
}

if [ ! -r "${CM_CONFIG}" ]; then
    drsm_unknown "${HOST} DRCM config ${CM_CONFIG} is missing or not readable"
    drsm_exit
fi

# Cluster config: server settings and one line per node,
# node|nodename|hostname|keep_alive_ip|node_is_active
CFG=$(awk '
    function val(s) { sub(/^[^=]*=[ \t]*/, "", s); sub(/[ \t\r]+$/, "", s); return s }
    function flush() { if (name != "") print "node|" name "|" host "|" ip "|" active; name = host = ip = ""; active = 1 }
    /^[ \t]*#/ { next }
    /^[ \t]*\[/ { flush(); sect = $0; gsub(/[][ \t\r]/, "", sect); next }
    sect == "CM_SERVER" && /^[ \t]*tcpport[ \t]*=/ { print "tcpport|" val($0) }
    sect == "CM_SERVER" && /^[ \t]*log_dir[ \t]*=/ { print "log_dir|" val($0) }
    sect == "CM_SERVER" && /^[ \t]*logfile[ \t]*=/ { print "logfile|" val($0) }
    sect == "CM_NODE" && /^[ \t]*nodename[ \t]*=/ { name = val($0) }
    sect == "CM_NODE" && /^[ \t]*hostname[ \t]*=/ { host = val($0) }
    sect == "CM_NODE" && /^[ \t]*keep_alive_ip[ \t]*=/ { ip = val($0) }
    sect == "CM_NODE" && /^[ \t]*node_is_active[ \t]*=/ { active = val($0) }
    END { flush() }
' "${CM_CONFIG}")

function cfg_value() { echo "${CFG}" | awk -F'|' -v k="${1}" '$1 == k { print $2; exit }'; }

TCPPORT=$(cfg_value tcpport)
if [ "${LOG_FILE}" == "" ]; then
    logdir=$(cfg_value log_dir)
    logfile=$(cfg_value logfile)
    LOG_FILE="${logdir:-/var/log/drcm}/${logfile:-drcm.log}"
fi

# This node is the [CM_NODE] whose hostname matches, as DRCM does it
MYHOST=$(hostname 2> /dev/null)
MYNODE=$(echo "${CFG}" | awk -F'|' -v h="${MYHOST}" -v s="${HOST}" '$1 == "node" && ($3 == h || $3 == s) { print $2; exit }')
PEERS=$(echo "${CFG}" | awk -F'|' -v me="${MYNODE}" '$1 == "node" && $2 != me && $5 != "0" { print $2 "|" $4 }')
if [ "${CLUSTER_NAME}" == "" ]; then
    CLUSTER_NAME=$(echo "${CFG}" | awk -F'|' '$1 == "node" { printf "%s%s", sep, $2; sep = "+" }')
fi
echo "DRCM cluster|${CLUSTER_NAME}"
echo "DRCM self|${MYNODE}"

echo "DRCM cluster health on ${HOST}"
echo "Config: ${CM_CONFIG}"
echo "This node: ${MYNODE:-not found in the config}"
if [ -x "${DRCM_SERVER}" ]; then
    version=$("${DRCM_SERVER}" --version 2> /dev/null | awk '/version/ { print $NF; exit }')
    if [ "${version}" != "" ]; then
	echo "DRCM version: ${version}"
	drsm_detail "DRCM version" "${version}"
    fi
fi
if [ "${MYNODE}" != "" ]; then drsm_detail "DRCM node" "${MYNODE}"; fi
if [ "${MYNODE}" == "" ]; then
    drsm_warn "${HOST} host name ${MYHOST} matches no [CM_NODE] hostname in ${CM_CONFIG}"
fi

# Services
if ! drsm_is_none "${SERVICE}"; then
    state=$(systemctl is-active "${SERVICE}" 2> /dev/null)
    if [ "${state}" == "active" ]; then
	drsm_ok "${HOST} ${SERVICE} is running"
    else
	drsm_crit "${HOST} ${SERVICE} is ${state:-not installed}, this node is not in the cluster"
    fi
fi
if ! drsm_is_none "${TUNNEL_SERVICES}"; then
    for unit in ${TUNNEL_SERVICES}
    do
	state=$(systemctl is-active "${unit}" 2> /dev/null)
	if [ "${state}" == "active" ]; then
	    drsm_ok "${HOST} cluster link ${unit} is running"
	else
	    drsm_crit "${HOST} cluster link ${unit} is ${state:-not installed}"
	fi
    done
fi

# Cluster status from this node's point of view
nodes_up=0
nodes_down=0
nodes_standby=0
standby_names=""
resources=0
failed_over=0
if [ ! -x "${DRCM_SERVER}" ]; then
    drsm_unknown "${HOST} ${DRCM_SERVER} is not installed, cannot read the cluster status"
else
    STAT=$(timeout "${STAT_TIMEOUT}" "${DRCM_SERVER}" --client --config-file="${CM_CONFIG}" --command=cm_stat 2>&1)
    if ! echo "${STAT}" | grep -q "C l u s t e r   H e a l t h"; then
	if echo "${STAT}" | grep -q "config file load error"; then
	    drsm_unknown "${HOST} $(whoami) cannot read the DRCM auth key, add the user to the group that owns /etc/drcm/.auth"
	else
	    drsm_crit "${HOST} cm_stat gave no cluster status: $(echo "${STAT}" | grep -v '^[[:space:]]*$' | tail -1)"
	fi
    else
	echo ""
	# cm_stat without its ==== banners, which look like the runner's
	# plugin headers
	echo "${STAT}" | sed -n '/M e m b e r/,$p' | sed -e 's/^=* M e m b e r.*/Cluster members:/' \
	    -e 's/^=* R e s o u r c e.*/Cluster resources:/' -e 's/^=* C l u s t e r   H e a l t h.*/Cluster health:/'
	echo ""
	# Member lines: name<TAB>hostname<TAB>Up|Down<TAB>ip
	while IFS=$'\t' read -r name nhost state ip
	do
	    name="${name#"${name%%[![:space:]]*}"}"
	    state="${state%%[[:space:]]*}"
	    echo "DRCM node|${name}|${nhost}|${state}|${ip}"
	    if [ "${state}" == "Up" ]; then
		nodes_up=$((nodes_up + 1))
	    elif [ "${state}" == "Standby" ] || [ "${state}" == "Releasing" ]; then
		nodes_standby=$((nodes_standby + 1))
		standby_names="${standby_names:+${standby_names} and }${name}"
		if [ "${state}" == "Standby" ]; then
		    standby_report "${HOST} cluster node ${name} is in STANDBY, its resources run on its peers"
		else
		    standby_report "${HOST} cluster node ${name} is RELEASING its resources to go into STANDBY"
		fi
	    else
		nodes_down=$((nodes_down + 1))
		drsm_crit "${HOST} cluster node ${name} (${ip}) is Down"
	    fi
	done < <(echo "${STAT}" | awk -F'\t' 'NF == 4 && ($3 ~ /^(Up|Down|Standby|Releasing)/)')
	# Resource lines: Type:<TAB>nickname<TAB>owner<TAB>status<TAB>start
	RES=$(echo "${STAT}" | awk -F'\t' '$1 ~ /^ +[A-Za-z]+:$/ && NF >= 4 { t = $1; gsub(/[ :]/, "", t); print t "|" $2 "|" $3 "|" $4 "|" $5 }')
	echo "${RES}" | awk 'NF { print "DRCM resource|" $0 }'
	while IFS='|' read -r type nick owner state start
	do
	    [ "${nick}" == "" ] && continue
	    resources=$((resources + 1))
	    if [ "${state}" == "OK-Backup" ]; then
		failed_over=$((failed_over + 1))
		if [ ${nodes_standby} -gt 0 ]; then
		    standby_report "${HOST} cluster ${type} ${nick} runs on ${owner} while ${standby_names} is in standby"
		else
		    failover_report "${HOST} cluster ${type} ${nick} is failed over, running on backup ${owner}"
		fi
	    fi
	done <<< "${RES}"
	# The same resource on two owners is a split cluster
	dup=$(echo "${RES}" | awk -F'|' 'NF >= 3 { k = $1 "|" $2; if (k in o && o[k] != $3) print $1 " " $2 " on " o[k] " and " $3; o[k] = $3 }')
	if [ "${dup}" != "" ]; then
	    while read -r line; do drsm_crit "${HOST} split cluster, ${line}"; done <<< "${dup}"
	fi
	if echo "${STAT}" | grep -q "WARNING - duplicate"; then
	    drsm_crit "${HOST} split cluster, cm_stat reports $(echo "${STAT}" | grep -o 'duplicate [a-zA-Z ]* resource' | head -1)"
	fi
	missing=$(echo "${STAT}" | grep -E 'loaded out of' | sed 's/^[[:space:]]*//' | head -3)
	if [ "${missing}" != "" ]; then
	    while read -r line; do drsm_crit "${HOST} cluster resources missing, ${line}"; done <<< "${missing}"
	fi
	health=$(echo "${STAT}" | awk -F': ' '/Cluster status:/ { print $2; exit }')
	echo "DRCM health|${health}"
	if [ ${nodes_standby} -gt 0 ]; then
	    echo "DRCM standby|${standby_names}"
	fi
	if [ "${health}" == "HEALTHY" ]; then
	    drsm_ok "${HOST} cluster status is HEALTHY, ${nodes_up} nodes up, ${resources} resources"
	elif [ ${nodes_standby} -gt 0 ] && [ ${nodes_down} -eq 0 ] && [[ "${health}" != *MISSING* ]]; then
	    standby_report "${HOST} cluster status is ${health}, ${standby_names} in STANDBY"
	elif [ "${DRSM_HAS_ERROR}" -eq 0 ] && [ "${DRSM_HAS_WARNING}" -eq 0 ]; then
	    drsm_warn "${HOST} cluster status is ${health}"
	else
	    echo "Cluster status: ${health}"
	fi
    fi
fi
# No cm_stat: the nodes from the config, state unknown
if [ $((nodes_up + nodes_down)) -eq 0 ]; then
    echo "${CFG}" | awk -F'|' '$1 == "node" { print "DRCM node|" $2 "|" $3 "|Unknown|" $4 }'
fi
drsm_metric drcm_nodes_up "${nodes_up}"
drsm_metric drcm_nodes_down "${nodes_down}"
drsm_metric drcm_nodes_standby "${nodes_standby}"
drsm_metric drcm_resources "${resources}"
drsm_metric drcm_resources_failed_over "${failed_over}"

# Cluster link: each active peer's TCP listener, which with an SSH
# tunnel is the local end of the tunnel
if [ "${LINK_CHECK}" == "yes" ] && [ "${TCPPORT}" != "" ]; then
    while IFS='|' read -r peer ip
    do
	[ "${peer}" == "" ] && continue
	if timeout "${LINK_TIMEOUT}" bash -c "exec 3<> /dev/tcp/${ip}/${TCPPORT}" 2> /dev/null; then
	    drsm_ok "${HOST} cluster link to ${peer} at ${ip}:${TCPPORT} connects"
	    echo "DRCM link|${peer}|OK"
	else
	    drsm_crit "${HOST} cluster link to ${peer} at ${ip}:${TCPPORT} does not connect"
	    echo "DRCM link|${peer}|FAIL"
	fi
    done <<< "${PEERS}"
fi

# Cluster log events. The log has syslog times (no year) in this
# node's time zone.
misses=0
events=0
if [ ! -r "${LOG_FILE}" ]; then
    drsm_unknown "${HOST} cluster log ${LOG_FILE} is missing or not readable"
else
    now=$(date +%s)
    since=$((now - EVENT_MINUTES * 60))
    ival=$((now - INTERVAL_MINUTES * 60))
    nb=$((STRIP_HOURS * 3600 / STRIP_STEP))
    sstart=$((now - nb * STRIP_STEP))
    peers=$(echo "${PEERS}" | awk -F'|' 'NF { printf "%s ", $1 }')
    LOG=$(tail -n 100000 "${LOG_FILE}" | awk -v now="${now}" -v ival="${ival}" -v sstart="${sstart}" \
	-v step="${STRIP_STEP}" -v nb="${nb}" -v peers="${peers}" -v year="$(date +%Y)" '
	BEGIN {
	    split("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec", m, " "); for (i = 1; i <= 12; i++) mon[m[i]] = i
	    np = split(peers, plist, " ")
	    rank["."] = 0; rank["o"] = 1; rank["m"] = 2; rank["s"] = 3; rank["i"] = 4; rank["d"] = 5
	}
	function bucket(e,   b) { b = int((e - sstart) / step); return (b >= nb) ? nb - 1 : b }
	function mark(p, b, c) { if (b >= 0 && b < nb && rank[c] > rank[(p, b) in st ? st[p, b] : "."]) st[p, b] = c }
	# Mark peer p (or every peer for "") from time a to time z
	function span(p, a, z, c,   b, j) {
	    if (a < sstart) a = sstart
	    for (b = bucket(a); b <= bucket(z) && b < nb; b++) {
		if (p != "") mark(p, b, c); else for (j = 1; j <= np; j++) mark(plist[j], b, c)
	    }
	}
	!($1 in mon) { next }
	{
	    split($3, t, ":")
	    e = mktime(year " " mon[$1] " " $2 " " t[1] " " t[2] " " t[3])
	    if (e > now + 86400) e = mktime((year - 1) " " mon[$1] " " $2 " " t[1] " " t[2] " " t[3])
	    msg = $0; sub(/^[A-Z][a-z][a-z] +[0-9]+ [0-9:]+ [^:]*: /, "", msg)
	    peer = ""
	    if (msg ~ /^Node [^ ]+ /) { split(msg, w, " "); peer = w[2] }
	    # This node in standby (DRCM 1.43), until an unstandby request
	    if (msg ~ /^Standby requested|^Starting in standby/) { if (!sby) sby = e }
	    else if (msg ~ /^Unstandby requested/) { if (sby) span("", sby, e, "s"); sby = 0 }
	    if (msg ~ /this node is isolated, stopping its resources/) { if (!iso) iso = e }
	    else if (msg ~ /no longer isolated/) { if (iso) span("", iso, e, "i"); iso = 0 }
	    if (peer != "") {
		if (msg ~ /is alive|is back on line/) {
		    alive[peer] = e
		    if (peer in down) { span(peer, down[peer], e, "d"); delete down[peer] }
		    if (e >= sstart) mark(peer, bucket(e), "o")
		    if (e >= ival) okn[peer]++
		}
		else if (msg ~ /failed keep alive check/) {
		    if (e >= sstart) mark(peer, bucket(e), "m")
		    if (e >= ival) missn[peer]++
		}
		else if (msg ~ /is dead|is inactive|back in failed state/) { if (!(peer in down)) down[peer] = e }
	    }
	    if (e < sstart) next
	    if (msg ~ /failed keep alive check/) print "miss|" e "|" msg
	    else if (msg ~ /^(Standby requested|Starting in standby|Unstandby requested|Peers released this node|This node released all its resources)/) print "standby|" e "|" msg
	    else if (msg ~ /is back on line/) print "recover|" e "|" msg
	    else if (msg ~ /is dead|is inactive|failback|back in failed state|isolated|takeover_check|is alive but failed over/) print "event|" e "|" msg
	    else if (msg ~ /ERROR - Resource script/) print "error|" e "|" msg
	}
	END {
	    if (iso) { print "isolated|" iso "|"; span("", iso, now, "i") }
	    if (sby) span("", sby, now, "s")
	    for (p in down) span(p, down[p], now, "d")
	    for (p in alive) print "alive|" alive[p] "|" p
	    for (j = 1; j <= np; j++) {
		p = plist[j]; s = ""
		for (b = 0; b < nb; b++) s = s (((p, b) in st) ? st[p, b] : ".")
		print "strip|" p "|" s
		print "count|" p "|" okn[p] + 0 "|" missn[p] + 0
	    }
	}')
    misses=$(echo "${LOG}" | awk -F'|' -v s="${since}" '$1 == "miss" && $2 >= s' | wc -l)
    events=$(echo "${LOG}" | awk -F'|' -v s="${since}" '$1 == "event" && $2 >= s' | wc -l)
    errors=$(echo "${LOG}" | awk -F'|' -v s="${since}" '$1 == "error" && $2 >= s' | wc -l)
    iso=$(echo "${LOG}" | awk -F'|' '$1 == "isolated" { print $2 }')
    if [ "${iso}" != "" ]; then
	drsm_crit "${HOST} this node is isolated from the cluster since $(date -d "@${iso}" '+%F %T'), its resources are stopped"
    fi
    if [ "${misses}" -ge "${KEEPALIVE_WARN}" ]; then
	drsm_warn "${HOST} ${misses} missed cluster keep alives in the last ${EVENT_MINUTES} minutes"
    else
	drsm_ok "${HOST} ${misses} missed cluster keep alives in the last ${EVENT_MINUTES} minutes"
    fi
    # Stale keep alives: an Up peer the log has not heard from lately
    while IFS='|' read -r peer ip
    do
	[ "${peer}" == "" ] && continue
	last=$(echo "${LOG}" | awk -F'|' -v p="${peer}" '$1 == "alive" && $3 == p { print $2 }')
	if [ "${last}" == "" ]; then
	    drsm_warn "${HOST} no keep alive from ${peer} in the cluster log"
	elif [ $((now - last)) -gt "${KEEPALIVE_STALE}" ]; then
	    drsm_warn "${HOST} last keep alive from ${peer} was $((now - last)) seconds ago"
	fi
    done <<< "${PEERS}"
    if [ "${events}" -gt 0 ]; then
	failover_report "${HOST} ${events} cluster failover events in the last ${EVENT_MINUTES} minutes"
    fi
    if [ "${errors}" -gt 0 ]; then
	drsm_crit "${HOST} ${errors} cluster resource script errors in the last ${EVENT_MINUTES} minutes"
    fi
    if [ $((events + errors + misses)) -gt 0 ]; then
	echo ""
	echo "Cluster log, last ${EVENT_MINUTES} minutes:"
	echo "${LOG}" | awk -F'|' -v s="${since}" '($1 == "miss" || $1 == "event" || $1 == "error") && $2 >= s { print strftime("%F %T", $2) " " $3 }' | tail -20
    fi
    # Keep alive strips, per peer counts for the trends history, and the
    # newest 100 log events of the strip period
    echo "${LOG}" | awk -F'|' -v s="${sstart}" -v st="${STRIP_STEP}" '$1 == "strip" { print "DRCM strip|" $2 "|" s "|" st "|" $3 }'
    while IFS='|' read -r kind peer ok missed
    do
	drsm_metric drcm_keepalive_ok "${ok}" "peer=\"${peer}\""
	drsm_metric drcm_keepalive_missed "${missed}" "peer=\"${peer}\""
    done < <(echo "${LOG}" | awk -F'|' '$1 == "count"')
    echo "${LOG}" | awk -F'|' '$1 == "miss" || $1 == "recover" || $1 == "standby" || $1 == "event" || $1 == "error" { print "DRCM event|" $2 "|" $1 "|" $3 }' | tail -100
fi
drsm_metric drcm_keepalive_misses "${misses}"
drsm_metric drcm_failover_events "${events}"

drsm_exit
# -----------------------------------------------------------
# *******************************
# ********* End of File *********
# *******************************
