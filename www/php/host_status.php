<?php
// ------------------------------- //
// -------- Start of File -------- //
// ------------------------------- //
// ----------------------------------------------------------- //
// PHP Source Code File
// PHP Version: 7.2 or higher, tested with PHP 8
// Original Author(s): DataReel Software Development 
// File Creation Date: 10/26/2026
// Date Last Modified: 10/26/2026
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

Last report time for one host, as JSON, for scripts on other servers.
The DRCM takeover check (etc/utils/drsm_report_check.sh) reads it to
see whether a cluster node is still reporting before taking over its
resources. Needs the same login as the other pages, so a server that
reads it must be listed in $AUTHnetworks.

  php/host_status.php?n=<host>

  {"host":"drworkstation2","time":1792982895,"age_secs":61,"state":"OK","stale":false}

Unknown hosts get a 404 with {"error":"not found"}.
*/
// ----------------------------------------------------------- //
// SCRIPT CONTENT STARTS BELOW.

require_once("../config/drsm.php");

// Our required includes
require_once("{$WWWdir}/php/query_post_validation.php");
require_once("{$WWWdir}/php/drsm_lib.php");

header("Content-Type: application/json");
header("Cache-Control: no-store");

$n = isset($_GET['n']) ? CleanQueryAsString($_GET['n'], 255) : "";

// Only accept a plain host name, this blocks ../ path traversal
if(!drsm_valid_host($n) || !file_exists("{$REPORTdir}/systems/{$n}/{$n}_report.txt")) {
  http_response_code(404);
  echo json_encode(array("error" => "not found")) . "\n";
  exit;
}

$hst = drsm_load_host($n);
echo json_encode(array(
  "host" => $n,
  "time" => (int)$hst["time"],
  "age_secs" => time() - (int)$hst["time"],
  "state" => (string)$hst["state"],
  "stale" => (bool)$hst["stale"]
)) . "\n";

// SCRIPT CONTENT ENDS ABOVE.
// ----------------------------------------------------------- //
// ------------------------------- //
// --------- End of File --------- //
// ------------------------------- //
?>
