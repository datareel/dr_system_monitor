# Changelog

All notable changes to the DataReel System Monitor (DRSM) are listed here.

## Unreleased: HTML documentation

### Added

- `docs/`, an HTML documentation set styled like the dashboard, with
  light and dark themes and no external fonts or scripts: overview,
  install, deployment setups (3 node production cluster, workstation
  with a dashboard on a PHP hosting account, the public live demo,
  cloud servers), Web dashboard, plugins, thresholds and alerts, MySQL
  and Postgres, and what's new. Screenshots are of the live demo.
- `tests/docs_test.sh`, run in CI, checks every local link, image and
  anchor in the docs.

### Changed

- `utils/install.sh` installs the docs to `${DRSMHOME}/docs`.

## Unreleased: Web interface redesign

A new look for the Web interface. Written by
[Claude Code](https://claude.com/claude-code) at the request of the
project owner. The pages read the same report files as before, so
`system_report.sh`, `system_check.sh` and `drsm_run.sh` reports all
show.

### Added

- Overview page for situational awareness: overall state banner, host
  counts, group connectivity and health checks, a "Needs attention"
  list of every current error and warning linked to its plugin, a host
  matrix, and a card per host with CPU, memory and disk bars and plugin
  states. Search and filter by state and host group.
- Heat map page: hosts against plugin checks colored by state, or
  against CPU, memory, disk, load per CPU and swap use.
- Host report page with resource gauges and a collapsible panel per
  plugin, problems first, with error and warning lines highlighted.
- Hosts table, sortable by any column. Connectivity page covers the
  connectivity and health reports for every host group.
- Light and dark themes, auto refresh with pause, wall display mode,
  relative report times, and stale host detection (`$STALEminutes`).
- Works on phones, tablets and desktops, under any URL path (for
  example `/drsm/dashboard`), with no fonts or scripts loaded from the
  internet.
- `www/php/drsm_lib.php`, shared report parsing and page layout.
  `site/custom.css` and `$SITEtitle` for site branding.
- `utils/make_web_demo.sh` builds a Web only copy of the dashboard for
  shared hosting such as HostGator, unpacked into any directory, with
  optional made up sample reports (`-s`) for a public live demo.
- `tests/www_test.sh` renders every page from real `drsm_run.sh`
  reports. CI lints and tests the pages with PHP 7.2 and 8.3.

### Changed

- The Web pages need PHP 7.2 or higher.
- A custom `site/page_header.php` must print `drsm_head_assets()` to
  get the new styles, see README.txt.

## Unreleased

Plugin framework, phase 1 of the plugin module design. Written by
[Claude Code](https://claude.com/claude-code) at the request of the
project owner. Nothing existing is removed: `system_check.sh`,
`system_report.sh` and the `bin/*_checks.sh` scripts work as before
while sites move over.

### Added

- `bin/drsm_run.sh`, a plugin runner that replaces the per-host loops in
  `system_check.sh` and `system_report.sh`. It writes the same report
  files, so the Web pages and email/text alerts need no changes, plus a
  per-host `status.json` with each plugin's state. `-m probes` runs the
  connectivity checks only, `-g` picks a host group, `-H` one host, `-n`
  turns alerts off, `-l` lists what would run.
- Plugin contract: each check is `plugins/<category>/<name>/` with a
  `plugin.conf` manifest and a `check.sh` (runs on the host) or
  `probe.sh` (runs on the monitor host). Settings reach the script as
  `DRSM_<KEY>` environment variables instead of positional arguments.
  Exit codes follow the Nagios convention (0 OK, 1 WARNING, 2 ERROR,
  3 UNKNOWN). Output keeps the `INFO - / WARNING - / ERROR -` lines and
  adds optional `METRIC` lines. See PLUGINS.md.
- Plugins ported from the existing checks with the same messages and
  thresholds: `core/cpu`, `core/load`, `core/memory`, `core/users`,
  `storage/disk`, `storage/raid`, `network/nics`, and the probes
  `network/ping`, `network/http`, `network/https`, `network/ftp`.
- Collectors: `local` for the monitor host and `ssh-linux`, which copies
  only the plugins a host uses to `~/drsm_agent` (skipped when unchanged)
  and runs them all in one SSH session.
- The runner enforces each plugin's `TIMEOUT`, reports a plugin with a
  missing required command as UNKNOWN instead of failing, and reports a
  plugin that returns nothing as an ERROR.
- Host files in `etc/hosts/<host>.conf` replace `systems.dat` rows and
  generated `<host>_profile.sh` scripts. They are parsed, never sourced.
  `etc/hosts/_defaults.conf` holds shared settings. Until host files
  exist the runner reads `systems.dat` directly.
- `utils/migrate_systems_dat.sh` converts `systems.dat`,
  `dev_systems.dat` and the custom arguments in profile scripts into
  host files.
- `utils/new_plugin.sh` creates a plugin from a template. Site plugins
  go in `plugins/local/`, which updates never overwrite.
- `tests/drsm_run_test.sh`, run in CI, tests the runner, settings,
  timeouts, probes, groups and migration without SSH or root.

### Changed

- `utils/install.sh` installs `lib`, `collectors`, `plugins` and
  PLUGINS.md, and creates `etc/hosts/_defaults.conf` once.

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
