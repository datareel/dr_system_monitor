# Upgrade a DRSM install

For admins (and their AI assistants) who move an install to a new
DRSM release. Read the "Before you use AI assistance" part and
sections 0 and 1 of `AGENTS.md` first. One step at a time; the admin
runs or approves each command. Plan the upgrade for a quiet time: a
cron run during the install can read half copied files.

## What install.sh keeps and replaces

- Kept: `etc/hosts` (host files and `_defaults.conf`), `etc/sites`,
  `plugins/local`, `$CONFIGdir/drsm.php` (the new release's copy is
  written beside it as `drsm.php_install_new`), `$WWWdir/site`, the
  reports, and a config in `$DRSMHOME/etc/drsm.sh` named by
  `DRSM_CONFIG`.
- Replaced: everything else under `$DRSMHOME` (`bin`, `lib`,
  `collectors`, `plugins` except `plugins/local`, `utils`, `docs`) and
  the pages in `$WWWdir/php`, `css`, `js`. Edits made to release
  files there are lost: move them to host files, `_defaults.conf`,
  `plugins/local` or `site/` before the upgrade.

## 1. Before the upgrade (read-only)

1. Unpack the new release next to the old source and check its
   sha256 against the downloads page (https://datareel.com/downloads/drsm/).
2. Read the new release's `CHANGELOG.md` from the installed version
   (`cat $DRSMHOME/version.txt`) up. Tell the admin about every changed
   setting and every "Changed" entry.
3. Run the read-only check against the new source and save the output:

```
$ bash ~/git/dr_system_monitor-<new>/utils/drsm_preflight.sh --source=$HOME/git/dr_system_monitor-<new> | tee ~/drsm_preflight_before.txt
```

   It shows how many files differ and lists edited release
   `plugin.conf` files that `install.sh` will replace. Hand every WARN
   to the admin. Fix every FAIL first.

## 2. Back up

```
$ B=~/drsm_backups/$(date +%Y%m%d_%H%M)_before_<new>; mkdir -p "$B"
$ cp -a "$DRSMHOME" "$B/drsm"
$ cp -a "$CONFIGdir/drsm.php" "$WWWdir/site" "$B/" 2>/dev/null
$ crontab -l > "$B/crontab.txt"
```

Use the values from `~/.drsm.sh` (or `$DRSM_CONFIG`) for the folders.

## 3. Install

1. Optional, to stop runs during the install: the admin comments out
   the DRSM cron lines (`crontab -e`) and notes them.
2. `cd ~/git/dr_system_monitor-<new>/utils && ./install.sh`, as the DRSM
   user (or root), with `DRSM_CONFIG` set if the install uses it. The
   admin answers the EULA.
3. Compare `$CONFIGdir/drsm.php_install_new` with `drsm.php`
   (`diff`). Tell the admin about new settings; the admin decides what
   to copy into `drsm.php`. Then move `drsm.php_install_new` into the
   backup folder.

## 4. Check

1. `cat $DRSMHOME/version.txt` shows the new version.
2. `drsm_run.sh -l`, then `drsm_run.sh -n -H <host> -v` for one host of
   each collector the site uses (ssh, local, wra, lra).
3. Open the dashboard: Overview, one host page, the menus.
4. The admin puts the cron lines back if they were commented out.
5. `utils/drsm_preflight.sh` again: compare with the saved output.

## Roll back

Copy the backup back: `$B/drsm` to `$DRSMHOME`, `drsm.php` and `site/`
to the dashboard, and reinstall the old pages with the old source's
`utils/install.sh`. The reports and host files are not changed by an
upgrade, so nothing else needs restoring.

## From an old system_check.sh setup

Releases before 1.30 ran `bin/system_check.sh` and
`bin/system_report.sh` from `systems.dat`. They keep working after the
upgrade. Moving to `drsm_run.sh` is its own change, after the upgrade:

1. `utils/migrate_systems_dat.sh` writes one host file per
   `systems.dat` row into `etc/hosts`. It is not a dry run, but it
   never overwrites a host file without `-f` and leaves the old files
   in place. Use `-o <empty folder>` first to review the result.
2. `drsm_run.sh -l`, then `drsm_run.sh -n -H <host> -v` for each kind
   of host.
3. The admin swaps the old cron lines for the `drsm_run.sh` lines in
   `crontabs/crontab_example.txt`.

## Report back

Old and new version, the backup folder, the pre-flight before and
after, the `drsm.php_install_new` differences and what the admin
decided, the test runs, and the cron state at the end.
