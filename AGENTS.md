# AGENTS.md: DRSM for AI coding assistants

DRSM (DataReel System Monitor) monitors Linux and Windows hosts and
shows them on a PHP dashboard. The checks are BASH plugins, run by
`bin/drsm_run.sh` from cron on one monitor host: on the host itself,
on Linux hosts over SSH, or from Windows agent report files. Each run
writes plain text report files; the PHP pages only read those files.
There is no database and no daemon.

This file is for GitHub Copilot, Gemini, Claude and other assistants,
and for the admins who use them. `.github/copilot-instructions.md`,
`GEMINI.md` and `CLAUDE.md` point here. The task guides are in
`docs/ai/`; `llms.txt` lists them and `llms-full.txt` has all of them
in one file.

## Two kinds of work

1. **Running DRSM for a site** (most admins): host files, plugin
   settings, sites and links, the dashboard settings, cron. Change the
   files under `$DRSMHOME/etc` and `$CONFIGdir`, never the installed
   code. See `docs/ai/maintain-a-site.md`.
2. **Changing DRSM itself**: plugins, the runner, the PHP pages. Work in
   the source tree, run the tests, then reinstall. See
   `docs/ai/write-a-plugin.md` and `docs/ai/change-the-dashboard.md`.

## Where things are

```
bin/drsm_run.sh          plugin runner, writes every report (cron runs it)
bin/archive.sh, purge.sh daily archive and hourly purge of report files
bin/system_*.sh          older per-host scripts, kept for old setups
lib/drsm_plugin.sh       helpers every plugin sources (drsm_warn, drsm_crit, ...)
lib/drsm_conf.sh         KEY=value reader for manifests, host and site files
lib/drsm_sites.sh        organizations, sites, tiers, site.json and links
lib/drsm_history.sh      metrics history for the trends page
collectors/              local.sh, ssh-linux.sh, wra.sh (Windows agent reports)
plugins/<cat>/<name>/    plugin.conf + check.sh (on the host) or probe.sh (from the monitor)
plugins/local/           site plugins, never overwritten by updates
etc/drsm.sh              config template, copied to ~/.drsm.sh (or named by DRSM_CONFIG)
etc/hosts/               _defaults.conf + one <host>.conf per host
etc/sites/               <org>.org and <org>/<site>.site files
www/php/                 dashboard pages; drsm_lib.php is the shared code
www/css/drsm.css, www/js/drsm.js   one stylesheet and one script, no framework
utils/install.sh         installs code to $DRSMHOME and pages to $WWWdir
utils/                   migrate_systems_dat.sh, wra_hosts.sh, new_plugin.sh, drsm_web_sync.sh, ...
tests/*.sh               all tests, plain BASH; run every one before a change is done
docs/*.html              user documentation (hand written HTML)
docs/ai/                 these guides; docs/ai/make_llms.sh rebuilds llms-full.txt
PLUGINS.md               full plugin, host file, site and Windows reference
CHANGELOG.md             add every change under "Unreleased"
```

Installed layout: code in `$DRSMHOME` (default `~/drsm`), dashboard in
`$WWWdir` with its PHP settings in `$CONFIGdir/drsm.php`, reports in
`$REPORTdir` (`system_health_report*.txt`, `system_check*_report*.txt`,
`systems/<host>/<host>_report.txt`, `archive/`). Every script reads
`$DRSM_CONFIG` if set, else `~/.drsm.sh`, else `$BASEdir/etc/drsm.sh`.

## Report format (the contract between plugins and pages)

- A plugin prints `INFO - text`, `WARNING - text`, `ERROR - text`,
  `UNKNOWN - text`, `METRIC name{labels}=value` and
  `DETAIL name=value` lines, plus any free text, and exits 0 OK,
  1 WARNING, 2 ERROR, 3 UNKNOWN.
- The runner wraps each plugin in `=== <cat>/<name> [STATE] <secs>s ===`
  and adds `HOSTNAME:`, `ETIME:`, `GROUP:` and other header lines.
- The pages find problems by the `ERROR - ` and `WARNING - ` prefixes
  (note the spaces). Keep message text in that form: `<host> <what> is
  <value>`, for example `web1:/var is at 91% capacity.`

## Rules

- BASH: `#!/bin/bash`, the file header block of the other scripts, tabs
  in nested blocks like the existing code, `function name()` style,
  quote every expansion, `[ ]` tests as in the existing scripts. No
  Python, Perl or other languages in plugins or core scripts.
- Scripts that copy, delete, rename or mirror anything default to a
  dry run and need `--apply`. Keep that for new utils.
- PHP must stay 7.2 compatible (see the note at the top of
  `www/php/drsm_lib.php`): no arrow functions, `??=`, `str_contains()`,
  `match`, or trailing commas in calls. Escape all output with `h()`;
  build page links with `drsm_url()`; start and end pages with
  `drsm_page_start()` and `drsm_page_end()`.
- Pages read files only. Never let a request name a path to read: map
  an ID to a configured file, as `extreports.php` and `readreport.php`
  do.
- Any PHP warning or notice fails `tests/www_test.sh`. Run pages with
  `php -d error_reporting=-1`.
- New PHP files must be added to the `files=` list in
  `utils/install.sh`, or they are not installed.
- Settings for one site never go in the code: host files, site files,
  `_defaults.conf`, `config/drsm.php` (`$SITEtitle`, `$SITElogo`,
  `$NAVextra`, `$EXTreports`, `$STALEminutes`, `$AUTH...`) and
  `site/custom.css`.
- Update `CHANGELOG.md` (Unreleased), the HTML docs page that covers
  the area, and `PLUGINS.md` for plugin or host file changes. After
  editing anything in `docs/ai/` or this file run
  `docs/ai/make_llms.sh`.

## Testing

```
$ for t in tests/*.sh; do bash "$t" || break; done
```

`drsm_run_test.sh` runs the runner and plugins against a temp tree,
`www_test.sh` renders every page with the PHP command line,
`auth_test.sh` covers the login, `docs_test.sh` checks the HTML docs
links and that `llms-full.txt` is current. To try a change on a real
install without alerts: `drsm_run.sh -n -H <host> -v`.

## Releases

`version.txt` and `CHANGELOG.md` (`## <ver> - <date>`), annotated git
tag `<ver>` (`<ver>-betaN` for betas), source tarball from
`git archive --prefix=dr_system_monitor-<ver>/`.
