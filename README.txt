DataReel System Admin Monitor README file
Last Modified: 10/23/2026

Contents:
--------
* Overview
* Documented Usage
* Requirements
* Setting up the system admin user
* Installing
* Setting up a DRSM development workstation
* Adding systems to monitor
* Web Server Setup
* Customizing the Web Interface
* Setting custom alert thresholds
* Email Text messaging setup
* Monitoring cloud servers
* Plugin monitoring with drsm_run.sh
* Monitoring Crons
* MySQL Utilities
* Postgres Utilities
* Remaining Work on This Project
* Support and Bug Tracking

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

Documented Usage:
----------------
* All commands prefixed with the $ prompt indicate the command is
  executed from a user account or from a service account. 

* All commands prefixed with the # prompt indicate the command is
  executed as root.

* In a configuration file example a ... symbol indicates omitted content
  for brevity.

Requirements:
------------
* Linux system with network access to systems being monitored.
  Tested distributions: RHEL/Rocky/Alma 8, 9, and 10, Fedora,
  Debian 11+, and Ubuntu 20.04+
* Bash 4 or higher, OpenSSH 7.6 or higher
* Apache with PHP 7.2 or higher if using Web interface, PHP 8 is
  supported
* User account to run DRSM software
* Keyed SSH access if using health checking
* Packages on the monitoring host: curl, iputils (ping), procps,
  and a mail command (s-nail, mailx, or bsd-mailx)
* Packages on the monitored hosts: procps. The lm_sensors package
  (lm-sensors on Debian/Ubuntu) is optional for CPU temperatures.

RHEL, Rocky, Alma, and Fedora:
# dnf install curl iputils procps-ng s-nail

Debian and Ubuntu:
# apt install curl iputils-ping procps bsd-mailx

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
$ ssh-keygen -t ed25519

NOTE: DSA keys are no longer supported by current OpenSSH releases.

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
> ssh-copy-id -i ~/.ssh/id_ed25519.pub $s
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

When the install completes DRSM will be installed to ${HOME}/drsm

To install without the EULA prompt, for example from a provisioning
script:

$ DRSM_ACCEPT_EULA=yes ./install.sh

To test your installation:

$ source ~/.drsm.sh
$ vi ${CONFIGdir}/systems.dat

# hostname,description,impact,is_web_server,is_linux,is_cluser_ip,can_ping,can_ssh
#
# is_web_server = ,yes,
# or with web protocal list
# is_web_server = ,yes:HTTP HTTPS FTP,

vm1,Test VM1, Test VM1 affected,no,yes,no,yes,yes
vm2,Test VM2, Test VM2 affected,no,yes,no,yes,yes
vm3,Test VM3, Test VM3 affected,no,yes,no,yes,yes
vm4,Test VM4, Test VM4 affected,no,yes,no,yes,yes

To print a system list:
$ ~/drsm/bin/print_systems.sh

To run a report test:
$ ~/drsm/bin/system_check.sh
$ ~/drsm/bin/system_report.sh 

To test the Web interface:
$ firefox http://$(hostname)/sysadmin

Setting up a DRSM development workstation:
-----------------------------------------
To setup a DRSM development workstation to run from your user account:

$ mkdir -p ~/git
$ cd ~/git
$ git clone https://github.com/datareel/dr_system_monitor
$ cd ~/git/dr_system_monitor/etc
$ cp -p drsm_dev.sh ~/.drsm.sh
$ cd ~/git/dr_system_monitor/utils
$ ./install.sh

Your default install directory will be:

$HOME/drsm

Your default Web directory will be:

$HOME/public_html/sysadmin

To view your $HOME/public_html directory:

$ firefox http://$(hostname)/~$(whoami)/sysadmin

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

RHEL, Rocky, Alma, and Fedora:
$ sudo su - root
# dnf install httpd php
# systemctl enable --now httpd

Debian and Ubuntu:
$ sudo su - root
# apt install apache2 libapache2-mod-php
# systemctl enable --now apache2

