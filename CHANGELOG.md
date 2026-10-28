# Changelog

All notable changes to the DataReel System Monitor (DRSM) are listed here.

## Unreleased

### Dashboard

#### Added

- The top bar has an Org links menu when the site picker shows All
  sites or a whole organization: the org links of each organization
  the user may see, by tier. The Site links menu for one site is
  unchanged.
- Reports from your own scripts: list text reports in a file named by
  `$EXTreports` and they show on a new page (extreports.php), in the
  top bar and in an Overview panel, with the ERROR, FAILED and WARNING
  rule of the older dashboard includes and an optional max age.
- `$METRICSskip`, for example `array("windows")`, names platforms or
  groups that send no resource metrics: their hosts get no gauges and
  are left off the trends page and the resource use heat map.
- `$SITElogo` puts a logo in the top bar and `$NAVextra` adds your own
  top bar menu items with optional submenus.
- A single-site install shows the Site links menu when
  `etc/sites/default/default.site` has LINK lines; drsm_run.sh writes
  them to `$REPORTdir/site.json`.

### Documentation

#### Added

- Guides for AI coding assistants: `AGENTS.md`, with
  `.github/copilot-instructions.md`, `GEMINI.md` and `CLAUDE.md`
  pointing to it, `llms.txt`, `llms-full.txt`, and task guides in
  `docs/ai` (maintain a site, write a plugin, change the dashboard),
  linked from the docs Overview page. `docs/ai/make_llms.sh` rebuilds
  `llms-full.txt`; `tests/docs_test.sh` checks it is current.

### Scripts

#### Added

- Ansible inventory as the host list: with `ANSIBLE_INVENTORY` and
  `ANSIBLE_TIERS` in the config, `drsm_run.sh` checks the Linux hosts
  of an Ansible INI inventory in the tiers of their groups (nested
  `:children` and host ranges included). Host files only add settings
  for those hosts; other host files work as before (`lib/drsm_ansible.sh`).
  `ANSIBLE_EXCLUSIVE=yes` skips Linux host files of hosts not in the
  inventory, so a host removed from Ansible leaves monitoring.
- Ansible Automation Platform (formerly Ansible Tower) and AWX
  inventories: `ANSIBLE_AAP_URL`, `ANSIBLE_AAP_INVENTORY` (ID or name)
  and a token file (`ANSIBLE_TOWER_*` names also accepted). The
  inventory is fetched with curl and jq from `/api/controller/v2`
  (AAP 2.5 and later) or `/api/v2`, cached, and the last good copy is
  used when the platform is down. `utils/drsm_ansible_hosts.sh` lists the
  hosts and tiers from either source.

- `DRSM_CONFIG` names the config file in place of `~/.drsm.sh`, so a
  second DRSM install can run from the same account, for example a new
  release beside an older one other scripts still source.
  utils/install.sh keeps a config in `$DRSMHOME/etc/drsm.sh` that
  `DRSM_CONFIG` names.
- utils/migrate_systems_dat.sh reads `<host>_profile.sh` from the dat
  file's folder first, so an old install's files can be converted with
  a new install's config.
- utils/wra_hosts.sh `-p` sets the plugins of the new host files, for
  agents older than 3.3 that send no PERFORMANCE section.

## 1.32-beta2 - 2026-10-27

Second 1.32 beta: complete Windows host pages. Release 1.31 stays the
stable release until 1.32 is final.

### Windows hosts

#### Changed

- Windows host pages show the whole agent report: each check starts
  with a one line summary, and lists the IP addresses, user profiles,
  service tag, every installed program, the Windows Update history,
  hotfixes and all Defender events. Uptime under a day is shown in
  hours, and the plugins say DataReel Reporting Agent.
- `drsm_detail name value` (`DETAIL name=value` lines) puts host facts
  in the Details panel of the host page. The Windows plugins use it
  for the agent version, IP address, service tag, user profiles,
  hardware, drives, uptime, newest patch and Defender definitions.
