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

DRSM trends: capacity statistics for hardware and cloud purchasing,
normal ranges learned from the metrics history, and the values that
fell outside them. With no host chosen it compares every host.
*/
// ----------------------------------------------------------- //
// SCRIPT CONTENT STARTS BELOW.

require_once("../config/drsm.php");

// Our required includes
require_once("{$WWWdir}/php/query_post_validation.php");
require_once("{$WWWdir}/php/drsm_lib.php");
require_once("{$WWWdir}/php/trends_lib.php");

$ranges = drsm_trend_ranges();
$range = (isset($_GET['r']) && isset($ranges[$_GET['r']])) ? $_GET['r'] : "30d";
$scope = isset($_GET['h']) ? drsm_scope() : drsm_scope_from_request();
$hosts = drsm_load_hosts($scope);

// One host: h=<host> with site=<org>/<site>, or h=<org>/<site>/<host>
$hostkey = "";
$hostname = "";
if(isset($_GET['h']) && $_GET['h'] != "") {
  $res = drsm_resolve_host($_GET['h'], isset($_GET['site']) ? $_GET['site'] : "");
  if($res["status"] == "ambiguous") {
    drsm_ambiguous_page($res, "trends.php", "h");
    exit;
  }
  if($res["status"] == "ok") {
    $hostkey = drsm_host_key($res["name"], $res["site"]);
    $hostname = $res["name"];
    // A host outside the picked scope still opens from a link
    if(!isset($hosts[$hostkey])) $hosts[$hostkey] = drsm_load_host($res["name"], $res["site"]);
  }
}
$now = time();
$since = ($ranges[$range]["secs"] > 0) ? $now - $ranges[$range]["secs"] : 0;

$verdicts = array(
  "over"  => array("label" => "Oversized", "cls" => "warn", "tip" => "Pays for more than it uses"),
  "ok"    => array("label" => "Right-sized", "cls" => "ok", "tip" => "Use fits the size with headroom"),
  "under" => array("label" => "Undersized", "cls" => "err", "tip" => "Needs more than it has")
);

function drsm_verdict_html($v)
{
  global $verdicts;
  if(!isset($verdicts[$v])) return "<span class=\"muted\">-</span>";
  $x = $verdicts[$v];
  return "<span class=\"badge " . h($x["cls"]) . "\" title=\"" . h($x["tip"]) . "\"><span class=\"dot\"></span>" . h($x["label"]) . "</span>";
}

function drsm_trend_link($host, $range)
{
  // $host is a host from drsm_load_hosts(), or "" for every host
  $args = array();
  if(is_array($host)) {
    $args["h"] = $host["name"];
    if($host["site"] != DRSM_LEGACY_SITE) $args["site"] = $host["site"];
  }
  if($range != "30d") $args["r"] = $range;
  return drsm_url("trends.php", $args);
}

// Anomalies for the main series of one host
function drsm_host_anomalies($d)
{
  $all = array();
  $bls = array();
  foreach($d["series"] as $key => $ser) {
    if($key == "mem_mb" || strpos($key, "diskmb:") === 0 || strpos($key, "iopeak:") === 0) continue;
    $info = drsm_trend_series_info($key);
    $bls[$key] = drsm_trend_baseline($ser, $info);
    foreach(drsm_trend_anomalies($ser, $bls[$key], $key) as $a) $all[] = $a;
  }
  usort($all, function($a, $b) { return $b["t"] - $a["t"]; });
  return array($all, $bls);
}

$overall = "OK";
foreach($hosts as $hst) $overall = drsm_worst($overall, $hst["state"]);

drsm_page_start("Trends", "trends", $overall);
?>
<section class="page-head">
  <div>
<?php if($hostname != "") { ?>
    <div class="crumbs"><a href="<?php echo h(drsm_trend_link("", $range)); ?>"><?php echo drsm_icon("back"); ?>All hosts</a></div>
    <h1><?php echo h($hostname); ?> trends</h1>
    <p class="muted"><?php if(drsm_multi_site()) echo h(drsm_site_label($hosts[$hostkey]["site"])) . " &middot; "; ?><?php echo h($hosts[$hostkey]["description"] != "" ? $hosts[$hostkey]["description"] : "Use over time, what this host needs, and what is normal for it."); ?></p>
<?php } else { ?>
    <h1>Trends</h1>
    <p class="muted">Use over time for sizing hardware and cloud purchases, and the normal range of each host so unusual values stand out.</p>
<?php } ?>
  </div>
  <div class="head-actions">
    <div class="seg" role="group" aria-label="Time range">
