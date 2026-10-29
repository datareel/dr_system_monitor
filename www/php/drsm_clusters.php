<?php
// ------------------------------- //
// -------- Start of File -------- //
// ------------------------------- //
// ----------------------------------------------------------- //
// PHP Source Code File
// PHP Version: 7.2 or higher, tested with PHP 8
// Original Author(s): DataReel Software Development
// File Creation Date: 10/28/2026
// Date Last Modified: 10/28/2026
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

DRCM clusters for the Clusters page, the host cards and the top bar.
The cluster/drcm plugin runs on every cluster node and prints
"DRCM kind|field|..." lines in its report section: cluster, self,
node, resource, link, health, strip (keep alive timeline) and event.
Each node is a "reporter" with its own view of the cluster.
*/
// ----------------------------------------------------------- //
// SCRIPT CONTENT STARTS BELOW.

define("DRSM_CLUSTER_PLUGIN", "cluster/drcm");

// Keep alive strip letters: label and CSS class
function drsm_cluster_strip_kinds()
{
  return array(
    "o" => array("label" => "Keep alives answered", "cls" => "s-ok"),
    "m" => array("label" => "Missed keep alives", "cls" => "s-miss"),
    "d" => array("label" => "Peer down", "cls" => "s-down"),
    "s" => array("label" => "This node in standby", "cls" => "s-stby"),
    "i" => array("label" => "This node isolated", "cls" => "s-iso"),
    "." => array("label" => "Nothing logged", "cls" => "s-none")
  );
}

/*
A host's cluster/drcm section, or null. Returns name, self, nodes
(name => host, state, ip), resources (type, nick, owner, state,
start), links (peer => OK or FAIL), health, strips (peer => start,
step, map), events (t, kind, text), text (the report lines for people)
and state.
*/
function drsm_cluster_parse($host)
{
  if(!isset($host["report"]["sections"])) return null;
  foreach($host["report"]["sections"] as $s) {
    if($s["id"] != DRSM_CLUSTER_PLUGIN) continue;
    $c = array("name" => "", "self" => "", "nodes" => array(), "resources" => array(), "links" => array(),
               "health" => "", "strips" => array(), "events" => array(), "text" => array(),
               "state" => $s["state"], "host" => $host);
    foreach($s["lines"] as $line) {
      if(!preg_match('/^DRCM ([a-z]+)\|(.*)$/', $line, $m)) {
        if(strpos($line, "METRIC ") !== 0 && strpos($line, "DETAIL ") !== 0) $c["text"][] = $line;
        continue;
      }
      $f = explode("|", $m[2]);
      switch($m[1]) {
      case "cluster": $c["name"] = $f[0]; break;
      case "self": $c["self"] = $f[0]; break;
      case "health": $c["health"] = $f[0]; break;
      case "node":
        if(count($f) >= 4) $c["nodes"][$f[0]] = array("host" => $f[1], "state" => $f[2], "ip" => $f[3]);
        break;
      case "resource":
        if(count($f) >= 4) $c["resources"][] = array("type" => $f[0], "nick" => $f[1], "owner" => $f[2], "state" => $f[3], "start" => isset($f[4]) ? $f[4] : "");
        break;
      case "link":
        if(count($f) >= 2) $c["links"][$f[0]] = $f[1];
        break;
      case "strip":
        if(count($f) >= 4 && ctype_digit($f[1]) && ctype_digit($f[2]) && (int)$f[2] > 0) {
          $c["strips"][$f[0]] = array("start" => drsm_demo_time((int)$f[1]), "step" => (int)$f[2], "map" => preg_replace('/[^omdsi.]/', ".", $f[3]));
        }
        break;
      case "event":
        if(count($f) >= 3 && ctype_digit($f[0])) $c["events"][] = array("t" => drsm_demo_time((int)$f[0]), "kind" => $f[1], "text" => implode("|", array_slice($f, 2)));
        break;
      }
    }
    if($c["name"] == "") $c["name"] = "cluster";
    if($host["stale"]) $c["state"] = drsm_worst($c["state"], "STALE");
    return $c;
  }
  return null;
}

