# Build, test and package DRSM

For developers (and their AI assistants) who change the DRSM source and
make a release or a site package. DRSM is BASH and PHP: there is no
compile step. A build is the tests plus a source tarball. Read the
"Before you use AI assistance" part and sections 0, 1 and 6 of
`AGENTS.md` first.

## Work tree

- Work in a git clone or an unpacked source tree, never in the
  installed `$DRSMHOME` or `$WWWdir`.
- Test machine packages: bash 4 or later, PHP 7.2 or later command
  line (`php`), `curl`, `git`. `shellcheck` and `node` are optional
  (the GitHub workflow in `.github/workflows/lint.yml` runs them).

## Test

```
$ for t in tests/*.sh; do bash "$t" || break; done
```

Every test must pass; never skip or remove a test to make a change
pass. The tests use temp folders and the local collector; they do not
contact other hosts or send alerts. `tests/docs_test.sh` also checks
that `llms-full.txt` matches the guides: run `docs/ai/make_llms.sh`
after editing `AGENTS.md` or `docs/ai/`.

Optional, as in the workflow:

```
$ shellcheck -S error -s bash bin/*.sh etc/*.sh utils/*.sh lib/*.sh collectors/*.sh plugins/*/*/*.sh tests/*.sh
$ node --check www/js/drsm.js
```

## Try it on a test install

Install the tree on a test account or test monitor host
(`utils/install.sh`, with `DRSM_CONFIG` naming a test config), then
`drsm_run.sh -n -H <host> -v`. Never test a change on the production
monitor first.

## Release (DataReel)

1. `version.txt` and `CHANGELOG.md`: rename "Unreleased" to
   `## <ver> - <YYYY-MM-DD>` (`<ver>-betaN` for betas). Update
   `docs/changelog.html`.
2. Run every test again.
3. Commit, then an annotated tag `<ver>`.
4. Source tarball and checksum:

```
$ git archive --format=tar.gz --prefix=dr_system_monitor-<ver>/ -o dr_system_monitor-<ver>.tar.gz <ver>
$ sha256sum dr_system_monitor-<ver>.tar.gz > dr_system_monitor-<ver>.tar.gz.sha256sum
```

Pushing tags and publishing to the website are steps for the
maintainer, never for the agent.

## Web only dashboard package

`utils/make_web_demo.sh -p /url/path -o outdir` builds a dashboard
copy that needs only PHP, for a hosted site fed by
`utils/drsm_web_sync.sh`; `-s` adds made up sample reports for a demo.
Check the output folder before it is copied anywhere.

## Report back

The files changed, the test results (every test name and PASS or
FAIL), the version and tag, and the tarball checksum.
