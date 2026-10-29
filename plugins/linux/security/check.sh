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
# DRSM plugin: the SECURITY and FAILED SERVICES sections of the last
# DataReel Reporting Agent for Linux report.
#
# ----------------------------------------------------------- 
# shellcheck source=lib/drsm_plugin.sh
source "${DRSM_LIB:-$(dirname "$0")/../../../lib}/drsm_plugin.sh"
# shellcheck source=plugins/linux/lra_report.sh
source "$(dirname "$0")/../lra_report.sh"

SELINUX_WARN=$(drsm_setting SELINUX_WARN 1)
FIREWALL_WARN=$(drsm_setting FIREWALL_WARN 1)
AUDITD_WARN=$(drsm_setting AUDITD_WARN 0)
SSH_ROOT_WARN=$(drsm_setting SSH_ROOT_WARN 1)
SSH_PASSWORD_WARN=$(drsm_setting SSH_PASSWORD_WARN 0)
FAILED_UNITS_WARN=$(drsm_setting FAILED_UNITS_WARN 1)
FAILED_UNITS_SKIP=$(drsm_setting FAILED_UNITS_SKIP "")
if drsm_is_none "${FAILED_UNITS_SKIP}"; then FAILED_UNITS_SKIP=""; fi

lra_load_report || drsm_exit
if ! lra_has_section "SECURITY" "${REPORT}"; then
    drsm_unknown "${LRA_HOST} report has no SECURITY section"
    drsm_exit
fi
declare -A S
while IFS='=' read -r k v; do
    if [[ "${k}" =~ ^[a-z0-9_]+$ ]]; then S[${k}]="${v}"; fi
done < <(lra_section "SECURITY" "${REPORT}")

function flag()
{
    # Warn when the setting is 1, otherwise list it, $1 == setting, $2 == text
    if [ "${1}" == "1" ]; then drsm_warn "${LRA_HOST} ${2}"; else echo "Note: ${2}"; fi
}

fw="firewalld ${S[firewalld]:-unknown}"
if [ "${S[firewalld]}" == "active" ] && [ "${S[firewalld_default_zone]}" != "" ]; then fw="${fw} (zone ${S[firewalld_default_zone]})"; fi
if [ "${S[firewalld]}" != "active" ] && [ "${S[nftables_rules]}" != "" ]; then fw="${fw}, ${S[nftables_rules]} nftables rules"; fi
echo "SELinux ${S[selinux]:-unknown}, ${fw}, auditd ${S[auditd]:-unknown}, FIPS ${S[fips]:-0}"
drsm_detail "SELinux" "${S[selinux]:-unknown}"
drsm_detail "Firewall" "${fw}"

if [ "${S[selinux]}" != "enforcing" ]; then flag "${SELINUX_WARN}" "SELinux is ${S[selinux]:-unknown}, not enforcing"; fi
if [ "${S[firewalld]}" != "active" ] && [ "${S[nftables_rules]:-0}" == "0" ]; then
    flag "${FIREWALL_WARN}" "has no firewall: firewalld is ${S[firewalld]:-unknown} and there are no nftables rules"
fi
if [ "${S[auditd]}" != "active" ]; then flag "${AUDITD_WARN}" "auditd is ${S[auditd]:-unknown}"; fi
if [ "${S[sshd]}" == "active" ]; then
    echo "sshd: port ${S[sshd_port]:-?}, PermitRootLogin ${S[sshd_permitrootlogin]:-?}, PasswordAuthentication ${S[sshd_passwordauthentication]:-?}"
    if [ "${S[sshd_permitrootlogin]}" == "yes" ]; then flag "${SSH_ROOT_WARN}" "sshd lets root log in with a password (PermitRootLogin yes)"; fi
    if [ "${S[sshd_passwordauthentication]}" == "yes" ]; then flag "${SSH_PASSWORD_WARN}" "sshd allows password logins (PasswordAuthentication yes)"; fi
    if [ "${S[sshd_permitemptypasswords]}" == "yes" ]; then drsm_crit "${LRA_HOST} sshd allows empty passwords (PermitEmptyPasswords yes)"; fi
fi
echo "Automatic updates: ${S[automatic_updates]:-unknown}"

failed=""
count=0
while read -r unit; do
    [ "${unit}" == "" ] && continue
    if [[ " ${FAILED_UNITS_SKIP} " == *" ${unit} "* ]]; then continue; fi
    failed="${failed} ${unit}"
    count=$((count + 1))
done < <(lra_section "FAILED SERVICES" "${REPORT}" | sed -n 's/^unit=//p')
if [ ${count} -gt 0 ]; then
    flag "${FAILED_UNITS_WARN}" "has ${count} failed systemd units:${failed}"
fi
drsm_metric failed_units "${count}"
if [ "${DRSM_HAS_ERROR}" == "0" ] && [ "${DRSM_HAS_WARNING}" == "0" ]; then
    drsm_ok "${LRA_HOST} security settings check good"
fi
drsm_exit
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# *******************************