/*
Clusters in a list of hosts, by name. Each has name, state, reporters
(host key => parsed section), nodes (merged: host, ip, state, views
from each reporter, the DRSM host that runs on it) and the resources
seen by any reporter.
*/
function drsm_clusters($hosts)
{
  $out = array();
  foreach($hosts as $key => $hst) {
    $c = drsm_cluster_parse($hst);
    if($c === null) continue;
    $n = $c["name"];
    if(!isset($out[$n])) $out[$n] = array("name" => $n, "state" => "OK", "reporters" => array(), "nodes" => array());
    $out[$n]["reporters"][$key] = $c;
    $out[$n]["state"] = drsm_worst($out[$n]["state"], $c["state"]);
  }
  foreach($out as $n => $cl) {
    $nodes = array();
    foreach($cl["reporters"] as $key => $c) {
      foreach($c["nodes"] as $name => $nd) {
        if(!isset($nodes[$name])) $nodes[$name] = array("name" => $name, "host" => $nd["host"], "ip" => $nd["ip"], "views" => array(), "drsm" => null, "state" => "");
        $nodes[$name]["views"][$key] = $nd["state"];
      }
      if($c["self"] != "" && isset($nodes[$c["self"]])) $nodes[$c["self"]]["drsm"] = $c["host"];
    }
    foreach($nodes as $name => $nd) {
      // Down when any node sees it down, Up when every view is Up
      $st = "Unknown";
      $vals = array_values($nd["views"]);
      if(in_array("Down", $vals)) $st = "Down";
      else if(in_array("Standby", $vals)) $st = "Standby";
      else if(in_array("Releasing", $vals)) $st = "Releasing";
      else if(count($vals) > 0 && count(array_unique($vals)) == 1 && $vals[0] == "Up") $st = "Up";
      $nodes[$name]["state"] = $st;
    }
    $out[$n]["nodes"] = $nodes;
  }
  ksort($out);
  return $out;
}

// State of one direction of a cluster link: the TCP check, then the
// newest strip steps (the last 30 minutes)
function drsm_cluster_link_state($c, $peer)
{
  $link = isset($c["links"][$peer]) ? $c["links"][$peer] : "";
  if($link == "FAIL") return "ERROR";
  if(!isset($c["strips"][$peer])) return ($link == "OK") ? "OK" : "UNKNOWN";
  $s = $c["strips"][$peer];
  $recent = substr($s["map"], -max(1, (int)(1800 / $s["step"])));
  if(strpos($recent, "d") !== false || strpos($recent, "i") !== false) return "ERROR";
  if(strpos($recent, "m") !== false) return "WARNING";
  if(strpos($recent, "o") !== false) return "OK";
  return "UNKNOWN";
}

// Steps of a strip that were not answered keep alives
function drsm_cluster_strip_bad($s)
{
  return substr_count($s["map"], "m") + substr_count($s["map"], "d") + substr_count($s["map"], "i");
}

