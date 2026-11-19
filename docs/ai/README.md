# DRSM guides for AI-assisted work

Task guides for AI agents such as Gemini CLI, Claude Code and GitHub
Copilot, and for the admins and developers who use them. Read
`AGENTS.md` (in the top folder of the source, and copied here) first:
it has the AI usage policy, the human in the loop rules, the layout,
the report format and the coding rules.

Before you use any AI assistance, review your agency's or company's AI
usage policies and get formal written approval from your management
team. Use only approved enterprise AI models. Naming an AI tool here
is a reference only, not an endorsement. See
https://datareel.com/terms.php, "AI-assisted use".

| Guide | Use it to |
| --- | --- |
| [AGENTS.md](AGENTS.md) | AI usage policy, rules for agents, layout, report format, coding rules, tests, support, report back |
| [new-install.md](new-install.md) | Set up DRSM on a new monitor host: packages, user, checksum, config, install, first hosts, cron |
| [upgrade.md](upgrade.md) | Upgrade an install: pre-flight check, backup, install, check, roll back, move from system_check.sh |
| [maintain-a-site.md](maintain-a-site.md) | Add or remove hosts, change thresholds, sites, links, alerts, cron, find why a host is red |
| [write-a-plugin.md](write-a-plugin.md) | Add a check as a plugin, local or for the DRSM release |
| [change-the-dashboard.md](change-the-dashboard.md) | Change or add a PHP page, menu items, other script reports, styles |
| [build-and-release.md](build-and-release.md) | Run the tests, try a change, make a release tarball or a web only dashboard |
| [fork-and-contribute.md](fork-and-contribute.md) | Keep a fork under the GPL, send changes to DataReel |
| [support.md](support.md) | Troubleshoot, when to stop, the support summary for DataReel |
| [SECURITY.md](../../SECURITY.md) | Security model, supported versions, how to report a vulnerability privately |
| [llms-full.txt](llms-full.txt) | All of the above in one file, to paste into an approved chat |

The read-only check for installs, upgrades and support is
`utils/drsm_preflight.sh`. The full references are `PLUGINS.md`,
`README.txt` and the HTML docs in `docs/`.
