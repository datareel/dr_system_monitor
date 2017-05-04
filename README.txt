DataReel System Admin Monitor README file
Last Modified: 05/04/2017

Contents:
--------
* Overview
* Requirements
* Setting up the system admin user
* Installing
* Adding systems to monitor
* Web Interface Setup
* Customizing the Web Interface
* Setting custom alert thresholds
* Email Text messaging setup
* Monitoring Crons
* Support

Overview:
--------
DRSM is an admin tool used to monitor connectivity and the system
health of servers and workstations. The monitoring code is written in
BASH and the Web interface is written in PHP. System connectivity
testing checks network connectivity and the connection status of HTTP,
HTTPS, and FTP as required. System health check reporting connects to
systems via keyed SSH sessions and monitors CPU, memory, disk, load,
and user statistics. Email and text message alerts can be sent based
on per-defined or user-defined thresholds.

Requirements:
------------
* Linux system with network access to systems being monitored
* Apache with PHP if using Web interface 
* User account to run DRSM software
* Keyed SSH access if using health checking

Setting up the system admin user:
-------------------------------
You can run the DRSM package from your user account or from a system
admin account. The DRSM user is configurable. The default DRSM user
account is sysadmin. To setup a sysadmin account: 

$ sudo su - root
# groupadd -g 3500 sysadmin
# useradd -u 3500 -g 3500 sysadmin
# passwd sysadmin
# su - sysadmin
$ ssh-keygen -t dsa
$ ssh-keygen -t rsa

To create sysadmin accounts on systems you want to generate health
check reports: 

$ for s in server1 server2 server3 server4; do
> echo $s
> ssh -tq $s "sudo su root -c 'groupadd -g 3500 sysadmin'"
> ssh -tq $s "sudo su root -c 'useradd -u 3500 -g 3500 sysadmin'"
> ssh -tq $s "sudo su root -c 'passwd sysadmin'"
> done

Copy sysadmin public key to all systems you want to generate health
check reports: 

$ sudo su - sysadmin
$ for s in server1 server2 server3 server4; do
> echo $s
> ssh-copy-id -i ~/.ssh/id_rsa.pub $s
> done

Installing:
----------
To install DRSM, from GITHUB:

$ mkdir ~/git
$  cd ~/git
$  git clone https://github.com/datareel/dr_system_monitor
$  cd dr_system_monitor/

Setup your DRSM configuration:

$ cp etc/drsm.sh ~/.drsm.sh
$ vi ~/.drsm.sh

...
export WWWdir=/var/www/html/sysadmin
...
export SYSADMIN_USERNAME=sysadmin
export SYSADMIN_GROUPNAME=sysadmin
...
export TEMPdir="/tmp/${SYSADMIN_USERNAME}/drsm"
...

NOTE: In the example below replace /var/www/html/sysadmin with your
${WWWdir} setting:

$ cat ~/.drsm.sh | grep WWWdir
$ su - root
# mkdir -p /var/www/html/sysadmin
# chmod 775 /var/www/html/sysadmin
# chown sysadmin:sysadmin /var/www/html/sysadmin
# exit

$ cd ~/git/dr_system_monitor/utils
$ ./install.sh

Accept EULA (Yes/no)> Yes
...
Install complete

When the install completes DRSM will be installed to ${HOME}/dsrm

To test your installation:

$ source ~/.drsm.sh
$ vi ${CONFIGdir}/systems.dat

# hostname,description,impact,is_web_server,is_linux,is_cluser_ip,can_ping,can_ssh
#
# is_webserver = ,yes,
# or with web protocal list
# is_webserver = ,yes:HTTP HTTPS FTP,

vm1,Test VM1, Test VM1 affected,no,yes,no,yes,yes
vm2,Test VM2, Test VM2 affected,no,yes,no,yes,yes
vm3,Test VM3, Test VM3 affected,no,yes,no,yes,yes
vm4,Test VM4, Test VM4 affected,no,yes,no,yes,yes

$ ~/drsm/bin/system_check.sh
$ ~/drsm/bin/system_report.sh 

To test the Web interface:

$ firefox http://$(hostname)/sysadmin

Adding systems to monitor:
-------------------------
The connectivity and heath reporting scripts use a CSV database file
to select systems to monitor. The CSV format is: 

hostname,description,impact,is_web_server,is_linux,is_cluser_ip,can_ping,can_ssh
hostname = The hostname or IP address of the server or workstation
description = A short text describing the server or workstation
impact = A short text stating the impact of a system warning or error
is_web_server = Is this a Web server, yes or no
NOTE: For Web servers you can specify a space separated protocol list:
is_web_server = ,yes:HTTP HTTPS FTP,
is_linux = Is this a Linux host, yes or no
is_cluser_ip = Is this hostname or IP the head of a cluster node, yes or no
can_ping = Can we ping this host, yes or no
can_ssh = Can we SSH with keyed authentication to this host, yes or no

To add production systems append new CSV lines to the
${CONFIGdir}/systems.dat file:

$ source ~/.drsm.sh
$ vi ${CONFIGdir}/systems.dat

# Web CMS cluster 
cms,CMS server,Web CMS is affected,yes,yes,yes,yes,yes
cms1,Primary CMS server,Web CMS is affected,no,yes,no,yes,yes
cms2,Backup CMS server,Web CMS is affected,no,yes,no,yes,yes

In the above example we checking the head of cluster and 2 cluster
nodes.

To add development systems append new CSV lines to the
${CONFIGdir}/dev_systems.dat file:

$ source ~/.drsm.sh
$ vi ${CONFIGdir}/dev_systems.dat

# DEV Web cluster 
wwwdev,Development Web server,WWWDEV Website is affected,yes,yes,yes,yes,yes
wwwdev1,Development Web server 1,WWWDEV Website is affected,no,yes,no,yes,yes
wwwdev2,Development Web server 2,WWWDEV Website is affected,no,yes,no,yes,yes

