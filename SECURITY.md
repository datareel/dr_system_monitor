# DRSM security

How the DataReel System Monitor (DRSM) protects the hosts it watches
and its dashboard, which versions get security fixes, and how to
report a security problem.

## Supported versions

| Version | Security fixes |
| --- | --- |
| 1.35 | Yes |
| 1.34 | Yes |
| 1.33 and older | No, upgrade (`docs/ai/upgrade.md`) |

## Report a vulnerability

Report security problems privately through the DataReel contact page,
https://datareel.com/contact.php, topic "Bug report". Do not open a
public issue or post the details anywhere else first.

- Say which DRSM version, which file or page, and how to reproduce the
  problem.
- Do not send passwords, password hashes, SSH keys, agent keys,
  `$AUTH...` values, real host names or report files with site data.
  Make up example values instead.
- The contact page asks for 3 to 5 business days for a reply.
- Messages are handled as described in
  https://datareel.com/privacy.php.

## Security model in short

### The monitor host

- DRSM runs as one ordinary user account (default `sysadmin`), from
  cron. It needs no root and runs no daemon.
- Health checks of Linux hosts use keyed SSH from the monitor host. The
  private key stays on the monitor host, in the DRSM user's `~/.ssh`.
  Connections use `BatchMode=yes`, `PasswordAuthentication=no`, a 15
  second connect timeout and `StrictHostKeyChecking=accept-new`: a new
  host key is accepted on first contact, a changed key is refused
  (`SSH_OPTS` in `bin/system_functions.sh`, `docs/deployment.html`).
- On a monitored Linux host the collector copies a small bundle to
  `~/drsm_agent` and runs the checks as the DRSM user there. Plugins
  must not write anywhere else on the host except `/tmp` (rule in
  `docs/ai/write-a-plugin.md`).
- Windows hosts and Linux hosts DRSM cannot reach over SSH run the
  DataReel Reporting Agents. The agents connect out to the report
  server; DRSM never connects to them. DRSM reads the agent report
  files on the monitor host (`COLLECTOR=wra`, `COLLECTOR=lra`).

### The dashboard

- The PHP pages only read report files. They never run checks, run
  commands from a request or write reports.
- A request never names a file to read: pages map an ID to a
  configured file (`extreports.php`, `readreport.php`).
- Every value is escaped with `h()` before it is printed.
- Login (`$AUTHenable = 1` in `$CONFIGdir/drsm.php`, off by default):
  - bcrypt password hashes (`utils/drsm_password.php`), never plain
    text passwords;
  - addresses in `$AUTHnetworks` get in without a login; everyone
    else gets the login page. The connection address is used;
    `X-Forwarded-For` is read only from proxies listed in
    `$AUTHproxies`;
  - HttpOnly, SameSite session cookies, Secure on HTTPS, a new session
    id at login, CSRF tokens on the login and sign out forms;
  - lockout after `$AUTHmaxfails` failed logins from one address for
    `$AUTHlockminutes`, idle and maximum session times
    (`$AUTHidleminutes`, `$AUTHmaxhours`), `$AUTHhttps` to refuse
    logins over plain HTTP;
  - `$AUTHscopes` and `$AUTHnetworkscopes` limit users and networks to
    their own organizations or sites.
- With login on, block direct access to the report folder
  (`Require all denied` in `$REPORTdir/.htaccess`, or
  `utils/make_web_demo.sh -a`): it is served as plain files that the
  login does not cover. README.txt "Login for Access From Outside Your
  Network" has the steps.

### Hook uploads

- Files the agents send to the report server's `hook.php` are
  untrusted. `plugins/uploads/upload_probe.sh` passes on only DRSM line
  kinds, and `upload_view.php` serves an uploaded HTML file with
  `Content-Security-Policy: sandbox; default-src 'none'`,
  `X-Content-Type-Options: nosniff` and `Referrer-Policy: no-referrer`.

### Scripts

- Scripts that copy, delete, rename or mirror files are a dry run
  unless given `--apply`.
- `utils/drsm_preflight.sh` is read-only: it writes nothing, contacts
  no host and prints counts, not host names or alert addresses.

## Keep it safe

- Keep the monitor account's SSH key, the `.htpasswd` and password
  hash settings and the agent keys off shared drives, tickets, chats
  and AI tools.
- Turn on the login before the dashboard is reachable from outside
  your network, and serve it over HTTPS.
- Upgrade to a supported version (`docs/ai/upgrade.md`); check the
  sha256 of every download against the downloads page,
  https://datareel.com/downloads/drsm/.

## AI-assisted use

Before you use any AI assistance with DRSM, review your agency's or
company's AI usage policies and get formal written approval from your
management team. Use only approved enterprise AI models. Never give an
AI tool passwords, SSH keys, `$AUTH...` settings or agent keys. See
`AGENTS.md`, "Before you use AI assistance", and the AI-assisted use
parts of https://datareel.com/terms.php and
https://datareel.com/privacy.php.

## License and warranty

DRSM is free software under the GNU General Public License version 3,
provided as is, without warranty (`license.txt`,
https://datareel.com/terms.php).
