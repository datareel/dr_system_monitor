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

Serves the payload of a host's hook upload: ?n=<host>&h=<hook id>.
Only for uploads/<id> plugins in the host's report, and only where the
report server keeps the payloads ($UPLOADSdir). The file comes from the
agent, so it is sent as plain text, or for DISPLAY=html with a sandbox
Content-Security-Policy that blocks scripts: it cannot read the
dashboard's cookies or pages.
*/
// ----------------------------------------------------------- //
// SCRIPT CONTENT STARTS BELOW.

require_once("../config/drsm.php");

// Our required includes
require_once("{$WWWdir}/php/query_post_validation.php");
require_once("{$WWWdir}/php/drsm_lib.php");

function drsm_upload_not_found($why)
{
  http_response_code(404);
  header("Content-Type: text/plain; charset=utf-8");
  echo $why . "\n";
  exit;
}

$name = (isset($_GET['n']) && is_string($_GET['n'])) ? $_GET['n'] : "";
$site = (isset($_GET['site']) && is_string($_GET['site'])) ? $_GET['site'] : "";
$id = (isset($_GET['h']) && is_string($_GET['h'])) ? $_GET['h'] : "";
// Only a host DRSM reports on, in the sites this visitor may see, and
// a hook that runs for it. The file name is built from the report's
// own lines and checked names, never from the request.
$res = drsm_resolve_host($name, $site);
if($res["status"] != "ok" || !drsm_valid_upload_id($id)) drsm_upload_not_found("No such host or hook.");
$hst = drsm_load_host($res["name"], $res["site"]);
$hook = null;
foreach($hst["report"]["sections"] as $s) {
  if($s["id"] == DRSM_UPLOAD_PREFIX . $id) $hook = drsm_upload_parse($s);
}
if($hook === null) drsm_upload_not_found("This host has no upload hook {$id}.");
$fname = drsm_upload_data_path($hook["name"], $id);
if($fname == "") drsm_upload_not_found("The upload is on the report server. Set \$UPLOADSdir in config/drsm.php on the server that receives the agent uploads.");

header("X-Content-Type-Options: nosniff");
header("Referrer-Policy: no-referrer");
if($hook["display"] == "html") {
  header("Content-Type: text/html; charset=utf-8");
  header("Content-Security-Policy: sandbox; default-src 'none'; style-src 'unsafe-inline'; img-src data:; font-src data:");
}
else {
  header("Content-Type: text/plain; charset=utf-8");
  header("Content-Security-Policy: sandbox; default-src 'none'");
}
header("Content-Length: " . filesize($fname));
readfile($fname);

// SCRIPT CONTENT ENDS ABOVE.
// ----------------------------------------------------------- //
// ------------------------------- //
// --------- End of File --------- //
// ------------------------------- //
?>
