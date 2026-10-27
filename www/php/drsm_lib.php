<?php
// ------------------------------- //
// -------- Start of File -------- //
// ------------------------------- //
// ----------------------------------------------------------- //
// PHP Source Code File
// PHP Version: 7.2 or higher, tested with PHP 8
// Original Author(s): DataReel Software Development
// File Creation Date: 10/23/2026
// Date Last Modified: 10/24/2026
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

Shared functions for the DRSM Web pages: report parsing, host
states, metrics, and the page layout. Reads the report files written
by bin/drsm_run.sh (plugin sections and status.json) and by the
older system_report.sh and system_check.sh scripts.

Keep this file PHP 7.2 compatible: no arrow functions, no ??=, no
str_contains(), no match, no trailing commas in calls.

Optional settings, set them in config/drsm.php:

$SITEtitle      = 'DR System Monitor';  // Name in the page header
$REFRESHseconds = 60;   // Page auto refresh, 0 turns it off
$STALEminutes   = 60;   // Host report age that counts as stale, 0 off
$DEMObuilt      = 0;    // Sample data build time, set by
                        // utils/make_web_demo.sh so report times
                        // stay recent on a live demo

Login for access from outside the internal networks is off by
default, see drsm_auth.php for the $AUTH settings.
*/
// ----------------------------------------------------------- //
// SCRIPT CONTENT STARTS BELOW.

if(!isset($SITEtitle) || $SITEtitle == "") $SITEtitle = "DR System Monitor";
if(!isset($REFRESHseconds)) $REFRESHseconds = 60;
if(!isset($STALEminutes)) $STALEminutes = 60;
if(!isset($DEMObuilt)) $DEMObuilt = 0;
if(!isset($REPORTvpath)) $REPORTvpath = "{$WWWvpath}/reports";
if(!isset($REPORTarchivevpath)) $REPORTarchivevpath = "{$REPORTvpath}/archive";

// Report times are stored as UNIX epoch seconds
date_default_timezone_set(@date_default_timezone_get());

// Largest report file we will read, bigger files are cut
define("DRSM_MAX_REPORT_BYTES", 4194304);

// Sample data keeps its age relative to now instead of its build time
function drsm_demo_time($t)
{
  global $DEMObuilt;
  if($DEMObuilt > 0 && $t > 0) return $t + (time() - (int)$DEMObuilt);
  return $t;
}

function h($s)
{
  return htmlspecialchars((string)$s, ENT_QUOTES, "UTF-8");
}

function drsm_url($page, $args = array())
{
  global $WWWvpath;
  $url = "{$WWWvpath}/php/{$page}";
  if(count($args) > 0) $url .= "?" . http_build_query($args);
  return $url;
}

// Archived reports. With login on they are read through archive.php,
// since the report folder itself is not covered by the login.
function drsm_archive_url($host = "", $prefix = "", $site = DRSM_LEGACY_SITE)
{
  global $REPORTvpath, $REPORTarchivevpath, $AUTHenable, $AUTHscopes;
  // Login, or users limited to some sites: the folders are not covered
  if(!empty($AUTHenable) || isset($AUTHscopes)) {
    $args = array();
    if($host != "") $args["h"] = $host;
    if($prefix != "") $args["p"] = $prefix;
    if($site != DRSM_LEGACY_SITE) $args["site"] = $site;
    return drsm_url("archive.php", $args);
  }
  if($host != "") return drsm_site_vpath($site) . "/systems/" . rawurlencode($host) . "/archive/";
  if($site != DRSM_LEGACY_SITE) return drsm_site_vpath($site) . "/archive/";
  return "{$REPORTarchivevpath}/";
}

// Severity order used to pick the worst state
function drsm_state_rank($state)
{
  $ranks = array("OK" => 0, "UNKNOWN" => 1, "WARNING" => 2, "STALE" => 3, "ERROR" => 4);
  return isset($ranks[$state]) ? $ranks[$state] : 1;
}

function drsm_worst($a, $b)
{
  return (drsm_state_rank($b) > drsm_state_rank($a)) ? $b : $a;
}

