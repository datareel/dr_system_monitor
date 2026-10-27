# CLAUDE.md: DRSM

Read AGENTS.md in the top folder of this repository before you change
anything. It has the layout, the report format, the coding rules and
the tests. Task guides are in docs/ai/ (maintain-a-site.md,
write-a-plugin.md, change-the-dashboard.md).

Short version:
- Site settings live in etc/hosts, etc/sites, config/drsm.php and
  site/custom.css, not in the code.
- BASH only for plugins and scripts; scripts that change files default
  to a dry run and need --apply.
- PHP 7.2 compatible, every value through h(), pages never read a path
  taken from the request.
- Run every tests/*.sh before you finish, and add the change to
  CHANGELOG.md under Unreleased.