The archived report links use Apache directory listings, so enable
"Options Indexes" for the ${WWWdir}/reports directory.

The reports include process lists and logged in user names. Do not
expose the sysadmin Web directory to the internet. Limit access with
the firewall rules below and/or Apache basic authentication, for
example in /etc/httpd/conf.d/sysadmin.conf (RHEL) or
/etc/apache2/conf-available/sysadmin.conf (Debian/Ubuntu):

<Directory /var/www/html/sysadmin>
    AuthType Basic
    AuthName "DRSM"
    AuthUserFile /etc/httpd/drsm.htpasswd
    Require valid-user
</Directory>

# htpasswd -c /etc/httpd/drsm.htpasswd sysadmin

RHEL Apache and PHP Configuration files:
/etc/httpd/conf/httpd.conf
/etc/httpf/conf.d/*.conf
/etc/httpd/conf.modules.d/*.conf
/etc/php.ini

Apache Log files:
/var/log/httpd

Debian and Ubuntu Apache configuration files are in /etc/apache2 and
log files are in /var/log/apache2.

Host-based firewall settings, RHEL family (firewalld):
# firewall-cmd --list-services
# firewall-cmd --list-rich-rules

If no HTTP services are listed above:
# firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.122.0/24" service name="http" accept'
# firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.122.0/24" service name="https" accept'
# firewall-cmd --reload
# firewall-cmd --list-rich-rules

Where  192.168.122.0/24 is the subnet you will allow to view your
system admin reports.

Host-based firewall settings, Debian and Ubuntu (ufw):
# ufw allow from 192.168.122.0/24 to any port 80,443 proto tcp

Web Only Install (Shared Hosting):
---------------------------------
The dashboard can run on a host with nothing but Apache and PHP 7.2
or higher, such as a HostGator or cPanel account. Build the package
on any Linux machine with a copy of DRSM:

$ ~/drsm/utils/make_web_demo.sh -p /drsm/dashboard -o /tmp/drsm_web

Add -s for a public live demo with made up sample hosts, or -a to
turn on the login for access from outside your network. -p is the
URL path the dashboard will be served from.

Upload /tmp/drsm_web/drsm_dashboard.zip to the parent directory of
that path, public_html/drsm for /drsm/dashboard, and extract it. In
cPanel: File Manager, open public_html, create the drsm folder, open
it, Upload the zip, then right click the zip and Extract. Browse to
https://<your site>/drsm/dashboard/

The package finds its own directory, so no server paths need to be
set. Reports go in dashboard/reports, copied from your monitor host
with the same layout as ${REPORTdir}. To protect a private copy, add
-a to turn on the dashboard login, see the next section.

Login for Access From Outside Your Network:
------------------------------------------
The dashboard can ask for a user name and password from anyone
outside your own networks, while people on the internal network get
straight in. It is off by default, so a public demo stays open. It is
plain PHP, so it works on shared hosting with no server changes.

1. Make a password hash for each account. Run this on any machine
with PHP, it asks for the password without showing it:

$ php ~/drsm/utils/drsm_password.php admin
Password:
Same password again:
  'admin' => '$2y$10$Q4m...',

2. Add the settings to $CONFIGdir/drsm.php (config/drsm.php in a Web
only install), with the line printed above in $AUTHusers:

$AUTHenable = 1;
$AUTHnetworks = array('127.0.0.1/32', '::1/128', '10.0.0.0/8',
                      '172.16.0.0/12', '192.168.0.0/16');
$AUTHusers = array(
  'admin' => '$2y$10$Q4m...',
);

$AUTHnetworks lists the internal networks as CIDRs, use your own
office or VPN ranges, or a single public address such as
'203.0.113.7/32'. An address not on the list gets the login page.

3. Block direct access to the report folder, since it is served as
plain files that the login does not cover. With login on, the
"Archived reports" buttons read reports through the pages instead.
make_web_demo.sh -a does this for you. Otherwise:

$ printf 'Require all denied\n' > $REPORTdir/.htaccess

Other settings, all optional:

$AUTHproxies = array();     // Proxies or CDNs in front of the site
$AUTHhttps = 1;             // Refuse logins over plain HTTP
$AUTHidleminutes = 60;      // Sign out after this long idle
$AUTHmaxhours = 12;         // Sign out this long after login
$AUTHmaxfails = 5;          // Failed logins from one address before
$AUTHlockminutes = 15;      // it is locked out for this long
$AUTHstatedir = '/path';    // Failed login counts, default
                            // $CONFIGdir/auth, must be writable by
                            // the Web server
$AUTHsessiondir = '';       // PHP session files, default PHP's own

How it decides who is internal: the address of the connection
(REMOTE_ADDR) is used, because a browser can put anything in an
X-Forwarded-For header. Only when the site sits behind a reverse
proxy or CDN, such as Cloudflare, list that proxy's ranges in
$AUTHproxies. X-Forwarded-For is then read only from those proxies,
right to left, and the first address that is not one of them counts.
On a plain HostGator or cPanel account leave $AUTHproxies empty.

Passwords are stored as bcrypt hashes, never in plain text. Sessions
use HttpOnly, SameSite cookies, marked Secure on HTTPS, with a new
session id at login. The login and sign out forms carry a CSRF token.
After $AUTHmaxfails failed logins an address is locked out for
$AUTHlockminutes minutes, and a user name after four times as many.
Failed logins go to the PHP error log. The login page needs HTTPS
unless $AUTHhttps is 0.

Customizing the Web Interface:
-----------------------------
The Web interface has four views, linked from the top bar:

Overview      Situational awareness: overall state, host counts, group
              connectivity and health checks, a "Needs attention" list
              of every current error and warning, a host matrix, and a
              card for each host with CPU, memory and disk use
Heat map      Every host against every plugin check, colored by state,
              or against CPU, memory, disk, load and swap use
Hosts         Sortable table of all hosts, select a host for its report
Connectivity  Group connectivity and health reports, by host group

The pages work on phones, tablets and desktops, have light and dark
themes, refresh themselves, and have a wall display mode for a NOC
screen. They load no fonts or scripts from the internet. PHP 7.2 or
higher is required.

Optional settings, add them to $CONFIGdir/drsm.php:

$SITEtitle = 'MY System Monitor';  // Name in the top bar
$REFRESHseconds = 60;              // Auto refresh, 0 turns it off
$STALEminutes = 60;                // Report age that counts as not
                                   // reporting, 0 turns it off

To change colors or styles, from your sysadmin user account:

$ source ~/.drsm.sh
$ vi $WWWdir/site/custom.css

custom.css is loaded after the DRSM styles. The colors are CSS
variables, for example:

:root { --accent: #e11d48; }

To replace the page header and footer, add page_header.php and
page_footer.php to $WWWdir/site. Print drsm_head_assets() in your
header to keep the DRSM styles and scripts, and keep the <main> tag
open for the page content:

$ vi $WWWdir/site/page_header.php

<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>MY System Monitor</title>
<?php echo drsm_head_assets(); ?>
</head>
<body data-refresh="<?php echo (int)$REFRESHseconds; ?>">
<main class="page">

$ vi $WWWdir/site/page_footer.php

</main>
</body>
</html>

NOTE: A page_header.php from an older DRSM release still works, but
the pages will not be styled until it prints drsm_head_assets().

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

The health check scripts are copied to each monitored host in the
${REMOTEdir} directory. The default is drsm/health_check_scripts
relative to the remote SSH user's home directory. To change it set
REMOTEdir in your ~/.drsm.sh file. Profiles created by older DRSM
versions call ${DRSMHOME}/health_check_scripts, which is the same
directory when the remote and local users have the same home
directory. Delete an old profile to have a new one generated.

Edit the system profile you need to modify, for example:

$ vi vm1_profile.sh

By default the disk checks, montiors disk usage for all mounted
partitions, warns at 90 percent usage, and errors at 99 percent usage.
If you want to skip the check on some of your mounted partitions you
need to supply a space separated list. To customize disk checking
alerts, edit the disk check section inside the double quotes:

"${REMOTEdir}/disk_checks.sh '/tmp /usr1' 80 90" 

In the example above, we will skip checks on /tmp and /usr1. We will
send a warning if we are at 80% disk usage on mounted partitions and
send an error if we are at 90% disk usage. If you want to set the
warning or error thresholds without skipping any mounted partitions:

"${REMOTEdir}/disk_checks.sh NONE 80 90"

By default the CPU check montiors the CPU usage for all sockets,
physical cores, and logical cores. The default warning level is 85
percent total usage and the default error level is 95 percent total
usage. By default the CPU check will list the top 100 processes in the
system report. To customize CPU checking alerts, edit the CPU check
section inside the double quotes:

"${REMOTEdir}/cpu_checks.sh 75 85 200"

In the example above, we will send a warning if we are at 75% percent
CPU usage, send an error if we are a 85% CPU usage, and list the top
200 processes in our health check report.

The load check monitors the 15 minute load average. The default warning
level is 2 times the number of CPUs and the default error level is 4
times the number of CPUs. To customize load
average checking alerts, edit the load check section inside the double
quotes:

"${REMOTEdir}/load_checks.sh 100 250"

In the example above, we will send a warning if our 15 minute load
average reaches 100 and send an error if our 15 minute load average
reaches 250. 

The memory check monitors available free memory, the amount
of SWAP spaced used, and lists the top 100 processes by default. The
default error level for free memory is 256 MB or less. The default
warning for SWAP usage is 1024 MB or higher. The top number of
processes listed in the report defaults to 100. To customize memory
checking alerts, edit the memory check section inside the double
quotes:

"${REMOTEdir}/memory_checks.sh 128 4096 300"

In the example above, we will send an error if our available free
memory is at or below 128 MB. We will send a warning if we are using
4096 MB or more of SWAP space, and list the top 300 processes in our
health check report.

By default the network checks monitor all active NICs, skipping
loopback, bridge, container, and VM tap devices. Reports uptime, the
total number of bytes received and the number bytes transmitted. The
check samples the NIC counters over 5 seconds. An error is sent if
more than 100 RX or TX errors occur in the sample, and a warning if
more than 1000 packets are dropped or more than 100 collisions occur.
To change the levels pass the NIC list (or '' for all NICs), dropped
packets, collisions, errors, and the sample time in seconds:

"${REMOTEdir}/network_checks.sh '' 5000 500 500 10"
 If you only
want to monitor specific Ethernet interfaces you need to supply a space
separated list. To customize network checking alerts, edit the network
check section inside the double quotes:

"${REMOTEdir}/network_checks.sh 'eth1 eth2'" 

In the example above, we will only monitor the eth1 and eth2
interfaces, all other active interfaces will be skipped.

The user check, generates a list of all users logged into the server
or workstation you are monitoring. If you want to generate an error
alert if a certain user or list of users are logged in:

"${REMOTEdir}/user_checks.sh 'usr1 usr2 usr3'"

If you want to generate a warning alert if a certain user or list of users are logged in:

"${REMOTEdir}/user_checks.sh NONE 'usr4 usr5 usr6'"

Email Text messaging setup:
-------------------------
By default the DRSM alerts are emailed to the "root" account on the
server or workstation running the DRSM package. Email and text
messages are only sent in 4 hour increments. For example, if you run
DRSM crons every 30 minutes and there is a system reporting an error,
you get one email and/or text error alert once in a 4 hour period and
not every 30 minutes. This prevents DRSM from generating excessive
email and/or text messages.

To setup and test the alert messaging, run the following:

$ source ~/.drsm.sh
$ cd $DRSMHOME/bin
$ ./test_alert.sh

To add or remove email addresses or SMS addresses, edit the email list
file:

$ source ~/.drsm.sh
$ cd $DRSMHOME/etc
$ vi alert.email.list

export EMAILlist="root,example@example.com"
export TEXTlist="5555555555@vtext.com,5555555555@txt.att.net"

For SMS, text messaging, use the “mobile number”@”domain” for mobile
provider, for example:
  
Verizon Wireless: mobile_number@vtext.com
T-Mobile: mobile_number@tmomail.net

NOTE: Several carriers have shut down their email to text gateways,
including AT&T (2025), Sprint, Nextel, and Cingular. Check with your
carrier before relying on text alerts.

DRSM uses the first mail, mailx, or s-nail command found in the PATH.
To use another mailer set MAILcmd in your ~/.drsm.sh file.

If your postfix configuration is not configured for a relay host or
smart host you may not be able to email or text from the workstation
or server running the DRSM package. To monitor postfix:

$ su - root
# tail -f /var/log/maillog

If your data center has a relay host, you can use the relay host by
modifying the postfix configuration:

# vi /etc/postfix/main.cf

relayhost = 192.168.1.12

# systemctl restart postfix

If you do not have a relay host, you can setup a smart host using an
external email account:

# cd /etc/postfix
# vi main.cf

# Enforce TLS encryption
smtp_tls_security_level = encrypt
smtp_sasl_auth_enable = yes
smtp_sasl_security_options = noanonymous
smtp_sasl_password_maps = hash:/etc/postfix/relay_passwd
relayhost = [smtp.gmail.com]:587
smtp_generic_maps = hash:/etc/postfix/generic

# vi /etc/postfix/relay_passwd

mailserver.example.com USERNAME:PASSWORD

# chmod 600 /etc/postfix/relay_passwd
# postmap /etc/postfix/relay_passwd 
# rm /etc/postfix/relay_passwd 

# vi /etc/postfix/generic

# NOTE: We need to change our From address to a valid domain
root@localdomain.local  username@example.com
@localdomain.local      username@example.com

# postmap /etc/postfix/generic

After changing the postfix configuration and building the hashes,
restart postfix to load the configuration changes and new hash tables:

# systemctl restart postfix
 
Monitoring cloud servers:
------------------------
* Most cloud providers block ICMP ping by default. Set can_ping to no
  for cloud servers. When can_ping is no and can_ssh is yes, the
  connectivity check uses an SSH login to test that the host is up.

* Most cloud providers block outbound SMTP on port 25. Use a smart
  host on port 587 as shown in the email setup section above.

* If the SSH user, port, or key differ from the monitoring account,
  set them in the monitoring account's ~/.ssh/config file using the
  same host name you put in systems.dat:

  Host cloud1.example.com
      User ubuntu
      Port 22
      IdentityFile ~/.ssh/id_ed25519

* SSH connections use BatchMode, a 15 second connect timeout, and
  StrictHostKeyChecking=accept-new. A new host's key is accepted on
  first contact, a changed host key is refused. To change the options
  set SSH_OPTS and SCP_OPTS in your ~/.drsm.sh file.

* Shared hosting accounts (for example HostGator shared plans) use a
  jailed SSH shell, often on port 2222. Set the port in ~/.ssh/config.
  On shared hosting the CPU, load, and process checks show the shared
  server, not just your account.

* To monitor the workstation running DRSM, add it to systems.dat and
  set up keyed SSH from the DRSM account to itself.

Plugin monitoring with drsm_run.sh:
----------------------------------
bin/drsm_run.sh is the plugin based replacement for system_check.sh
and system_report.sh. Each check is a folder under plugins/ with a
plugin.conf manifest and a BASH script, so new checks are added
without changing any core script. It writes the same report files,
so the Web pages and email/text alerts work unchanged. The old
scripts keep working while you move over. See PLUGINS.md for the
full guide and for writing your own plugins.

Hosts are set up with one file each in ${DRSMHOME}/etc/hosts instead
of a systems.dat row and a generated <host>_profile.sh script. To
convert your current systems.dat, dev_systems.dat, and profiles:

$ ~/drsm/utils/migrate_systems_dat.sh
$ ~/drsm/bin/drsm_run.sh -l

Until host files exist, drsm_run.sh reads systems.dat directly.

To run all hosts, a single host, or the dev group with no alerts:

$ ~/drsm/bin/drsm_run.sh -n
$ ~/drsm/bin/drsm_run.sh -n -H cloud1
$ ~/drsm/bin/drsm_run.sh -n -g dev

To run only the connectivity probes, the system_check.sh job:

$ ~/drsm/bin/drsm_run.sh -m probes

To create a plugin for your own site, for example a custom
application:

$ ~/drsm/utils/new_plugin.sh local/myapp

Monitoring Crons:
----------------
To run the DRSM package for production and development system
monitoring setup user crons to run the system check and report
scripts. In the example crontab entries below we are using
/home/sysadmin/drsm as our installation directory:

# Check for production system errors every 30 minutes
*/30 * * * * /home/sysadmin/drsm/bin/system_check.sh &> /dev/null
15,45 * * * * /home/sysadmin/drsm/bin/system_report.sh &> /dev/null

