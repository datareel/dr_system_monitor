# DRSM plugins

DRSM runs every check as a plugin. A plugin is a folder with a small
manifest and one BASH script. `bin/drsm_run.sh` finds the plugins each
host needs, runs them on the host or against it, and writes the same
report files the Web pages and email/text alerts already use. Adding a
check means adding a folder, not editing a core script.

Everything is BASH. Writing a plugin needs no other language.

## Layout

```
bin/drsm_run.sh            plugin runner
lib/drsm_plugin.sh         helpers every plugin sources
lib/drsm_conf.sh           KEY=value reader for manifests and host files
lib/drsm_job.sh            runs plugins on the target, with timeouts
collectors/local.sh        runs plugins on the monitor host itself
collectors/ssh-linux.sh    copies and runs plugins on Linux hosts over SSH
plugins/<category>/<name>/
    plugin.conf            manifest: description, platforms, settings
    check.sh               runs on the host (MODE=remote)
    probe.sh               runs on the monitor host against the host (MODE=probe)
plugins/local/             your own plugins, never overwritten by updates
etc/hosts/_defaults.conf   settings shared by all hosts
etc/hosts/<host>.conf      one file per host
utils/new_plugin.sh        creates a plugin from a template
utils/migrate_systems_dat.sh  converts systems.dat and profiles to host files
```

## Plugins included

| Plugin | Runs | Checks |
| --- | --- | --- |
| `core/cpu` | host | CPU usage, steal time, top processes, CPU temperatures |
| `core/load` | host | 15 minute load average against the CPU count |
| `core/memory` | host | Available memory, swap use, top processes |
| `core/users` | host | Logged in users, alerts for listed user names |
| `storage/disk` | host | Space and inodes on every local file system |
| `storage/raid` | host | mdadm software RAID, LSI MegaRAID drives |
| `network/nics` | host | Interface errors, drops, collisions |
| `network/ping` | monitor | Host answers ping |
| `network/http` | monitor | HTTP service answers |
| `network/https` | monitor | HTTPS service answers with a valid certificate |
| `network/ftp` | monitor | FTP service answers |

These are the checks from `bin/*_checks.sh` and `system_check.sh`, with
the same messages and thresholds.

## Quick start

1. Convert your current setup, or write host files by hand from
   `etc/hosts/example.conf_example`:

   ```
   $ ~/drsm/utils/migrate_systems_dat.sh
   ```

2. See what would run:

   ```
   $ ~/drsm/bin/drsm_run.sh -l
   ```

3. Run once without sending alerts, then read the reports in the Web
   interface or under `${REPORTdir}/systems/<host>/`:

   ```
   $ ~/drsm/bin/drsm_run.sh -n
   ```

4. Replace the `system_check.sh` and `system_report.sh` cron lines with
   the `drsm_run.sh` lines in `crontabs/crontab_example.txt`.

Until any host file exists in `etc/hosts`, `drsm_run.sh` reads
`systems.dat` (or `<group>_systems.dat`) and runs the standard plugin
set, so it works before you migrate.

### Runner options

| Option | Meaning |
| --- | --- |
| `-g group` | Host group, default `production`. `-g dev` reads `dev_systems.dat` before migration |
| `-H host` | One host only, for testing |
| `-m probes` | Connectivity probes only, the `system_check.sh` job. Default `all` |
| `-e` | Email a status report even when everything passes |
| `-n` | Do not send alerts |
| `-l` | List hosts and plugins, then exit |
| `-v` | Verbose |

Exit code: 0 all good, 1 warnings, 2 errors.

## Host files

One file per host in `etc/hosts`, named `<host>.conf`. The files are
plain `KEY=value` lines. They are read, never run, so a typo cannot
execute anything. Values with spaces go in double quotes.

```
HOST=cloud1
DESCRIPTION="AWS web server"
IMPACT="Public website is down"
GROUP=production
PLATFORM=linux
COLLECTOR=ssh
PROBES="network/ping network/https"
PLUGINS="storage/disk storage/raid core/cpu core/load core/memory network/nics core/users"

# Plugin settings: <category>_<name>_<SETTING>=value
storage_disk_WARN=85
storage_disk_SKIP="/mnt/scratch"
network_https_URL=https://www.example.com/
core_cpu_TIMEOUT=60
```

| Key | Meaning |
| --- | --- |
| `HOST` | Name or address for SSH and probes, default is the file name |
| `DESCRIPTION`, `IMPACT` | Shown in reports and alerts |
| `GROUP` | Host group, selected with `drsm_run.sh -g` |
| `PLATFORM` | `linux` today; `windows` when its collector is added |
| `COLLECTOR` | `ssh`, `local` for the monitor host itself, `none` for probes only |
| `ENABLED` | `no` skips the host |
| `PROBES` | Plugins run from the monitor host against this host |
| `PLUGINS` | Plugins run on the host |

`_defaults.conf` is read before every host file, so put the common
`PLUGINS` list and site wide settings there. A host file only lists
what differs. Files starting with `_` are not hosts.

If `network/ping` fails, the host is reported down and its remote
plugins are skipped, as the old `system_report.sh` did.

## Writing a plugin

```
$ ~/drsm/utils/new_plugin.sh local/myapp          # runs on the host
$ ~/drsm/utils/new_plugin.sh local/myapp_url probe  # runs against the host
```

