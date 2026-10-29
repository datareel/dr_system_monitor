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

DRSM clusters: the DRCM clusters the cluster/drcm plugin reports on,
which hosts are in each, a diagram of the nodes and their keep alive
links, the resources and their owners, a keep alive timeline for each
link, the missed keep alives over time from the metrics history, the
cluster log events and each node's CM status report.
*/
// ----------------------------------------------------------- //
// SCRIPT CONTENT STARTS BELOW.

require_once("../config/drsm.php");

// Our required includes
require_once("{$WWWdir}/php/query_post_validation.php");
require_once("{$WWWdir}/php/drsm_lib.php");
require_once("{$WWWdir}/php/trends_lib.php");

$ranges = array("7d" => array("label" => "7 days", "secs" => 7 * 86400, "bucket" => 3600),
                "30d" => array("label" => "30 days", "secs" => 30 * 86400, "bucket" => 6 * 3600),
                "90d" => array("label" => "90 days", "secs" => 90 * 86400, "bucket" => 86400));
$range = (isset($_GET['r']) && isset($ranges[$_GET['r']])) ? $_GET['r'] : "7d";
$hosts = drsm_load_hosts();
$clusters = drsm_clusters($hosts);
// A cluster is picked by its name, matched against the loaded list
$cname = "";
if(isset($_GET['c']) && isset($clusters[$_GET['c']])) $cname = $_GET['c'];
else if(count($clusters) > 0) $cname = array_keys($clusters)[0];

$overall = "OK";
foreach($clusters as $cl) $overall = drsm_worst($overall, $cl["state"]);
drsm_page_start("Clusters", "clusters", count($clusters) ? $overall : "");

/*
Keep alive history of one reporter from its metrics history: per time
bucket and peer, the keep alives answered and missed, and whether the
report saw a node down.
*/
function drsm_cluster_history($c, $since, $bucket)
{
  $out = array();
  $hst = $c["host"];
  $fname = drsm_history_path($hst["name"], $hst["site"]);
  if(!is_readable($fname)) return $out;
  $fh = @fopen($fname, "r");
  if($fh === false) return $out;
  $fsince = $since - (drsm_demo_time(1) - 1);
  drsm_history_seek($fh, $fsince);
  while(($line = fgets($fh)) !== false) {
    if(strpos($line, "drcm_") === false) continue;
    $parts = explode("\t", rtrim($line, "\r\n"));
    $t = drsm_demo_time((int)$parts[0]);
    if($t < $since) continue;
    $b = (int)(($t - $since) / $bucket);
    $down = 0;
    for($i = 1; $i < count($parts); $i++) {
      if(strpos($parts[$i], "drcm_") !== 0) continue;
      $eq = strrpos($parts[$i], "=");
      if($eq === false) continue;
      $label = "";
      $name = drsm_trend_key(substr($parts[$i], 0, $eq), $label);
      $v = (float)substr($parts[$i], $eq + 1);
      if($name == "drcm_nodes_down") $down = $v;
      if($label == "" || ($name != "drcm_keepalive_missed" && $name != "drcm_keepalive_ok")) continue;
      if(!isset($out[$label][$b])) $out[$label][$b] = array("ok" => 0, "miss" => 0, "down" => 0, "n" => 0);
      $out[$label][$b][$name == "drcm_keepalive_ok" ? "ok" : "miss"] += $v;
      if($name == "drcm_keepalive_ok") $out[$label][$b]["n"]++;
    }
    foreach($out as $peer => $bs) if(isset($bs[$b]) && $down > 0) $out[$peer][$b]["down"]++;
  }
  fclose($fh);
  return $out;
}