<?php foreach($ranges as $key => $rg) { ?>
      <a href="<?php echo h(drsm_trend_link($hostkey != "" ? $hosts[$hostkey] : "", $key)); ?>"<?php if($range == $key) echo ' class="active" aria-current="page"'; ?>><?php echo h($rg["label"]); ?></a>
<?php } ?>
    </div>
<?php if(count($hosts) > 0) { ?>
    <form class="host-pick" method="get" action="<?php echo h(drsm_url("trends.php")); ?>">
      <?php if($range != "30d") { ?><input type="hidden" name="r" value="<?php echo h($range); ?>"><?php } ?>
      <label class="sr" for="trend-host">Host</label>
      <select id="trend-host" name="h" data-autosubmit>
        <option value="">All hosts</option>
<?php   foreach($hosts as $hst) { ?>
        <option value="<?php echo h($hst["key"]); ?>"<?php if($hst["key"] == $hostkey) echo " selected"; ?>><?php echo h($hst["name"] . ($hst["site"] != DRSM_LEGACY_SITE && drsm_multi_site() ? " - " . drsm_site_label($hst["site"]) : "")); ?></option>
<?php   } ?>
      </select>
      <noscript><button class="button" type="submit">Show</button></noscript>
    </form>
<?php } ?>
  </div>
