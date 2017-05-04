DataReel System Admin Monitor README file
Last Modified: 05/04/2017

Contents:
--------
* Overview
* Requirements
* Setting up the system admin user
* Installing
* Adding systems to monitor
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


Customizing the Web Interface:
-----------------------------


Setting custom alert thresholds:
------------------------------


Email Text messaging setup:
-------------------------


Monitoring Crons:
----------------


Support:
-------