# Send a status report every week day at 13:00
00 13 * * mon,tue,wed,thu,fri /home/sysadmin/drsm/bin/system_check.sh YES &> /dev/null
15 13 * * mon,tue,wed,thu,fri /home/sysadmin/drsm/bin/system_report.sh YES &> /dev/null

# Check for DEV system errors
35 09,10,11,12,13,14,15,16 * * mon,tue,wed,thu,fri /home/sysadmin/drsm/bin/system_check.sh NO DEV &> /dev/null
55 09,10,11,12,13,14,15,16 * * mon,tue,wed,thu,fri /home/sysadmin/drsm/bin/system_report.sh NO DEV &> /dev/null

# System reports archive and purge
59 23 * * * /home/sysadmin/drsm/bin/archive.sh
00 * * * * /home/sysadmin/drsm/bin/purge.sh

If you are running the DRSM package on a server cluster, the following
is an HA crontab example using the sysadmin user account:

# Check for production system errors every 30 minutes
*/30 * * * * sysadmin bash -c '/home/sysadmin/drsm/bin/system_check.sh &> /dev/null'
15,45 * * * * sysadmin bash -c '/home/sysadmin/drsm/bin/system_report.sh &> /dev/null'

# Send a status report every week day at 13:00
00 13 * * mon,tue,wed,thu,fri sysadmin bash -c '/home/sysadmin/drsm/bin/system_check.sh YES &> /dev/null'
15 13 * * mon,tue,wed,thu,fri sysadmin bash -c '/home/sysadmin/drsm/bin/system_report.sh YES &> /dev/null'

