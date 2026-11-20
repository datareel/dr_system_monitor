<?php
// ------------------------------- //
// -------- Start of File -------- //
// ------------------------------- //
// ----------------------------------------------------------- //
// PHP Source Code File
// PHP Version: 7.2 or higher, tested with PHP 8
// Original Author(s): DataReel Software Development
// File Creation Date: 11/20/2026
// Date Last Modified: 11/20/2026
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

Page layouts and the meters layout of the Overview and Heat map pages.

Two layouts:

  meters  (default) Round percentage meters. The Overview shows one
          tile per group of reports (sites, host platforms, group
          checks, clusters, other script reports, and each check
          category) with a ring of state slices and the percent that
          is healthy; a tile opens the list of its reports. The Heat
          map is a mosaic of every check, grouped by tile, with the
          tile meters across the top.
  cards   The host cards Overview and the host by check table heat
          map of DRSM 1.31 to 1.34.

Settings in config/drsm.php:

$PAGElayout   = 'meters'; // Default layout: meters or cards. Viewers
                          // pick their own with the Layout switch on
                          // the Overview and Heat map pages (cookie
                          // drsm_layout, or ?layout= in the URL)
$METERtiles   = array('sites', 'platforms', 'groupchecks', 'clusters',
                      'ext', 'checks'); // Overview tiles, in order
$METERlabels  = array();  // Check category titles, such as
                          // array('storage' => 'Disks and RAID')
$METERsitesOnly = true;   // With more than one site shown (All
                          // sites, an organization), the Overview
                          // shows one tile per site only: select a
                          // site to drill down to its own tiles
$METERsolidRed = 0.80;    // A tile turns solid red only when this
                          // share of its reports is in error; below
                          // that it keeps a red top line, badge and
                          // ring slice
*/
// ----------------------------------------------------------- //
// SCRIPT CONTENT STARTS BELOW.

define("DRSM_LAYOUTS", "meters cards");

if(!isset($PAGElayout) || !in_array($PAGElayout, explode(" ", DRSM_LAYOUTS))) $PAGElayout = "meters";
if(!isset($METERtiles) || !is_array($METERtiles)) $METERtiles = array("sites", "platforms", "groupchecks", "clusters", "ext", "checks");
if(!isset($METERlabels) || !is_array($METERlabels)) $METERlabels = array();
if(!isset($METERsolidRed) || !is_numeric($METERsolidRed)) $METERsolidRed = 0.80;
if(!isset($METERsitesOnly)) $METERsitesOnly = true;

// The layout for this request: ?layout= (kept in the drsm_layout
// cookie), then the cookie, then $PAGElayout
function drsm_layout()
{
  global $PAGElayout, $WWWvpath;
  static $layout = null;
  if($layout !== null) return $layout;
  $all = explode(" ", DRSM_LAYOUTS);
  $layout = $PAGElayout;
  if(isset($_GET["layout"]) && in_array($_GET["layout"], $all, true)) {
    $layout = $_GET["layout"];
    if(!headers_sent() && PHP_SAPI != "cli") {
      $path = (isset($WWWvpath) && $WWWvpath != "") ? $WWWvpath : "/";
      $secure = !empty($_SERVER["HTTPS"]) && $_SERVER["HTTPS"] != "off";
      if(PHP_VERSION_ID >= 70300) {
        setcookie("drsm_layout", $layout, array("expires" => time() + 365 * 86400, "path" => $path, "secure" => $secure, "httponly" => true, "samesite" => "Lax"));
      }
      else {
        setcookie("drsm_layout", $layout, time() + 365 * 86400, $path . "; samesite=Lax", "", $secure, true);
      }
    }
  }
  else if(isset($_COOKIE["drsm_layout"]) && in_array($_COOKIE["drsm_layout"], $all, true)) {
    $layout = $_COOKIE["drsm_layout"];
  }
  return $layout;
}

// Layout switch for a page head: links back to $page with $args
function drsm_layout_switch($page, $args = array())
{
  $cur = drsm_layout();
  $out = "<div class=\"seg layout-seg\" role=\"group\" aria-label=\"Page layout\">";
  foreach(array("meters" => "Meters", "cards" => "Cards") as $id => $label) {
    $out .= "<a href=\"" . h(drsm_url($page, array("layout" => $id) + $args)) . "\"" . ($cur == $id ? " class=\"active\" aria-current=\"true\"" : "")
      . " title=\"" . h($id == "meters" ? "Round percentage meters" : "Host cards and tables") . "\">" . h($label) . "</a>";
  }
  return $out . "</div>";
}

