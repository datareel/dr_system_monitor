# Fork DRSM or send changes to DataReel

For developers (and their AI assistants) who keep their own copy of
DRSM or send fixes back. Read the "Before you use AI assistance" part
and sections 0 and 1 of `AGENTS.md` first.

## Site changes first

Most site needs do not need a fork. Host files, site files,
`_defaults.conf`, `plugins/local`, `config/drsm.php`, `$NAVextra`,
`$EXTreports`, `site/custom.css` and `site/page_header.php` survive
every upgrade (`docs/ai/upgrade.md`). Suggest them before a fork.

## License

DRSM is free software under the GNU General Public License version 3
or any later version (`license.txt`). A fork that is given to others
must:

- keep `license.txt` and the copyright and license header of every
  file, and add your own name under "Contributor(s)" in the files you
  change;
- give its source code, with your changes, to everyone who gets the
  program;
- say that it is changed and when (a `CHANGELOG.md` entry is enough).

DataReel is a name of DataReel Software Development (see
https://datareel.com/terms.php, "Trademarks"). A fork that is
distributed must not look like a DataReel release: give it its own name
or a clear "modified" version (for example `1.34-site1`), and point its
support at its own maintainers, not at DataReel.

## Keeping a fork

1. Start from a released source tarball (checked against its sha256 on
   https://datareel.com/downloads/drsm/) or a git clone, on a branch of
   your own.
2. Keep each change small and in its own commit. Follow the coding
   rules in `AGENTS.md` section 6 and run every `tests/*.sh`.
3. For a new DRSM release, merge it into your branch, run the tests,
   then upgrade your installs (`docs/ai/upgrade.md`).

## Sending changes to DataReel

The DataReel project accepts bug fixes, enhancements and additions
from all developers (https://datareel.com/about.php). Send them from
the contact page, https://datareel.com/contact.php, with the topic
"Bug report" or "Project or development inquiry":

- what the change does and why, the DRSM version it is based on, and
  the test results;
- the change as a patch (`git format-patch` or `diff -u`), or ask in the
  message how to send it;
- no host names, addresses, accounts, passwords or other site data in
  the patch or the message.

The contact page asks for 3 to 5 business days for a reply.

## Report back

The branch and commits, the files changed, the test results, and the
license and naming points the developer still has to check.
