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

Hook uploads: reports from other sources that the DataReel Reporting
Agents send to hook.php, checked by the uploads/<id> plugins (see
plugins/uploads/upload_probe.sh). This file draws a hook's data in its
section of the host page (readreport.php) with the display named in
the manifest's DISPLAY setting:

  table  UPLOAD columns| and UPLOAD row| lines as a table
  kv     UPLOAD value| lines as a list of names and values
  text   the payload as plain text (upload_view.php)
  html   the payload as a page in a sandbox (upload_view.php)

The lines are in the host report as DATA lines:

  UPLOAD meta|<agent host name>|<hook id>|<display>|<title>|<etime>
  UPLOAD columns|<name>|<name>...
  UPLOAD row|<cell>|<cell>...
  UPLOAD value|<name>|<value>

Any other DISPLAY name is a site display plug-in: the file
$UPLOADdisplayDir/<name>.php (default php/uploads/ in the dashboard) with
a function drsm_upload_display_<name>($hook) that returns HTML, escaped
with h(). $hook has the keys host, site, id, name, title, display,
time, columns, rows, values, lines (the section's report lines) and
view_url. Display plug-ins are code: install only ones you trust.

Settings in config/drsm.php:

$UPLOADSdir       = '';   // the report server's [hooks] dir, only where
                        // the uploads land: text and html displays
$UPLOADdisplayDir = '';   // site display plug-ins, default php/uploads
*/
// ----------------------------------------------------------- //
// SCRIPT CONTENT STARTS BELOW.

define("DRSM_UPLOAD_PREFIX", "uploads/");
define("DRSM_UPLOAD_MAX_ROWS", 500);

function drsm_is_upload_section($id)
{
  return strpos($id, DRSM_UPLOAD_PREFIX) === 0;
}

function drsm_valid_upload_id($id)
{
  return is_string($id) && preg_match('/^[a-z0-9_]{1,32}$/', $id) === 1;
}

// The UPLOAD lines of an uploads/<id> report section
function drsm_upload_parse($section)
{
  $hook = array("id" => substr($section["id"], strlen(DRSM_UPLOAD_PREFIX)), "name" => "", "title" => "",
                "display" => "text", "time" => 0, "columns" => array(), "rows" => array(),
                "values" => array(), "lines" => $section["lines"]);
  foreach($section["lines"] as $line) {
    if(strpos($line, "UPLOAD ") !== 0) continue;
    $p = explode("|", substr($line, 7));
    $kind = array_shift($p);
    if($kind == "meta" && count($p) >= 5) {
      $hook["name"] = $p[0];
      $hook["display"] = $p[2];
      $hook["title"] = $p[3];
      $hook["time"] = (int)$p[4];
    }
    else if($kind == "columns") {
      $hook["columns"] = $p;
    }
    else if($kind == "row" && count($hook["rows"]) < DRSM_UPLOAD_MAX_ROWS) {
      $hook["rows"][] = $p;
    }
    else if($kind == "value" && count($p) >= 2) {
      $n = array_shift($p);
      $hook["values"][$n] = implode("|", $p);
    }
  }
  if($hook["title"] == "") $hook["title"] = $hook["id"];
  return $hook;
}

// Where the payload of a hook is, "" when this dashboard has no
// $UPLOADSdir or no data. Built from checked names only.
function drsm_upload_data_path($name, $id)
{
  global $UPLOADSdir;
  if(!isset($UPLOADSdir) || $UPLOADSdir == "") return "";
  if(!drsm_valid_upload_id($id) || !preg_match('/^[a-z0-9][a-z0-9_-]{0,62}$/', $name)) return "";
  $f = rtrim($UPLOADSdir, "/") . "/{$name}/{$id}/latest.data";
  return is_file($f) ? $f : "";
}

function drsm_upload_display_table($hook)
{
  if(count($hook["rows"]) == 0) return "<p class=\"pad muted small\">No rows.</p>";
  $out = "<div class=\"table-wrap\"><table class=\"table\"><thead><tr>";
  foreach($hook["columns"] as $c) $out .= "<th>" . h($c) . "</th>";
  $out .= "</tr></thead><tbody>";
  foreach($hook["rows"] as $r) {
    $out .= "<tr>";
    foreach($r as $c) $out .= "<td>" . h($c) . "</td>";
    $out .= "</tr>";
  }
  $out .= "</tbody></table></div>";
  if(count($hook["rows"]) >= DRSM_UPLOAD_MAX_ROWS) $out .= "<p class=\"pad muted small\">First " . DRSM_UPLOAD_MAX_ROWS . " rows.</p>";
  return $out . drsm_upload_display_kv($hook);
}

function drsm_upload_display_kv($hook)
{
  if(count($hook["values"]) == 0) return "";
  $out = "<dl class=\"meta pad\">";
  foreach($hook["values"] as $k => $v) $out .= "<dt>" . h($k) . "</dt><dd>" . h($v) . "</dd>";
  return $out . "</dl>";
}

function drsm_upload_show_file($hook, $label)
{
  if($hook["view_url"] == "") {
    return "<p class=\"pad muted small\">The " . h($label) . " is on the report server. Set \$UPLOADSdir in config/drsm.php on the server that receives the agent uploads to show it here.</p>";
  }
  return "<p class=\"pad small\"><a href=\"" . h($hook["view_url"]) . "\" target=\"_blank\" rel=\"noopener\">" .
    drsm_icon("link") . "Open the " . h($label) . "</a></p>" . drsm_upload_display_kv($hook);
}

// HTML for a hook section of the host page
function drsm_upload_render($section, $host, $site)
{
  global $WWWdir, $UPLOADdisplayDir;
  $hook = drsm_upload_parse($section);
  $hook["host"] = $host;
  $hook["site"] = $site;
  $hook["view_url"] = drsm_upload_data_path($hook["name"], $hook["id"]) != "" ?
    drsm_url("upload_view.php", array("n" => $host, "site" => $site, "h" => $hook["id"])) : "";
  $display = preg_match('/^[a-z0-9_]{1,32}$/', $hook["display"]) ? $hook["display"] : "text";
  switch($display) {
    case "table": return drsm_upload_display_table($hook);
    case "kv": return drsm_upload_display_kv($hook);
    case "text": return drsm_upload_show_file($hook, "report");
    case "html": return drsm_upload_show_file($hook, "report page");
  }
  $dir = (isset($UPLOADdisplayDir) && $UPLOADdisplayDir != "") ? $UPLOADdisplayDir : "{$WWWdir}/php/uploads";
  $fn = "drsm_upload_display_{$display}";
  if(!function_exists($fn) && is_file("{$dir}/{$display}.php")) include_once("{$dir}/{$display}.php");
  if(function_exists($fn)) return (string)call_user_func($fn, $hook);
  return "<p class=\"pad muted small\">Display plug-in " . h($display) . " is not installed.</p>" . drsm_upload_display_kv($hook);
}

// SCRIPT CONTENT ENDS ABOVE.
// ----------------------------------------------------------- //
// ------------------------------- //
// --------- End of File --------- //
// ------------------------------- //
?>
