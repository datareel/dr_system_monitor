<?php
// ------------------------------- //
// -------- Start of File -------- //
// ------------------------------- //
// ----------------------------------------------------------- //
// PHP Source Code File
// PHP Version: 7.2 or higher, tested with PHP 8
// Original Author(s): DataReel Software Development 
// File Creation Date: 05/25/2013
// Date Last Modified: 10/23/2026
//
// Version control: 2.00
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

System report processing script: one host's health check report,
shown as a summary, resource gauges, and a panel for each plugin.
*/
// ----------------------------------------------------------- //
// SCRIPT CONTENT STARTS BELOW.

require_once("../config/drsm.php");

// Our required includes
require_once("{$WWWdir}/php/query_post_validation.php");
require_once("{$WWWdir}/php/drsm_lib.php");

$n = isset($_GET['n']) ? CleanQueryAsString($_GET['n'], 255) : "";

// Only accept a plain host name, this blocks ../ path traversal
if(!drsm_valid_host($n)) {
  $n = "";
}

$fname = "{$REPORTdir}/systems/{$n}/{$n}_report.txt";

if(($n == "") || !file_exists("{$fname}")) {
  http_response_code(404);
  drsm_page_start("Not found", "hosts", "");
?>
<section class="panel">
  <div class="empty">
    <h1>Host not found</h1>
    <p>There is no report for this host. Check the link, or pick a host from the list.</p>
    <p><a class="button" href="<?php echo h(drsm_url("reports.php")); ?>"><?php echo drsm_icon("back"); ?>All hosts</a></p>
  </div>
</section>
<?php
  drsm_page_end();
  exit;
}

$hst = drsm_load_host($n);
$rep = $hst["report"];
$metriccols = drsm_metric_columns();

// Line style for report text
function drsm_render_lines($lines)
{
  $out = "";
  foreach($lines as $line) {
    $cls = "";
    switch(drsm_line_level($line)) {
      case "ERROR": $cls = "l-err"; break;
      case "WARNING": $cls = "l-warn"; break;
      case "UNKNOWN": $cls = "l-unk"; break;
      case "INFO": $cls = "l-info"; break;
      case "METRIC": $cls = "l-metric"; break;
    }
    $out .= ($cls != "") ? "<span class=\"{$cls}\">" . h($line) . "</span>\n" : h($line) . "\n";
  }
  return $out;
}

// Plugin section order: problems first, in report order otherwise
$sections = $rep["sections"];
$order = array();
foreach($sections as $i => $s) $order[$i] = array(-drsm_state_rank($s["state"]), $i);
uksort($sections, function($a, $b) use ($order) {
  if($order[$a][0] != $order[$b][0]) return $order[$a][0] - $order[$b][0];
  return $order[$a][1] - $order[$b][1];
});

$meta = array(
  "Description" => $hst["description"],
  "Impact" => $hst["impact"],
  "Group" => $hst["group"],
  "Platform" => $hst["platform"],
  "Collector" => $hst["collector"]
);

drsm_page_start($hst["name"], "hosts", $hst["state"]);
?>
<nav class="crumbs" aria-label="Breadcrumb"><a href="<?php echo h(drsm_url("reports.php")); ?>"><?php echo drsm_icon("back"); ?>Hosts</a></nav>

<section class="hero compact <?php echo h(drsm_state_class($hst["state"])); ?>">
  <div class="hero-status">
    <span class="pulse" aria-hidden="true"></span>
    <div>
      <h1><?php echo h($hst["name"]); ?></h1>
      <p><?php echo $hst["description"] != "" ? h($hst["description"]) : "Health check report"; ?></p>
    </div>
  </div>
  <div class="hero-meta">
    <?php echo drsm_badge($hst["state"]); ?>
    <span class="muted">Reported <?php echo drsm_time_html($hst["time"]); ?></span>
    <a class="button ghost" href="<?php echo h(drsm_archive_url($hst["name"])); ?>"><?php echo drsm_icon("archive"); ?>Archived reports</a>
  </div>
</section>

<?php if($hst["note"] != "") { ?>
<div class="callout <?php echo h(drsm_state_class($hst["stale"] ? "STALE" : "ERROR")); ?>"><?php echo drsm_icon("alert"); ?><span><?php echo h($hst["note"]); ?></span></div>
<?php } ?>