# Check for DEV system errors
35 09,10,11,12,13,14,15,16 * * mon,tue,wed,thu,fri sysadmin bash -c '/home/sysadmin/drsm/bin/system_check.sh NO DEV &> /dev/null'
55 09,10,11,12,13,14,15,16 * * mon,tue,wed,thu,fri sysadmin bash -c '/home/sysadmin/drsm/bin/system_report.sh NO DEV &> /dev/null'

# System reports archive and purge
59 23 * * * sysadmin bash -c '/home/sysadmin/drsm/bin/archive.sh &> /dev/null'
00 * * * *  sysadmin bash -c '/home/sysadmin/drsm/bin/purge.sh &> /dev/null'

MySQL Utilities:
---------------
The DRSM MySQL utilities include backup, stat collection, and
optimization scripts. Each utility will give you the option to store
MySQL credentials, allowing you to automate database backups and
optimization. To test connectivity and store MySQL credentials:

$ source ~/.drsm.sh
$ cd $DRSMHOME/mysql
$ ./mysql_dbflush.sh 

MySQL HOST: cms.example.com
MySQL USER: dbadmin
MySQL PW: ***********
Do you want to save MySQL auth for cms.example.com (yes/no)> yes

Flushing QUERY CACHE
Flushing PRIVILEGES
Flushing TABLES
Flushing HOSTS
Flushing LOGS
Flushing STATUS
Flushing USER_RESOURCES

