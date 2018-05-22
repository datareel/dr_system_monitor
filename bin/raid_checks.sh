#!/bin/bash
# ----------------------------------------------------------- 
# BASH Script
# Operating System(s): RHEL/CENTOS
# Run Level(s): 3, 5
# Shell: BASH shell
# Original Author(s): DataReel Software Development
# File Creation Date: 02/20/2018
# Date Last Modified: 05/22/2018
#
# Version control: 1.03
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
# Check of local RAID controllers for drive failures.
#
# NOTE: This version will check RAID contollers using the 
# LSI chipset. The LSI check requires MegaCli utility to be
# installed. To setup MegaCli check the system to see if
# it has an LSI controller:
#
# dmesg | grep -i megaraid
# 
# If so install the MegaCli utiltiy, for example:
#
# yum localinstall MegaCli-8.07.14-1.noarch.rpm
#
# Your system admin account must have sudo rights 
# to run the MegaCli64 binary, for example:
#
# visudo
#
#  sysadmin ALL= NOPASSWD:/opt/MegaRAID/MegaCli/MegaCli64
#
# TODO: Add Linux sofware RAID checks.
# ----------------------------------------------------------- 

# TODO: Check for Linux software RAID here
# ...
# ...

# Check for LSI RAID contollers
find /sys/bus/pci -type f -print | grep -i megaraid &> /dev/null
if [ $? -ne 0 ]; then
    echo "INFO: This system does not have LSI RAID controller hardware installed"
    exit 0
fi

# Check to see if LSI RAID module is loaded
find /sys/module -type f -print | grep -i megaraid &> /dev/null
if [ $? -ne 0 ]; then
    echo "INFO: The LSI RAID controller kernel module is not loaded"
    exit 0
fi

if [ ! -f /opt/MegaRAID/MegaCli/MegaCli64 ]; then
    echo "INFO: This system has LSI RAID hardware but does not have the MegaRAID utility installed"
    exit 0
fi

sudo -Al | grep MegaCli64 &> /dev/null
if [ $? -ne 0 ]; then
    echo "INFO: Our system admin account does not sudo rights to run the MegaRAID utility"
    exit 0
fi

sudo /opt/MegaRAID/MegaCli/MegaCli64 -PdList -aAll  | grep -i Failed
if [ $? -eq 0 ]; then
    echo "ERROR - One or more hard drives have failed in RAID array"
    echo "ERROR - For more info run: /opt/MegaRAID/MegaCli/MegaCli64 -PdList -aAll"
    exit 2
else
    echo "INFO - All drives RAID drives check good" 
fi

exit 0
# ----------------------------------------------------------- 
# ******************************* 
# ********* End of File ********* 
# ******************************* 