/*
Node and link diagram as inline SVG. One box per node, colored by
state and linked to its host report; between each pair one line per
direction that a node reports, colored by drsm_cluster_link_state().
*/
function drsm_cluster_diagram($cl)
{
  $nodes = array_values($cl["nodes"]);
  $n = count($nodes);
  if($n == 0) return "";
  $bw = 250; $bh = 100;
  if($n <= 3) {
    $W = max(560, $n * ($bw + 170));
    $H = $bh + 64;
    $pos = array();
    for($i = 0; $i < $n; $i++) $pos[] = array(($i + 0.5) * $W / $n, $H / 2);
  }
  else {
    $W = 760; $H = 520;
    $r = 190;
    $pos = array();
    for($i = 0; $i < $n; $i++) {
      $a = -M_PI / 2 + 2 * M_PI * $i / $n;
      $pos[] = array($W / 2 + $r * 1.35 * cos($a), $H / 2 + $r * sin($a));
    }
  }
  $idx = array();
  foreach($nodes as $i => $nd) $idx[$nd["name"]] = $i;

  $svg = "<svg class=\"cl-svg\" viewBox=\"0 0 " . (int)$W . " " . (int)$H . "\" role=\"img\" aria-label=\"" . h($cl["name"] . " cluster nodes and keep alive links") . "\">";
  $svg .= "<defs><marker id=\"cl-arrow\" viewBox=\"0 0 10 10\" refX=\"9\" refY=\"5\" markerWidth=\"7\" markerHeight=\"7\" orient=\"auto-start-reverse\"><path d=\"M0 0L10 5L0 10z\" fill=\"context-stroke\"/></marker></defs>";

  // Links: reporter (the node it runs on) to each peer in its strips
  $lines = "";
  foreach($cl["reporters"] as $c) {
    if($c["self"] == "" || !isset($idx[$c["self"]])) continue;
    $peers = array_unique(array_merge(array_keys($c["strips"]), array_keys($c["links"])));
    foreach($peers as $peer) {
      if(!isset($idx[$peer])) continue;
      $a = $pos[$idx[$c["self"]]];
      $b = $pos[$idx[$peer]];
      $dx = $b[0] - $a[0]; $dy = $b[1] - $a[1];
      $len = sqrt($dx * $dx + $dy * $dy);
      if($len < 1) continue;
      $ux = $dx / $len; $uy = $dy / $len;
      // Each direction on its own side of the center line
      $ox = -$uy * 9; $oy = $ux * 9;
      // Leave the boxes: clip to the box edge along the line
      $tx = ($ux != 0) ? ($bw / 2 + 8) / abs($ux) : 1e9;
      $ty = ($uy != 0) ? ($bh / 2 + 8) / abs($uy) : 1e9;
      $cut = min($tx, $ty);
      $x1 = $a[0] + $ux * $cut + $ox; $y1 = $a[1] + $uy * $cut + $oy;
      $x2 = $b[0] - $ux * $cut + $ox; $y2 = $b[1] - $uy * $cut + $oy;
      $st = drsm_cluster_link_state($c, $peer);
      $bad = isset($c["strips"][$peer]) ? drsm_cluster_strip_bad($c["strips"][$peer]) : 0;
      $tip = $c["self"] . " to " . $peer . ": " . drsm_state_label($st) . (isset($c["links"][$peer]) ? ", TCP link " . $c["links"][$peer] : "") . ", " . $bad . " dropout steps in the strip";
      $lines .= "<line class=\"cl-link " . h(drsm_state_class($st)) . "\" x1=\"" . round($x1, 1) . "\" y1=\"" . round($y1, 1) . "\" x2=\"" . round($x2, 1) . "\" y2=\"" . round($y2, 1) . "\" marker-end=\"url(#cl-arrow)\"><title>" . h($tip) . "</title></line>";
      $lx = ($x1 + $x2) / 2 + $ox * 1.4; $ly = ($y1 + $y2) / 2 + $oy * 1.4 + 4;
      $lines .= "<text class=\"cl-ltext\" x=\"" . round($lx, 1) . "\" y=\"" . round($ly, 1) . "\" text-anchor=\"middle\">" . h($bad > 0 ? $bad . " drops" : drsm_state_label($st)) . "</text>";
    }
  }
  $svg .= $lines;

  foreach($nodes as $i => $nd) {
    $x = $pos[$i][0] - $bw / 2; $y = $pos[$i][1] - $bh / 2;
    $st = drsm_cluster_node_state($nd["state"]);
    $owned = 0;
    foreach($cl["reporters"] as $c) {
      foreach($c["resources"] as $r) if($r["owner"] == $nd["host"]) $owned++;
      break;
    }
    $sub = $nd["drsm"] !== null ? "DRSM host " . $nd["drsm"]["name"] : "no DRSM report";
    $g = "<g class=\"cl-node " . h(drsm_state_class($st)) . "\">";
    $g .= "<title>" . h($nd["name"] . " (" . $nd["host"] . ", " . $nd["ip"] . "): " . $nd["state"]) . "</title>";
    $g .= "<rect x=\"" . round($x, 1) . "\" y=\"" . round($y, 1) . "\" width=\"{$bw}\" height=\"{$bh}\" rx=\"12\"/>";
    $g .= "<circle cx=\"" . round($x + 18, 1) . "\" cy=\"" . round($y + 22, 1) . "\" r=\"5\"/>";
    $g .= "<text class=\"cl-name\" x=\"" . round($x + 30, 1) . "\" y=\"" . round($y + 27, 1) . "\">" . h($nd["name"]) . "</text>";
    $hn = strlen($nd["host"]) > 36 ? substr($nd["host"], 0, 35) . "..." : $nd["host"];
    $g .= "<text class=\"cl-sub\" x=\"" . round($x + 14, 1) . "\" y=\"" . round($y + 48, 1) . "\">" . h($hn) . "</text>";
    $g .= "<text class=\"cl-sub\" x=\"" . round($x + 14, 1) . "\" y=\"" . round($y + 68, 1) . "\">" . h($nd["state"] . ", " . $owned . " resource" . ($owned == 1 ? "" : "s") . " running") . "</text>";
    $g .= "<text class=\"cl-sub\" x=\"" . round($x + 14, 1) . "\" y=\"" . round($y + 87, 1) . "\">" . h($sub) . "</text>";
    $g .= "</g>";
    if($nd["drsm"] !== null) $g = "<a href=\"" . h(drsm_host_url("readreport.php", $nd["drsm"], array(), drsm_plugin_anchor(DRSM_CLUSTER_PLUGIN))) . "\">{$g}</a>";
    $svg .= $g;
  }
  $svg .= "</svg>";
  return $svg;
}