Run the same command again, this time supplying the MySQL server's
hostname:

$ ./mysql_dbflush.sh cms.example.com

If you selected yes to save the MySQL credentials, you will not be
prompted for a user name and password.

To run a MySQL backup, first check your backup settings:

$ vi ~/.drsm.sh

...
export BACKUP_age=30
...
export BACKUPdir=${HOME}/backups

This config will save 30 days of backups in the $HOME/backups
directory. Next, run the back up script supplying the hostname of the
MySQL server you wish to backup:

source ~/.drsm.sh
cd $DRSMHOME/mysql
./mysql_backup.sh cms.example.com

To collect MySQL statistics:

./collect_mysql_stats.sh cms.example.com

To optimize MySQL performance:

./mysql_defragment.sh cms.example.com
./mysql_dbflush.sh cms.example.com

Postgres Utilities:
------------------
The DRSM Postgres utilities include backup and optimization
scripts. Each utility will give you the option to store Postgres
credentials, allowing you to automate database backups and
optimization.

To test connectivity and store Postgres credentials:

$ source ~/.drsm.sh
$ cd $DRSMHOME/postgres
$ ./postgres_db_checks.sh

PG host: gis.example.com
PG username: postgres
PG pass: ***********
Do you want to save PG auth for gis.example.com (yes/no)> yes