</section>
<?php
// ---------------------------------------------------------------- //
// All hosts: one capacity row each
// ---------------------------------------------------------------- //
if($hostkey == "") {
  $rows = array();
  foreach($hosts as $hst) {
    $d = drsm_trend_load($hst["name"], $since, $hst["site"]);
    $cap = array();
    foreach(drsm_trend_capacity($d, in_array($hst["name"], $TRENDshared)) as $c) $cap[$c["id"]] = $c;
    $disks = array();
    foreach($cap as $id => $c) if(strpos($id, "disk:") === 0) $disks[] = $c;
    $traffic = drsm_trend_traffic($d);
    list($anoms, $bls) = drsm_host_anomalies($d);
    $recent = 0;
    foreach($anoms as $a) if($a["t"] >= $now - 86400) $recent++;
    $aws = drsm_section_facts($hst["report"], "cloud/aws");
    $rows[] = array("host" => $hst, "d" => $d, "cap" => $cap, "disks" => $disks, "traffic" => $traffic, "recent" => $recent,
                    "anoms" => count($anoms), "type" => isset($aws["Instance type"]) ? $aws["Instance type"] : "");
  }
?>
<section class="panel flush">
  <div class="panel-head pad"><h2><?php echo drsm_icon("trend"); ?>Capacity by host</h2><span class="muted small"><?php echo h($ranges[$range]["label"]); ?> of history, <?php echo (int)$TRENDheadroom; ?>% headroom</span></div>
<?php if(count($rows) == 0) { ?>
  <div class="empty"><p>No hosts have posted a report yet.</p></div>
<?php } else { ?>
  <div class="table-wrap">
    <table class="table trend-table">
      <thead>
        <tr><th scope="col">Host</th><th scope="col">History</th><th scope="col">CPU p95</th><th scope="col">CPUs have / need</th><th scope="col">Memory peak</th><th scope="col">Memory have / need</th><th scope="col">Disk have / need</th><th scope="col">Network out / 30 days</th><th scope="col">Outside normal, 24h</th></tr>
      </thead>
      <tbody>
<?php   foreach($rows as $row) {
          $c = $row["cap"];
          $url = drsm_trend_link($row["host"], $range); ?>
        <tr>
          <th scope="row"><a href="<?php echo h($url); ?>"><strong><?php echo h($row["host"]["name"]); ?></strong></a><?php if($row["type"] != "") { ?> <span class="tag"><?php echo h($row["type"]); ?></span><?php } ?><?php if(in_array($row["host"]["name"], $TRENDshared)) { ?> <span class="tag">shared</span><?php } ?></th>
<?php     if(!$row["d"]["exists"] || $row["d"]["count"] == 0) { ?>
          <td colspan="8" class="muted">No metrics history yet. It starts with the next report, or run <code>utils/drsm_metrics_backfill.sh</code>.</td>
<?php       continue;
          } ?>
          <td><?php echo h(drsm_age_text($row["d"]["last"] - $row["d"]["first"])); ?><br><span class="muted small"><?php echo (int)$row["d"]["count"]; ?> reports</span></td>
          <td class="num"><?php echo isset($c["cpu"]) ? h($c["cpu"]["p95"]) : "-"; ?></td>
          <td><?php if(isset($c["cpu"])) { ?><?php echo h($c["cpu"]["have"] . " / " . $c["cpu"]["need"]); ?> <?php echo drsm_verdict_html($c["cpu"]["verdict"]); ?><?php } else echo "-"; ?></td>
          <td class="num"><?php echo isset($c["mem"]) ? h($c["mem"]["max"]) : "-"; ?></td>
          <td><?php if(isset($c["mem"])) { ?><?php echo h($c["mem"]["have"] . " / " . $c["mem"]["need"]); ?> <?php echo drsm_verdict_html($c["mem"]["verdict"]); ?><?php } else echo "-"; ?></td>
          <td>
<?php     foreach($row["disks"] as $dk) { ?>
            <div class="small"><span class="chip-id"><?php echo h(substr($dk["id"], 5)); ?></span><?php echo h($dk["have"] . " / " . $dk["need"]); ?> <?php echo drsm_verdict_html($dk["verdict"]); ?></div>
<?php     } ?>
<?php     if(count($row["disks"]) == 0) echo "<span class=\"muted small\">Sizes start with the next report</span>"; ?>
          </td>
          <td class="num"><?php echo $row["traffic"]["net"] ? h(drsm_fmt_bytes($row["traffic"]["net"]["tx_month"])) : "-"; ?></td>
          <td class="num"><?php if($row["recent"] > 0) { ?><a class="badge warn" href="<?php echo h($url); ?>#outside"><span class="dot"></span><?php echo (int)$row["recent"]; ?></a><?php } else { ?><span class="badge ok"><span class="dot"></span>0</span><?php } ?></td>
        </tr>
<?php   } ?>
      </tbody>
    </table>
  </div>
<?php } ?>
</section>

<section class="panel">
  <div class="panel-head"><h2><?php echo drsm_icon("search"); ?>How to read this page</h2></div>
  <ul class="notes">
    <li><strong>Need</strong> is the size that keeps <?php echo (int)$TRENDheadroom; ?>% free: CPU at the 95th percentile of use, memory at the 99th percentile, and disk at today's use plus a year of the measured growth.</li>
    <li><strong>Oversized</strong> means the host would fit in less than half of what it has, so a smaller server or cloud instance would do. <strong>Undersized</strong> means it needs more than it has.</li>
    <li><strong>Outside normal</strong> counts reports where a value left its normal range: the median for that hour of the day, plus or minus <?php echo h($TRENDsigma); ?> robust standard deviations. Ranges need a day of history, and use the hour of the day once there are 3 days.</li>
    <li>Network out is every byte the host's interfaces sent, scaled to 30 days.</li>
    <li>Hosts marked <strong>shared</strong> are shared hosting accounts (<code>$TRENDshared</code>), where the figures are the provider's whole server, so they get no sizing.</li>
  </ul>
</section>
<?php
  drsm_page_end();
  exit;
}

// ---------------------------------------------------------------- //
// One host
// ---------------------------------------------------------------- //
$hst = $hosts[$hostkey];
$d = drsm_trend_load($hostname, $since, $hst["site"]);
$from = ($since > 0) ? $since : $d["first"];
$to = max($now, $d["last"]);
if($since > 0 && $d["first"] > 0) $from = max($since, min($d["first"], $now - 86400));
$shared = in_array($hostname, $TRENDshared);
$cap = drsm_trend_capacity($d, $shared);
$capid = array();
foreach($cap as $c) $capid[$c["id"]] = $c;
$traffic = drsm_trend_traffic($d);
list($anoms, $bls) = drsm_host_anomalies($d);
$recent = 0;
foreach($anoms as $a) if($a["t"] >= $now - 86400) $recent++;
$aws = drsm_section_facts($hst["report"], "cloud/aws");
$cloud = count($aws) > 0;

