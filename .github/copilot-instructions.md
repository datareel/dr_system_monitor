# GitHub Copilot instructions for DRSM

Before any AI assistance: written management approval under your
agency or company AI usage policy, and approved enterprise AI models
only (see "Before you use AI assistance" in AGENTS.md). Copilot
assists the administrators and developers, who review and approve each
step. Nothing runs autonomously: do not use auto-approve or auto-run
for terminal commands. Naming GitHub Copilot here is a reference only,
not an endorsement; product names are trademarks of their respective
owners.

Read AGENTS.md in the top folder of this repository before you change
anything. It has the rules for agents, the layout, the report format,
the coding rules, the tests and support. Task guides are in docs/ai/
(new-install.md, upgrade.md, maintain-a-site.md, write-a-plugin.md,
change-the-dashboard.md, build-and-release.md, fork-and-contribute.md,
support.md).

Short version:
- One step at a time: show the command and the host, the person runs
  or approves it. Read-only checks first (utils/drsm_preflight.sh).
- Site settings live in etc/hosts, etc/sites, config/drsm.php and
  site/custom.css, not in the code.
- BASH only for plugins and scripts; scripts that change files default
  to a dry run and need --apply.
- PHP 7.2 compatible, every value through h(), pages never read a path
  taken from the request.
- Never print or copy passwords, SSH keys, $AUTH settings or agent
  keys.
- Run every tests/*.sh before you finish, and add the change to
  CHANGELOG.md under Unreleased.
