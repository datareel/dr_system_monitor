<?php
// ------------------------------- //
// -------- Start of File -------- //
// ------------------------------- //
// ----------------------------------------------------------- //
// PHP Source Code File
// PHP Version: 7.2 or higher, tested with PHP 8
// Original Author(s): DataReel Software Development 
// File Creation Date: 10/23/2026
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

DRSM heat map: every host against every plugin check, colored by
state, or against CPU, memory, disk, load and swap use.
*/
// ----------------------------------------------------------- //
// SCRIPT CONTENT STARTS BELOW.

require_once("../config/drsm.php");

// Our required includes
require_once("{$WWWdir}/php/query_post_validation.php");
require_once("{$WWWdir}/php/drsm_lib.php");

$mode = (isset($_GET['mode']) && $_GET['mode'] == "metrics") ? "metrics" : "status";
$sortby = (isset($_GET['sort']) && $_GET['sort'] == "name") ? "name" : "state";
$scope = drsm_scope_from_request();
$sites = drsm_scope_sites($scope);
$multi = (count($sites) > 1);
$bysite = ($multi && isset($_GET['by']) && $_GET['by'] == "site");

$hosts = drsm_load_hosts($scope);
$alltiers = drsm_tiers($hosts);
$tier = drsm_tier_from_request();
$hosts = drsm_tier_filter($hosts, $tier);
$overall = "OK";
foreach($hosts as $hst) $overall = drsm_worst($overall, $hst["state"]);

// Worst hosts first, so problems are at the top of the map
if($sortby == "state") uasort($hosts, "drsm_cmp_worst");

// One map for every host, or one per site
$sets = $bysite ? drsm_hosts_by_site($hosts, $sites) : array("" => $hosts);
// With a tier picked, skip the sites that have no hosts in it
if($tier != "" && $bysite) $sets = array_filter($sets, "count");
$metriccols = drsm_metric_columns();

function drsm_heat_link($mode, $sortby, $bysite, $tier = null)
{
  $args = array("mode" => $mode, "sort" => $sortby);
  if($bysite) $args["by"] = "site";
  if($tier !== null) $args["tier"] = $tier;
  return drsm_url("heatmap.php", $args);
}

// Host row header, with its site when the map mixes sites
function drsm_heat_row_head($hst, $hurl, $showsite)
{
  return "<th scope=\"row\"><a href=\"" . h($hurl) . "\"><span class=\"dot-lg " . h(drsm_state_class($hst["state"])) . "\" aria-hidden=\"true\"></span><span class=\"truncate\">" . h($hst["name"])
    . drsm_tier_badge($hst["group"])
    . ($showsite ? "<span class=\"site-tag\">" . h(drsm_site_label($hst["site"])) . "</span>" : "") . "</span></a></th>";
}