Run the same command again, this time supplying the Postgres server's hostname:

$ ./postgres_db_checks.sh gis.example.com

If you selected yes to save the Postgres credentials, you will not be
prompted for a user name and password.

To run a Postgres backup, first check your backup settings:

$ vi ~/.drsm.sh

...
export BACKUP_age=30
...
export BACKUPdir=${HOME}/backups

This will save 30 days of backups in the $HOME/backups
directory. Next, run the backup script supplying the hostname of the
database server you wish to backup:

$ source ~/.drsm.sh
$ cd $DRSMHOME/postgres
$ ./postgres_backup.sh gis.example.com

To optimize Postgres database performance:

$ ./postgres_optimize.sh gis.example.com

If you need to backup and optimize different versions of Postgres, you
will need to configure your runtime environment to use the same
version of Postgres installed on each DB server. For example if your
workstation has postgres 8.4 installed and your server is running
version 9.2, you will need to use version 9.2 utilities on your
workstation. To do this globally on your system monitor, install a
copy of 9.2 in /usr/local and set the following environmental
variables: 

$ vi ~/.drsm.sh

# Postgres utils settings
export LD_LIBRARY_PATH="/usr/local/pgsql-9.2/lib"
export PSQL="/usr/local/pgsql-9.2/bin/psql"
export PG_DUMP="/usr/local/pgsql-9.2/bin/pg_dump"
export PG_RESTORE="/usr/local/pgsql-9.2/bin/pg_restore"
export VACUUMDB="/usr/local/pgsql-9.2/bin/vacuumdb"

To set Postgres variables for individual database servers:

$ source ~/.drsm.sh
$ vi $DRSMHOME/.auth/gis.example.com.pg

Set your PG variables in the .pg file corresponding to each database
server's hostname.

Remaining Work on This Project:
------------------------------
* Rewrite of Postgres stat collection

See CHANGELOG.md for the list of changes in each release.

Support and Bug Tracking:
------------------------
For any DRSM support issues, questions, or suggestions open a ticket
on GITHUB:

https://github.com/datareel/dr_system_monitor/issues

If you wish to contribute to the DRSM project, fork a copy of the DRSM
repo or post code updates to open issue thread.