function drsm_state_class($state)
{
  $classes = array("OK" => "ok", "WARNING" => "warn", "ERROR" => "err", "UNKNOWN" => "unk", "STALE" => "stale");
  return isset($classes[$state]) ? $classes[$state] : "unk";
}

function drsm_state_label($state)
{
  $labels = array("OK" => "OK", "WARNING" => "Warning", "ERROR" => "Error", "UNKNOWN" => "Unknown", "STALE" => "Stale");
  return isset($labels[$state]) ? $labels[$state] : $state;
}

function drsm_badge($state, $extra = "")
{
  $cls = drsm_state_class($state);
  return "<span class=\"badge {$cls}\"><span class=\"dot\"></span>" . h(drsm_state_label($state)) . h($extra) . "</span>";
}

// Level of one report line: ERROR, WARNING, UNKNOWN, INFO or ""
function drsm_line_level($line)
{
  if(strpos($line, "ERROR - ") !== false) return "ERROR";
  if(strpos($line, "WARNING - ") !== false) return "WARNING";
  if(strpos($line, "IMPACT - ") === 0) return "ERROR";
  if(strpos($line, "UNKNOWN - ") === 0) return "UNKNOWN";
  if(strpos($line, "INFO - ") === 0) return "INFO";
  if(strpos($line, "METRIC ") === 0) return "METRIC";
  return "";
}

function drsm_read_lines($fname)
{
  if(!is_readable($fname)) return false;
  $data = @file_get_contents($fname, false, null, 0, DRSM_MAX_REPORT_BYTES);
  if($data === false) return false;
  return preg_split('/\r\n|\n|\r/', rtrim($data, "\r\n"));
}

/*
Parse a host or group report. Returns:
  fields   header NAME:value pairs (first value wins)
  sections plugin sections from drsm_run.sh, each with id, state,
           secs, lines
  pre      lines before the first section
  messages ERROR, WARNING and UNKNOWN lines with their plugin
  metrics  name => list of array(labels, value)
  state    worst state found in the lines and sections
*/
function drsm_parse_report($fname)
{
  $r = array("fields" => array(), "sections" => array(), "pre" => array(),
             "messages" => array(), "metrics" => array(), "state" => "OK",
             "exists" => false, "mtime" => 0);
  $lines = drsm_read_lines($fname);
  if($lines === false) return $r;
  $r["exists"] = true;
  $r["mtime"] = drsm_demo_time((int)@filemtime($fname));

  $cur = -1;
  foreach($lines as $line) {
    if(preg_match('/^=== (\S+) \[([A-Z]+)\] (\d+)s ===$/', $line, $m)) {
      $r["sections"][] = array("id" => $m[1], "state" => $m[2], "secs" => (int)$m[3], "lines" => array());
      $cur = count($r["sections"]) - 1;
      $r["state"] = drsm_worst($r["state"], $m[2]);
      continue;
    }
    $plugin = ($cur >= 0) ? $r["sections"][$cur]["id"] : "";
    if($cur >= 0) {
      $r["sections"][$cur]["lines"][] = $line;
    }
    else {
      $r["pre"][] = $line;
      // Header fields are NAME:value, split on the first colon only
      // since values such as descriptions can contain colons
      if(preg_match('/^([A-Z_]+):(.*)$/', $line, $m) && !isset($r["fields"][$m[1]])) {
        $r["fields"][$m[1]] = trim($m[2]);
      }
    }
    $level = drsm_line_level($line);
    if($level == "ERROR" || $level == "WARNING" || $level == "UNKNOWN") {
      $r["messages"][] = array("level" => $level, "text" => $line, "plugin" => $plugin);
      if($level != "UNKNOWN") $r["state"] = drsm_worst($r["state"], $level);
    }
    else if($level == "METRIC" && preg_match('/^METRIC ([A-Za-z0-9_.]+)(\{.*\})?=(-?[0-9.]+)/', $line, $m)) {
      $r["metrics"][$m[1]][] = array($m[2], (float)$m[3]);
    }
  }
  return $r;
}