To test your production and development configurations:

$ ~/drsm/bin/system_check.sh
$ ~/drsm/bin/system_check.sh NO DEV

Web Server Setup:
-------------------
On your workstation or server running the DRSM package you will need
to have Apache and PHP installed:

$ sudo su - root
# yum groupinstall 'Web Server'
# yum groupinstall 'PHP Support'

For testing:
# yum install wget
# yum install firefox

Apache and PHP Configuration files:
/etc/httpd/conf/httpd.conf
/etc/httpf/conf.d/*.conf
/etc/httpd/conf.modules.d/*.conf
/etc/php.ini

Apache Log files:
/var/log/httpd

Host-based firewall settings:
# firewall-cmd --list-services
# firewall-cmd --list-rich-rules

If no HTTP services are listed above:
# firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.122.0/24" service name="http" accept'
# firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.122.0/24" service name="https" accept'
# firewall-cmd --reload
# firewall-cmd --list-rich-rules

Where  192.168.122.0/24 is the subnet you will allow to view your
system admin reports.

Start and enable the HTTPD service:
# systemctl start httpd
# systemctl enable httpd

Customizing the Web Interface:
-----------------------------
To customize your index page, page headers and footers, from your
sysadmin user account:

$ source ~/.drsm.sh
$ cd $WWWdir/site

Add or create the page_header.php and page_footer.php files:

$ vi page_header.php

<!DOCTYPE html>
<html>
<head>
<title>MY System Monitor</title>
</head>
<body>
<h1>MY System Monitoring Pages</h1>
<hr />

$ vi page_footer.php

<hr />
</body>
</html>

To customize your sysadmin index page:

$ source ~/.drsm.sh
$ cd $WWWdir

In the $WWWdir add or edit the index.php file:

$ vi index.php

The $WWWdir/index.php and $WWWdir/site files will not get overwritten
if you update or re-install the DRSM package.

Setting custom alert thresholds:
------------------------------
When generating health check reports you may need to increase or
decrease the default alert levels. When you run the system_report.sh
script a configuration profile will be automatically generate for each
host in your ${CONFIGdir}/systems.dat and ${CONFIGdir}/dev_systems.dat
files. To change the default alert settings per system:

$ source ~/.drsm.sh
$ cd $CONFIGdir
$ ls *profile.sh

Edit the system profile you need to modify, for example:

$ vi vm1_profile.sh

By default the disk checks, look at the disk usage for all mounted
partitions, warn at 90 percent usage, and error a 99 percent usage.
If you want to skip the check on some of your mounted partitions you
need to supply a space separated list. To customize disk checking
alerts, edit the disk check section inside the double quotes:

"${DRSMHOME}/health_check_scripts/disk_checks.sh '/tmp /usr1' 80 90" 

In the example above, we will skip checks on /tmp and /usr1. We will
send a warning if we are at 80% disk usage on mounted partitions and
send an error if we are a 90% disk usage. If you want to set the
warning or error thresholds without skipping any mounted partitions:

"${DRSMHOME}/health_check_scripts/disk_checks.sh NONE 80 90"

By default the CPU check, looks at the CPU usage for all sockets,
physical cores, and logical cores. The default waning level is 85
percent total usage and the default error level is 95 percent total
usage. By default the CPU check will list the top 100 processes in the
system report. To customize CPU checking alerts, edit the CPU check
section inside the double quotes:

"${DRSMHOME}/health_check_scripts/cpu_checks.sh 75 85 200"

In the example above, we will send a warning if we are at 75% percent
CPU usage, send an error if we are a 85% CPU usage, and list the top
200 processes in our health check report.

The load check monitors the 15 minute load average. The default waning
level is 35 and the default error level is 50. To customize load
average checking alerts, edit the load check section inside the double
quotes:


"${DRSMHOME}/health_check_scripts/load_checks.sh 100 250"

In the example above, we will send a warning if our 15 minute load
average reaches 100 and send an error if our 15 minute load average
reaches 250. 

The memory check monitor the available amount free memory, the amount
of SWAP spaced used, lists the top 100 processes by default. The
default error level for free memory is 256 MB or less. The default
warning for SWAP usage is 1024 MB or higher. The top number of
processes listed in the report, defaults to 100. To customize memory
checking alerts, edit the memory check section inside the double
quotes:

"${DRSMHOME}/health_check_scripts/memory_checks.sh 128 4096 300"

In the example above, we will send an error if our available free
memory is at or below 128 MB. We will send a warning if we are using
4096 MB or more of SWAP space, and list the top 300 processes in our
health check report.

By default the network checks monitor all active NICs. Reports uptime,
the total number of bytes received and the number bytes transmitted.
Errors and warning are based excessive packet loss, excessive number
of dropped packets and/or excessive number of collisions. If you only
want to monitor specific Ethernet interfaces to supply a space
separated list. To customize network checking alerts, edit the network
check section inside the double quotes:

"${DRSMHOME}/health_check_scripts/network_checks.sh 'eth1 eth2'" 

In the example above, we will only monitor the eth1 and eth2
interfaces, all other active interfaces will be skipped.

The user check, generates a list of all users logged into the server
or workstation you are monitoring. If you want to generate an error
alert if a certain user or list of users are logged in:

"${DRSMHOME}/health_check_scripts/user_checks.sh 'usr1 usr2 usr3'"

If you want to generate a warning alert if a certain user or list of users are logged in:

"${DRSMHOME}/health_check_scripts/user_checks.sh NONE 'usr4 usr5 usr6'"

Email Text messaging setup:
-------------------------



Monitoring Crons:
----------------


Support:
-------