// Check category title from the plugin ID prefix
function drsm_meter_category_label($cat)
{
  global $METERlabels;
  if(isset($METERlabels[$cat]) && $METERlabels[$cat] != "") return (string)$METERlabels[$cat];
  $known = array("core" => "Core system", "linux" => "Linux agent checks", "windows" => "Windows agent checks",
                 "network" => "Network", "storage" => "Storage", "cluster" => "Cluster checks",
                 "uploads" => "Uploads", "cloud" => "Cloud", "security" => "Security", "services" => "Services",
                 "database" => "Databases", "web" => "Web");
  return isset($known[$cat]) ? $known[$cat] : ucfirst($cat);
}

function drsm_meter_category_icon($cat)
{
  $icons = array("core" => "grid", "linux" => "list", "windows" => "windows", "network" => "net", "storage" => "archive",
                 "cluster" => "link", "uploads" => "file", "cloud" => "cloud", "security" => "lock");
  return isset($icons[$cat]) ? $icons[$cat] : "check";
}

function drsm_meter_category($id)
{
  $p = strrpos($id, "/");
  return ($p === false) ? "other" : substr($id, 0, $p);
}

// Platform of a host for the platform tiles
function drsm_meter_platform($hst)
{
  $p = strtolower($hst["platform"]);
  if($p == "windows" || $hst["collector"] == "wra") return "windows";
  if($p == "" || $p == "linux") return "linux";
  return "other";
}

function drsm_meter_counts()
{
  return array("OK" => 0, "WARNING" => 0, "ERROR" => 0, "STALE" => 0, "UNKNOWN" => 0);
}

// A tile item: one report line in a tile's list
function drsm_meter_item($title, $state, $href = "", $note = "", $time = 0)
{
  return array("title" => $title, "state" => $state, "href" => $href, "note" => $note, "time" => $time,
               "counts" => array(), "hosts" => array(), "all" => array());
}

// Add one item to a tile: its units are its host counts, or 1
function drsm_meter_add(&$t, $it)
{
  $t["items"][] = $it;
  if($it["state"] == "") return;
  $t["state"] = ($t["state"] == "") ? $it["state"] : drsm_worst($t["state"], $it["state"]);
  if($it["time"] > $t["time"]) $t["time"] = $it["time"];
  if(count($it["counts"]) > 0) {
    foreach($it["counts"] as $s => $n) { $t["counts"][$s] += $n; $t["units"] += $n; }
  }
  else {
    $s = isset($t["counts"][$it["state"]]) ? $it["state"] : "UNKNOWN";
    $t["counts"][$s]++;
    $t["units"]++;
  }
}

function drsm_meter_tile($id, $title, $icon, $about)
{
  return array("id" => $id, "title" => $title, "icon" => $icon, "about" => $about, "items" => array(), "state" => "",
               "units" => 0, "time" => 0, "counts" => drsm_meter_counts(), "pct" => null, "cells" => array());
}

// Hosts as one tile item, with the hosts that are not OK under it and
// every host as a heat map cell
function drsm_meter_hosts_item($title, $hosts, $href = "", $multi = false)
{
  $it = drsm_meter_item($title, "", $href);
  $c = drsm_meter_counts();
  $state = "OK";
  foreach($hosts as $hst) {
    $st = isset($c[$hst["state"]]) ? $hst["state"] : "UNKNOWN";
    $c[$st]++;
    $state = drsm_worst($state, $st);
    if($hst["time"] > $it["time"]) $it["time"] = $hst["time"];
    $u = drsm_host_url("readreport.php", $hst);
    if($st != "OK") $it["hosts"][] = array("name" => $hst["name"] . ($multi ? " (" . drsm_site_label($hst["site"]) . ")" : ""), "state" => $st, "href" => $u);
    $it["all"][] = array("t" => $hst["name"], "s" => $st, "h" => $u, "g" => $title);
  }
  usort($it["hosts"], function($a, $b) {
    $d = drsm_state_rank($b["state"]) - drsm_state_rank($a["state"]);
    return ($d != 0) ? $d : strcmp($a["name"], $b["name"]);
  });
  $it["counts"] = $c;
  if(count($hosts) > 0) $it["state"] = $state;
  else $it["note"] = "No hosts";
  if($it["href"] == "" && count($hosts) > 0) $it["href"] = drsm_url("hosts.php");
  return $it;
}