- The memory, load and swap gauges fall back to the `mem_total_mb`,
  `cpu_count` and `swap_total_mb` metrics, so Windows hosts get a
  memory gauge.
- The Windows plugins work on DRSM 1.31 installs from the agent's
  `drsm/install.sh`, which has no `drsm_detail` helper.

## 1.32-beta1 - 2026-10-26

Beta release of 1.32: organizations and sites, tiers and site links,
trends, Windows hosts and the fixes below. Release 1.31 stays the
stable release until 1.32 is final.

### Organizations and sites

#### Added

- Organizations and sites: organization > site > group > host, for
  monitoring several customers or offices from one dashboard. Site
  files in `etc/sites` (`<org>.org`, `<org>/<site>.site`) with name,
  location, time zone, alert addresses, stale limit, collector ID and
  host defaults. Hosts join a site with `SITE=<org>/<site>`, or every
  host of a monitor host with `DRSM_SITE` in `~/.drsm.sh`. Two sites
  may have a host with the same name.
- `drsm_run.sh` runs each site in turn with its own lock, log, alert
  throttle and alert subject, or one site with `-s org/site`. `-H`
  takes `org/site/host`. Site reports go to `reports/orgs/<org>/<site>`
  with a `site.json`, plus `reports/orgs/<org>/org.json`. Plugins get
  `DRSM_ORG` and `DRSM_SITE`.
- Several monitor hosts per dashboard: `DRSM_COLLECTOR_ID` and the
  site's `COLLECTOR_ID` decide which monitor host runs a site.
- Organizations page (`www/php/orgs.php`): a card per site with its
  worst state, host counts, a heat map tile per host (check status or
  resource use), its monitor host, and a "Collector not reporting"
  banner when the monitor host stops. It leads the menu when there is
  more than one site.
- Site picker in the page header for all sites, one organization or
  one site. Hosts has Organization and Site columns, the heat map can
  group by site, the Overview lists the sites, and Trends groups the
  capacity table by site with site totals.
- `$AUTHscopes` and `$AUTHnetworkscopes` limit users and networks to
  organizations or sites, in every page and in `host_status.php`.
- `utils/drsm_migrate_sites.sh` moves hosts and reports into a site,
  `utils/drsm_remove_site.sh` removes a site, and
  `utils/drsm_add_collector.sh` prints an `rrsync` limited SSH key
  line for a site's monitor host. All are dry run or print only.
- `host_status.php` (from the DRCM takeover check work) takes
  `site=`, or `n=<org>/<site>/<host>`, and answers 409 for a host name
  found in two sites.
- The Web only demo (`make_web_demo.sh -s`) has two organizations with
  two sites each, one with a monitor host that stopped reporting.
- Tiers: `GROUP` values `dev`, `qa` and `ops`, shown as DEV, QA and
  OPS. `ops` is another name for `production`: ops hosts run with the
  production hosts and keep the production report names, and
  `drsm_run.sh -g ops` is the production run. `GROUP` may be set in a
  site file for every host of the site. The Organizations, Heat map and
  Hosts pages have a tier filter (`tier=`, remembered in the
  `drsm_tier` cookie), site cards count hosts by tier, and the heat map
  and host table show each host's tier. The Hosts page tier buttons
  replace its group list.
- `ALERT_EMAIL_<TIER>` in a site file (`ALERT_EMAIL_DEV`,
  `ALERT_EMAIL_QA`, `ALERT_EMAIL_OPS`) sends that tier's alerts to its
  own addresses, falling back to `ALERT_EMAIL`. QA alert subjects say
  "QA Systems".

- Site links: `LINK="Menu/Submenu/Name|https://url|tier"` lines in
  site and org files fill a Site links menu, in the top bar when the
  site picker shows one site and on each Organizations site card. Each
  `/` in the name makes a submenu, the optional tier shows the link
  only with that tier filter (or All), and org links appear for every
  site of the org. Only http and https URLs are kept, checked when
  `drsm_run.sh` writes them into `site.json` and again on the
  dashboard. Links open in a new tab with `rel="noopener noreferrer"`.
  The menus are `<details>` elements, so they open by click, tap or
  keyboard without the script; the script closes them on Escape or a
  click elsewhere.