if(!$d["exists"] || $d["count"] == 0) {
?>
<section class="panel">
  <div class="empty">
    <?php echo drsm_icon("trend"); ?>
    <p>No metrics history for <?php echo h($hostname); ?> yet<?php echo $since > 0 ? " in the last " . h($ranges[$range]["label"]) : ""; ?>.</p>
    <p class="muted">DRSM adds a line to the history with each report. To start from the reports already archived, run <code>utils/drsm_metrics_backfill.sh --apply</code> on the monitor host.</p>
  </div>
</section>
<?php
  drsm_page_end();
  exit;
}

$span = $d["last"] - $d["first"];
$disk_growth = 0;
$disk_known = false;
foreach($d["series"] as $key => $ser) {
  if(strpos($key, "diskmb:") !== 0 || $span < 2 * 86400) continue;
  $s = drsm_trend_slope($ser);
  if($s !== null) { $disk_growth += $s * 30; $disk_known = true; }
}
?>
<section class="kpis" aria-label="Summary">
  <div class="kpi"><span class="kpi-label">History</span><span class="kpi-value"><?php echo h(drsm_age_text($span)); ?></span><span class="kpi-sub"><?php echo (int)$d["count"]; ?> reports</span></div>
  <div class="kpi <?php echo isset($capid["cpu"]) ? h($verdicts[$capid["cpu"]["verdict"]]["cls"] ?? "") : ""; ?>"><span class="kpi-label">CPU p95</span><span class="kpi-value"><?php echo isset($capid["cpu"]) ? h($capid["cpu"]["p95"]) : "-"; ?></span><span class="kpi-sub"><?php echo isset($capid["cpu"]) ? h("needs " . $capid["cpu"]["need"] . " of " . $capid["cpu"]["have"]) : "no data"; ?></span></div>
  <div class="kpi <?php echo isset($capid["mem"]) ? h($verdicts[$capid["mem"]["verdict"]]["cls"] ?? "") : ""; ?>"><span class="kpi-label">Memory peak</span><span class="kpi-value"><?php echo isset($capid["mem"]) ? h($capid["mem"]["max"]) : "-"; ?></span><span class="kpi-sub"><?php echo isset($capid["mem"]) ? h("needs " . $capid["mem"]["need"] . " of " . $capid["mem"]["have"]) : "no data"; ?></span></div>
  <div class="kpi"><span class="kpi-label">Disk growth</span><span class="kpi-value"><?php echo $disk_known ? h(drsm_fmt_bytes($disk_growth * 1048576)) : "-"; ?></span><span class="kpi-sub"><?php echo $disk_known ? "a month, all disks" : "needs 2 days"; ?></span></div>
  <div class="kpi"><span class="kpi-label">Network out</span><span class="kpi-value"><?php echo $traffic["net"] ? h(drsm_fmt_bytes($traffic["net"]["tx_month"])) : "-"; ?></span><span class="kpi-sub">per 30 days</span></div>
  <a class="kpi <?php echo $recent > 0 ? "warn" : "ok"; ?>" href="#outside"><span class="kpi-label">Outside normal</span><span class="kpi-value"><?php echo (int)$recent; ?></span><span class="kpi-sub">in the last 24 hours</span></a>
</section>

<section class="panel flush">
  <div class="panel-head pad"><h2><?php echo drsm_icon("trend"); ?>Capacity and sizing</h2><span class="muted small"><?php echo h($ranges[$range]["label"]); ?>, <?php echo (int)$TRENDheadroom; ?>% headroom</span></div>
  <div class="table-wrap">
    <table class="table trend-table">
      <thead><tr><th scope="col">Resource</th><th scope="col" class="num">Has</th><th scope="col" class="num">Average</th><th scope="col" class="num">95th pct</th><th scope="col" class="num">Peak</th><th scope="col" class="num">Needs</th><th scope="col">Sizing</th><th scope="col">Notes</th></tr></thead>
      <tbody>
<?php foreach($cap as $c) { ?>
        <tr>
          <th scope="row"><?php echo h($c["label"]); ?></th>
          <td class="num"><?php echo h($c["have"]); ?></td>
          <td class="num"><?php echo h($c["avg"]); ?></td>
          <td class="num"><?php echo h($c["p95"]); ?></td>
          <td class="num"><?php echo h($c["max"]); ?></td>
          <td class="num strong"><?php echo h($c["need"]); ?></td>
          <td><?php echo drsm_verdict_html($c["verdict"]); ?></td>
          <td class="muted small"><?php echo h($c["note"]); ?></td>
        </tr>
<?php } ?>
<?php if(count($cap) == 0) { ?>
        <tr><td colspan="8" class="muted">The history has no CPU, memory or disk metrics yet.</td></tr>
<?php } ?>
      </tbody>
    </table>
  </div>