function drsm_metric_max($metrics, $name, &$labels)
{
  $labels = "";
  if(!isset($metrics[$name])) return null;
  $best = null;
  foreach($metrics[$name] as $mv) {
    if($best === null || $mv[1] > $best) {
      $best = $mv[1];
      $labels = $mv[0];
    }
  }
  return $best;
}

// First number on a "Label: N" line in a plugin section
function drsm_section_number($sections, $id, $label)
{
  foreach($sections as $s) {
    if($s["id"] != $id) continue;
    foreach($s["lines"] as $line) {
      if(strpos($line, $label) === 0 && preg_match('/(-?[0-9.]+)/', substr($line, strlen($label)), $m)) {
        return (float)$m[1];
      }
    }
  }
  return null;
}

// The heat map metrics, all as percentages
function drsm_metric_columns()
{
  return array(
    "cpu"  => array("label" => "CPU",    "title" => "CPU used"),
    "mem"  => array("label" => "Memory", "title" => "Memory used"),
    "disk" => array("label" => "Disk",   "title" => "Fullest file system"),
    "load" => array("label" => "Load",   "title" => "15 minute load per CPU"),
    "swap" => array("label" => "Swap",   "title" => "Swap used")
  );
}

function drsm_host_metrics($rep)
{
  $out = array();
  $m = $rep["metrics"];
  $s = $rep["sections"];
  $labels = "";

  $v = drsm_metric_max($m, "cpu_used_pct", $labels);
  if($v !== null) $out["cpu"] = array("pct" => $v, "text" => round($v) . "%");

  $avail = drsm_metric_max($m, "mem_available_mb", $labels);
  $total = drsm_section_number($s, "core/memory", "Total physical:");
  if($avail !== null && $total) {
    $pct = max(0, min(100, 100 - ($avail / $total * 100)));
    $out["mem"] = array("pct" => $pct, "text" => round($pct) . "%", "detail" => round($avail) . " MB free of " . round($total) . " MB");
  }

  $v = drsm_metric_max($m, "disk_used_pct", $labels);
  if($v !== null) {
    $mount = "";
    if(preg_match('/mount="([^"]*)"/', $labels, $mm)) $mount = $mm[1];
    $out["disk"] = array("pct" => $v, "text" => round($v) . "%", "detail" => $mount);
  }

  $v = drsm_metric_max($m, "load_15m", $labels);
  $cpus = drsm_section_number($s, "core/load", "Number of CPUs:");
  if($v !== null && $cpus) {
    $out["load"] = array("pct" => $v / $cpus * 100, "text" => (string)$v, "detail" => "{$v} on {$cpus} CPUs");
  }

  $v = drsm_metric_max($m, "swap_used_mb", $labels);
  $total = drsm_section_number($s, "core/memory", "Total SWAP:");
  if($v !== null && $total) {
    $pct = $v / $total * 100;
    $out["swap"] = array("pct" => $pct, "text" => round($pct) . "%", "detail" => round($v) . " MB of " . round($total) . " MB");
  }
  return $out;
}

// Heat level 0 to 5 for a percentage
function drsm_heat_level($pct)
{
  if($pct === null) return -1;
  if($pct >= 95) return 5;
  if($pct >= 85) return 4;
  if($pct >= 70) return 3;
  if($pct >= 50) return 2;
  if($pct >= 25) return 1;
  return 0;
}

function drsm_valid_host($n)
{
  return (bool)(preg_match('/^[A-Za-z0-9][A-Za-z0-9._-]*$/', $n) && strpos($n, "..") === false);
}