/*
Keep alive strip as inline SVG: one bar per run of equal steps, with
the times and meaning in its tooltip, and hour marks below.
*/
function drsm_cluster_strip_svg($s, $label)
{
  $kinds = drsm_cluster_strip_kinds();
  $map = $s["map"];
  $nb = strlen($map);
  if($nb == 0) return "";
  $W = 1200; $L = 0; $H = 34; $bh = 18;
  $from = $s["start"];
  $to = $from + $nb * $s["step"];
  $x = function($t) use ($from, $to, $W) { return ($t - $from) / ($to - $from) * $W; };
  $svg = "<svg class=\"cl-strip\" viewBox=\"0 0 {$W} {$H}\" preserveAspectRatio=\"none\" role=\"img\" aria-label=\"" . h($label) . "\">";
  $i = 0;
  while($i < $nb) {
    $c = $map[$i];
    $j = $i;
    while($j + 1 < $nb && $map[$j + 1] == $c) $j++;
    $t0 = $from + $i * $s["step"];
    $t1 = $from + ($j + 1) * $s["step"];
    $tip = date("M j g:i A", $t0) . " to " . date("g:i A", $t1) . ": " . $kinds[$c]["label"];
    $svg .= "<rect class=\"" . $kinds[$c]["cls"] . "\" x=\"" . round($x($t0), 2) . "\" y=\"0\" width=\"" . max(0.6, round($x($t1) - $x($t0), 2)) . "\" height=\"{$bh}\"><title>" . h($tip) . "</title></rect>";
    $i = $j + 1;
  }
  // Marks every 3 hours (6 for longer strips)
  $every = ($to - $from > 2 * 86400) ? 6 * 3600 : 3 * 3600;
  for($t = (int)(ceil($from / $every) * $every); $t <= $to; $t += $every) {
    $xx = round($x($t), 1);
    $anchor = ($xx < 30) ? "start" : (($xx > $W - 30) ? "end" : "middle");
    $svg .= "<line class=\"tick\" x1=\"{$xx}\" x2=\"{$xx}\" y1=\"{$bh}\" y2=\"" . ($bh + 4) . "\"/>";
    $svg .= "<text class=\"ax\" x=\"{$xx}\" y=\"" . ($H - 2) . "\" text-anchor=\"{$anchor}\">" . h(date("g A", $t)) . "</text>";
  }
  $svg .= "</svg>";
  return $svg;
}