// Bar chart of missed keep alives per bucket, red where a report saw a
// node down or no keep alive was answered
function drsm_cluster_history_svg($bs, $since, $bucket, $nb, $label)
{
  $W = 1200; $H = 150; $L = 40; $R = 8; $T = 10; $B = 24;
  $pw = $W - $L - $R; $ph = $H - $T - $B;
  $max = 0;
  foreach($bs as $v) $max = max($max, $v["miss"]);
  $ymax = max(4, drsm_nice_ceil($max * 1.1));
  $bw = $pw / $nb;
  $svg = "<svg class=\"trend-svg cl-hist\" viewBox=\"0 0 {$W} {$H}\" role=\"img\" aria-label=\"" . h($label) . "\">";
  for($i = 0; $i <= 2; $i++) {
    $v = $ymax * $i / 2;
    $yy = round($T + $ph - $v / $ymax * $ph, 1);
    $svg .= "<line class=\"grid\" x1=\"{$L}\" x2=\"" . ($W - $R) . "\" y1=\"{$yy}\" y2=\"{$yy}\"/>";
    $svg .= "<text class=\"ax\" x=\"" . ($L - 6) . "\" y=\"" . ($yy + 4) . "\" text-anchor=\"end\">" . h((string)round($v)) . "</text>";
  }
  $fmt = "M j";
  for($i = 0; $i <= 4; $i++) {
    $t = $since + $nb * $bucket * $i / 4;
    $anchor = ($i == 0) ? "start" : (($i == 4) ? "end" : "middle");
    $svg .= "<text class=\"ax\" x=\"" . round($L + $pw * $i / 4, 1) . "\" y=\"" . ($H - 6) . "\" text-anchor=\"{$anchor}\">" . h(date($fmt, (int)$t)) . "</text>";
  }
  for($b = 0; $b < $nb; $b++) {
    $x0 = round($L + $b * $bw, 2);
    $w = max(0.8, round($bw - ($bw > 3 ? 1 : 0), 2));
    $t0 = $since + $b * $bucket;
    $when = date(($bucket < 86400) ? "M j g A" : "M j", $t0);
    if(!isset($bs[$b])) {
      $svg .= "<rect class=\"h-none\" x=\"{$x0}\" y=\"" . ($T + $ph - 2) . "\" width=\"{$w}\" height=\"2\"><title>" . h($when . ": no reports") . "</title></rect>";
      continue;
    }
    $v = $bs[$b];
    $tip = $when . ": " . (int)$v["miss"] . " missed, " . (int)$v["ok"] . " answered" . ($v["down"] > 0 ? ", node down in " . (int)$v["down"] . " reports" : "");
    if($v["down"] > 0 || ($v["ok"] == 0 && $v["n"] > 0)) {
      $svg .= "<rect class=\"h-down\" x=\"{$x0}\" y=\"{$T}\" width=\"{$w}\" height=\"{$ph}\"><title>" . h($tip) . "</title></rect>";
      continue;
    }
    $hh = round($v["miss"] / $ymax * $ph, 1);
    if($hh <= 0) {
      $svg .= "<rect class=\"h-ok\" x=\"{$x0}\" y=\"" . ($T + $ph - 3) . "\" width=\"{$w}\" height=\"3\"><title>" . h($tip) . "</title></rect>";
    }
    else {
      $svg .= "<rect class=\"h-miss\" x=\"{$x0}\" y=\"" . round($T + $ph - $hh, 1) . "\" width=\"{$w}\" height=\"" . max(1, $hh) . "\"><title>" . h($tip) . "</title></rect>";
    }
  }
  $svg .= "</svg>";
  return $svg;
}
?>
<section class="page-head">
  <div>
    <h1>Clusters</h1>
    <p class="muted">DataReel Cluster Manager (DRCM) clusters, as each node sees them</p>
  </div>
<?php if(count($clusters) > 1) { ?>
  <div class="head-actions">
    <div class="seg" role="group" aria-label="Cluster">
<?php foreach($clusters as $n => $cl) { ?>
      <a class="<?php echo $n == $cname ? "active" : ""; ?>" href="<?php echo h(drsm_url("clusters.php", array("c" => $n, "r" => $range))); ?>"><span class="dot" style="--tone: var(--<?php echo h(drsm_state_class($cl["state"])); ?>)"></span><?php echo h($n); ?></a>
<?php } ?>
    </div>
  </div>
<?php } ?>
</section>
<?php
if(count($clusters) == 0) {
?>
<section class="panel">
  <div class="empty">
    <?php echo drsm_icon("net"); ?>
    <p>No host reports a DRCM cluster yet.</p>
    <p class="muted">Add <code>cluster/drcm</code> to the <code>PLUGINS</code> of every cluster node in its host file; the cluster shows here after the next run.</p>
  </div>
</section>
<?php
  drsm_page_end();
  exit;
}