/*
Load one host from <site reports>/systems/<host>, ${REPORTdir}/systems
for the default site. Plugin states come from status.json when
drsm_run.sh wrote one, otherwise from the report text.
*/
function drsm_load_host($hostdir, $site = DRSM_LEGACY_SITE)
{
  global $STALEminutes;
  $dir = drsm_site_dir($site) . "/systems/{$hostdir}";
  $rep = drsm_parse_report("{$dir}/{$hostdir}_report.txt");
  $f = $rep["fields"];
  $sites = drsm_all_sites();
  $stale = isset($sites[$site]) ? $sites[$site]["stale_minutes"] : $STALEminutes;
  $host = array(
    "name" => $hostdir,
    "site" => $site,
    "key" => drsm_host_key($hostdir, $site),
    "description" => isset($f["DESCRIPTION"]) ? $f["DESCRIPTION"] : "",
    "impact" => isset($f["IMPACT"]) ? $f["IMPACT"] : "",
    "group" => (isset($f["GROUP"]) && $f["GROUP"] != "") ? $f["GROUP"] : "production",
    "platform" => isset($f["PLATFORM"]) ? $f["PLATFORM"] : "",
    "collector" => isset($f["COLLECTOR"]) ? $f["COLLECTOR"] : "",
    "time" => (isset($f["ETIME"]) && ctype_digit($f["ETIME"])) ? drsm_demo_time((int)$f["ETIME"]) : $rep["mtime"],
    "plugins" => array(),
    "report" => $rep,
    "state" => $rep["state"],
    "stale" => false,
    "note" => ""
  );

  if(!$rep["exists"]) {
    $host["state"] = "ERROR";
    $host["note"] = "No report posted";
    return $host;
  }

  $secs = array();
  foreach($rep["sections"] as $s) $secs[$s["id"]] = $s;

  $json = @file_get_contents("{$dir}/status.json");
  $status = ($json !== false) ? json_decode($json, true) : null;
  if(is_array($status) && isset($status["plugins"]) && is_array($status["plugins"])) {
    foreach($status["plugins"] as $p) {
      if(!isset($p["id"]) || !isset($p["state"])) continue;
      $host["plugins"][$p["id"]] = array("state" => (string)$p["state"], "secs" => isset($p["secs"]) ? (int)$p["secs"] : 0);
      $host["state"] = drsm_worst($host["state"], (string)$p["state"]);
    }
    if(isset($status["group"]) && $status["group"] != "") $host["group"] = (string)$status["group"];
  }
  else {
    foreach($secs as $id => $s) $host["plugins"][$id] = array("state" => $s["state"], "secs" => $s["secs"]);
  }

  // Count each plugin's problem lines for the tooltips
  foreach($host["plugins"] as $id => $p) {
    $host["plugins"][$id]["msgs"] = array();
  }
  foreach($rep["messages"] as $msg) {
    if($msg["plugin"] != "" && isset($host["plugins"][$msg["plugin"]])) {
      $host["plugins"][$msg["plugin"]]["msgs"][] = $msg["text"];
    }
  }

  if($stale > 0 && $host["time"] > 0 && (time() - $host["time"]) > ($stale * 60)) {
    $host["stale"] = true;
    $host["state"] = drsm_worst($host["state"], "STALE");
    $host["note"] = "Last report is over " . drsm_age_text($stale * 60) . " old";
  }
  $host["metrics"] = drsm_host_metrics($rep);
  return $host;
}

/*
Every host in a scope, keyed by drsm_host_key(): "" for every visible
site, an organization, or org/site. With no argument, the scope picked
in the page header.
*/
function drsm_load_hosts($scope = null)
{
  if($scope === null) $scope = drsm_scope();
  $hosts = array();
  foreach(drsm_scope_sites($scope) as $site => $s) {
    $dir = drsm_site_dir($site) . "/systems";
    if(!is_dir($dir)) continue;
    $names = scandir($dir);
    if($names === false) continue;
    foreach($names as $name) {
      // Skip hidden files and anything that is not a host directory
      if(substr($name, 0, 1) == ".") continue;
      if(!drsm_valid_host($name) || !is_dir("{$dir}/{$name}")) continue;
      $hosts[drsm_host_key($name, $site)] = drsm_load_host($name, $site);
    }
  }
  uasort($hosts, function($a, $b) {
    $d = strcmp($a["name"], $b["name"]);
    return ($d != 0) ? $d : strcmp($a["site"], $b["site"]);
  });
  return $hosts;
}