- Organizations, Heat map and Connectivity in the main menu have
  submenus for their views. The main menu shows icons only below
  1440 pixels wide so the top bar fits with the site picker and the
  Site links menu. The Web only demo has example site and org links.

- Documentation: the HTML docs, README and PLUGINS.md cover
  organizations and sites, tiers, site links, the main menu submenus,
  several monitor hosts feeding one dashboard, scoped logins and per
  site and per tier alert addresses. The screenshots in `docs/images`
  were retaken from the new demo, with a new Site links image.

#### Changed

- `drsm_web_sync.sh` copies each site to `orgs/<org>/<site>` on the
  dashboard with its own `--delete`, so other monitor hosts' sites are
  kept. A reports folder with no sites is copied as before.
  `WEBSYNC_RRSYNC=1` for a dashboard that limits the key with rrsync.
- `drsm_remove_host.sh` takes `org/site/host`, `wra_hosts.sh` and
  `drsm_metrics_backfill.sh` take `-s org/site`.
- `purge.sh` keeps `site.json` and `org.json`.
- The Organizations menu item, the brand logo and the Overview
  "Organizations" link now always open every organization and site,
  and set the site picker back to "All sites". Before, a site picked in
  the picker kept the Organizations page filtered. A filtered
  Organizations page names its scope and has a "Show all
  organizations" link.

### Trends and capacity planning

#### Added

- Trends page (`www/php/trends.php`): capacity by host with what each
  host has and needs (oversized, right-sized, undersized), averages,
  95th percentiles and peaks, disk growth and time to 90% full,
  network traffic per 30 days, disk IOPS and throughput, and charts
  with a normal range learned per hour of the day. Values outside the
  range are flagged and listed. `$TRENDheadroom`, `$TRENDsigma` and
  `$TRENDshared` in `config/drsm.php`.
- AWS panel for EC2 hosts: instance type, EBS volumes, data transfer
  out, EBS I/O and public IPv4 beside the measured need, with a list
  of billed items DRSM cannot measure.
- Metrics history, `reports/systems/<host>/metrics_history.tsv`, one
  line per report written by `bin/drsm_run.sh` (`lib/drsm_history.sh`),
  kept `HISTORYdays` days (730). `bin/purge.sh` keeps it.
- `utils/drsm_metrics_backfill.sh` builds the history from archived
  and offline reports, dry run unless `--apply`.
- `storage/diskio` plugin (disk I/O counters) and `cloud/aws` plugin
  (EC2 instance metadata). Neither alerts.
- New metrics: `cpu_count` and `cpu_ticks_*` counters (`core/cpu`),
  `mem_total_mb` and `swap_total_mb` (`core/memory`), `disk_size_mb`
  and `disk_used_mb` (`storage/disk`).
- The Web only demo (`make_web_demo.sh -s`) has 30 days of sample
  history.

### Windows hosts

#### Added

- `windows/checkin`, `windows/defender`, `windows/patches` and
  `windows/apps` plugins for Windows hosts that run the Windows
  Reporting Agent. They read the report the agent sends to the monitor
  side, so DRSM never connects to the Windows host.
- `collectors/wra.sh` (`COLLECTOR=wra`, `PLATFORM=windows`), with the
  `WRA_REPORTS_DIR` and `WRA_NAME` host keys.
- `utils/wra_hosts.sh` creates host files from the agent reports
  directory, dry run unless `--apply`.
- `etc/hosts/windows.conf_example` and tests in
  `tests/drsm_run_test.sh`.
- `windows/resources` plugin: CPU, memory, commit charge, disk space
  per drive and network counters from agent 3.3 reports, with the
  Linux metric names so Windows hosts appear on the gauges and the
  trends page. The trends page times rates by the report's
  `sample_etime`, because the agent and `drsm_run.sh` run on their
  own schedules.

### Hosted dashboard

#### Added

