<?php
// ------------------------------- //
// -------- Start of File -------- //
// ------------------------------- //
// ----------------------------------------------------------- //
// PHP Source Code File
// PHP Version: 7.2 or higher, tested with PHP 8
// Original Author(s): DataReel Software Development 
// File Creation Date: 10/23/2026
// Date Last Modified: 11/20/2026
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
state, or against CPU, memory, disk, load and swap use. In the meters
layout (drsm_meters.php) the checks are a mosaic grouped by check type,
host or site, with round meters for each group across the top.
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
$layout = drsm_layout();
// Meters layout grouping: check type, host or site
// With more than one site shown, by site first ($METERsitesOnly), so
// each site's meter drills down to that site's heat map
// A viewer's pick is kept in the drsm_heatby cookie
$groupby = ($multi && !empty($METERsitesOnly)) ? "site" : "type";
if(isset($_GET['by']) && in_array($_GET['by'], array("type", "host", "site"), true)) {
  $groupby = $_GET['by'];
  if($layout == "meters") drsm_meter_cookie("drsm_heatby", $groupby);
}
else if(isset($_COOKIE['drsm_heatby']) && in_array($_COOKIE['drsm_heatby'], array("type", "host", "site"), true)) {
  $groupby = $_COOKIE['drsm_heatby'];
}
if($groupby == "site" && !$multi) $groupby = "type";
// The grouping the head links keep
$byarg = ($layout == "meters") ? $groupby : $bysite;

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
  if($bysite === true) $args["by"] = "site";
  else if(is_string($bysite) && $bysite != "") $args["by"] = $bysite;
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

// DRCM clusters: one row each, with node, link, keep alive, resource
// and CM status cells that open the Clusters page
function drsm_heat_clusters($clusters)
{
  $cols = array("nodes" => "Nodes", "links" => "Keep alive links", "drops" => "Drops 24 h", "resources" => "Resources", "cm" => "CM status"); ?>
  <div class="heat-site"><span class="dot-lg <?php $w = "OK"; foreach($clusters as $cl) $w = drsm_worst($w, $cl["state"]); echo h(drsm_state_class($w)); ?>" aria-hidden="true"></span><h2><a href="<?php echo h(drsm_url("clusters.php")); ?>">Clusters</a></h2><span class="muted small"><?php echo count($clusters); ?> DRCM cluster<?php echo count($clusters) == 1 ? "" : "s"; ?></span></div>
  <div class="heat-wrap" tabindex="0" aria-label="Cluster status, scrolls sideways">
    <table class="heat clusters">
      <thead>
        <tr>
          <th scope="col" class="corner">Cluster</th>
<?php foreach($cols as $k => $label) { ?>
          <th scope="col"><span class="col-cat">cluster</span><span class="col-name"><?php echo h($label); ?></span></th>
<?php } ?>
        </tr>
      </thead>
      <tbody>
<?php foreach($clusters as $cn => $cl) {
        $cs = drsm_cluster_summary($cl);
        $curl = drsm_url("clusters.php", array("c" => $cn)); ?>
        <tr>
          <th scope="row"><a href="<?php echo h($curl); ?>"><span class="dot-lg <?php echo h(drsm_state_class($cl["state"])); ?>" aria-hidden="true"></span><span class="truncate"><?php echo h($cn); ?></span></a></th>
<?php   foreach($cols as $k => $label) {
          $tip = "{$cn} - {$label}: " . drsm_state_label($cs[$k][0]) . "\n" . $cs[$k][2];
          $anchor = ($k == "drops") ? "#cl-strips" : ""; ?>
          <td><a class="hcell wide <?php echo h(drsm_state_class($cs[$k][0])); ?>" href="<?php echo h($curl . $anchor); ?>" title="<?php echo h($tip); ?>" aria-label="<?php echo h($tip); ?>"><?php echo drsm_state_icon($cs[$k][0]); ?><span class="hcell-text"><?php echo h($cs[$k][1]); ?></span></a></td>
<?php   } ?>
        </tr>
<?php } ?>
      </tbody>
    </table>
  </div>
<?php
}