</section>

<?php if($cloud) {
  $need_cpu = isset($capid["cpu"]["need_raw"]) ? $capid["cpu"]["need_raw"] : null;
  $need_mem = isset($capid["mem"]["need_raw"]) ? $capid["mem"]["need_raw"] : null;
  $need_disk = 0;
  foreach($cap as $c) if(strpos($c["id"], "disk:") === 0 && $c["need_raw"]) $need_disk += $c["need_raw"];
  $ebs_total = 0;
  foreach($d["sizes"]["ebs"] as $gib) $ebs_total += $gib;
?>
<div class="split">
  <section class="panel">
    <div class="panel-head"><h2><?php echo drsm_icon("cloud"); ?>AWS: what you pay for</h2><span class="tag">from instance metadata</span></div>
    <div class="table-wrap">
      <table class="table trend-table">
        <thead><tr><th scope="col">Billed item</th><th scope="col">You have</th><th scope="col">Measured need</th></tr></thead>
        <tbody>
          <tr><th scope="row">Instance</th><td><strong><?php echo h(isset($aws["Instance type"]) ? $aws["Instance type"] : "-"); ?></strong><br><span class="muted small"><?php echo h(trim((isset($aws["Lifecycle"]) ? $aws["Lifecycle"] : "") . ", " . (isset($aws["Region"]) ? $aws["Region"] : "") . (isset($aws["Availability zone"]) ? " (" . $aws["Availability zone"] . ")" : ""), ", ")); ?></span></td>
            <td><?php echo $need_cpu !== null ? h("at least " . $need_cpu . " vCPU" . ($need_cpu == 1 ? "" : "s")) : "-"; ?><?php echo $need_mem !== null ? h(" and " . $need_mem . " GiB memory") : ""; ?><br><span class="muted small">Has <?php echo h((isset($capid["cpu"]) ? $capid["cpu"]["have"] : "-") . ", " . (isset($capid["mem"]) ? $capid["mem"]["have"] : "-")); ?></span></td></tr>
          <tr><th scope="row">EBS storage</th><td><strong><?php echo $ebs_total > 0 ? h($ebs_total . " GiB") : "-"; ?></strong>
<?php foreach($aws as $k => $v) { if(strpos($k, "Volume ") !== 0) continue; ?>
            <br><span class="muted small"><?php echo h(substr($k, 7) . ": " . $v); ?></span>
<?php } ?>
            </td>
            <td><?php echo $need_disk > 0 ? h($need_disk . " GiB") : "-"; ?><br><span class="muted small">today's use plus a year of growth, <?php echo (int)$TRENDheadroom; ?>% free</span></td></tr>
<?php if($traffic["net"]) { ?>
          <tr><th scope="row">Data transfer out</th><td><?php echo h(drsm_fmt_bytes($traffic["net"]["tx_month"])); ?> per 30 days<br><span class="muted small">in: <?php echo h(drsm_fmt_bytes($traffic["net"]["rx_month"])); ?>, not billed</span></td><td><span class="muted small">All bytes the instance sent. Only the part going to the internet or other regions is billed.</span></td></tr>
<?php } ?>
<?php foreach($traffic["io"] as $dev => $io) { ?>
          <tr><th scope="row">EBS I/O <?php echo h($dev); ?></th><td><?php echo h(round($io["iops"]["p95"]) . " IOPS, " . ($io["bw"] ? drsm_fmt_bytes($io["bw"]["p95"]) . "/s" : "-")); ?> at p95<br><span class="muted small">peak sample <?php echo $io["peak"] ? h(round($io["peak"]["max"]) . " IOPS") : "-"; ?></span></td><td><span class="muted small">gp3 includes 3,000 IOPS and 125 MiB/s, extra is billed</span></td></tr>
<?php } ?>
<?php if(isset($aws["Public IPv4"]) && $aws["Public IPv4"] != "") { ?>
          <tr><th scope="row">Public IPv4</th><td><?php echo h($aws["Public IPv4"]); ?></td><td><span class="muted small">Public IPv4 addresses are billed by the hour</span></td></tr>
<?php } ?>
        </tbody>
      </table>
    </div>
  </section>
  <aside class="panel">
    <div class="panel-head"><h2><?php echo drsm_icon("alert"); ?>Not measured by DRSM</h2></div>
    <p class="muted small">Check these in the AWS console or Cost Explorer:</p>
    <ul class="notes">
      <li>The hourly price, and whether a Savings Plan or Reserved Instance covers it</li>
      <li>EBS volume type and any IOPS or throughput provisioned above the gp3 baseline</li>
      <li>EBS snapshots and AMIs</li>
      <li>Which part of the data sent went to the internet, another region or another zone</li>
      <li>Elastic IPs not attached, load balancers, CloudWatch, S3 and other services</li>
    </ul>
  </aside>
</div>
<?php } ?>