This creates the folder, a commented `plugin.conf`, and a script you can
run by hand right away:

```
$ DRSM_WARN=50 bash ~/drsm/plugins/local/myapp/check.sh
$ DRSM_TARGET=cloud1 bash ~/drsm/plugins/local/myapp_url/probe.sh
```

Then add `local/myapp` to `PLUGINS` (or `PROBES`) in a host file.

### Manifest

```
NAME=myapp
CATEGORY=local
DESCRIPTION="Order queue is draining"
PLATFORMS="linux"      # linux, windows, or any
MODE=remote            # remote runs check.sh on the host, probe runs probe.sh here
TIMEOUT=30             # seconds, enforced by the runner
REQUIRES="curl jq"     # commands that must exist, else the plugin is UNKNOWN
NEEDS_SUDO=no          # informational: no, yes, or optional

# Every other key is a setting with its default
WARN=100
CRIT=500
QUEUE_DIR=/var/spool/myapp
```

Each setting reaches the script as `DRSM_<KEY>`, and a host overrides it
with `<category>_<name>_<KEY>`, for example `local_myapp_WARN=200`.
A host can also set `<category>_<name>_TIMEOUT`.

### Script

```bash
#!/bin/bash
source "${DRSM_LIB:-$(dirname "$0")/../../../lib}/drsm_plugin.sh"

WARN=$(drsm_setting WARN 100)
CRIT=$(drsm_setting CRIT 500)
QUEUE_DIR=$(drsm_setting QUEUE_DIR /var/spool/myapp)

count=$(find "${QUEUE_DIR}" -type f | wc -l)
if [ "${count}" -ge "${CRIT}" ]; then
    drsm_crit "${HOST} myapp queue has ${count} files"
elif [ "${count}" -ge "${WARN}" ]; then
    drsm_warn "${HOST} myapp queue has ${count} files"
else
    drsm_ok "${HOST} myapp queue checks good at ${count} files"
fi
drsm_metric myapp_queue_files "${count}"

drsm_exit
```

| Helper | Prints | Effect |
| --- | --- | --- |
| `drsm_ok`, `drsm_info` | `INFO - ...` | none |
| `drsm_warn` | `WARNING - ...` | state at least WARNING |
| `drsm_crit` | `ERROR - ...` | state ERROR, alerts are sent |
| `drsm_unknown` | `UNKNOWN - ...` | state UNKNOWN when nothing worse |
| `drsm_metric name value [labels]` | `METRIC name{labels}=value` | for graphs later |
| `drsm_setting NAME default` | | value of `DRSM_NAME` or the default |
| `drsm_target` | | the host a probe checks, `DRSM_TARGET` |
| `drsm_gt a b` | | floating point a > b without `bc` |
| `drsm_exit` | | exits with the state |

Any other output is printed in the report as is.

Exit codes follow the Nagios plugin convention: 0 OK, 1 WARNING,
2 ERROR, 3 UNKNOWN. The runner also counts an `ERROR - ` or
`WARNING - ` line in the output, so a plugin that prints the message
but exits 0 is still caught. A plugin that runs past its `TIMEOUT` is
stopped and reported as a WARNING. A missing `REQUIRES` command makes
the plugin UNKNOWN, which is shown in the report but does not alert,
for example `smartctl` on a shared hosting server without root.

## How a run works

For each host the runner builds a job script from `lib/drsm_job.sh` and
one line per plugin, with the plugin's settings and timeout. Probe jobs
run on the monitor host. Remote jobs go through the host's collector:

- `local` runs the job in place from `${DRSMHOME}`.
- `ssh-linux` copies `lib/drsm_plugin.sh` and the host's plugins to
  `~/drsm_agent` on the host as one tar stream (skipped when the
  checksum has not changed), then runs the whole job in one SSH session
  with `bash -s`. Set `DRSM_REMOTE_BASE` to use another directory. It
  uses `SSH_OPTS` from `bin/system_functions.sh`.

Each plugin's output is a section of the host report:

```
=== storage/disk [WARNING] 0s ===
Disk usage checks for cloud1
WARNING - cloud1:/var is at 92% capacity.
METRIC disk_used_pct{mount="/var"}=92
```

The runner writes:

| File | Same as |
| --- | --- |
| `${REPORTdir}/systems/<host>/<host>_report.txt` and archive | `system_report.sh` |
| `${REPORTdir}/systems/<host>/status.json` | new: plugin states for the Web pages |
| `${REPORTdir}/system_health_report.txt`, `_errors.txt` | `system_report.sh` |
| `${REPORTdir}/system_check_report.txt`, `_report_errors.txt` | `system_check.sh` |

Groups other than production add `_<group>` to the group report names,
so `-g dev` writes the same `_dev` files as before. Alerts use
`bin/text_email_alert.sh` with the same subjects and 4 hour throttle.

## Next

The design in the project doc adds, in later releases: storage, network
and core checks (SMART, mounts, backup age, TCP ports, TLS expiry, DNS,
time sync, failed services); generic database, container, service and
process plugins plus a `custom/command` catch-all; a Windows collector
over OpenSSH and PowerShell; configurable notifiers (email, SMS, Slack,
ntfy, webhook) with alert-on-change; and a plugin status grid in the
Web interface.