// Meters layout, check status: groups of cells, problems first in
// each group, with a meter for each group
function drsm_heat_mosaic($groups)
{
  $total = 0;
  $n = drsm_meter_counts();
  foreach($groups as $g) {
    $total += count($g["cells"]);
    foreach($g["cells"] as $c) $n[isset($n[$c["s"]]) ? $c["s"] : "UNKNOWN"]++;
  }
  $cell = ($total > 900) ? 14 : (($total > 500) ? 18 : (($total > 250) ? 22 : 28));
  $i = 0; ?>
  <section class="m-gauges" aria-label="Group meters">
<?php foreach($groups as $g) {
        $cls = ($g["state"] == "") ? "none" : drsm_state_class($g["state"]);
        if(drsm_meter_minor($g)) $cls .= " minor";
        $nb = $g["counts"]["ERROR"] + $g["counts"]["WARNING"] + $g["counts"]["STALE"]; ?>
    <a class="m-g <?php echo h($cls); ?>" href="<?php echo h(isset($g["href"]) ? $g["href"] : "#" . $g["id"]); ?>" title="<?php echo h($g["title"] . ($g["about"] != "" && substr($g["id"], 0, 5) == "host-" ? " (" . $g["about"] . ")" : "") . ": " . ($g["state"] == "" ? "no reports" : drsm_state_label($g["state"]))); ?>">
      <?php echo drsm_meter_gauge($g["pct"], $g["state"], 64, $g["counts"]); ?>
      <span class="name"><?php echo h($g["title"]); ?></span>
      <span class="bad"><?php echo ($g["state"] == "") ? "no reports" : (($nb > 0) ? (int)$nb . " need attention" : count($g["cells"]) . " OK"); ?></span>
    </a>
<?php } ?>
  </section>
  <section class="m-field" style="--cell: <?php echo (int)$cell; ?>px" aria-label="All checks">
<?php foreach($groups as $g) {
        if(count($g["cells"]) == 0) continue;
        $cells = $g["cells"];
        usort($cells, function($a, $b) {
          $d = drsm_state_rank($b["s"]) - drsm_state_rank($a["s"]);
          return ($d != 0) ? $d : strcmp($a["t"], $b["t"]);
        });
        $cols = max(4, (int)ceil(sqrt(count($cells) * 2.2))); ?>
    <div class="m-grp <?php echo h(drsm_state_class($g["state"] == "" ? "UNKNOWN" : $g["state"])); ?>" id="<?php echo h($g["id"]); ?>">
      <h2><i></i><?php if(isset($g["href"])) { ?><a href="<?php echo h($g["href"]); ?>"><?php echo h($g["title"]); ?></a><?php } else { echo h($g["title"]); } ?><?php if(substr($g["id"], 0, 5) == "host-" && $g["about"] != "") { ?><span class="muted"><?php echo h($g["about"]); ?></span><?php } ?><span class="muted"><?php echo count($cells); ?></span></h2>
      <div class="m-cells" style="--w: calc(<?php echo $cols; ?> * (var(--cell) + 3px))">
<?php   foreach($cells as $c) {
          $tip = (($c["g"] != "" && strpos($c["t"], $c["g"]) !== 0) ? $c["g"] . ": " : "") . $c["t"] . " - " . drsm_state_label($c["s"]); ?>
        <a class="m-c <?php echo h(drsm_state_class($c["s"])); ?>" style="--i: <?php echo $i++; ?>" href="<?php echo h($c["h"]); ?>" title="<?php echo h($tip); ?>"><span class="sr"><?php echo h($tip); ?></span></a>
<?php   } ?>
      </div>
    </div>
<?php } ?>
  </section>
  <div class="legend m-legend">
    <span><i class="ok"></i>OK <?php echo (int)$n["OK"]; ?></span><span><i class="warn"></i>Warning <?php echo (int)$n["WARNING"]; ?></span><span><i class="err"></i>Error <?php echo (int)$n["ERROR"]; ?></span><span><i class="stale"></i>Stale <?php echo (int)$n["STALE"]; ?></span><?php if($n["UNKNOWN"] > 0) { ?><span><i class="unk"></i>Unknown <?php echo (int)$n["UNKNOWN"]; ?></span><?php } ?>
  </div>
<?php
}

