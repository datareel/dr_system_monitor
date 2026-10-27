# Change the DRSM dashboard

The dashboard is plain PHP pages in `www/php/` (installed to
`$WWWdir/php/`), one stylesheet `www/css/drsm.css` and one script
`www/js/drsm.js`. Pages read the report files in `$REPORTdir`; they
never run checks or write reports.

## Settings first

Most site changes need no code. In `$CONFIGdir/drsm.php`:

```php
$SITEtitle = 'Example System Monitor';   // top bar name
$SITElogo = '/images/logo.svg';          // logo before the name
$REFRESHseconds = 300;                   // auto refresh, 0 off
$STALEminutes = 120;                     // report age that counts as not reporting
$NAVextra = array(                       // own top bar items
  array("label" => "Classic", "url" => "/classic/", "icon" => "layout"),
  array("label" => "Tools", "url" => "/tools/", "icon" => "link",
        "sub" => array(array("Time converter", "/tools/utc.php"))));
$EXTreports = '/var/www/html/dashboard/config/ext_reports.conf';
$EXTtitle = 'Site reports';
```

Icons: grid, heat, list, trend, net, file, windows, layout, link,
external, building, cloud, archive, lock, alert, check.

### Reports from your own scripts ($EXTreports)

```
# Title | report file | link | max age minutes | status file
[backups] Backups and patching
PROD backups | /var/www/html/sysadmin/backup/prod_summary.txt | | 1500
SSL certificates | /path/all_certs.txt | | 1500 | /path/cert_errors.txt
Scan results | /path/scan.txt | | | -
Storage console | - | https://storage.example.com/
```

ERROR or FAILED in the status file (default: the report file) is an
error, WARNING a warning, a missing file an error, older than the max
age Stale (`ETIME:` line, else the file time). An empty link shows the
file in the dashboard; `-` as the file is a plain link; `-` as the
status file shows the report with no state.

### Colors and header

`$WWWdir/site/custom.css` loads after `drsm.css`; override the CSS
variables (`--accent`, `--accent-2`, ...) for light and dark themes.
A full custom header is `$WWWdir/site/page_header.php`; it must print
`drsm_head_assets()` and leave `<main>` open.

## Code changes

- Page skeleton, as in `www/php/extreports.php`:

```php
require_once("../config/drsm.php");
require_once("{$WWWdir}/php/query_post_validation.php");
require_once("{$WWWdir}/php/drsm_lib.php");
drsm_page_start("Title", "menu-key", $state);
// ... HTML, every value through h() ...
drsm_page_end();
```

- Helpers in `drsm_lib.php`: `h()`, `drsm_url($page, $args)`,
  `drsm_load_hosts()`, `drsm_badge($state)`, `drsm_time_html($t)`,
  `drsm_icon($name)`, `drsm_read_lines($file)`, `drsm_worst($a, $b)`,
  states OK, WARNING, ERROR, UNKNOWN, STALE. Sites and links are in
  `drsm_sites.php`, other script reports in `drsm_ext.php`, login in
  `drsm_auth.php`, trends in `trends_lib.php`.
- The top bar is `default_header.php` (`$drsm_nav`, `$drsm_sub`).
- PHP 7.2 compatible code only, no PHP warnings or notices.
- A request may pick an ID, never a file path.
- Add a new PHP file to the `files=` list in `utils/install.sh`.
- Add checks for the change to `tests/www_test.sh` (`render`, `expect`,
  `reject`) and run all of `tests/*.sh`.
- Document it in `docs/dashboard.html` and `CHANGELOG.md`.
- Screenshots for the docs: headless Chrome against `php -S` on a copy
  made by `utils/make_web_demo.sh -s`.
