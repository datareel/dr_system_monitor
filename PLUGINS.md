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
collectors/wra.sh          reads Windows Reporting Agent reports for Windows hosts
plugins/<category>/<name>/
    plugin.conf            manifest: description, platforms, settings
    check.sh               runs on the host (MODE=remote)
    probe.sh               runs on the monitor host against the host (MODE=probe)
plugins/local/             your own plugins, never overwritten by updates
etc/hosts/_defaults.conf   settings shared by all hosts
etc/hosts/<host>.conf      one file per host
utils/new_plugin.sh        creates a plugin from a template
utils/migrate_systems_dat.sh  converts systems.dat and profiles to host files
utils/wra_hosts.sh         creates host files for Windows agent hosts
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
| `storage/diskio` | host | Disk read and write operations and bytes, for IOPS and throughput trends |
| `cloud/aws` | host | AWS EC2 instance type, zone, public IPv4 and EBS volume sizes from instance metadata |
| `network/nics` | host | Interface errors, drops, collisions |
| `network/ping` | monitor | Host answers ping |
| `network/http` | monitor | HTTP service answers |
| `network/https` | monitor | HTTPS service answers with a valid certificate |
| `network/ftp` | monitor | FTP service answers |
| `windows/checkin` | agent report | Windows host reported recently, complete report, agent version |
| `windows/defender` | agent report | Defender threats, protection turned off, old definitions |
| `windows/patches` | agent report | Age of the newest Windows patch |
| `windows/apps` | agent report | Required and forbidden installed programs |
| `windows/resources` | agent report | CPU, memory, commit charge, disk space and network use, agent 3.3 and later |

`storage/diskio` and `cloud/aws` never alert. They add numbers to the
trends page, so they are not in the default plugin list: add them to
`PLUGINS` for the hosts you size, for example
`PLUGINS="... storage/diskio cloud/aws"` for an EC2 instance. Skip
`storage/diskio` on shared hosting, where `/proc/diskstats` is the
provider's whole server.