// Meters layout groups: tiles by check type, or one group per host or
// site with that host's or site's checks as cells
function drsm_heat_meter_groups($hosts, $groupreports, $sites, $groupby)
{
  if($groupby == "type") return drsm_meter_tiles($hosts, $groupreports, $sites, array("groupchecks", "clusters", "ext", "checks"));
  $multi = (count($sites) > 1);
  $sets = array();
  if($groupby == "site") {
    foreach(drsm_hosts_by_site($hosts, $sites) as $sid => $set) {
      if(count($set) > 0) $sets["site-" . preg_replace('/[^A-Za-z0-9_-]/', "-", $sid)] = array($sites[$sid]["name"], "building", $set, $sites[$sid]["orgname"], $sid);
    }
  }
  else {
    foreach($hosts as $k => $hst) $sets["host-" . preg_replace('/[^A-Za-z0-9_-]/', "-", $k)] = array($hst["name"], "grid", array($k => $hst), $multi ? drsm_site_label($hst["site"]) : "");
  }
  $out = array();
  foreach($sets as $id => $set) {
    $t = drsm_meter_tile($id, $set[0], $set[1], isset($set[3]) ? $set[3] : "");
    // A site's meter opens that site's heat map, with its group checks
    if(isset($set[4])) {
      $t["href"] = drsm_url("heatmap.php", array("site" => $set[4]));
      foreach($groupreports as $gr) {
        if($gr["site"] != $set[4]) continue;
        $title = (($gr["kind"] == "check") ? "Connectivity" : "Health checks") . ", " . ucfirst($gr["group"]);
        $url = ($gr["kind"] == "check") ? drsm_url("checks.php", ($gr["group"] == "production" ? array() : array("g" => $gr["group"])) + array("site" => $gr["site"]))
                                        : drsm_url("checks.php", array("r" => "health", "g" => $gr["group"], "site" => $gr["site"]));
        drsm_meter_add($t, drsm_meter_item($title, $gr["state"], $url));
        $t["cells"][] = array("t" => $title, "s" => $gr["state"], "h" => $url, "g" => "");
      }
    }
    foreach($set[2] as $hst) {
      $hurl = drsm_host_url("readreport.php", $hst);
      if(count($hst["plugins"]) == 0) {
        drsm_meter_add($t, drsm_meter_item($hst["name"], $hst["state"], $hurl));
        $t["cells"][] = array("t" => $hst["name"], "s" => $hst["state"], "h" => $hurl, "g" => "");
        continue;
      }
      foreach($hst["plugins"] as $pid => $p) {
        $st = ($hst["stale"] && $p["state"] == "OK") ? "STALE" : $p["state"];
        drsm_meter_add($t, drsm_meter_item($pid, $st, $hurl));
        $tip = count($p["msgs"]) ? " - " . implode(" | ", array_slice($p["msgs"], 0, 3)) : "";
        $t["cells"][] = array("t" => ($groupby == "site" ? $hst["name"] . " " : "") . $pid . $tip, "s" => $st, "h" => $hurl . "#" . drsm_plugin_anchor($pid), "g" => "");
      }
    }
    $t["pct"] = ($t["units"] > 0) ? (int)floor(100 * $t["counts"]["OK"] / $t["units"]) : null;
    $out[] = $t;
  }
  // Worst groups first when sorted by state
  return $out;
}

