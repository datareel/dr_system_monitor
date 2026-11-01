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

  php/host_status.php?n=<host>[&site=<org>/<site>]

  {"host":"drworkstation2","site":"default/default","time":1792982895,"age_secs":61,"state":"OK","stale":false}

n can also be <org>/<site>/<host>. Unknown hosts get a 404 with
{"error":"not found"}. A plain name found in more than one site gets a
409 with {"error":"ambiguous","sites":["<org>/<site>",...]}.
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
$site = (isset($_GET['site']) && is_string($_GET['site'])) ? $_GET['site'] : "";

// Only plain host and site names are accepted, this blocks ../ path
// traversal, and only in the sites this visitor may see
$res = drsm_resolve_host($n, $site);
if($res["status"] == "ambiguous") {
  http_response_code(409);
  echo json_encode(array("error" => "ambiguous", "sites" => $res["matches"])) . "\n";
  exit;
}
$n = $res["name"];
$site = $res["site"];
if($n == "" || !file_exists(drsm_site_dir($site) . "/systems/{$n}/{$n}_report.txt")) {
  http_response_code(404);
  echo json_encode(array("error" => "not found")) . "\n";
  exit;
}

$hst = drsm_load_host($n, $site);
$out = array(
  "host" => $n,
  "site" => $site,
  "time" => (int)$hst["time"],
  "age_secs" => time() - (int)$hst["time"],
  "state" => (string)$hst["state"],
  "stale" => (bool)$hst["stale"]
);
// The host's own agent (Linux / Windows reporting agent): "time" above is when the dashboard last ran the
// host's checks, every run whether the agent reported or not, so for an agent host age_secs never grows past
// the run interval. The checkin plugins record the agent report's age at that run; add the time since the run.
// The DRCM takeover check (drsm_report_check.sh) uses agent_age_secs when it is here.
$metrics = isset($hst["report"]["metrics"]) ? $hst["report"]["metrics"] : array();
foreach(array("lra_report_age_seconds", "wra_report_age_seconds") as $mname) {
  if(isset($metrics[$mname][0][1])) {
    $agent_age = (int)$metrics[$mname][0][1] + max(0, time() - (int)$hst["time"]);
    $out["agent_age_secs"] = $agent_age;
    $out["agent_time"] = time() - $agent_age;
    break;
  }
}
echo json_encode($out) . "\n";

// SCRIPT CONTENT ENDS ABOVE.
// ----------------------------------------------------------- //
// ------------------------------- //
// --------- End of File --------- //
// ------------------------------- //
?>