function drsm_heat_status($hosts, $showsite)
{
  // Columns: every plugin any host runs, grouped by category
  $plugins = array();
  foreach($hosts as $hst) {
    foreach($hst["plugins"] as $id => $p) $plugins[$id] = true;
  }
  $plugins = array_keys($plugins);
  sort($plugins);
  if(count($plugins) == 0) { ?>
  <div class="empty"><p>These hosts use the older report scripts, which do not list plugin checks. Run <code>bin/drsm_run.sh</code> to fill the heat map, or switch to the host matrix on the overview.</p></div>
<?php
    return;
  }
  // Per column totals for the summary row
  $coltotals = array();
  foreach($plugins as $id) $coltotals[$id] = "OK";
  foreach($hosts as $hst) {
    foreach($hst["plugins"] as $id => $p) $coltotals[$id] = drsm_worst($coltotals[$id], $p["state"]);
  } ?>
  <div class="heat-wrap" tabindex="0" aria-label="Host and check heat map, scrolls sideways">
    <table class="heat">
      <thead>
        <tr>
          <th scope="col" class="corner">Host</th>
<?php foreach($plugins as $id) { ?>
          <th scope="col" title="<?php echo h($id); ?>"><span class="col-cat"><?php echo h(substr($id, 0, max(0, (int)strrpos($id, "/")))); ?></span><span class="col-name"><?php echo h(drsm_plugin_short($id)); ?></span></th>
<?php } ?>
        </tr>
      </thead>
      <tbody>
<?php foreach($hosts as $hst) {
        $hurl = drsm_host_url("readreport.php", $hst); ?>
        <tr>
          <?php echo drsm_heat_row_head($hst, $hurl, $showsite); ?>

<?php   foreach($plugins as $id) {
          if(!isset($hst["plugins"][$id])) { ?>
          <td class="none"><span class="sr">not run</span></td>
<?php       continue;
          }
          $p = $hst["plugins"][$id];
          $tip = "{$hst["name"]} - {$id}: " . drsm_state_label($p["state"]) . (count($p["msgs"]) ? "\n" . implode("\n", $p["msgs"]) : ""); ?>
          <td><a class="hcell <?php echo h(drsm_state_class($p["state"])); ?>" href="<?php echo h($hurl . "#" . drsm_plugin_anchor($id)); ?>" title="<?php echo h($tip); ?>" aria-label="<?php echo h($tip); ?>"><?php echo drsm_state_icon($p["state"]); ?></a></td>
<?php   } ?>
        </tr>
<?php } ?>
      </tbody>
      <tfoot>
        <tr>
          <th scope="row">Worst</th>
<?php foreach($plugins as $id) { ?>
          <td><span class="hcell small <?php echo h(drsm_state_class($coltotals[$id])); ?>" title="<?php echo h($id . ": worst state " . drsm_state_label($coltotals[$id])); ?>"><?php echo drsm_state_icon($coltotals[$id]); ?></span></td>
<?php } ?>
        </tr>
      </tfoot>
    </table>
  </div>
<?php
}

function drsm_heat_metrics($hosts, $showsite)
{
  $metriccols = drsm_metric_columns(); ?>
  <div class="heat-wrap" tabindex="0" aria-label="Resource use heat map, scrolls sideways">
    <table class="heat metrics">
      <thead>
        <tr>
          <th scope="col" class="corner">Host</th>
<?php foreach($metriccols as $key => $col) { ?>
          <th scope="col" title="<?php echo h($col["title"]); ?>"><span class="col-name"><?php echo h($col["label"]); ?></span></th>
<?php } ?>
        </tr>
      </thead>
      <tbody>
<?php foreach($hosts as $hst) {
        $hurl = drsm_host_url("readreport.php", $hst); ?>
        <tr>
          <?php echo drsm_heat_row_head($hst, $hurl, $showsite); ?>

<?php   foreach($metriccols as $key => $col) {
          if(!isset($hst["metrics"][$key])) { ?>
          <td class="none"><span class="mcell none" title="<?php echo h($col["title"] . ": no data"); ?>">&ndash;</span></td>
<?php       continue;
          }
          $mt = $hst["metrics"][$key];
          $tip = "{$hst["name"]} - {$col["title"]} {$mt["text"]}" . (isset($mt["detail"]) && $mt["detail"] != "" ? " ({$mt["detail"]})" : ""); ?>
          <td><span class="mcell h<?php echo drsm_heat_level($mt["pct"]); ?>" title="<?php echo h($tip); ?>"><?php echo h($key == "load" ? round($mt["pct"]) . "%" : $mt["text"]); ?></span></td>
<?php   } ?>
        </tr>
<?php } ?>
      </tbody>
    </table>
  </div>
<?php
}