/*
Every Overview tile with its items, worst state, units, counts and
percent healthy. Each tile also gets its heat map cells: one per host
for host tiles, one per host and check for the check category tiles,
one per report for the others.
*/
function drsm_meter_tiles($hosts, $groupreports, $sites, $kinds = null)
{
  global $METERtiles;
  $multi = (count($sites) > 1);
  if($kinds === null) $kinds = $METERtiles;
  $out = array();
  foreach($kinds as $kind) {
    if($kind == "sites" && $multi) {
      $bysite = drsm_hosts_by_site($hosts, $sites);
      $t = drsm_meter_tile("sites", "Sites", "building", "Hosts at each site");
      foreach($sites as $sid => $s) {
        $it = drsm_meter_hosts_item($s["name"], $bysite[$sid], drsm_url("index.php", array("site" => $sid)));
        $sm = drsm_site_summary($s, $bysite[$sid]);
        if($sm["down"]) { $it["note"] = "Collector not reporting"; $it["state"] = drsm_worst($it["state"], "STALE"); }
        drsm_meter_add($t, $it);
        foreach($it["all"] as $c) { $c["g"] = $s["name"]; $t["cells"][] = $c; }
      }
      $out[] = $t;
    }
    else if($kind == "platforms") {
      $names = array("linux" => array("Linux hosts", "list", "Linux and Unix hosts"),
                     "windows" => array("Windows hosts", "windows", "Windows computers with the Windows Reporting Agent"),
                     "other" => array("Other devices", "net", "Network devices and other hosts"));
      $by = array();
      foreach($hosts as $k => $hst) $by[drsm_meter_platform($hst)][$k] = $hst;
      foreach($names as $p => $nm) {
        if(!isset($by[$p])) continue;
        $t = drsm_meter_tile("platform-{$p}", $nm[0], $nm[1], $nm[2]);
        // One item per tier, with its problem hosts
        $tiers = array();
        foreach($by[$p] as $k => $hst) $tiers[drsm_tier_id($hst["group"])][$k] = $hst;
        ksort($tiers);
        foreach($tiers as $tid => $th) {
          $it = drsm_meter_hosts_item(drsm_tier_label($tid) . " tier", $th, drsm_url("hosts.php", array("tier" => $tid)), $multi);
          drsm_meter_add($t, $it);
          foreach($it["all"] as $c) $t["cells"][] = $c;
        }
        $out[] = $t;
      }
    }
    else if($kind == "groupchecks" && count($groupreports) > 0) {
      $t = drsm_meter_tile("groupchecks", "Group checks", "net", "Connectivity and health checks run for each group");
      foreach($groupreports as $gr) {
        $label = ($gr["kind"] == "check") ? "Connectivity" : "Health checks";
        $sitearg = ($gr["site"] != DRSM_LEGACY_SITE) ? array("site" => $gr["site"]) : array();
        $url = ($gr["kind"] == "check") ? drsm_url("checks.php", ($gr["group"] == "production" ? array() : array("g" => $gr["group"])) + $sitearg)
                                        : drsm_url("checks.php", array("r" => "health", "g" => $gr["group"]) + $sitearg);
        $title = $label . ($multi ? ", " . drsm_site_label($gr["site"]) : "") . ", " . ucfirst($gr["group"]);
        $it = drsm_meter_item($title, $gr["state"], $url, $gr["exists"] ? "" : "Not posted", $gr["exists"] ? $gr["time"] : 0);
        drsm_meter_add($t, $it);
        $t["cells"][] = array("t" => $title, "s" => $gr["state"], "h" => $url, "g" => "");
      }
      $out[] = $t;
    }
    else if($kind == "clusters") {
      $clusters = drsm_clusters($hosts);
      if(count($clusters) == 0) continue;
      $t = drsm_meter_tile("clusters", "Clusters", "link", "DRCM clusters: nodes, keep alive links, resources and CM status");
      $cols = array("nodes" => "Nodes", "links" => "Keep alive links", "drops" => "Keep alive drops 24 h", "resources" => "Resources", "cm" => "CM status");
      foreach($clusters as $cn => $cl) {
        $cs = drsm_cluster_summary($cl);
        $curl = drsm_url("clusters.php", array("c" => $cn));
        $it = drsm_meter_item($cn, "", $curl);
        $it["counts"] = drsm_meter_counts();
        foreach($cols as $k => $label) {
          $st = isset($it["counts"][$cs[$k][0]]) ? $cs[$k][0] : "UNKNOWN";
          $it["counts"][$st]++;
          $it["state"] = ($it["state"] == "") ? $st : drsm_worst($it["state"], $st);
          if($st != "OK") $it["hosts"][] = array("name" => "{$label}: {$cs[$k][1]}", "state" => $st, "href" => $curl);
          $t["cells"][] = array("t" => "{$cn} {$label}: {$cs[$k][1]}", "s" => $st, "h" => $curl, "g" => $cn);
        }
        drsm_meter_add($t, $it);
      }
      $out[] = $t;
    }
    else if($kind == "ext" && drsm_ext_enabled()) {
      foreach(drsm_ext_sections() as $sid => $sec) {
        $t = drsm_meter_tile("ext-{$sid}", $sec["title"], "file", "Other script reports");
        foreach($sec["items"] as $ei) {
          $st = drsm_ext_state($ei);
          $href = drsm_ext_href($ei);
          if($href == "") $href = drsm_url("extreports.php", array("s" => $sid));
          drsm_meter_add($t, drsm_meter_item($ei["title"], $st["state"], $href, $st["note"], $st["time"]));
          if($st["state"] != "") $t["cells"][] = array("t" => $ei["title"], "s" => $st["state"], "h" => $href, "g" => "");
        }
        $out[] = $t;
      }
    }
    else if($kind == "checks") {
      // One tile per check category, one item per plugin
      $cats = array();
      foreach($hosts as $hst) {
        foreach($hst["plugins"] as $id => $p) $cats[drsm_meter_category($id)][$id][] = $hst;
      }
      ksort($cats);
      // The Clusters tile already shows the cluster checks
      if(in_array("clusters", $kinds) && isset($cats["cluster"]) && count(drsm_clusters($hosts)) > 0) unset($cats["cluster"]);
      foreach($cats as $cat => $plugins) {
        ksort($plugins);
        $t = drsm_meter_tile("cat-" . preg_replace('/[^a-z0-9_-]/i', "-", $cat), drsm_meter_category_label($cat), drsm_meter_category_icon($cat), "Plugin checks in " . $cat . "/");
        foreach($plugins as $id => $hl) {
          $it = drsm_meter_item($id, "", drsm_url("heatmap.php") . "#" . $t["id"]);
          $it["counts"] = drsm_meter_counts();
          foreach($hl as $hst) {
            $p = $hst["plugins"][$id];
            $st = isset($it["counts"][$p["state"]]) ? $p["state"] : "UNKNOWN";
            // A check on a host that stopped reporting is not current
            if($hst["stale"] && $st == "OK") $st = "STALE";
            $it["counts"][$st]++;
            $it["state"] = ($it["state"] == "") ? $st : drsm_worst($it["state"], $st);
            if($hst["time"] > $it["time"]) $it["time"] = $hst["time"];
            $u = drsm_host_url("readreport.php", $hst) . "#" . drsm_plugin_anchor($id);
            $tip = count($p["msgs"]) ? " - " . implode(" | ", array_slice($p["msgs"], 0, 3)) : "";
            if($st != "OK") $it["hosts"][] = array("name" => $hst["name"] . ($multi ? " (" . drsm_site_label($hst["site"]) . ")" : ""), "state" => $st, "href" => $u);
            $t["cells"][] = array("t" => $hst["name"] . " " . $id . $tip, "s" => $st, "h" => $u, "g" => $hst["name"]);
          }
          drsm_meter_add($t, $it);
        }
        $out[] = $t;
      }
    }
  }
  foreach($out as $i => $t) {
    $out[$i]["pct"] = ($t["units"] > 0) ? (int)floor(100 * $t["counts"]["OK"] / $t["units"]) : null;
  }
  return $out;
}