// Meters layout, resource use: a card of round meters for each host
function drsm_heat_meter_uses($hosts, $showsite)
{
  $metriccols = drsm_metric_columns(); ?>
  <div class="m-hosts">
<?php foreach($hosts as $hst) { ?>
    <a class="m-host <?php echo h(drsm_state_class($hst["state"])); ?>" href="<?php echo h(drsm_host_url("readreport.php", $hst)); ?>">
      <span class="m-host-name"><span class="dot-lg <?php echo h(drsm_state_class($hst["state"])); ?>" aria-hidden="true"></span><span class="truncate"><?php echo h($hst["name"]); ?></span><?php echo drsm_tier_badge($hst["group"]); ?></span>
<?php   if($showsite) { ?><span class="muted small"><?php echo h(drsm_site_label($hst["site"])); ?></span><?php } ?>
      <span class="m-uses">
<?php   foreach($metriccols as $key => $col) {
          if(isset($hst["metrics"][$key])) echo drsm_meter_use($hst["metrics"][$key], $col, $key);
          else echo "<span class=\"m-use none\" title=\"" . h($col["title"] . ": no data") . "\"><svg viewBox=\"0 0 36 36\" aria-hidden=\"true\"><circle class=\"g-track\" cx=\"18\" cy=\"18\" r=\"15.9\"/></svg><span class=\"m-use-v\">&ndash;</span><span class=\"m-use-l\">" . h($col["label"]) . "</span></span>";
        } ?>
      </span>
    </a>
<?php } ?>
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
    <?php echo drsm_layout_switch("heatmap.php", array("mode" => $mode, "sort" => $sortby)); ?>
    <?php echo drsm_tier_buttons($alltiers, $tier, function($t) use ($mode, $sortby, $byarg) { return drsm_heat_link($mode, $sortby, $byarg, $t); }); ?>
    <div class="seg" role="group" aria-label="Heat map type">
      <a href="<?php echo h(drsm_heat_link("status", $sortby, $byarg)); ?>"<?php if($mode == "status") echo ' class="active" aria-current="page"'; ?>>Check status</a>
      <a href="<?php echo h(drsm_heat_link("metrics", $sortby, $byarg)); ?>"<?php if($mode == "metrics") echo ' class="active" aria-current="page"'; ?>>Resource use</a>
    </div>
    <div class="seg" role="group" aria-label="Sort hosts">
      <a href="<?php echo h(drsm_heat_link($mode, "state", $byarg)); ?>"<?php if($sortby == "state") echo ' class="active"'; ?>>Worst first</a>
      <a href="<?php echo h(drsm_heat_link($mode, "name", $byarg)); ?>"<?php if($sortby == "name") echo ' class="active"'; ?>>A to Z</a>
    </div>
<?php if($layout == "meters" && $mode == "status") { ?>
    <div class="seg" role="group" aria-label="Group checks by">
      <a href="<?php echo h(drsm_heat_link($mode, $sortby, "type")); ?>"<?php if($groupby == "type") echo ' class="active"'; ?>>By check type</a>
      <a href="<?php echo h(drsm_heat_link($mode, $sortby, "host")); ?>"<?php if($groupby == "host") echo ' class="active"'; ?>>By host</a>
<?php   if($multi) { ?>
      <a href="<?php echo h(drsm_heat_link($mode, $sortby, "site")); ?>"<?php if($groupby == "site") echo ' class="active"'; ?>>By site</a>
<?php   } ?>
    </div>
<?php } else if($multi && $layout != "meters") { ?>
    <div class="seg" role="group" aria-label="Group hosts">
      <a href="<?php echo h(drsm_heat_link($mode, $sortby, false)); ?>"<?php if(!$bysite) echo ' class="active"'; ?>>All hosts</a>
      <a href="<?php echo h(drsm_heat_link($mode, $sortby, true)); ?>"<?php if($bysite) echo ' class="active"'; ?>>By site</a>
    </div>
<?php } ?>
  </div>
</section>

<?php if($layout == "meters") {
  if(count($hosts) == 0) { ?>
<section class="panel"><div class="empty"><p>No hosts have posted a report yet.</p></div></section>
<?php
  }
  else if($mode == "status") {
    $groupreports = drsm_group_reports($scope);
    if($tier != "") $groupreports = array_filter($groupreports, function($gr) use ($tier) { return drsm_tier_id($gr["group"]) == $tier; });
    $mgroups = drsm_heat_meter_groups($hosts, $groupreports, $sites, $groupby);
    if($sortby == "state") {
      usort($mgroups, function($a, $b) {
        $d = drsm_state_rank($b["state"]) - drsm_state_rank($a["state"]);
        return ($d != 0) ? $d : strcmp($a["title"], $b["title"]);
      });
    }
    drsm_heat_mosaic($mgroups);
  }
  else { ?>
<section class="panel">
<?php drsm_heat_meter_uses(array_filter($hosts, function($hst) { return empty($hst["nometrics"]); }), $multi); ?>
  <div class="legend pad scale">
    <span>0%</span><i class="h0"></i><i class="h1"></i><i class="h2"></i><i class="h3"></i><i class="h4"></i><i class="h5"></i><span>100%</span>
    <span class="muted">Load is the 15 minute load average per CPU.</span>
  </div>
</section>
<?php
  }
  drsm_page_end();
  return;
}

// Clusters first in both views, so the map shows everything
$clusters = drsm_clusters($hosts);
if(count($clusters) > 0) { ?>
<section class="panel flush">
<?php drsm_heat_clusters($clusters); ?>
</section>
<?php } ?>
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
