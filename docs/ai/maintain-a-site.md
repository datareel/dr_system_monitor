# Maintain a DRSM site

For admins (and their AI assistants) who run DRSM for an organization.
Change configuration files, not the installed code. Everything below
is plain text; check a change with `drsm_run.sh -l` and test with
`drsm_run.sh -n -H <host> -v` (`-n` sends no alerts).

## Find the install

```
$ echo "${DRSM_CONFIG:-$HOME/.drsm.sh}"     # the config every script reads
$ grep -E 'DRSMHOME|WWWdir|REPORTdir|CONFIGdir' "${DRSM_CONFIG:-$HOME/.drsm.sh}"
$ crontab -l | grep drsm                     # what runs and as whom
```

When a site runs two DRSM installs in one account (a new release
beside an older one), each new-DRSM cron line sets `DRSM_CONFIG`. Use
the same prefix when you run a script by hand.

## Hosts

- One file per host: `$DRSMHOME/etc/hosts/<host>.conf` with `HOST`,
  `DESCRIPTION`, `IMPACT`, `GROUP` (`production`/`ops`, `dev`, `qa` or
  your own, such as `windows`), `PLATFORM`, `COLLECTOR` (`ssh`,
  `local`, `wra`, `none`), `PROBES`, `PLUGINS`, `ENABLED=no` to pause.
- Shared values go in `etc/hosts/_defaults.conf`; a host file lists only
  what differs.
- Plugin settings: `<category>_<name>_<SETTING>=value`, for example
  `storage_disk_WARN=85`, `storage_disk_SKIP="/mnt/scratch"`,
  `core_cpu_TIMEOUT=60`. The defaults and every setting are in
  `plugins/<category>/<name>/plugin.conf`.
- Linux hosts over SSH need the monitor account's key in the host's
  `authorized_keys`. The collector copies a small bundle to
  `~/drsm_agent` on the host.
- Windows hosts: `utils/wra_hosts.sh` (dry run, then `--apply`) makes a
  host file per agent report. Use `-g` for the group and `-p` for the
  plugins; leave out `windows/resources` for agents older than 3.3.
- Remove a host and its reports: `utils/drsm_remove_host.sh <host>`
  (dry run), then `--apply`.
- From an old `systems.dat` setup: `utils/migrate_systems_dat.sh`.
- Sites that keep Linux hosts in Ansible: set `ANSIBLE_INVENTORY` and
  `ANSIBLE_TIERS` in the config. Then add or move a Linux host in the
  Ansible inventory, not with a host file; a host file only adds
  settings. With Ansible Automation Platform (formerly Tower) or AWX
  set `ANSIBLE_AAP_URL`, `ANSIBLE_AAP_INVENTORY` and
  `ANSIBLE_AAP_TOKEN_FILE` instead.
  `utils/drsm_ansible_hosts.sh` and `drsm_run.sh -l` show the result.

## Sites, tiers and links

- `etc/sites/<org>.org` (NAME, CONTACT, LINK) and
  `etc/sites/<org>/<site>.site` (NAME, LOCATION, TZ, ALERT_EMAIL,
  ALERT_EMAIL_<TIER>, STALE_MINUTES, COLLECTOR_ID, LINK, and host
  defaults). A host joins a site with `SITE=<org>/<site>`.
- A single-site install uses `etc/sites/default/default.site` for its
  name and links.
- Links: `LINK="Menu/Submenu/Name|https://url|tier"`. Each `/` makes a
  submenu, http and https only, tier optional. They show in the Site
  links menu after the next run.

## Status messages

`utils/drsm_message.sh --apply add <info|warning|critical> "<text>"
[--link URL] [--until "YYYY-MM-DD HH:MM"] [--pin]` posts a notice that
scrolls across the top of every page; `list`, `remove <n>` and `clean`
manage them (file `$CONFIGdir/messages.conf`).

## Alerts

- Addresses: `$ALERTdir/alert.email.list` (`EMAILlist`, `TEXTlist`), or
  `ALERT_EMAIL` / `ALERT_EMAIL_<TIER>` in a site file.
- `drsm_run.sh` alerts on ERROR; `-n` turns alerts off for a run (use
  it in cron for groups that should only show on the dashboard).

## Dashboard settings

In `$CONFIGdir/drsm.php` (see `change-the-dashboard.md`): `$SITEtitle`,
`$SITElogo`, `$REFRESHseconds`, `$STALEminutes`, `$NAVextra` (own menu
items), `$EXTreports` (reports from your own scripts), `$AUTH...`
(login). Colors in `$WWWdir/site/custom.css`.

## Why is a host red?

1. Open the host page (Hosts, then the host). Each plugin section shows
   its own lines; the first ERROR line is the cause.
2. "Waiting for the first report": the host has a host file but no run has written
   its report yet, or the group's cron line is missing.
3. "Not reporting" / Stale: the report is older than `$STALEminutes`
   (or the site's `STALE_MINUTES`). Check cron and the run log in
   `$LOGdir/drsm_run*.log`.
4. Run it by hand: `drsm_run.sh -n -H <host> -v`.
5. A plugin is UNKNOWN when a command in its `REQUIRES` is missing on
   the host.

## Upgrade

1. Unpack the new release next to the old source.
2. Run `utils/install.sh <new source>` as the DRSM user (or root),
   with `DRSM_CONFIG` set if the install uses it. It keeps
   `_defaults.conf`, host and site files, `plugins/local`, `config/drsm.php`
   (it writes `drsm.php_install_new` beside it) and `$WWWdir/site`.
3. Compare `drsm.php_install_new` with `drsm.php` for new settings.
4. `drsm_run.sh -l`, then one run with `-n`.