$cl = $clusters[$cname];
$now = time();
$reporters = $cl["reporters"];
$first = reset($reporters);
$nup = 0;
foreach($cl["nodes"] as $nd) if($nd["state"] == "Up") $nup++;
$events = array();
foreach($reporters as $key => $c) foreach($c["events"] as $e) { $e["by"] = $c; $events[] = $e; }
usort($events, function($a, $b) { return $b["t"] - $a["t"]; });
$drops = 0;
$day = $now - 86400;
foreach($events as $e) if($e["t"] >= $day && $e["kind"] == "miss") $drops++;
$failovers = 0;
foreach($events as $e) if($e["t"] >= $day && $e["kind"] == "event") $failovers++;
$backup = 0;
foreach($first["resources"] as $r) if($r["state"] == "OK-Backup") $backup++;
?>
<section class="kpis" aria-label="Summary">
  <div class="kpi <?php echo h(drsm_state_class($cl["state"])); ?>"><span class="kpi-label">Cluster</span><span class="kpi-value"><?php echo h(drsm_state_label($cl["state"])); ?></span><span class="kpi-sub"><?php echo h($first["health"] != "" ? $first["health"] : "no CM status"); ?></span></div>
  <div class="kpi <?php echo $nup == count($cl["nodes"]) ? "ok" : "err"; ?>"><span class="kpi-label">Nodes up</span><span class="kpi-value"><?php echo (int)$nup; ?> / <?php echo count($cl["nodes"]); ?></span><span class="kpi-sub"><?php echo count($reporters); ?> reporting to DRSM</span></div>
  <div class="kpi <?php echo $backup > 0 ? "warn" : "ok"; ?>"><span class="kpi-label">Resources</span><span class="kpi-value"><?php echo count($first["resources"]); ?></span><span class="kpi-sub"><?php echo $backup > 0 ? (int)$backup . " on backup nodes" : "all on their owners"; ?></span></div>
  <a class="kpi <?php echo $drops > 0 ? "warn" : "ok"; ?>" href="#cl-strips"><span class="kpi-label">Keep alive drops</span><span class="kpi-value"><?php echo (int)$drops; ?></span><span class="kpi-sub">missed, last 24 hours</span></a>
  <a class="kpi <?php echo $failovers > 0 ? "warn" : "ok"; ?>" href="#cl-events"><span class="kpi-label">Failover events</span><span class="kpi-value"><?php echo (int)$failovers; ?></span><span class="kpi-sub">last 24 hours</span></a>
</section>

<section class="panel">
  <div class="panel-head"><h2><?php echo drsm_icon("net"); ?><?php echo h($cl["name"]); ?></h2><span class="muted small">Arrows are the keep alives each node logs from its peers. Select a node for its host report.</span></div>
  <div class="cl-diagram"><?php echo drsm_cluster_diagram($cl); ?></div>
  <div class="table-wrap">
    <table class="table">
      <thead><tr><th scope="col">Node</th><th scope="col">Host name</th><th scope="col">Keep alive IP</th><th scope="col">State</th><th scope="col">Seen by</th><th scope="col">DRSM host</th></tr></thead>
      <tbody>
<?php foreach($cl["nodes"] as $nd) { ?>
        <tr>
          <th scope="row"><?php echo h($nd["name"]); ?></th>
          <td class="small"><?php echo h($nd["host"]); ?></td>
          <td><code><?php echo h($nd["ip"]); ?></code></td>
          <td><?php echo drsm_cluster_badge($nd["state"] == "Up" ? "OK" : ($nd["state"] == "Down" ? "ERROR" : "UNKNOWN"), $nd["state"]); ?></td>
          <td class="small"><?php $v = array(); foreach($nd["views"] as $k => $s) $v[] = $reporters[$k]["self"] . ": " . $s; echo h(implode(", ", $v)); ?></td>
          <td><?php if($nd["drsm"] !== null) { ?><a href="<?php echo h(drsm_host_url("readreport.php", $nd["drsm"], array(), drsm_plugin_anchor(DRSM_CLUSTER_PLUGIN))); ?>"><?php echo h($nd["drsm"]["name"]); ?></a><?php } else { ?><span class="muted">none</span><?php } ?></td>
        </tr>
<?php } ?>
      </tbody>
    </table>
  </div>