/*
Site tiles for an Overview of more than one site: one tile per site,
with its hosts and group checks in the ring. Its list has a link to
the site's own Overview, then the site's tiles (Linux hosts, group
checks, check categories and so on), each opening that tile on the
site's page.
*/
function drsm_meter_site_tiles($hosts, $sites)
{
  global $METERtiles;
  $bysite = drsm_hosts_by_site($hosts, $sites);
  $kinds = array_values(array_diff($METERtiles, array("sites")));
  $out = array();
  foreach($sites as $sid => $s) {
    $sh = $bysite[$sid];
    $sg = drsm_site_group_reports($sid);
    $surl = drsm_url("index.php", array("site" => $sid));
    $about = implode(", ", array_filter(array($s["orgname"], $s["location"]), "strlen"));
    $t = drsm_meter_tile("site-" . preg_replace('/[^A-Za-z0-9_-]/', "-", $sid), $s["name"], "building", $about);
    $t["href"] = $surl;
    $t["hostcount"] = count($sh);
    $t["checkcount"] = count($sg);
    // The ring: every host and every group check of the site
    $hi = drsm_meter_hosts_item("Hosts", $sh, $surl);
    $sm = drsm_site_summary($s, $sh);
    if(count($sh) > 0) {
      foreach($hi["counts"] as $st => $n) { $t["counts"][$st] += $n; $t["units"] += $n; }
      $t["state"] = $hi["state"];
      $t["time"] = $hi["time"];
    }
    foreach($sg as $gr) {
      $st = isset($t["counts"][$gr["state"]]) ? $gr["state"] : "UNKNOWN";
      $t["counts"][$st]++;
      $t["units"]++;
      $t["state"] = ($t["state"] == "") ? $st : drsm_worst($t["state"], $st);
    }
    if($sm["down"]) $t["state"] = ($t["state"] == "") ? "STALE" : drsm_worst($t["state"], "STALE");
    // The list: open the site, then its own tiles
    $open = drsm_meter_item("Open the " . $s["name"] . " status page", "", $surl, $sm["down"] ? "Collector not reporting" : "");
    $t["items"][] = $open;
    foreach(drsm_meter_tiles($sh, $sg, array($sid => $s), $kinds) as $st) {
      $it = drsm_meter_item($st["title"], $st["state"], $surl . "#tile-" . $st["id"]);
      $it["counts"] = $st["counts"];
      foreach($st["items"] as $sub) {
        foreach($sub["hosts"] as $hh) {
          // Check category lists name the check with the host
          if(substr($st["id"], 0, 4) == "cat-") $hh["name"] .= " " . drsm_plugin_short($sub["title"]);
          $it["hosts"][] = $hh;
        }
        if(count($sub["counts"]) == 0 && $sub["state"] != "" && $sub["state"] != "OK") $it["hosts"][] = array("name" => $sub["title"], "state" => $sub["state"], "href" => $sub["href"]);
      }
      $t["items"][] = $it;
    }
    $t["pct"] = ($t["units"] > 0) ? (int)floor(100 * $t["counts"]["OK"] / $t["units"]) : null;
    $out[] = $t;
  }
  return $out;
}