The Linux checks are the ones from `bin/*_checks.sh` and `system_check.sh`,
with the same messages and thresholds. The Windows plugins are described
in [Windows hosts](#windows-hosts).

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
| `SITE` | Organization and site, `<org>/<site>`, see [Organizations and sites](#organizations-and-sites) |
| `GROUP` | Host group and tier: `ops` (or `production`, the default), `dev` or `qa`, selected with `drsm_run.sh -g`, see [Tiers](#tiers) |
| `PLATFORM` | `linux` or `windows` |
| `COLLECTOR` | `ssh`, `local` for the monitor host itself, `wra` for Windows Reporting Agent hosts, `none` for probes only |
| `ENABLED` | `no` skips the host |
| `PROBES` | Plugins run from the monitor host against this host |
| `PLUGINS` | Plugins run on the host |

`_defaults.conf` is read before every host file, so put the common
`PLUGINS` list and site wide settings there. A host file only lists
what differs. Files starting with `_` are not hosts.

To stop monitoring a host and remove its reports, run
`utils/drsm_remove_host.sh <host>` (dry run) and then with `--apply`.
The host file is saved to `etc/hosts/removed` first.

If `network/ping` fails, the host is reported down and its remote
plugins are skipped, as the old `system_report.sh` did.

## Ansible inventory

DRSM can take its Linux host list from an Ansible INI inventory. In
`~/.drsm.sh`:

```
export ANSIBLE_INVENTORY=/etc/ansible/hosts
export ANSIBLE_TIERS="production=prod qa=qa dev=dev"   # tier=group[,group]
export ANSIBLE_DEFAULT_TIER=""                          # tier for other hosts, empty leaves them out
export ANSIBLE_SHORT_NAMES=yes                          # web1.example.com becomes web1
export ANSIBLE_EXCLUSIVE=no                             # yes: Linux hosts only from Ansible
```

With `ANSIBLE_EXCLUSIVE=yes`, Linux host files of hosts the inventory
does not list are skipped, so removing a host from Ansible stops its
checks from the next run; Windows and other host files still run. The
host's last report stays on the dashboard, shown as not reporting,
until `utils/drsm_remove_host.sh <host> --apply` removes it.

Hosts in a listed group, or in a group under it through
`[group:children]` at any depth, are Linux hosts checked over SSH in
that tier with the `_defaults.conf` plugins; a host in two tiers goes
to the first tier listed. A host file with the same short or full name
(or `HOST=`) adds settings, but the tier comes from Ansible. Host files
for hosts Ansible does not list work as before. Ranges such as
`web[01:03]` are expanded; `:vars` sections and host variables are
skipped; YAML inventories are not read. See `lib/drsm_ansible.sh`.

### Ansible Automation Platform or AWX

DRSM can read the inventory from Ansible Automation Platform (AAP,
formerly Ansible Tower) or AWX instead of a file:

```
export ANSIBLE_AAP_URL=https://aap.example.com
export ANSIBLE_AAP_INVENTORY=12                     # ID or name
export ANSIBLE_AAP_TOKEN_FILE=~/.drsm_aap_token     # OAuth2 token, mode 600
export ANSIBLE_AAP_CA_FILE=""                       # CA bundle for a private CA
export ANSIBLE_AAP_CACHE_MINUTES=15
export ANSIBLE_AAP_API=""                           # empty tries /api/controller/v2, then /api/v2
export ANSIBLE_TIERS="production=prod qa=qa dev=dev"
```

The inventory script (`<api>/inventories/<id>/script/`) is fetched
with curl and jq into an INI copy in `$VARdir`, reused for the cache
time, and read like a local inventory. AAP 2.5 and later serve the
controller API at `/api/controller/v2`, older AAP, Tower and AWX at
`/api/v2`; both are tried. The `ANSIBLE_TOWER_*` names of these
settings still work. If the platform cannot be reached the last good
copy is used with a warning. A read-only token is enough;
it is sent from a header file, never on the command line.
`utils/drsm_ansible_hosts.sh` (`-f` to fetch now) lists the hosts and
tiers DRSM takes from either source.

## Organizations and sites

Hosts can be grouped into organizations and sites, for example one
organization per customer and one site per office or data center:
organization > site > group > host. Each site has its own reports,
alerts and dashboard card, and two sites may have a host with the same
name. Hosts with no site are in the `default/default` site, which keeps
the reports where they have always been, so nothing changes until you
add a site.

Site files live in `etc/sites` (`SITESdir` in `~/.drsm.sh`):

```
etc/sites/acme.org            NAME="Acme Corp", CONTACT="..."
etc/sites/acme/hq.site        the hq site of acme
```

| Site key | Meaning |
| --- | --- |
| `NAME`, `LOCATION` | Shown on the Organizations page |
| `TZ` | Time zone for the site's report times |
| `ALERT_EMAIL` | Alert addresses for the site, replace `alert.email.list` |
| `LINK` | A Site links menu entry, `LINK="Menu/Submenu/Name\|https://url\|tier"`, see [Site links](#site-links). Also in org files |
| `ALERT_EMAIL_<TIER>` | Alert addresses for one tier at the site, for example `ALERT_EMAIL_DEV`, else `ALERT_EMAIL` |
| `STALE_MINUTES` | When a host report or the site's monitor host counts as not reporting, default 60 |
| `COLLECTOR_ID` | The monitor host that runs the site, see below |

Any host key or plugin setting in a site file is a default for the
site's hosts, read after `_defaults.conf` and before the host file, for
example `PROBES` or `WRA_REPORTS_DIR`. Examples are in
`etc/sites/example.org_example` and
`etc/sites/example/example.site_example`.

`GROUP` in a site file is a default too, so a whole site can be a QA or
DEV site.

To limit dashboard users to their own organizations or sites, list
them in `$AUTHscopes` (per user) and `$AUTHnetworkscopes` (per internal
network) in the dashboard's `config/drsm.php`; see `php/drsm_auth.php`.

A host joins a site with `SITE=<org>/<site>` in its host file. Hosts
without one use `DRSM_SITE` from `~/.drsm.sh`, so a monitor host that
only watches one site can set it once. IDs use `a-z`, `0-9`, `_` and
`-`.

`drsm_run.sh` runs each site in turn, with its own lock, log, alert
throttle and alert subject (`[!ALERT!] DRSM acme/hq Health Checks ...`).
`-s org/site` runs one site. `-H` takes a host name, or
`org/site/host` when two sites have a host with that name. Reports go
to `${REPORTdir}/orgs/<org>/<site>`, with the same layout as before
inside, plus `site.json` (the site, its monitor host and host states)
and `${REPORTdir}/orgs/<org>/org.json`.

Several monitor hosts can feed one dashboard, for example one at each
customer. Each sets `DRSM_COLLECTOR_ID` (default its short host name)
and each site file names its `COLLECTOR_ID`. A monitor host skips sites
that name another collector; sites with no `COLLECTOR_ID` run on any.
`utils/drsm_web_sync.sh` copies each site to its own folder on the
dashboard, and `utils/drsm_add_collector.sh org/site` prints an SSH key
line that limits a monitor host to its site's folder with `rrsync`.

| Tool | Does |
| --- | --- |
| `utils/drsm_migrate_sites.sh org/site [host ...]` | Moves hosts and their reports from the default site into a site, dry run unless `--apply` |
| `utils/drsm_remove_site.sh org/site` | Removes a site's hosts, site file and reports, dry run unless `--apply` |
| `utils/drsm_remove_host.sh org/site/host` | Removes one host of a site |
| `utils/wra_hosts.sh -s org/site` | Windows host files for a site |
| `utils/drsm_metrics_backfill.sh -s org/site` | History for a site's hosts |


## Tiers

`GROUP` sorts hosts into tiers: `dev`, `qa` and `ops`. The dashboard
shows them as DEV, QA and OPS, with All and a button per tier on the
Organizations, Heat map and Hosts pages. `ops` is another name for
`production`, the default group: ops hosts run with the production
hosts, write the production report names (no `_<group>` suffix) and
get texts, so existing production files keep their names. Run each
tier from cron:

```
15,45 * * * * ~/drsm/bin/drsm_run.sh &> /dev/null          # OPS
55 09-16 * * mon-fri ~/drsm/bin/drsm_run.sh -g dev &> /dev/null
55 09-16 * * mon-fri ~/drsm/bin/drsm_run.sh -g qa &> /dev/null
```

DEV and QA alerts never send texts. A site file can send each tier's
alerts to its own addresses with `ALERT_EMAIL_DEV`, `ALERT_EMAIL_QA`
and `ALERT_EMAIL_OPS`; a tier without one uses `ALERT_EMAIL`, then
`alert.email.list`. Other group names still work and show as their own
tier, in upper case.


## Site links

Site and org files can list links for the dashboard's Site links menu,
one `LINK` line each:

```
LINK="Wiki|https://wiki.example.com/"
LINK="Grafana/Database|https://grafana.example.com/d/db"
LINK="Apps/OSA/Admin|https://osa.example.com/admin|ops"
```

The first field is the name, and each `/` in it makes a submenu, to any
depth up to six levels. The second is the URL: only `http` and `https`
links are kept, others are reported by `drsm_run.sh` and skipped, and
the dashboard checks them again. The optional third field is a tier
(`dev`, `qa`, `ops`): the link shows only when the tier filter is All
or that tier. Links in `<org>.org` show for every site of the
organization, in an Org links section of the same menu.

`drsm_run.sh` puts the links in `site.json`, so `drsm_web_sync.sh`
takes them to a hosted dashboard, and users only see the links of
sites they may see. The menu is in the top bar when the site picker
shows one site, and on each site card on the Organizations page. When
the picker shows All sites or a whole organization, the top bar has an
Org links menu instead, with the org links of each organization shown.
Links open in a new tab.

## Windows hosts

Windows hosts run the Windows Reporting Agent, a small Windows service
from the agent distribution. Every 45 minutes it sends a text report
(installed programs, Windows Defender events, Windows Update history,
hotfixes, users, IP addresses) to the monitor side by signed HTTPS
upload, a CIFS share, or SCP. DRSM never connects to the Windows host:
the `wra` collector runs the `windows/*` plugins on the monitor host
against each host's last report,
`${WRA_REPORTS_DIR}/<host>_windows_report_agent.txt`.

A Windows host file, also in `etc/hosts/windows.conf_example`:

```
HOST=laptop1
PLATFORM=windows
COLLECTOR=wra
PROBES=""
PLUGINS="windows/checkin windows/defender windows/patches windows/apps windows/resources"
```

`PROBES=""` turns off the ping probe, laptops move between networks.
Set `WRA_REPORTS_DIR` once in `_defaults.conf`: it is `reports_dir`
from the agent's `server.ini`, or the folder the CIFS or SCP delivery
writes to. The default is `/var/www/html/windows/reports`. Set
`WRA_NAME` when the agent reports under a name other than `HOST`.
Linux plugins in `_defaults.conf` are skipped on Windows hosts.

For many hosts, `utils/wra_hosts.sh` makes one host file per report.
It only lists what it would write until run with `--apply`, and never
changes a host file that exists:

```
$ ~/drsm/utils/wra_hosts.sh -d /var/www/html/windows/reports
$ ~/drsm/utils/wra_hosts.sh -d /var/www/html/windows/reports --apply
```

| Plugin | Setting | Default | Meaning |
| --- | --- | --- | --- |
| `windows/checkin` | `WARN_HOURS` | 48 | Hours without a report before a warning |
| | `CRIT_DAYS` | 15 | Days without a report before an error |
| | `MIN_VERSION` | | Lowest agent version that does not warn |
| `windows/defender` | `LOOKBACK_DAYS` | 7 | Days of Defender events that alert |
| | `PROTECTION_LOOKBACK_DAYS` | 30 | Days that protection turned off keeps alerting |
| | `CRIT_EVENTS` | threats, failed remediation, protection off | Event IDs that are errors |
| | `WARN_EVENTS` | threat removed, update failures | Event IDs that are warnings |
| | `DEFINITIONS_WARN_DAYS` | 7 | Age of the newest Security Intelligence update, 0 to skip |
| `windows/patches` | `WARN_DAYS`, `CRIT_DAYS` | 45, 90 | Age of the newest Windows patch |
| | `IGNORE` | definition updates | Patch titles that do not count |
| `windows/apps` | `REQUIRED` | NONE | Programs that must be installed |
| | `FORBIDDEN` | NONE | Programs that are errors |
| | `WARN` | NONE | Programs that are warnings |
| `windows/resources` | `CPU_WARN`, `CPU_CRIT` | 85, 95 | CPU used percent, a 5 second sample |
| | `MIN_AVAIL_MB` | 256 | Available memory at or below this is an error |
| | `COMMIT_WARN` | 90 | Commit charge (memory plus page file) percent of the limit |
| | `DISK_WARN`, `DISK_CRIT` | 90, 99 | Space used percent on each fixed drive |
| | `DISK_SKIP` | | Drives to skip, for example `"D: E:"` |
| | `UPTIME_WARN_DAYS` | 0 | Days without a restart before a warning, 0 to skip |
| | `MAX_AGE_HOURS` | 2 | Older reports are not checked, `windows/checkin` reports them |

`windows/resources` uses the metric names of the Linux plugins
(`cpu_used_pct`, `mem_available_mb`, `disk_used_pct{mount="C:"}`,
`nic_rx_bytes{nic="Wi-Fi"}` and so on), so Windows hosts get the same
gauges and trends. Its `sample_etime` metric is the time the agent
read the counters: the trends page times network rates by the
reports, and counts a report that two runs saw only once.

The `windows/apps` lists are case insensitive regular expressions
separated by semicolons, because program names have spaces:
`windows_apps_REQUIRED="Microsoft Defender;Mozilla Firefox"`.

A host that has never sent a report, or whose report file is empty, is
an ERROR from `windows/checkin`; the other Windows plugins are UNKNOWN
until a report arrives. To run a Windows plugin by hand:

```
$ DRSM_TARGET=laptop1 DRSM_WRA_REPORT=/var/www/html/windows/reports/laptop1_windows_report_agent.txt \
    bash ~/drsm/plugins/windows/checkin/check.sh
```

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
| `drsm_detail name value` | `DETAIL name=value` | a host fact shown in the Details panel of the host page, such as an IP address or agent version |
| `drsm_setting NAME default` | | value of `DRSM_NAME` or the default |
| `drsm_target` | | the host a probe checks, `DRSM_TARGET` |
| `drsm_gt a b` | | floating point a > b without `bc` |
| `drsm_exit` | | exits with the state |

Any other output is printed in the report as is.

Every plugin also gets these, for messages or settings that depend on
where the host is:

| Variable | Value |
| --- | --- |
| `DRSM_TARGET` | the host name from the host file |
| `DRSM_HOST_DESCRIPTION`, `DRSM_HOST_IMPACT` | from the host file |
| `DRSM_ORG`, `DRSM_SITE` | the host's organization and site IDs, `default` and `default` for hosts in no site |

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
- `wra` runs the `windows/*` plugins in place from `${DRSMHOME}` against
  the host's last Windows Reporting Agent report. See
  [Windows hosts](#windows-hosts).
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

The runner writes, for the default site (sites other than
default/default write the same files under `${REPORTdir}/orgs/<org>/<site>`):

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
process plugins plus a `custom/command` catch-all; live Windows checks
over OpenSSH and PowerShell, alongside the Windows Reporting Agent; configurable notifiers (email, SMS, Slack,
ntfy, webhook) with alert-on-change; and a plugin status grid in the
Web interface.