<?php if($traffic["net"] || count($traffic["io"]) > 0) { ?>
<section class="panel flush">
  <div class="panel-head pad"><h2><?php echo drsm_icon("net"); ?>Network and disk I/O</h2></div>
  <div class="table-wrap">
    <table class="table trend-table">
      <thead><tr><th scope="col">Item</th><th scope="col" class="num">Total</th><th scope="col" class="num">Per 30 days</th><th scope="col" class="num">Average</th><th scope="col" class="num">95th pct</th><th scope="col" class="num">Peak</th></tr></thead>
      <tbody>
<?php if($traffic["net"]) { $n = $traffic["net"]; ?>
        <tr><th scope="row">Network out</th><td class="num"><?php echo h(drsm_fmt_bytes($n["tx_total"])); ?></td><td class="num strong"><?php echo h(drsm_fmt_bytes($n["tx_month"])); ?></td><td class="num"><?php echo h(drsm_fmt_value($n["tx"]["avg"], "B/s")); ?></td><td class="num"><?php echo h(drsm_fmt_value($n["tx"]["p95"], "B/s")); ?></td><td class="num"><?php echo h(drsm_fmt_value($n["tx"]["max"], "B/s")); ?></td></tr>
<?php   if($n["rx"]) { ?>
        <tr><th scope="row">Network in</th><td class="num"><?php echo h(drsm_fmt_bytes($n["rx_total"])); ?></td><td class="num"><?php echo h(drsm_fmt_bytes($n["rx_month"])); ?></td><td class="num"><?php echo h(drsm_fmt_value($n["rx"]["avg"], "B/s")); ?></td><td class="num"><?php echo h(drsm_fmt_value($n["rx"]["p95"], "B/s")); ?></td><td class="num"><?php echo h(drsm_fmt_value($n["rx"]["max"], "B/s")); ?></td></tr>
<?php   } ?>
<?php } ?>
<?php foreach($traffic["io"] as $dev => $io) { ?>
        <tr><th scope="row">Disk IOPS <?php echo h($dev); ?></th><td class="num">-</td><td class="num">-</td><td class="num"><?php echo h(drsm_fmt_value($io["iops"]["avg"], "IOPS")); ?></td><td class="num"><?php echo h(drsm_fmt_value($io["iops"]["p95"], "IOPS")); ?></td><td class="num"><?php echo h(drsm_fmt_value($io["peak"] ? max($io["peak"]["max"], $io["iops"]["max"]) : $io["iops"]["max"], "IOPS")); ?></td></tr>
<?php   if($io["bw"]) { ?>
        <tr><th scope="row">Disk throughput <?php echo h($dev); ?></th><td class="num">-</td><td class="num">-</td><td class="num"><?php echo h(drsm_fmt_value($io["bw"]["avg"], "B/s")); ?></td><td class="num"><?php echo h(drsm_fmt_value($io["bw"]["p95"], "B/s")); ?></td><td class="num"><?php echo h(drsm_fmt_value($io["bw"]["max"], "B/s")); ?></td></tr>
<?php   } ?>
<?php } ?>
      </tbody>
    </table>
  </div>
  <p class="pad muted small">Rates are averages between two reports. Disk I/O peaks shorter than the report interval only show in the short sample the plugin takes on each run.</p>
</section>
<?php } ?>