/*
Ring segments: each state gets its share of the ring, so one error out
of 60 reports is a thin red slice, not a red ring. A state that is not
OK gets at least a small visible slice. SVG circles with class
"seg ok|warn|stale|err|unk" in a box of $box units.
*/
function drsm_ring_segments($counts, $r, $box = 80)
{
  $c = 2 * M_PI * $r;
  $mid = $box / 2;
  $total = 0;
  foreach(array("OK", "WARNING", "STALE", "ERROR", "UNKNOWN") as $s) $total += isset($counts[$s]) ? (int)$counts[$s] : 0;
  if($total == 0) return "";
  $order = array("OK" => "ok", "WARNING" => "warn", "STALE" => "stale", "UNKNOWN" => "unk", "ERROR" => "err");
  $len = array();
  foreach($order as $s => $cls) {
    $n = isset($counts[$s]) ? (int)$counts[$s] : 0;
    if($n == 0) continue;
    $len[$s] = $c * $n / $total;
    if($s != "OK") $len[$s] = max($len[$s], $c * 0.035);
  }
  // Take the minimum slices back from the OK part
  $sum = array_sum($len);
  if($sum > $c && isset($len["OK"])) $len["OK"] = max(0, $len["OK"] - ($sum - $c));
  $gap = (count($len) > 1) ? 1.2 : 0;
  $out = "";
  $off = 0;
  foreach($order as $s => $cls) {
    if(!isset($len[$s]) || $len[$s] <= 0) continue;
    $l = max(0.5, $len[$s] - $gap);
    $out .= "<circle class=\"seg {$cls}\" cx=\"{$mid}\" cy=\"{$mid}\" r=\"{$r}\" stroke-dasharray=\"" . round($l, 2) . " " . round($c, 2)
      . "\" stroke-dashoffset=\"" . round(-$off, 2) . "\" transform=\"rotate(-90 {$mid} {$mid})\"/>";
    $off += $len[$s];
  }
  return $out;
}