// Hosts split by site, in site order
function drsm_hosts_by_site($hosts, $sites)
{
  $out = array();
  foreach($sites as $id => $s) $out[$id] = array();
  foreach($hosts as $key => $hst) $out[$hst["site"]][$key] = $hst;
  return $out;
}

function drsm_host_counts($hosts)
{
  $c = array("total" => count($hosts), "OK" => 0, "WARNING" => 0, "ERROR" => 0, "STALE" => 0, "UNKNOWN" => 0,
             "checks" => 0, "checks_bad" => 0);
  foreach($hosts as $hst) {
    $c[$hst["state"]] = isset($c[$hst["state"]]) ? $c[$hst["state"]] + 1 : 1;
    foreach($hst["plugins"] as $p) {
      $c["checks"]++;
      if($p["state"] == "ERROR" || $p["state"] == "WARNING") $c["checks_bad"]++;
    }
  }
  return $c;
}

function drsm_groups($hosts)
{
  $groups = array();
  foreach($hosts as $hst) $groups[$hst["group"]] = true;
  $groups = array_keys($groups);
  sort($groups);
  return $groups;
}

/*
Group reports written by system_check.sh, system_report.sh and
drsm_run.sh. Production has no suffix, other groups add _<group>:
system_check_<group>_report.txt and system_health_report_<group>.txt
*/
function drsm_group_report_file($kind, $group, $site = DRSM_LEGACY_SITE)
{
  $dir = drsm_site_dir($site);
  if($kind == "check") {
    return ($group == "production") ? "{$dir}/system_check_report.txt" : "{$dir}/system_check_{$group}_report.txt";
  }
  return ($group == "production") ? "{$dir}/system_health_report.txt" : "{$dir}/system_health_report_{$group}.txt";
}

// Group reports of every site in a scope, default the picked scope
function drsm_group_reports($scope = null)
{
  if($scope === null) $scope = drsm_scope();
  $out = array();
  foreach(drsm_scope_sites($scope) as $site => $s) {
    foreach(drsm_site_group_reports($site) as $gr) $out[] = $gr;
  }
  return $out;
}

function drsm_site_group_reports($site)
{
  $dir = drsm_site_dir($site);
  $groups = array("production" => true);
  foreach(array("system_check_*_report.txt", "system_health_report_*.txt") as $pat) {
    $found = glob("{$dir}/{$pat}");
    if(!is_array($found)) continue;
    foreach($found as $f) {
      $b = basename($f);
      if(preg_match('/^system_check_([A-Za-z0-9-]+)_report\.txt$/', $b, $m) && $m[1] != "report") $groups[$m[1]] = true;
      if(preg_match('/^system_health_report_([A-Za-z0-9-]+)\.txt$/', $b, $m) && $m[1] != "errors") $groups[$m[1]] = true;
    }
  }
  $out = array();
  foreach(array_keys($groups) as $g) {
    foreach(array("check", "health") as $kind) {
      $fname = drsm_group_report_file($kind, $g, $site);
      if($g != "production" && !file_exists($fname)) continue;
      $rep = drsm_parse_report($fname);
      $state = $rep["exists"] ? $rep["state"] : "ERROR";
      $out[] = array("group" => $g, "kind" => $kind, "state" => $state, "exists" => $rep["exists"], "site" => $site,
                     "time" => $rep["mtime"], "errors" => count($rep["messages"]));
    }
  }
  return $out;
}

function drsm_age_text($secs)
{
  if($secs < 90) return round($secs) . " seconds";
  if($secs < 5400) return round($secs / 60) . " minutes";
  if($secs < 129600) return round($secs / 3600) . " hours";
  return round($secs / 86400) . " days";
}

// A time shown as "5 min ago" in the browser, or with $absolute as the
// date and time in the viewer's own time zone
function drsm_time_html($epoch, $absolute = false)
{
  if(!$epoch) return "<span class=\"muted\">never</span>";
  $full = date("M j, Y g:i A T", $epoch);
  $attr = $absolute ? "data-abs" : "data-epoch";
  return "<time datetime=\"" . h(date("c", $epoch)) . "\" " . $attr . "=\"" . (int)$epoch . "\" title=\"" . h($full) . "\">" . h($full) . "</time>";
}