<?php
// Charts: the main series, then the fullest disks, network and I/O
$charts = array();
foreach(array("cpu", "mem", "load", "swap_mb", "steal") as $key) {
  if(!isset($d["series"][$key])) continue;
  if(($key == "steal" || $key == "swap_mb") && max($d["series"][$key]["v"]) <= 0) continue;
  $charts[] = $key;
}
$diskkeys = array();
foreach($d["series"] as $key => $ser) if(strpos($key, "disk:") === 0) $diskkeys[$key] = end($ser["v"]);
arsort($diskkeys);
foreach(array_slice(array_keys($diskkeys), 0, 4) as $key) $charts[] = $key;
foreach(array("tx", "rx") as $key) if(isset($d["series"][$key])) $charts[] = $key;
foreach($d["series"] as $key => $ser) if(strpos($key, "iops:") === 0) $charts[] = $key;
?>
<section class="trend-grid" aria-label="Trend charts">
<?php foreach($charts as $key) {
        $info = drsm_trend_series_info($key);
        $ser = $d["series"][$key];
        $bl = isset($bls[$key]) ? $bls[$key] : drsm_trend_baseline($ser, $info);
        $mine = array();
        foreach($anoms as $a) if($a["key"] == $key) $mine[] = $a;
        $st = drsm_trend_stats($ser["v"]);
        $last = end($ser["v"]); ?>
  <section class="panel trend-card">
    <div class="panel-head">
      <h2><?php echo h($info["label"]); ?></h2>
      <span class="trend-now"><?php echo h(drsm_fmt_value($last, $info["unit"])); ?></span>
    </div>
    <?php echo drsm_trend_chart($ser, $bl, $mine, $info, $from, $to); ?>
    <div class="trend-foot">
      <span>avg <strong><?php echo h(drsm_fmt_value($st["avg"], $info["unit"])); ?></strong></span>
      <span>p95 <strong><?php echo h(drsm_fmt_value($st["p95"], $info["unit"])); ?></strong></span>
      <span>peak <strong><?php echo h(drsm_fmt_value($st["max"], $info["unit"])); ?></strong></span>
<?php   if($bl["mode"] != "none") { ?>
      <span class="muted"><i class="key-band"></i>normal <?php echo $bl["mode"] == "hourly" ? "by hour of day" : h(drsm_fmt_value($bl["all"]["lo"], $info["unit"]) . " to " . drsm_fmt_value($bl["all"]["hi"], $info["unit"])); ?></span>
<?php     if(count($mine) > 0) { ?><span class="muted"><i class="key-anom"></i><?php echo count($mine); ?> outside</span><?php } ?>
<?php   } else { ?>
      <span class="muted">normal range after 24 reports</span>
<?php   } ?>
    </div>
  </section>
<?php } ?>
</section>

<section class="panel flush" id="outside">
  <div class="panel-head pad"><h2><?php echo drsm_icon("alert"); ?>Outside the normal range</h2><span class="count"><?php echo count($anoms); ?></span></div>
<?php if(count($anoms) == 0) { ?>
  <div class="empty ok"><?php echo drsm_icon("check"); ?><p><?php echo $span < 6 * 3600 ? "Not enough history yet to learn what is normal." : "Every value in this range was within its normal range."; ?></p></div>
<?php } else { ?>
  <div class="table-wrap">
    <table class="table trend-table">
      <thead><tr><th scope="col">Time</th><th scope="col">Metric</th><th scope="col" class="num">Value</th><th scope="col" class="num">Normal range</th><th scope="col"></th></tr></thead>
      <tbody>
<?php   foreach(array_slice($anoms, 0, 100) as $a) {
          $info = drsm_trend_series_info($a["key"]); ?>
        <tr class="<?php echo $a["dir"] == "high" ? "row-warn" : ""; ?>">
          <td><?php echo drsm_time_html($a["t"], true); ?></td>
          <td><?php echo h($info["label"]); ?></td>
          <td class="num strong"><?php echo h(drsm_fmt_value($a["v"], $info["unit"])); ?></td>
          <td class="num"><?php echo h(drsm_fmt_value($a["band"]["lo"], $info["unit"]) . " to " . drsm_fmt_value($a["band"]["hi"], $info["unit"])); ?></td>
          <td><span class="badge <?php echo $a["dir"] == "high" ? "warn" : "unk"; ?>"><span class="dot"></span><?php echo $a["dir"] == "high" ? "Above normal" : "Below normal"; ?></span></td>
        </tr>
<?php   } ?>
      </tbody>
    </table>
  </div>
<?php   if(count($anoms) > 100) { ?><p class="pad muted small">Showing the newest 100 of <?php echo count($anoms); ?>.</p><?php } ?>
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