</section>

<section class="panel flush">
  <div class="panel-head pad"><h2><?php echo drsm_icon("layout"); ?>Resources</h2></div>
  <div class="table-wrap">
    <table class="table">
      <thead><tr><th scope="col">Type</th><th scope="col">Resource</th><th scope="col">Running on</th><th scope="col">State</th><th scope="col">Since</th><th scope="col">Reported by</th></tr></thead>
      <tbody>
<?php
$rows = array();
foreach($reporters as $c) {
  foreach($c["resources"] as $r) {
    $k = $r["type"] . "|" . $r["nick"] . "|" . $r["owner"];
    if(!isset($rows[$k])) { $rows[$k] = $r; $rows[$k]["by"] = array(); }
    $rows[$k]["by"][] = $c["self"];
  }
}
$owners = array();
foreach($rows as $r) $owners[$r["type"] . "|" . $r["nick"]][] = $r["owner"];
foreach($rows as $r) {
  $split = count(array_unique($owners[$r["type"] . "|" . $r["nick"]])) > 1;
  $st = $split ? "ERROR" : ($r["state"] == "OK-Backup" ? "WARNING" : "OK");
?>
        <tr class="<?php echo $st == "ERROR" ? "row-err" : ""; ?>">
          <td><?php echo h($r["type"]); ?></td>
          <th scope="row"><?php echo h($r["nick"]); ?></th>
          <td class="small"><?php echo h($r["owner"]); ?></td>
          <td><?php echo drsm_cluster_badge($st, $split ? "On two nodes" : $r["state"]); ?></td>
          <td class="small"><?php echo h($r["start"]); ?></td>
          <td class="small"><?php echo h(implode(", ", array_unique($r["by"]))); ?></td>
        </tr>
<?php } ?>
<?php if(count($rows) == 0) { ?>
        <tr><td colspan="6" class="muted">No resources in the CM status.</td></tr>
<?php } ?>
      </tbody>
    </table>
  </div>
</section>

<section class="panel" id="cl-strips">
  <div class="panel-head wrap"><h2><?php echo drsm_icon("trend"); ?>Keep alive timeline</h2>
    <span class="cl-legend small">
<?php foreach(drsm_cluster_strip_kinds() as $k => $kind) { ?>
      <span><i class="<?php echo h($kind["cls"]); ?>"></i><?php echo h($kind["label"]); ?></span>
<?php } ?>
    </span>
  </div>
<?php
$any = false;
foreach($reporters as $c) {
  foreach($c["strips"] as $peer => $s) {
    $any = true;
    $hours = round(strlen($s["map"]) * $s["step"] / 3600);
?>
  <div class="cl-strip-row">
    <div class="cl-strip-label"><strong><?php echo h($c["self"]); ?></strong> from <strong><?php echo h($peer); ?></strong>
      <span class="muted small"><?php echo (int)$hours; ?> hours in <?php echo (int)($s["step"] / 60); ?> minute steps, <?php echo (int)drsm_cluster_strip_bad($s); ?> steps with drops, report <?php echo drsm_time_html($c["host"]["time"]); ?></span></div>
    <?php echo drsm_cluster_strip_svg($s, $c["self"] . " keep alives from " . $peer); ?>
  </div>
<?php
  }
}
if(!$any) echo "  <p class=\"muted\">No keep alive timeline in the reports yet.</p>\n";
?>
</section>

<section class="panel">
  <div class="panel-head wrap"><h2><?php echo drsm_icon("alert"); ?>Missed keep alives</h2>
    <div class="seg" role="group" aria-label="Range">