// Health meter: percent of OK reports inside a ring of state slices
function drsm_meter_gauge($pct, $state, $size = 84, $counts = array())
{
  $cls = ($state == "") ? "none" : drsm_state_class($state);
  $v = ($pct === null) ? 0 : max(0, min(100, $pct));
  $label = ($pct === null) ? "&ndash;" : ((int)$v . "<small>%</small>");
  return "<span class=\"m-gauge {$cls}\" style=\"width:{$size}px;height:{$size}px\" role=\"img\" aria-label=\"" . (($pct === null) ? "No data" : "{$v} percent healthy") . "\">"
    . "<svg viewBox=\"0 0 80 80\" aria-hidden=\"true\"><circle class=\"m-track\" cx=\"40\" cy=\"40\" r=\"34\"/>"
    . drsm_ring_segments($counts, 34) . "</svg>"
    . "<span class=\"m-val\">{$label}</span></span>";
}

// Resource meter for a host: a ring filled to the percent used
function drsm_meter_use($mt, $col, $key)
{
  $pct = max(0, min(100, $mt["pct"]));
  $text = ($key == "load") ? round($mt["pct"]) . "%" : $mt["text"];
  return "<span class=\"m-use h" . drsm_heat_level($mt["pct"]) . "\" title=\"" . h($col["title"] . " " . $text . (isset($mt["detail"]) && $mt["detail"] != "" ? " (" . $mt["detail"] . ")" : "")) . "\">"
    . "<svg viewBox=\"0 0 36 36\" aria-hidden=\"true\"><circle class=\"g-track\" cx=\"18\" cy=\"18\" r=\"15.9\"/><circle class=\"g-fill\" cx=\"18\" cy=\"18\" r=\"15.9\" stroke-dasharray=\"" . round($pct, 1) . " 100\"/></svg>"
    . "<span class=\"m-use-v\">" . h($text) . "</span><span class=\"m-use-l\">" . h($col["label"]) . "</span></span>";
}

// Solid red only when $METERsolidRed or more of a tile is in error
function drsm_meter_minor($t)
{
  global $METERsolidRed;
  $e = isset($t["counts"]["ERROR"]) ? (int)$t["counts"]["ERROR"] : 0;
  return $e > 0 && $t["units"] > 0 && $e / $t["units"] < $METERsolidRed;
}

// Counts as colored dots and numbers
function drsm_meter_counts_html($c)
{
  $out = "";
  foreach(array("ERROR" => "err", "WARNING" => "warn", "STALE" => "stale", "UNKNOWN" => "unk", "OK" => "ok") as $s => $cls) {
    if(!empty($c[$s])) $out .= "<span class=\"cnt {$cls}\" title=\"" . h(drsm_state_label($s)) . "\"><i></i>" . (int)$c[$s] . "</span>";
  }
  return $out;
}

// Units word for a tile
function drsm_meter_units_word($t)
{
  if(substr($t["id"], 0, 9) == "platform-" || $t["id"] == "sites") return ($t["units"] == 1) ? "host" : "hosts";
  if(substr($t["id"], 0, 4) == "cat-" || $t["id"] == "clusters") return ($t["units"] == 1) ? "check" : "checks";
  return ($t["units"] == 1) ? "report" : "reports";
}

