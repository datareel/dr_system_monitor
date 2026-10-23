# Changelog

All notable changes to the DataReel System Monitor (DRSM) are listed here.

## 1.30 - 2026-10-23

This release is a full code review and modernization pass. The code was
reviewed and updated by [Claude Code](https://claude.com/claude-code), with
the changes made at the request of the project owner. The goal is to run
DRSM on current Linux distributions (RHEL/Rocky/Alma 8, 9, and 10, Fedora,
Debian 11+, Ubuntu 20.04+), PHP 7.2 through 8, and cloud servers.

### Fixed: monitoring did not work or reported wrong results

- `system_report.sh` had no `#!/bin/bash` line. Run from cron on Debian or
  Ubuntu it ran under `dash` and failed.
- `system_report.sh` never detected a failed SSH login, because the exit code
  of `SSHCheck | tee` was the exit code of `tee`.
- `system_report.sh` did not initialize `has_warning`, so the "no warnings or
  errors" message was never written.
- `system_report.sh` reused the previous run's results when a remote check
  failed. Stale output is now deleted before each run, and a check that
  returns nothing is reported as an ERROR.
- `HTTPCheck` always passed, even when the web server was down. The exit
  code it tested had already been overwritten. HTTP, HTTPS, and FTP checks
  now share one check that uses `curl` (RHEL 10 replaced `wget` with
  `wget2`). A server that answers with an error or redirect still counts as
  up, and an invalid HTTPS certificate counts as a failure.
- The web checks saved every downloaded page to disk. They no longer do.
- `cpu_checks.sh` reported the average CPU usage since boot, not the current
  usage. It now samples `/proc/stat` twice. On hosts with 10 or more CPUs the
  per-CPU lines (`cpu1`, `cpu10`, ...) also matched each other and broke the
  math. Hypervisor steal time is now reported, which matters on cloud VMs.
- `load_checks.sh` reported load warnings as errors, and used `bc`, which is
  not installed on many minimal and cloud images. It now reads
  `/proc/loadavg`. Default levels now scale with the CPU count (warning at 2x,
  error at 4x) instead of a fixed 35/50, which never fired on small VMs.
- `memory_checks.sh` now uses the kernel's `MemAvailable` value and no longer
  needs `bc`. The low memory error message printed the wrong number.
- `network_checks.sh` never re-read the counters after its retry wait, so
  the retry logic compared a value with itself. It now reads
  `/sys/class/net/*/statistics` over a 5 second sample and alerts on the
  increase. Interface names such as `eth0@if12` and `veth*`/`docker*`
  devices are handled.
- `disk_checks.sh` only checked file systems listed in `/etc/fstab` and only
  ext2/3/4 and xfs. It now checks every mounted local file system (including
  btrfs, the Fedora default) and also warns on inode usage. The RAID
  check's exit code was read after it had been overwritten.
- `user_checks.sh` matched user names as substrings (`bob` matched `bobby`),
  and the logged in user count was parsed from `w` output in a way that
  broke depending on the uptime format.
- `raid_checks.sh` reported predictive drive failures but exited 0. It now
  also checks Linux software RAID (`/proc/mdstat`) for degraded, inactive,
  failed, and rebuilding arrays.
- `read_cpu_temps.sh` and the CPU temperature check required
  `/etc/sysconfig/lm_sensors`, which only exists on RHEL. Temperatures are
  now parsed for Intel (`Core N`, `Package id N`) and AMD (`Tctl`, `Tdie`)
  sensors, and sensors without high/critical limits no longer cause errors.
- `process_lock.sh` matched PIDs as substrings of `ps` output. A stale lock
  could make it kill unrelated processes whose PID contained the same digits.
  It now checks the exact PID and kills only that process and its children.
  Lock files are no longer world writable.
- `text_email_alert.sh` hard coded `/bin/mail` and needed `bc`. It now finds
  `mail`, `mailx`, or `s-nail`, or uses `MAILcmd` from the config.
- `purge.sh` wrote the report purge log twice to the same file, so the first
  log was lost.
- The crontab examples said "every 30 minutes" but ran once an hour.
- `install.sh` did not install the `postgres` directory and only worked when
  run from the `utils` directory.
- `drsm_dev.sh` could pick the wrong group name for the current user.

### Fixed: web interface (PHP 8)

- `default_header.php` had a raw `<meta>` tag inside a PHP block. This was a
  parse error, so every page failed unless a custom site header was
  installed.
- `"${var}"` string interpolation, deprecated in PHP 8.2, was changed to
  `"{$var}"` in all PHP files.
- `reports.php` parsed the report time from a date string that contains
  colons, so every "last report" time showed as 1970. It now uses the
  `ETIME` epoch field. Descriptions that contain colons are no longer cut
  off.
- `readreport.php` and `checks.php` used `include()` to print report text.
  Reports contain remote command output, so any `<?php` in that output would
  run as code on the web server, and any HTML in it was rendered. Reports are
  now escaped and printed as text.
- `readreport.php` accepted `../` in the host name. It now only accepts a
  plain host name, and shows the site header and footer.
- `index.php`: `CheckServerStatus()` used config variables without
  `global`.

### Fixed: MySQL and Postgres utilities

- `collect_mysql_stats.php` used the `mysql_*` functions, which were removed
  in PHP 7. It now uses `mysqli`.
- MySQL passwords were passed on the command line, visible to every user in
  `ps`. The scripts now use a temporary private option file.
- Saved credential files broke on passwords containing quotes. Values are
  now quoted with `printf %q`.
- `mysql_backup.sh` now skips the `information_schema`,
  `performance_schema`, and `sys` schemas and uses `--single-transaction`
  for consistent InnoDB backups without locking. Routines and triggers are
  included.
- `mysql_defragment.sh` skipped the system schemas, no longer misreads
  table status columns that contain spaces, and no longer divides by zero
  on empty tables.
- `mysql_dbflush.sh` no longer fails on MySQL 8, which removed the query
  cache.
- The Postgres scripts now list databases with a SQL query instead of
  parsing `psql -l` output, and `postgres_backup.sh` now writes `pg_dump`
  and `gzip` errors to its log instead of losing them.

### Changed

- Shared SSH options in `SSH_OPTS`/`SCP_OPTS`: `BatchMode`, a 15 second
  connect timeout so a down host cannot hang a cron run, and
  `StrictHostKeyChecking=accept-new` instead of `no`, so a changed host key
  is refused.
- Health check scripts are copied to `REMOTEdir` on each host, by default
  `drsm/health_check_scripts` relative to the remote user's home directory.
  This works when the remote SSH user is different, as on cloud images
  (`ubuntu`, `ec2-user`). For a standard install this is the same directory
  as before.
- When `can_ping` is `no` and `can_ssh` is `yes`, `system_check.sh` tests
  connectivity with an SSH login, since most cloud providers block ping.
- Connection alert emails now include the IMPACT line for each failure.
- `systems.dat` is parsed without generating and sourcing a shell script,
  which also handles Windows line endings and spaces around commas.
- `install.sh` can run without the EULA prompt with `DRSM_ACCEPT_EULA=yes`.
- `pingscan.sh` uses `ip neigh` and `getent` instead of the deprecated
  `arp` and `host` commands.
- README updated for Debian/Ubuntu, `dnf`, ed25519 SSH keys (DSA keys are
  no longer supported by OpenSSH), cloud servers, protecting the web
  reports, and email-to-text gateways that carriers have shut down.
- Added a GitHub Actions lint workflow (bash syntax, ShellCheck errors, PHP
  syntax).

### Known issues not changed in this release

- `postgres_optimize.sh` runs `vacuumdb --full`, which takes exclusive table
  locks while it runs.
- `postgres_stats.sh` only lists databases; stat collection is still to do.
- Saved database credentials in `$DRSMHOME/.auth` are plain text files
  protected by file permissions (mode 600).
