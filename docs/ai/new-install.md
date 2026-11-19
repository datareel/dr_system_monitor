# New DRSM install

For admins (and their AI assistants) who set up DRSM on a new monitor
host. Read the "Before you use AI assistance" part and sections 0 and 1
of `AGENTS.md` first: the agent shows each step, the admin runs it or
approves it, one host at a time. The full manual is `README.txt`
(Requirements to Monitoring Crons) and `docs/install.html`.

## 1. Read-only check first

Unpack the release (step 3) and run the read-only check as the DRSM
user. It changes nothing; give the output to the agent:

```
$ bash dr_system_monitor/utils/drsm_preflight.sh
```

Before the install it reports the missing install folder and
dashboard folders as INFO or WARN. Every FAIL (for example no bash 4,
no `ssh` or `curl`, PHP older than 7.2) must be fixed first.

## 2. Packages and the DRSM user

- Monitor host: bash 4 or later, OpenSSH 7.6 or later, `curl`, `ping`,
  a mail command, and Apache with PHP 7.2 or later for the dashboard.
  RHEL, Rocky, Alma, Fedora: `dnf install curl iputils procps-ng s-nail`.
  Debian, Ubuntu: `apt install curl iputils-ping procps bsd-mailx`.
- The DRSM user (default `sysadmin`, set by `SYSADMIN_USERNAME`) runs
  every script and owns the reports. README.txt "Setting up the system
  admin user" has the commands. The admin makes the account and its
  SSH key (`ssh-keygen -t ed25519`); the agent never reads or copies
  private keys.
- Monitored Linux hosts over SSH need the DRSM user and its public key
  in `authorized_keys`. The admin copies the key (`ssh-copy-id`), one
  host at a time.

## 3. Get and check the release

```
$ mkdir -p ~/git && cd ~/git
$ wget https://datareel.com/downloads/drsm/dr_system_monitor-<version>.tar.gz
$ sha256sum dr_system_monitor-<version>.tar.gz
```

Compare the checksum with the one on the downloads page
(https://datareel.com/downloads/drsm/). Stop if it differs. Then
`tar xzf`, and `mv dr_system_monitor-<version> dr_system_monitor`.

## 4. Config and folders

1. `cp etc/drsm.sh ~/.drsm.sh` (or `etc/drsm_dev.sh` for a development
   workstation that runs from a user account), then set `WWWdir`,
   `SYSADMIN_USERNAME`, `SYSADMIN_GROUPNAME` and `DRSMHOME` in it.
   A second install in the same account uses its own file named by
   `DRSM_CONFIG`.
2. As root, make `$WWWdir` and give it to the DRSM user (README.txt
   "Installing").
3. Web server: README.txt "Web Server Setup" and docs/install.html
   "Web". Turn on the dashboard login (README.txt "Login for Access
   From Outside Your Network") before the dashboard is reachable from
   outside the network. The admin types the password; the agent never
   sees it.

## 5. Install

```
$ cd ~/git/dr_system_monitor/utils
$ ./install.sh
```

`install.sh` is not a dry run: it shows the EULA (GNU General Public
License version 3, no warranty) and installs after `Yes`. The admin
answers the EULA. `DRSM_ACCEPT_EULA=yes` is for the admin's own
provisioning scripts only; an agent does not accept the license for
the admin.

## 6. Hosts and the first run

1. `etc/hosts/_defaults.conf` holds shared settings, then one
   `<host>.conf` per host (`docs/ai/maintain-a-site.md`, "Hosts").
   Windows hosts and Linux agent hosts: `utils/wra_hosts.sh` and
   `utils/lra_hosts.sh` (dry run, then `--apply`).
2. `~/drsm/bin/drsm_run.sh -l` lists the hosts and plugins (read-only).
3. `~/drsm/bin/drsm_run.sh -n -H <host> -v` checks one host with no
   alerts. Fix every ERROR that is a setup problem (missing key,
   missing command) before the next host.
4. Open the dashboard and check the host page.

## 7. Cron and alerts

- Alert addresses: `$DRSMHOME/etc/alert.email.list` (`EMAILlist`,
  `TEXTlist`), or `ALERT_EMAIL` in a site file. The admin enters the
  addresses.
- Cron lines: `crontabs/crontab_example.txt` and README.txt "Plugin
  monitoring with drsm_run.sh". The admin reads and installs them with
  `crontab -e`; an agent does not install cron lines.
- Run `utils/drsm_preflight.sh` again: the newest report age and the
  cron lines should now be OK.

## Report back

The packages added, the config values set (no passwords), the hosts
added and their first run result, the cron lines the admin installed,
and the final pre-flight summary.
