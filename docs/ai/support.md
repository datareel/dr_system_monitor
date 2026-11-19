# DRSM troubleshooting and support

For admins (and their AI assistants) when DRSM does not work as
expected. Read the "Before you use AI assistance" part and sections 0
and 1 of `AGENTS.md` first. Diagnose read-only first; change nothing
until the admin agrees on the cause and the fix. The manual parts are
`docs/ai/maintain-a-site.md` "Why is a host red?", README.txt and
`docs/admin.html`.

## 1. Where to look (read-only)

| What | Command or file |
| --- | --- |
| Whole install summary | `utils/drsm_preflight.sh` |
| Hosts and plugins the runner sees | `drsm_run.sh -l` |
| One host's last report | Dashboard host page, or `$REPORTdir/systems/<host>/<host>_report.txt` |
| Group reports | `$REPORTdir/system_health_report*.txt`, `system_check*_report*.txt` |
| Run logs | `$LOGdir/drsm_run*.log` |
| What cron runs | `crontab -l` (and `/etc/cron.d` if the site uses it) |
| Agent reports (Windows, Linux) | `WRA_REPORTS_DIR`, `LRA_REPORTS_DIR` in `_defaults.conf` |
| Web server errors | the Apache error log (README.txt "Apache Log files") |

## 2. Common problems

- **Host is Stale or "Not reporting".** The report is older than
  `$STALEminutes` or the site's `STALE_MINUTES`. Check the cron line for
  its group and the last run log. Agent hosts: check the newest agent
  report in `WRA_REPORTS_DIR` or `LRA_REPORTS_DIR`.
- **"Waiting for the first report".** A host file exists but no run
  has written its report: its group has no cron line, or
  `ENABLED=no`.
- **SSH host ERROR "cannot connect".** The DRSM user's key is not in
  the host's `authorized_keys`, the host key changed, or the host is
  down. The admin checks with `ssh <host> true` as the DRSM user. Do
  not set `StrictHostKeyChecking=no`.
- **Plugin UNKNOWN.** A command in the plugin's `REQUIRES` is missing
  on the host, or the plugin ran past its `TIMEOUT`.
- **No alerts.** No mail command on the monitor host, an empty
  `alert.email.list`, cron lines with `-n`, or the site's
  `ALERT_EMAIL`. Do not send a test alert without the admin's OK: it
  reaches real people.
- **Blank or broken dashboard page.** Run
  `php -d error_reporting=-1 -l $CONFIGdir/drsm.php`, then read the
  Apache error log. After an upgrade, compare `drsm.php_install_new`
  with `drsm.php`.
- **Login does not work.** The admin checks the `$AUTH...` settings
  and the password file. The agent does not read or change them.

## 3. Stop and hand over at once

Do not try to fix these yourself. Report to the admin straight away,
with the summary in section 4:

- signs that someone else has the DRSM user's SSH key, the dashboard
  password or an agent key, or the dashboard is open to the internet
  without its login;
- agent or hook uploads that look forged or that the dashboard shows
  as raw HTML or script;
- anything that needs changes on many monitored hosts, a new SSH key,
  turning off a security setting, or deleting reports or archives.

## 4. Support summary

When a problem is not solved, give the admin a summary they can send
to their team or to DataReel from https://datareel.com/contact.php
(topic "Application support", or "Bug report" for a DRSM bug).
AI-assisted support ends here: the people take it from this summary.

1. DRSM version (`$DRSMHOME/version.txt`), OS, bash and PHP versions.
2. The `utils/drsm_preflight.sh` output.
3. The plugin section of the report that shows the problem, and the
   run log lines around it (times included).
4. What happened, when, what changed before it, and every command
   already tried with its result.

Never include passwords, SSH keys, `$AUTH...` values, agent keys or
alert addresses. Remove host names, addresses and other site data when
the admin asks for that or their policy requires it. The contact page
asks for 3 to 5 business days for a reply, and not to send passwords,
account numbers or other sensitive information. Messages are handled
as described in https://datareel.com/privacy.php.

DRSM is free software under the GNU General Public License version 3,
provided as is. Check every command an agent proposes before it runs;
the admin running DRSM is responsible for the changes made.