// Short name of a plugin id, storage/disk shows as disk
function drsm_plugin_short($id)
{
  $p = strrpos($id, "/");
  return ($p === false) ? $id : substr($id, $p + 1);
}

function drsm_plugin_anchor($id)
{
  return "p-" . preg_replace('/[^A-Za-z0-9_-]/', "-", $id);
}

function drsm_icon($name)
{
  $paths = array(
    "grid" => '<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>',
    "heat" => '<rect x="3" y="3" width="5" height="5" rx="1"/><rect x="9.5" y="3" width="5" height="5" rx="1"/><rect x="16" y="3" width="5" height="5" rx="1"/><rect x="3" y="9.5" width="5" height="5" rx="1"/><rect x="9.5" y="9.5" width="5" height="5" rx="1"/><rect x="16" y="9.5" width="5" height="5" rx="1"/><rect x="3" y="16" width="5" height="5" rx="1"/><rect x="9.5" y="16" width="5" height="5" rx="1"/><rect x="16" y="16" width="5" height="5" rx="1"/>',
    "list" => '<path d="M8 6h13M8 12h13M8 18h13"/><circle cx="4" cy="6" r="1"/><circle cx="4" cy="12" r="1"/><circle cx="4" cy="18" r="1"/>',
    "net" => '<circle cx="12" cy="5" r="2.5"/><circle cx="5" cy="19" r="2.5"/><circle cx="19" cy="19" r="2.5"/><path d="M12 7.5v4M12 11.5l-5.5 5.5M12 11.5l5.5 5.5"/>',
    "sun" => '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
    "moon" => '<path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"/>',
    "expand" => '<path d="M8 3H3v5M16 3h5v5M8 21H3v-5M16 21h5v-5"/>',
    "pause" => '<path d="M9 5v14M15 5v14"/>',
    "refresh" => '<path d="M20 12a8 8 0 1 1-2.3-5.7M20 4v5h-5"/>',
    "search" => '<circle cx="11" cy="11" r="7"/><path d="M20 20l-4-4"/>',
    "archive" => '<rect x="3" y="4" width="18" height="4" rx="1"/><path d="M5 8v11a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1V8M10 12h4"/>',
    "back" => '<path d="M15 18l-6-6 6-6"/>',
    "alert" => '<path d="M12 3l9.5 17H2.5z"/><path d="M12 10v4M12 17.5v.5"/>',
    "check" => '<path d="M5 12.5l4.5 4.5L19 7.5"/>',
    "lock" => '<rect x="4.5" y="10.5" width="15" height="10" rx="2"/><path d="M8 10.5V7.5a4 4 0 0 1 8 0v3"/>',
    "trend" => '<path d="M3 17l6-6 4 4 8-8"/><path d="M15 7h6v6"/>',
    "building" => '<path d="M4 21V5a1 1 0 0 1 1-1h9a1 1 0 0 1 1 1v16M15 9h4a1 1 0 0 1 1 1v11M2.5 21h19M8 8h3M8 12h3M8 16h3"/>',
    "cloud" => '<path d="M7 18a4.5 4.5 0 0 1-.6-9 6 6 0 0 1 11.5 1.5A3.75 3.75 0 0 1 17.5 18z"/>',
    "logout" => '<path d="M15 4h3a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2h-3M10 16l-4-4 4-4M6 12h10"/>'
  );
  $p = isset($paths[$name]) ? $paths[$name] : "";
  return "<svg class=\"icon\" viewBox=\"0 0 24 24\" aria-hidden=\"true\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\">{$p}</svg>";
}