// The tiles grid of the Overview
function drsm_meter_tiles_html($tiles)
{
  ob_start(); ?>
<section class="m-tiles" aria-label="Report groups">
<?php foreach($tiles as $t) {
        $cls = ($t["state"] == "") ? "none" : drsm_state_class($t["state"]);
        if(drsm_meter_minor($t)) $cls .= " minor"; ?>
  <details class="m-tile <?php echo h($cls); ?>" id="tile-<?php echo h($t["id"]); ?>" data-menu>
    <summary title="<?php echo h($t["about"]); ?>">
      <span class="t-head"><?php echo drsm_icon($t["icon"]); ?><span class="t-title"><?php echo h($t["title"]); ?></span><?php echo drsm_icon("chevron"); ?></span>
      <span class="t-body">
        <?php echo drsm_meter_gauge($t["pct"], $t["state"], 84, $t["counts"]); ?>
        <span class="t-sum">
          <?php if($t["state"] != "") { echo drsm_badge($t["state"]); } else { ?><span class="badge unk"><span class="dot"></span>No reports</span><?php } ?>
          <span class="t-counts"><?php echo drsm_meter_counts_html($t["counts"]); ?></span>
<?php     if(isset($t["hostcount"])) { ?>
          <span class="muted small"><?php echo (int)$t["hostcount"] . " host" . ($t["hostcount"] == 1 ? "" : "s") . ", " . (int)$t["checkcount"] . " group check" . ($t["checkcount"] == 1 ? "" : "s") . ($t["time"] > 0 ? " &middot; " . drsm_time_html($t["time"]) : ""); ?></span>
<?php       if($t["about"] != "") { ?><span class="muted small"><?php echo h($t["about"]); ?></span><?php } ?>
<?php     } else { ?>
          <span class="muted small"><?php echo ($t["units"] > 0) ? (int)$t["units"] . " " . drsm_meter_units_word($t) . ($t["time"] > 0 ? " &middot; " . drsm_time_html($t["time"]) : "") : h($t["about"]); ?></span>
<?php     } ?>
        </span>
      </span>
    </summary>
    <div class="menu-panel t-panel">
      <p class="menu-head"><?php echo h($t["title"]); ?></p>
      <ul class="t-items">
<?php   foreach($t["items"] as $it) { ?>
        <li class="<?php echo h(($it["state"] == "") ? "link" : drsm_state_class($it["state"])); ?>">
          <a href="<?php echo h($it["href"] != "" ? $it["href"] : "#"); ?>">
            <span class="t-it"><?php echo h($it["title"]); ?>
<?php     if(count($it["counts"]) > 0) { ?>
              <span class="t-counts small"><?php echo drsm_meter_counts_html($it["counts"]); ?></span>
<?php     } ?>
<?php     if($it["note"] != "") { ?><span class="muted small"><?php echo h($it["note"]); ?></span><?php } ?>
            </span>
            <?php echo ($it["state"] != "") ? drsm_badge($it["state"]) : drsm_icon("external"); ?>
          </a>
<?php     if(count($it["hosts"]) > 0) { ?>
          <ul class="t-hosts">
<?php       foreach(array_slice($it["hosts"], 0, 8) as $hst) { ?>
            <li class="<?php echo h(drsm_state_class($hst["state"])); ?>"><a href="<?php echo h($hst["href"]); ?>"><i></i><?php echo h($hst["name"]); ?><span class="muted"><?php echo h(drsm_state_label($hst["state"])); ?></span></a></li>
<?php       } ?>
<?php       if(count($it["hosts"]) > 8) { ?>
            <li class="more"><a href="<?php echo h($it["href"]); ?>"><?php echo count($it["hosts"]) - 8; ?> more</a></li>
<?php       } ?>
          </ul>
<?php     } ?>
        </li>
<?php   } ?>
      </ul>
    </div>
  </details>
<?php } ?>
</section>
<?php
  return ob_get_clean();
}

// Banner tone with the solid red rule: red only when a tile is mostly
// in error, amber when any tile needs attention. array(state, tiles
// that need attention)
function drsm_meter_overall($tiles)
{
  $state = "OK";
  $bad = 0;
  foreach($tiles as $t) {
    if($t["state"] == "" || $t["state"] == "OK") continue;
    $bad++;
    $tone = ($t["state"] == "ERROR" && !drsm_meter_minor($t)) ? "ERROR" : "WARNING";
    $state = drsm_worst($state, $tone);
  }
  return array($state, $bad);
}

// SCRIPT CONTENT ENDS ABOVE.
// ----------------------------------------------------------- //
// ------------------------------- //
// --------- End of File --------- //
// ------------------------------- //
?>
