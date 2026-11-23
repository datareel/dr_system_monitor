# AGENTS.md: DRSM AI-assisted install, upgrade, development and support

DRSM (DataReel System Monitor) monitors Linux and Windows hosts and
shows them on a PHP dashboard. The checks are BASH plugins, run by
`bin/drsm_run.sh` from cron on one monitor host: on the host itself,
on Linux hosts over SSH, or from Windows and Linux agent report files. Each run
writes plain text report files; the PHP pages only read those files.
There is no database and no daemon.

This file is for AI-assisted work on DRSM: it tells an AI agent
(Gemini CLI, Claude Code, GitHub Copilot, Codex and others) how to
assist a site's own system administrators and developers to install,
set up, upgrade, build, fork, change and troubleshoot DRSM. The agent
assists; it does not replace the administrators or DataReel support,
and it never acts autonomously (section 0). The people review and
approve every step, and problems the agent cannot solve go to DataReel
(section 9).

`GEMINI.md` and `CLAUDE.md` import this file and
`.github/copilot-instructions.md` points to it. The task guides are in
`docs/ai/`; `llms.txt` lists them and `llms-full.txt` has all of them
in one file. The full manuals are `README.txt`, `PLUGINS.md` and the
HTML docs in `docs/` (also https://datareel.com/drsm/docs/). When this
file and the manuals or the code disagree, the manuals and the code
win: say so to the person you work for.

## Before you use AI assistance

Review all of your agency's or company's AI usage policies, and get
formal written approval from your management team, in the form of a
business use case and justification, before you use any AI assistance
with DRSM. AI desktops and command line tools may be used with this
guide only in strict compliance with those policies and that approval.

- **Use only approved enterprise AI models.** An AI agent working on
  DRSM may process potentially sensitive data: host names, addresses,
  configuration files, reports, logs and command output. Use only your
  agency's or company's enterprise AI models that have built-in
  safeguards against disclosing information and that guarantee your
  internal information will not be used to train public models.
- **Warning:** public or free AI tools, open source AI models and
  self-built AI models may expose your information to public learning
  models or to other parties, depending on how the model is hosted,
  configured and licensed. Use them only after a comprehensive review
  of what information might be exposed and what the potential risks
  are.
- **The entire risk of AI-assisted use rests with the user.** DataReel
  cannot be held accountable for actions taken, commands run or other
  outcomes of AI assistance (see https://datareel.com/terms.php).
- **No endorsement.** Any mention of a specific AI tool, model or
  product in this guide, such as Gemini, Gemini CLI, Claude Code or
  GitHub Copilot, is a reference only. It is not an endorsement or a
  recommendation to use that product. Product names are trademarks of
  their respective owners.
- **Nothing goes to DataReel.** These guides and
  `utils/drsm_preflight.sh` send nothing to DataReel. Anything you give
  an AI tool goes to that tool's provider under its terms and privacy
  policy (see https://datareel.com/privacy.php). Never give an AI tool
  passwords, tokens, SSH keys, `$AUTH...` settings or the
  `.htpasswd` and agent key files.

**For the agent:** at the start of a session, ask the person to
confirm that this AI-assisted use is approved under their
organization's AI usage policy and that you are an approved enterprise
AI model. If they cannot confirm it, stop and do not ask for or read
any host, report or configuration data.

## 0. Human in the loop: the agent never acts on its own

AI-assisted means the agent assists a person; it never acts
autonomously. Every change to a monitor host, a monitored host or the
DRSM source is made by a person or explicitly approved by one, one
step at a time.

- **Advisory mode is the default.** The agent explains the next step
  and prints the exact command and the host it is for. The person runs
  it and pastes the output back. Use this mode unless the organization
  allows the agent to run tools.
- **If tool execution is allowed, each command still needs its own
  explicit approval** before it runs. Never use auto-approve modes: no
  Gemini CLI `--yolo` or auto-accept, no Claude Code permission bypass
  (`--dangerously-skip-permissions`, bypass mode), no auto-run in other
  agents.
- **No unattended work:** no scheduled, background or batch runs of
  changing commands set up by the agent, no loops over hosts, and no
  changes across hosts over SSH loops, pdsh, Ansible or similar. One
  host per approval. Cron lines for DRSM itself are written by the
  person, after they have read them.
- **Dry run first.** Scripts that copy, delete, rename or mirror
  anything (`drsm_remove_host.sh`, `wra_hosts.sh`, `lra_hosts.sh`,
  `drsm_web_sync.sh`, `drsm_message.sh` and others) show what they
  would do unless given `--apply`. Show the dry run to the person; they
  decide on `--apply`.
- **Read-only diagnostics first.** The agent may propose read-only
  checks (`utils/drsm_preflight.sh`, `drsm_run.sh -l`, reading reports
  and logs) before anything else; they are shown and approved the same
  way. `drsm_run.sh -n` is not read-only: it connects to hosts over SSH
  and writes reports, but sends no alerts.

**Works with strict AI policies.** These files contain no code that
runs by itself: `AGENTS.md`, `GEMINI.md`, `CLAUDE.md`,
`.github/copilot-instructions.md`, `llms.txt` and `docs/ai/*.md` are
text, and `utils/drsm_preflight.sh` is a read-only script that the
person runs. Everything in this guide works in advisory mode, with no
tool execution by the agent.

## 1. Rules for agents (read these first)

DRSM sends alerts to people, runs as an account with SSH keys to many
hosts, and its dashboard may be reachable from outside the network. A
wrong step can page the on-call staff, lock the monitor out of hosts
or publish site data. Follow these rules on every task:

1. **Show, then the person runs or approves it.** Before any command
   that changes something (`utils/install.sh`, `--apply`, `crontab`,
   `ssh-copy-id`, edits under `$DRSMHOME/etc`, `$CONFIGdir` or
   `$WWWdir`, `dnf`, `firewall-cmd`, Apache settings), print the
   command and the host. In advisory mode the person runs it; otherwise
   wait for an explicit yes for that one command (section 0).
2. **Back up before changing.** Copy `$DRSMHOME/etc`,
   `$CONFIGdir/drsm.php`, `$WWWdir/site` and the crontab
   (`crontab -l > file`) into a dated backup folder first. Never
   delete; move aside.
3. **Test without alerts.** Use `drsm_run.sh -n -H <host> -v` to try a
   change. A run without `-n` can send email and text alerts.
4. **Stop on any failed check.** If a check fails or the output is not
   what the guide says to expect, stop and report. Do not improvise a
   fix on a production monitor.
5. **Never touch secrets.** Do not print, copy or change SSH private
   keys, `.htpasswd` files, `$AUTH...` values, the push alert tokens
   in `alert.push.conf`, the Windows and Linux agent key files or the
   alert lists' addresses. Ask the person to do those steps.
6. **Never weaken security silently.** Do not turn off the dashboard
   login, SELinux or firewalld, open the dashboard to the internet, set
   `StrictHostKeyChecking=no`, or let a page read a path taken from the
   request, to make something work. Report instead.
7. **No secrets or site data in files you write** (host names,
   addresses, accounts, passwords), unless the person asks for that file
   on their own systems. Never put site data in the DRSM source or in
   a change meant for DataReel.
8. **Keep a log.** List each command, on which host, and its result,
   and give it to the person at the end (section 10).

## 2. Task guides

| Task | Guide |
| --- | --- |
| New install on a monitor host | `docs/ai/new-install.md` |
| Upgrade an install (also from old `system_check.sh` setups) | `docs/ai/upgrade.md` |
| Run DRSM for a site: hosts, settings, sites, alerts, cron | `docs/ai/maintain-a-site.md` |
| Write a plugin | `docs/ai/write-a-plugin.md` |
| Change the dashboard | `docs/ai/change-the-dashboard.md` |
| Build, test and package a release | `docs/ai/build-and-release.md` |
| Fork DRSM or send changes to DataReel | `docs/ai/fork-and-contribute.md` |
| Troubleshooting and support | `docs/ai/support.md` |
| Security model, supported versions, reporting a vulnerability | `SECURITY.md` |

## 3. Two kinds of change

1. **Running DRSM for a site** (most admins): host files, plugin
   settings, sites and links, the dashboard settings, cron. Change the
   files under `$DRSMHOME/etc` and `$CONFIGdir`, never the installed
   code. See `docs/ai/maintain-a-site.md`.
2. **Changing DRSM itself**: plugins, the runner, the PHP pages. Work in
   the source tree, run the tests, then reinstall. See
   `docs/ai/write-a-plugin.md` and `docs/ai/change-the-dashboard.md`.

## 4. Where things are

```
bin/drsm_run.sh          plugin runner, writes every report (cron runs it)
bin/archive.sh, purge.sh daily archive and hourly purge of report files
bin/system_*.sh          older per-host scripts, kept for old setups
lib/drsm_plugin.sh       helpers every plugin sources (drsm_warn, drsm_crit, ...)
lib/drsm_conf.sh         KEY=value reader for manifests, host and site files
lib/drsm_sites.sh        organizations, sites, tiers, site.json and links
lib/drsm_history.sh      metrics history for the trends page
lib/drsm_ansible.sh      Ansible INI inventory as the host list (ANSIBLE_INVENTORY)
collectors/              local.sh, ssh-linux.sh, wra.sh (Windows agent reports), lra.sh (Linux agent reports)
plugins/<cat>/<name>/    plugin.conf + check.sh (on the host) or probe.sh (from the monitor)
plugins/uploads/         hook uploads: upload_probe.sh + one folder per hook ID
plugins/local/           site plugins, never overwritten by updates
etc/drsm.sh              config template, copied to ~/.drsm.sh (or named by DRSM_CONFIG)
etc/hosts/               _defaults.conf + one <host>.conf per host
etc/sites/               <org>.org and <org>/<site>.site files
www/php/                 dashboard pages; drsm_lib.php is the shared code
www/css/drsm.css, www/js/drsm.js   one stylesheet and one script, no framework
utils/install.sh         installs code to $DRSMHOME and pages to $WWWdir
utils/                   drsm_preflight.sh (read-only check), migrate_systems_dat.sh, wra_hosts.sh, lra_hosts.sh, new_plugin.sh, drsm_web_sync.sh, ...
tests/*.sh               all tests, plain BASH; run every one before a change is done
docs/*.html              user documentation (hand written HTML)
docs/ai/                 these guides; docs/ai/make_llms.sh rebuilds llms-full.txt
PLUGINS.md               full plugin, host file, site, Windows and Linux agent reference
SECURITY.md              security model, supported versions, how to report a vulnerability
CHANGELOG.md             add every change under "Unreleased"
```

Installed layout: code in `$DRSMHOME` (default `~/drsm`), dashboard in
`$WWWdir` with its PHP settings in `$CONFIGdir/drsm.php`, reports in
`$REPORTdir` (`system_health_report*.txt`, `system_check*_report*.txt`,
`systems/<host>/<host>_report.txt`, `archive/`). Every script reads
`$DRSM_CONFIG` if set, else `~/.drsm.sh`, else `$BASEdir/etc/drsm.sh`.

## 5. Report format (the contract between plugins and pages)

- A plugin prints `INFO - text`, `WARNING - text`, `ERROR - text`,
  `UNKNOWN - text`, `METRIC name{labels}=value` and
  `DETAIL name=value` lines, plus any free text, and exits 0 OK,
  1 WARNING, 2 ERROR, 3 UNKNOWN.
- Lines a page reads but people do not, `DRCM kind|...` from
  `cluster/drcm`, `VULN kind|...` from `linux/vulnerabilities` and
  `UPLOAD kind|...` from the `uploads/*` plugins, are hidden on the host
  page (`drsm_line_level()` returns `DATA`). The VULN lines are
  `summary`, `advisory`, `unfixed`, `compliance` and `rule`;
  PLUGINS.md "Linux agent hosts" has their fields. The UPLOAD lines are
  `meta`, `columns`, `row` and `value`, see PLUGINS.md "Hook uploads".
- Agent hosts: the `wra` and `lra` collectors run the `windows/*` and
  `linux/*` plugins on the monitor host against the host's last agent
  report (`DRSM_WRA_REPORT`, `DRSM_LRA_REPORT`); nothing connects to
  the host.
- Hook uploads: `uploads/<id>` plugins (MODE=probe) read files the
  agents sent to the report server's `hook.php` (`DRSM_UPLOADS_DIR`,
  from `UPLOADS_DIR`; `UPLOADS=auto` or a list in the host file adds
  them). The payload is untrusted: `plugins/uploads/upload_probe.sh`
  only passes DRSM line kinds, and `upload_view.php` serves files
  sandboxed.
- The runner wraps each plugin in `=== <cat>/<name> [STATE] <secs>s ===`
  and adds `HOSTNAME:`, `ETIME:`, `GROUP:` and other header lines.
- The pages find problems by the `ERROR - ` and `WARNING - ` prefixes
  (note the spaces). Keep message text in that form: `<host> <what> is
  <value>`, for example `web1:/var is at 91% capacity.`

## 6. Coding rules

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

## 7. Testing

```
$ for t in tests/*.sh; do bash "$t" || break; done
```

`drsm_run_test.sh` runs the runner and plugins against a temp tree,
`www_test.sh` renders every page with the PHP command line,
`auth_test.sh` covers the login, `docs_test.sh` checks the HTML docs
links and that `llms-full.txt` is current, `preflight_test.sh` checks
that `utils/drsm_preflight.sh` writes nothing. To try a change on a real
install without alerts: `drsm_run.sh -n -H <host> -v`.

## 8. Releases

`version.txt` and `CHANGELOG.md` (`## <ver> - <date>`), annotated git
tag `<ver>` (`<ver>-betaN` for betas), source tarball from
`git archive --prefix=dr_system_monitor-<ver>/`. See
`docs/ai/build-and-release.md`.

## 9. Support

Troubleshooting steps, the cases where the agent must stop at once,
and the support summary are in `docs/ai/support.md`. When a problem
is not solved, give the person the support summary for their team or
for DataReel (https://datareel.com/contact.php, topic "Application
support" or "Bug report"). AI-assisted support ends there: the people
take it from the summary. Never put passwords, keys or other secrets
in it. Security problems are reported privately, as `SECURITY.md`
says.

DRSM is free software under the GNU General Public License version 3,
provided as is, without warranty (`license.txt`). Check every command
an agent proposes before it runs; the person running DRSM is
responsible for the changes made.

## 10. Report back

End every task with: the hosts touched, each command and its result,
the files changed (with the backup folder), the dry runs shown and
what was applied, the test results (`tests/*.sh` or
`drsm_run.sh -n -H <host> -v`), every WARN from
`utils/drsm_preflight.sh` and what was decided, and anything left for
the person to do.
