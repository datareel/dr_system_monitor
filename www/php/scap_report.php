<?php
// ------------------------------- //
// -------- Start of File -------- //
// ------------------------------- //
// ----------------------------------------------------------- //
// PHP Source Code File
// PHP Version: 7.2 or higher, tested with PHP 8
// Original Author(s): DataReel Software Development
// File Creation Date: 10/29/2026
// Date Last Modified: 10/29/2026
//
// Version control: 1.00
//
// Contributor(s):
// ----------------------------------------------------------- //
// ------------- Program Description and Details ------------- //
// ----------------------------------------------------------- //
/*
This file is part of the DataReel system monitor distribution.

Datareel is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the
Free Software Foundation, either version 3 of the License, or (at your
option) any later version.

Datareel software is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with the DataReel software distribution.  If not, see
<http://www.gnu.org/licenses/>.

Serves a host's OpenSCAP HTML report from the DataReel Reporting Agent
for Linux: ?n=<host>&kind=scap|compliance. The file comes from the
agent, so it is sent with a sandbox Content-Security-Policy: it runs in
its own origin and cannot read the dashboard's cookies or pages.
*/
// ----------------------------------------------------------- //
// SCRIPT CONTENT STARTS BELOW.

require_once("../config/drsm.php");

// Our required includes
require_once("{$WWWdir}/php/query_post_validation.php");
require_once("{$WWWdir}/php/drsm_lib.php");

$name = (isset($_GET['n']) && is_string($_GET['n'])) ? $_GET['n'] : "";
$site = (isset($_GET['site']) && is_string($_GET['site'])) ? $_GET['site'] : "";
$kind = (isset($_GET['kind']) && is_string($_GET['kind'])) ? $_GET['kind'] : "scap";
// Only a host DRSM reports on, in the sites this visitor may see. The
// file name is built from fixed parts, never from the request.
$res = drsm_resolve_host($name, $site);
$fname = ($res["status"] == "ok") ? drsm_vuln_html_path($res["name"], $kind) : "";
if($fname == "") {
  http_response_code(404);
  header("Content-Type: text/plain; charset=utf-8");
  echo "No OpenSCAP report for this host. Set \$LRAreportsDir in config/drsm.php on the server that receives the agent uploads.\n";
  exit;
}
header("Content-Type: text/html; charset=utf-8");
// The OpenSCAP report needs its own scripts and styles, nothing else
header("Content-Security-Policy: sandbox allow-scripts; default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data:; font-src data:");
header("X-Content-Type-Options: nosniff");
header("Referrer-Policy: no-referrer");
header("Content-Length: " . filesize($fname));
readfile($fname);

// SCRIPT CONTENT ENDS ABOVE.
// ----------------------------------------------------------- //
// ------------------------------- //
// --------- End of File --------- //
// ------------------------------- //
?>
