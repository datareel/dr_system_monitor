# Write a DRSM plugin

A check is a folder `plugins/<category>/<name>/` with `plugin.conf`
and `check.sh` (runs on the host) or `probe.sh` (runs on the monitor
host against the host). Site-only plugins go in `plugins/local/`.
The full reference is `PLUGINS.md`, section "Writing a plugin".

## Steps

1. `utils/new_plugin.sh local/<name>` (or `local/<name> probe`) makes
   the folder from a template.
2. Fill in `plugin.conf`: `NAME`, `CATEGORY`, `DESCRIPTION`,
   `PLATFORMS` (`linux`, `windows`, `any`), `MODE` (`remote` or
   `probe`), `TIMEOUT`, `REQUIRES` (commands that must exist),
   `NEEDS_SUDO`, then one `KEY=default` line per setting.
3. Write the script:

```bash
#!/bin/bash
source "${DRSM_LIB:-$(dirname "$0")/../../../lib}/drsm_plugin.sh"

WARN=$(drsm_setting WARN 100)
CRIT=$(drsm_setting CRIT 500)

count=$(find /var/spool/myapp -type f | wc -l)
if [ "${count}" -ge "${CRIT}" ]; then
    drsm_crit "${HOST} myapp queue has ${count} files"
elif [ "${count}" -ge "${WARN}" ]; then
    drsm_warn "${HOST} myapp queue has ${count} files"
else
    drsm_ok "${HOST} myapp queue checks good at ${count} files"
fi
drsm_metric myapp_queue_files "${count}"
drsm_exit
```

4. Run it by hand: `DRSM_WARN=50 bash plugins/local/<name>/check.sh`
   (probes: `DRSM_TARGET=<host> bash .../probe.sh`).
5. Add it to `PLUGINS` (or `PROBES`) in a host file or
   `_defaults.conf`, then `drsm_run.sh -n -H <host> -v`.

## Helpers (lib/drsm_plugin.sh)

`drsm_ok`/`drsm_info` (INFO), `drsm_warn` (WARNING), `drsm_crit`
(ERROR, alerts), `drsm_unknown`, `drsm_metric name value [labels]`
(trends), `drsm_detail name value` (host page Details), `drsm_setting
NAME default`, `drsm_target`, `drsm_gt a b` (float compare),
`drsm_exit`. Settings arrive as `DRSM_<KEY>`; hosts override them with
`<category>_<name>_<KEY>`.

## Rules

- BASH only, and only commands found on a minimal RHEL install unless
  listed in `REQUIRES`.
- Messages start with the host name and say what is wrong and the value.
- Never prompt, never write outside `/tmp` on the host, finish well
  inside `TIMEOUT`.
- A plugin for the DRSM release also needs a test in
  `tests/drsm_run_test.sh`, a row in the PLUGINS.md table and
  docs/plugins.html, and a CHANGELOG entry.