- `utils/drsm_web_sync.sh` copies ${REPORTdir} to a Web only dashboard
  on another server (WEBSYNC_DEST in ~/.drsm.sh) with rsync over SSH.
  Dry run unless --apply, retries, one run at a time, never touches
  the remote pages, config or .htaccess files.
- www/php/host_status.php returns one host's last report time, age,
  state and stale flag as JSON (php/host_status.php?n=<host>), for
  scripts on other servers such as the DRCM takeover check
  (drsm_report_check.sh). Same login as the other pages, so the
  reading server goes in $AUTHnetworks.

### Removing hosts

- `utils/drsm_remove_host.sh` removes a host file (backed up to
  `etc/hosts/removed`), its `${REPORTdir}/systems/<host>` folder, and
  its old profile and `systems.dat` lines. Dry run unless `--apply`;
  `--remote` also deletes the DRSM files on the host.

### Fixes

- `network/nics` reads `/proc/net/dev` on hosts without
  `/sys/class/net`, such as HostGator jailed shells, where it used to
  report OK with no interfaces. It now warns when it finds none.
- The SSH collector tries the connection test 3 times, 10 seconds
  apart (`DRSM_SSH_TRIES`, `DRSM_SSH_WAIT`), and the docs show SSH
  connection sharing for hosts that throttle login bursts.
- The page footer shows the date and time the page was generated, in
  the viewer's time zone, instead of "just now".

## 1.31 - 2026-10-25

Release 1.31 includes the plugin framework, the Web interface redesign,
the HTML documentation and the dashboard login below.

### Dashboard login

Optional login for dashboard access from the internet. Written by
[Claude Code](https://claude.com/claude-code) at the request of the
project owner. Off by default, so existing sites and the public demo
are unchanged.

#### Added

- `$AUTHenable` in `config/drsm.php`: requests from the internal
  networks in `$AUTHnetworks` (CIDRs, IPv4 and IPv6) get open access,
  everyone else gets a login page in the dashboard style. Plain PHP,
  works on shared hosting.
- Bcrypt password hashes in `$AUTHusers`, made with
  `utils/drsm_password.php`.
- Secure sessions (HttpOnly, SameSite, Secure on HTTPS, new id at
  login, idle and absolute timeouts), CSRF tokens on the login and
  sign out forms, and failed login lockouts per address and per user.
  Logins need HTTPS unless `$AUTHhttps` is 0.
- `X-Forwarded-For` is ignored unless the connection comes from a
  proxy listed in `$AUTHproxies`.
- `www/php/archive.php` reads archived reports through PHP, so the
  login covers them. `make_web_demo.sh -a` builds a package with
  login on and the report folder blocked.

### HTML documentation

#### Added

- `docs/`, an HTML documentation set styled like the dashboard, with
  light and dark themes and no external fonts or scripts: overview,
  install, deployment setups (3 node production cluster, workstation
  with a dashboard on a PHP hosting account, the public live demo,
  cloud servers), Web dashboard, plugins, thresholds and alerts, MySQL
  and Postgres, and what's new. Screenshots are of the live demo.
- `tests/docs_test.sh`, run in CI, checks every local link, image and
  anchor in the docs.

#### Changed

- `utils/install.sh` installs the docs to `${DRSMHOME}/docs`.

### Web interface redesign

A new look for the Web interface. Written by
[Claude Code](https://claude.com/claude-code) at the request of the
project owner. The pages read the same report files as before, so
`system_report.sh`, `system_check.sh` and `drsm_run.sh` reports all
show.

#### Added

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

#### Changed

- The Web pages need PHP 7.2 or higher.
- A custom `site/page_header.php` must print `drsm_head_assets()` to
  get the new styles, see README.txt.

### Plugin framework

Plugin framework, phase 1 of the plugin module design. Written by
[Claude Code](https://claude.com/claude-code) at the request of the
project owner. Nothing existing is removed: `system_check.sh`,
`system_report.sh` and the `bin/*_checks.sh` scripts work as before
while sites move over.

#### Added

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

#### Changed

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