// Filled status icon for the heat map: check, triangle, X, ? or clock
function drsm_state_icon($state, $extra = "")
{
  $shapes = array(
    "ok" => '<circle cx="12" cy="12" r="10.5" fill="currentColor"/><path d="M7.2 12.4l3.2 3.2 6.4-6.8" fill="none" stroke="#fff" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/>',
    "warn" => '<path d="M10.3 3.6a2 2 0 0 1 3.4 0l8.4 14.6a2 2 0 0 1-1.7 3H3.6a2 2 0 0 1-1.7-3z" fill="currentColor"/><path d="M12 9v4.6" stroke="#2a1700" stroke-width="2.6" stroke-linecap="round"/><circle cx="12" cy="17.3" r="1.5" fill="#2a1700"/>',
    "err" => '<circle cx="12" cy="12" r="10.5" fill="currentColor"/><path d="M8.3 8.3l7.4 7.4M15.7 8.3l-7.4 7.4" stroke="#fff" stroke-width="2.6" stroke-linecap="round"/>',
    "stale" => '<circle cx="12" cy="12" r="10.5" fill="currentColor"/><path d="M12 6.8V12l3.6 2.2" fill="none" stroke="#fff" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>',
    "unk" => '<circle cx="12" cy="12" r="10.5" fill="currentColor"/><path d="M9.3 9.4a2.8 2.8 0 1 1 3.8 2.6c-.7.3-1.1.9-1.1 1.6v.4" fill="none" stroke="#fff" stroke-width="2.4" stroke-linecap="round"/><circle cx="12" cy="17.2" r="1.4" fill="#fff"/>'
  );
  $cls = drsm_state_class($state);
  $shape = isset($shapes[$cls]) ? $shapes[$cls] : $shapes["unk"];
  return "<svg class=\"sicon {$cls}{$extra}\" viewBox=\"0 0 24 24\" aria-hidden=\"true\">{$shape}</svg>";
}

// <link> and <script> tags for a custom site page_header.php
function drsm_head_assets()
{
  global $WWWvpath, $WWWdir;
  $v = @filemtime("{$WWWdir}/css/drsm.css");
  $out = "<link rel=\"stylesheet\" href=\"" . h("{$WWWvpath}/css/drsm.css?v={$v}") . "\">\n";
  if(file_exists("{$WWWdir}/site/custom.css")) {
    $out .= "<link rel=\"stylesheet\" href=\"" . h("{$WWWvpath}/site/custom.css?v=" . @filemtime("{$WWWdir}/site/custom.css")) . "\">\n";
  }
  $out .= "<link rel=\"icon\" type=\"image/svg+xml\" href=\"" . h("{$WWWvpath}/images/favicon.svg") . "\">\n";
  $out .= "<script src=\"" . h("{$WWWvpath}/js/drsm.js?v=" . @filemtime("{$WWWdir}/js/drsm.js")) . "\"></script>\n";
  return $out;
}

// Page layout. $PAGEtitle and $PAGEactive are read by default_header.php
function drsm_page_start($title, $active, $state = "")
{
  global $SITEincludes, $WWWdir, $WWWvpath, $SITEtitle, $REFRESHseconds, $PAGEtitle, $PAGEactive, $PAGEstate, $AUTHuser, $AUTHcsrf;
  $PAGEtitle = $title;
  $PAGEactive = $active;
  $PAGEstate = $state;
  if(isset($SITEincludes) && file_exists("{$SITEincludes}/page_header.php")) {
    include_once("{$SITEincludes}/page_header.php");
  }
  else {
    include_once("{$WWWdir}/php/default_header.php");
  }
}

function drsm_page_end()
{
  global $SITEincludes, $WWWdir, $WWWvpath, $SITEtitle;
  if(isset($SITEincludes) && file_exists("{$SITEincludes}/page_footer.php")) {
    include_once("{$SITEincludes}/page_footer.php");
  }
  else {
    include_once("{$WWWdir}/php/default_footer.php");
  }
}

// Organizations and sites
require_once("{$WWWdir}/php/drsm_sites.php");

// Optional login for requests from outside the internal networks,
// see drsm_auth.php. login.php does its own checks.
require_once("{$WWWdir}/php/drsm_auth.php");
if(!defined("DRSM_LOGIN_PAGE")) drsm_auth_require();

// SCRIPT CONTENT ENDS ABOVE.
// ----------------------------------------------------------- //
// ------------------------------- //
// --------- End of File --------- //
// ------------------------------- //
?>