// Report lines as HTML, styled by level as on the host page
/*
Status of one cluster for the overview and the heat map. Each part is
array(state, text, tip): nodes (Up count), links (keep alive links,
worst direction), resources (split, on backup, normal), drops (missed
keep alives in the last 24 hours) and cm (each node's CM status).
*/
function drsm_cluster_summary($cl)
{
  $now = time();
  $up = 0; $sby = 0; $nst = "";
  $tips = array();
  foreach($cl["nodes"] as $nd) {
    if($nd["state"] == "Up") $up++;
    if($nd["state"] == "Standby" || $nd["state"] == "Releasing") $sby++;
    $s = drsm_cluster_node_state($nd["state"]);
    $nst = ($nst == "") ? $s : drsm_worst($nst, $s);
    $tips[] = $nd["name"] . ": " . $nd["state"];
  }
  $n = count($cl["nodes"]);
  $out = array("state" => $cl["state"], "standby" => $sby);
  $out["nodes"] = array($nst == "" ? "UNKNOWN" : $nst, "{$up}/{$n} up" . ($sby > 0 ? ", {$sby} standby" : ""), implode(", ", $tips));

  $lst = ""; $tips = array();
  $drops = 0; $dtips = array();
  foreach($cl["reporters"] as $c) {
    $peers = array_unique(array_merge(array_keys($c["strips"]), array_keys($c["links"])));
    foreach($peers as $peer) {
      $st = drsm_cluster_link_state($c, $peer);
      $lst = ($lst == "") ? $st : drsm_worst($lst, $st);
      $tips[] = $c["self"] . " from " . $peer . ": " . drsm_state_label($st);
    }
    $mine = 0;
    foreach($c["events"] as $e) if($e["kind"] == "miss" && $e["t"] >= $now - 86400) $mine++;
    $drops += $mine;
    $dtips[] = $c["self"] . ": " . $mine . " missed";
  }
  $nl = count($tips);
  $out["links"] = array($lst == "" ? "UNKNOWN" : $lst, $nl . " link" . ($nl == 1 ? "" : "s"), implode(", ", $tips));
  $out["drops"] = array($drops > 0 ? "WARNING" : "OK", (string)$drops, "Missed keep alives in the last 24 hours, " . implode(", ", $dtips));

  $rst = "OK"; $nr = 0; $backup = 0; $split = 0;
  $owners = array();
  foreach($cl["reporters"] as $c) {
    foreach($c["resources"] as $r) $owners[$r["type"] . "|" . $r["nick"]][$r["owner"]] = $r["state"];
  }
  foreach($owners as $k => $o) {
    $nr++;
    if(count($o) > 1) $split++;
    else if(in_array("OK-Backup", $o)) $backup++;
  }
  if($split > 0) $rst = "ERROR"; else if($backup > 0) $rst = "WARNING"; else if($nr == 0) $rst = "UNKNOWN";
  $out["resources"] = array($rst, $split > 0 ? "{$split} split" : ($backup > 0 ? "{$backup} on " . ($sby > 0 ? "peer" : "backup") : (string)$nr),
                            $nr . " resource" . ($nr == 1 ? "" : "s") . ($split > 0 ? ", {$split} running on two nodes" : "") . ($backup > 0 ? ", {$backup} on a backup node" : ""));

  $cst = ""; $tips = array();
  foreach($cl["reporters"] as $c) {
    $cst = ($cst == "") ? $c["state"] : drsm_worst($cst, $c["state"]);
    $tips[] = $c["self"] . ": " . ($c["health"] != "" ? $c["health"] : "no CM status") . " (" . drsm_state_label($c["state"]) . ")";
  }
  $first = reset($cl["reporters"]);
  $out["cm"] = array($cst == "" ? "UNKNOWN" : $cst, ($first && $first["health"] != "") ? $first["health"] : "-", implode(", ", $tips));
  return $out;
}

// Dashboard state of a node state from cm_stat: Up, Standby or
// Releasing (DRCM 1.43, planned), Down, or Unknown
function drsm_cluster_node_state($s)
{
  if($s == "Up") return "OK";
  if($s == "Standby" || $s == "Releasing") return "WARNING";
  if($s == "Down") return "ERROR";
  return "UNKNOWN";
}

// Badge with its own words in place of the state name
function drsm_cluster_badge($state, $text)
{
  return "<span class=\"badge " . drsm_state_class($state) . "\"><span class=\"dot\"></span>" . h($text) . "</span>";
}

function drsm_cluster_lines_html($lines)
{
  $cls = array("ERROR" => "l-err", "WARNING" => "l-warn", "UNKNOWN" => "l-unk", "INFO" => "l-info");
  $out = "";
  foreach($lines as $line) {
    $lv = drsm_line_level($line);
    $out .= isset($cls[$lv]) ? "<span class=\"{$cls[$lv]}\">" . h($line) . "</span>\n" : h($line) . "\n";
  }
  return $out;
}

// True when any host in the visible sites runs cluster/drcm, from the
// small status.json files, for the top bar
function drsm_clusters_present()
{
  static $present = null;
  if($present !== null) return $present;
  $present = false;
  foreach(drsm_scope_sites(drsm_scope()) as $site => $s) {
    $files = glob(drsm_site_dir($site) . "/systems/*/status.json");
    if($files === false) continue;
    foreach($files as $f) {
      $json = @file_get_contents($f, false, null, 0, 65536);
      if($json !== false && strpos($json, "\"" . str_replace("/", "\\/", DRSM_CLUSTER_PLUGIN) . "\"") !== false) $present = true;
      if($json !== false && strpos($json, "\"" . DRSM_CLUSTER_PLUGIN . "\"") !== false) $present = true;
      if($present) return $present;
    }
  }
  return $present;
}

// SCRIPT CONTENT ENDS ABOVE.
// ----------------------------------------------------------- //
// ------------------------------- //
// --------- End of File --------- //
// ------------------------------- //
?>