drsm_page_start("Heat map", "heatmap", $overall);
?>
<section class="page-head">
  <div>
    <h1>Heat map</h1>
    <p class="muted"><?php echo $mode == "status" ? "Each cell is one plugin check on one host. Select a cell to open that check." : "Resource use on each host from the latest plugin metrics."; ?></p>
  </div>
  <div class="head-actions">
    <?php echo drsm_tier_buttons($alltiers, $tier, function($t) use ($mode, $sortby, $bysite) { return drsm_heat_link($mode, $sortby, $bysite, $t); }); ?>
    <div class="seg" role="group" aria-label="Heat map type">
      <a href="<?php echo h(drsm_heat_link("status", $sortby, $bysite)); ?>"<?php if($mode == "status") echo ' class="active" aria-current="page"'; ?>>Check status</a>
      <a href="<?php echo h(drsm_heat_link("metrics", $sortby, $bysite)); ?>"<?php if($mode == "metrics") echo ' class="active" aria-current="page"'; ?>>Resource use</a>
    </div>
    <div class="seg" role="group" aria-label="Sort hosts">
      <a href="<?php echo h(drsm_heat_link($mode, "state", $bysite)); ?>"<?php if($sortby == "state") echo ' class="active"'; ?>>Worst first</a>
      <a href="<?php echo h(drsm_heat_link($mode, "name", $bysite)); ?>"<?php if($sortby == "name") echo ' class="active"'; ?>>A to Z</a>
    </div>
<?php if($multi) { ?>
    <div class="seg" role="group" aria-label="Group hosts">
      <a href="<?php echo h(drsm_heat_link($mode, $sortby, false)); ?>"<?php if(!$bysite) echo ' class="active"'; ?>>All hosts</a>
      <a href="<?php echo h(drsm_heat_link($mode, $sortby, true)); ?>"<?php if($bysite) echo ' class="active"'; ?>>By site</a>
    </div>
<?php } ?>
  </div>
</section>

<?php $nset = 0;
foreach($sets as $sid => $set) {
  $nset++; ?>
<section class="panel flush">
<?php   if($sid != "") {
          $sm = drsm_site_summary($sites[$sid], $set); ?>
  <div class="heat-site"><span class="dot-lg <?php echo h(drsm_state_class($sm["state"])); ?>" aria-hidden="true"></span><h2><a href="<?php echo h(drsm_url("index.php", array("site" => $sid))); ?>"><?php echo h(drsm_site_label($sid)); ?></a></h2><span class="muted small"><?php echo count($set); ?> host<?php echo count($set) == 1 ? "" : "s"; ?></span></div>
<?php   } ?>
<?php   if(count($set) == 0) { ?>
  <div class="empty"><p>No hosts have posted a report yet.</p></div>
<?php   } else if($mode == "status") {
          drsm_heat_status($set, $multi && !$bysite);
        } else {
          // Hosts with no metrics ($METRICSskip) are left off
          drsm_heat_metrics(array_filter($set, function($hst) { return empty($hst["nometrics"]); }), $multi && !$bysite);
        } ?>
<?php   // The legend goes under the last map
        if($nset == count($sets) && count($hosts) > 0) { ?>
<?php     if($mode == "status") { ?>
  <div class="legend pad">
    <span><?php echo drsm_state_icon("OK"); ?>OK</span><span><?php echo drsm_state_icon("WARNING"); ?>Warning</span><span><?php echo drsm_state_icon("ERROR"); ?>Error</span><span><?php echo drsm_state_icon("UNKNOWN"); ?>Unknown</span><span><i class="none"></i>Not run</span>
  </div>
<?php   } else { ?>
  <div class="legend pad scale">
    <span>0%</span><i class="h0"></i><i class="h1"></i><i class="h2"></i><i class="h3"></i><i class="h4"></i><i class="h5"></i><span>100%</span>
    <span class="muted">Load is the 15 minute load average per CPU.</span>
  </div>
<?php     } ?>
<?php   } ?>
</section>
<?php } ?>
<?php
drsm_page_end();

// SCRIPT CONTENT ENDS ABOVE.
// ----------------------------------------------------------- //
// ------------------------------- //
// --------- End of File --------- //
// ------------------------------- //
?>