<?php foreach($ranges as $k => $rg) { ?>
      <a class="<?php echo $k == $range ? "active" : ""; ?>" href="<?php echo h(drsm_url("clusters.php", array("c" => $cname, "r" => $k))); ?>#cl-history"><?php echo h($rg["label"]); ?></a>
<?php } ?>
    </div>
  </div>
  <div id="cl-history">
<?php
$rg = $ranges[$range];
$nb = (int)($rg["secs"] / $rg["bucket"]);
$since = (int)(floor(($now - $rg["secs"]) / $rg["bucket"]) + 1) * $rg["bucket"];
$any = false;
foreach($reporters as $c) {
  $hist = drsm_cluster_history($c, $since, $rg["bucket"]);
  foreach($hist as $peer => $bs) {
    $any = true;
    $miss = 0;
    foreach($bs as $v) $miss += $v["miss"];
?>
    <div class="cl-strip-row">
      <div class="cl-strip-label"><strong><?php echo h($c["self"]); ?></strong> from <strong><?php echo h($peer); ?></strong>
        <span class="muted small"><?php echo (int)$miss; ?> missed in <?php echo h($rg["label"]); ?>, bars per <?php echo h(drsm_age_text($rg["bucket"])); ?>, red when a node was down or no keep alive was answered</span></div>
      <?php echo drsm_cluster_history_svg($bs, $since, $rg["bucket"], $nb, $c["self"] . " missed keep alives from " . $peer); ?>
    </div>
<?php
  }
}
if(!$any) echo "    <p class=\"muted\">The metrics history has no keep alive counts yet. Each report adds one.</p>\n";
?>
  </div>
</section>

<section class="panel flush" id="cl-events">
  <div class="panel-head pad"><h2><?php echo drsm_icon("list"); ?>Cluster events</h2><span class="muted small">From each node's cluster log, newest first</span></div>
  <div class="table-wrap">
    <table class="table">
      <thead><tr><th scope="col">Time</th><th scope="col">Node log</th><th scope="col">Kind</th><th scope="col">Event</th></tr></thead>
      <tbody>
<?php
$kinds = array("miss" => array("WARNING", "Dropout"), "recover" => array("OK", "Recovered"), "event" => array("WARNING", "Failover"), "error" => array("ERROR", "Error"));
foreach(array_slice($events, 0, 200) as $e) {
  $k = isset($kinds[$e["kind"]]) ? $kinds[$e["kind"]] : array("UNKNOWN", $e["kind"]);
?>
        <tr>
          <td class="small"><?php echo drsm_time_html($e["t"], true); ?></td>
          <td><?php echo h($e["by"]["self"]); ?></td>
          <td><?php echo drsm_cluster_badge($k[0], $k[1]); ?></td>
          <td class="small"><?php echo h($e["text"]); ?></td>
        </tr>
<?php } ?>
<?php if(count($events) == 0) { ?>
        <tr><td colspan="4" class="muted">No dropouts, failovers or errors in the cluster logs in the timeline period.</td></tr>
<?php } ?>
      </tbody>
    </table>
  </div>
</section>

<section class="panel">
  <div class="panel-head"><h2><?php echo drsm_icon("file"); ?>CM status reports</h2></div>
<?php foreach($reporters as $c) { ?>
  <details class="cl-cm"<?php echo $c === $first ? " open" : ""; ?>>
    <summary><?php echo drsm_badge($c["state"]); ?> <strong><?php echo h($c["self"] != "" ? $c["self"] : $c["host"]["name"]); ?></strong> <span class="muted small">on <?php echo h($c["host"]["name"]); ?>, <?php echo drsm_time_html($c["host"]["time"]); ?></span></summary>
    <pre class="report"><?php echo drsm_cluster_lines_html($c["text"]); ?></pre>
  </details>
<?php } ?>
</section>
<?php
drsm_page_end();

// SCRIPT CONTENT ENDS ABOVE.
// ----------------------------------------------------------- //
// ------------------------------- //
// --------- End of File --------- //
// ------------------------------- //
?>
