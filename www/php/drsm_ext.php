<?php
// ------------------------------- //
// -------- Start of File -------- //
// ------------------------------- //
// ----------------------------------------------------------- //
// PHP Source Code File
// PHP Version: 7.2 or higher, tested with PHP 8
// Original Author(s): DataReel Software Development
// File Creation Date: 10/27/2026
// Date Last Modified: 10/27/2026
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

External reports: text files written by your own scripts (backup,
patching, certificate, SNMP and other checks) shown with a state on
the extreports.php page and the Overview. Settings in config/drsm.php:

$EXTreports = '/path/ext_reports.conf';  // Off when unset or missing
$EXTtitle   = 'Other reports';           // Menu and page name

The file has a [id] Title line for each section, then one line per
report:

  Title | report file | link | max age minutes | status file

- report file: the text file to show and check, or - for a plain link
- link: where the title goes. Empty shows the file in the dashboard
  (extreports.php?v=<id>). A link may also be a page or folder.
- max age minutes: STALE when the report is older, 0 or empty is off.
  The time is the report's ETIME: line, else the file time.
- status file: read for the state in place of the report file, for
  scripts that write a separate errors file. - shows the report with
  no state.

The state is ERROR when the file is missing or a line has ERROR or
FAILED, WARNING when a line has WARNING, else OK, the same rule the
older dashboard includes used. # starts a comment line.
*/
// ----------------------------------------------------------- //
// SCRIPT CONTENT STARTS BELOW.

if(!isset($EXTtitle) || $EXTtitle == "") $EXTtitle = "Other reports";

function drsm_ext_enabled()
{
  global $EXTreports;
  return isset($EXTreports) && $EXTreports != "" && is_readable($EXTreports);
}

// Sections in file order: id => array("title", "items")
function drsm_ext_sections()
{
  global $EXTreports;
  static $cache = null;
  if($cache !== null) return $cache;
  $cache = array();
  if(!drsm_ext_enabled()) return $cache;
  $sid = "";
  foreach(file($EXTreports, FILE_IGNORE_NEW_LINES) ?: array() as $line) {
    $line = trim($line);
    if($line == "" || $line[0] == "#") continue;
    if(preg_match('/^\[([a-z0-9_-]+)\]\s*(.*)$/i', $line, $m)) {
      $sid = strtolower($m[1]);
      if(!isset($cache[$sid])) $cache[$sid] = array("title" => ($m[2] != "") ? $m[2] : $sid, "items" => array());
      continue;
    }
    if($sid == "") {
      $sid = "reports";
      $cache[$sid] = array("title" => "Reports", "items" => array());
    }
    $f = array_map("trim", explode("|", $line));
    while(count($f) < 5) $f[] = "";
    if($f[0] == "") continue;
    $n = count($cache[$sid]["items"]);
    $cache[$sid]["items"][] = array(
      "id" => "{$sid}-{$n}",
      "title" => $f[0],
      "file" => ($f[1] == "-") ? "" : $f[1],
      "link" => $f[2],
      "maxage" => (int)$f[3],
      "status" => ($f[4] == "-" || $f[1] == "-") ? "" : (($f[4] != "") ? $f[4] : $f[1])
    );
  }
  return $cache;
}

function drsm_ext_find($id)
{
  foreach(drsm_ext_sections() as $sec) {
    foreach($sec["items"] as $it) if($it["id"] === $id) return $it;
  }
  return null;
}

// State of one report: array("state", "time", "note")
function drsm_ext_state($it)
{
  // No status: a plain link, or a file shown with its time only
  if($it["status"] == "") {
    $t = ($it["file"] != "" && is_file($it["file"])) ? drsm_demo_time((int)@filemtime($it["file"])) : 0;
    return array("state" => "", "time" => $t, "note" => "");
  }
  $files = array_unique(array_filter(array($it["file"], $it["status"]), "strlen"));
  foreach($files as $f) {
    if(!is_readable($f)) return array("state" => "ERROR", "time" => 0, "note" => "Report file is missing");
  }
  $state = "OK";
  $etime = 0;
  if(is_dir($it["status"])) return array("state" => "", "time" => drsm_demo_time((int)@filemtime($it["status"])), "note" => "");
  $fp = @fopen($it["status"], "r");
  $n = 0;
  while($fp && ($buf = fgets($fp, 4096)) !== false && $n++ < 200000) {
    if($etime == 0 && preg_match('/^\s*ETIME:\s*([0-9]{9,11})/', $buf, $m)) $etime = (int)$m[1];
    if(strpos($buf, "ERROR") !== false || strpos($buf, "FAILED") !== false) $state = "ERROR";
    else if($state == "OK" && strpos($buf, "WARNING") !== false) $state = "WARNING";
  }
  if($fp) fclose($fp);
  if($etime == 0 && $it["file"] != "" && $it["file"] != $it["status"] && is_file($it["file"])) {
    // The time of the report itself, not of its errors file
    $fp = @fopen($it["file"], "r");
    for($i = 0; $fp && $i < 50 && ($buf = fgets($fp, 4096)) !== false; $i++) {
      if(preg_match('/^\s*ETIME:\s*([0-9]{9,11})/', $buf, $m)) { $etime = (int)$m[1]; break; }
    }
    if($fp) fclose($fp);
  }
  $t = ($etime > 0) ? $etime : (int)@filemtime(($it["file"] != "") ? $it["file"] : $it["status"]);
  $t = drsm_demo_time($t);
  $note = "";
  if($it["maxage"] > 0 && $t > 0 && time() - $t > $it["maxage"] * 60) {
    $note = "Report is older than " . drsm_ext_age_text($it["maxage"]);
    if($state != "ERROR") $state = "STALE";
  }
  return array("state" => $state, "time" => $t, "note" => $note);
}

function drsm_ext_age_text($min)
{
  if($min % 1440 == 0) return ($min / 1440) . (($min == 1440) ? " day" : " days");
  if($min % 60 == 0) return ($min / 60) . (($min == 60) ? " hour" : " hours");
  return "{$min} minutes";
}

// Where a report title goes
function drsm_ext_href($it)
{
  if($it["link"] != "") return $it["link"];
  if($it["file"] != "" && is_file($it["file"])) return drsm_url("extreports.php", array("v" => $it["id"]));
  return "";
}

// Worst state and counts of a section's reports
function drsm_ext_summary($sec)
{
  $sum = array("state" => "OK", "OK" => 0, "WARNING" => 0, "ERROR" => 0, "STALE" => 0, "total" => 0);
  foreach($sec["items"] as $it) {
    $st = drsm_ext_state($it);
    if($st["state"] == "") continue;
    $sum["total"]++;
    $sum[$st["state"]]++;
    $sum["state"] = drsm_worst($sum["state"], $st["state"]);
  }
  if($sum["total"] == 0) $sum["state"] = "";
  return $sum;
}

// SCRIPT CONTENT ENDS ABOVE.
// ----------------------------------------------------------- //
// ------------------------------- //
// --------- End of File --------- //
// ------------------------------- //
?>