<div class="detail-grid">
  <section class="panel">
    <div class="panel-head"><h2>Details</h2></div>
    <dl class="meta">
<?php foreach($meta as $k => $v) { if($v == "") continue; ?>
      <dt><?php echo h($k); ?></dt><dd><?php echo h($v); ?></dd>
<?php } ?>
<?php if(isset($rep["fields"]["REPORT_TIME"]) && $DEMObuilt == 0) { ?>
      <dt>Report time</dt><dd><?php echo h($rep["fields"]["REPORT_TIME"]); ?></dd>
<?php } ?>
    </dl>
  </section>

<?php if(count($hst["metrics"]) > 0) { ?>
  <section class="panel">
    <div class="panel-head"><h2>Resource use</h2></div>
    <div class="gauges">
<?php   foreach($metriccols as $key => $col) {
          if(!isset($hst["metrics"][$key])) continue;
          $mt = $hst["metrics"][$key];
          $pct = max(0, min(100, $mt["pct"])); ?>
      <div class="gauge h<?php echo drsm_heat_level($mt["pct"]); ?>" title="<?php echo h($col["title"] . (isset($mt["detail"]) && $mt["detail"] != "" ? ": " . $mt["detail"] : "")); ?>">
        <svg viewBox="0 0 36 36" aria-hidden="true"><circle class="g-track" cx="18" cy="18" r="15.9"/><circle class="g-fill" cx="18" cy="18" r="15.9" stroke-dasharray="<?php echo round($pct, 1); ?> 100"/></svg>
        <div class="g-text"><strong><?php echo h($key == "load" ? round($mt["pct"]) . "%" : $mt["text"]); ?></strong><span><?php echo h($col["label"]); ?></span></div>
      </div>
<?php   } ?>
    </div>
  </section>
<?php } ?>
</div>

<?php if(count($sections) > 0) { ?>
<section class="panel">
  <div class="panel-head wrap">
    <h2>Checks</h2>
    <div class="head-actions">
      <button type="button" class="button ghost small" data-action="expand-all">Expand all</button>
      <button type="button" class="button ghost small" data-action="collapse-all">Collapse all</button>
    </div>
  </div>
  <div class="sections">
<?php   foreach($sections as $s) {
          $open = ($s["state"] == "ERROR" || $s["state"] == "WARNING" || $s["state"] == "UNKNOWN");
          $summary = "";
          foreach($s["lines"] as $line) {
            $lvl = drsm_line_level($line);
            if($lvl == "ERROR" || $lvl == "WARNING" || $lvl == "UNKNOWN") { $summary = $line; break; }
          }
          if($summary == "") {
            foreach($s["lines"] as $line) if(trim($line) != "" && drsm_line_level($line) != "METRIC") { $summary = $line; break; }
          } ?>
    <details class="section <?php echo h(drsm_state_class($s["state"])); ?>" id="<?php echo h(drsm_plugin_anchor($s["id"])); ?>"<?php if($open) echo " open"; ?>>
      <summary>
        <span class="dot-lg <?php echo h(drsm_state_class($s["state"])); ?>" aria-hidden="true"></span>
        <span class="sec-id"><?php echo h($s["id"]); ?></span>
        <span class="sec-sum truncate"><?php echo h(preg_replace('/^(ERROR|WARNING|INFO|UNKNOWN) - /', "", $summary)); ?></span>
        <span class="sec-meta"><?php echo drsm_badge($s["state"]); ?><span class="muted small"><?php echo (int)$s["secs"]; ?>s</span></span>
      </summary>
      <pre class="report"><?php echo drsm_render_lines($s["lines"]); ?></pre>
    </details>
<?php   } ?>
  </div>
</section>
<?php } ?>

<section class="panel">
  <details class="raw"<?php if(count($sections) == 0) echo " open"; ?>>
    <summary><h2>Full report text</h2></summary>
    <pre class="report"><?php echo drsm_render_lines(drsm_read_lines($fname) ?: array()); ?></pre>
  </details>
</section>
<?php
drsm_page_end();

// SCRIPT CONTENT ENDS ABOVE.
// ----------------------------------------------------------- //
// ------------------------------- //
// --------- End of File --------- //
// ------------------------------- //
?>
