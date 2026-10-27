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

DRSM Organizations page: every organization and site at a glance.
Each site card shows its worst state, host counts, a tile per host
(check status, or resource use with mode=metrics), and its collector.
A site whose collector has stopped writing site.json gets a "Collector
not reporting" banner. The landing page when there is more than one
site. The menu and brand links open it with site= to clear the site
picker scope; a scoped view offers "Show all organizations".
*/
// ----------------------------------------------------------- //
// SCRIPT CONTENT STARTS BELOW.

require_once("../config/drsm.php");

// Our required includes
require_once("{$WWWdir}/php/query_post_validation.php");
require_once("{$WWWdir}/php/drsm_lib.php");

$mode = (isset($_GET['mode']) && $_GET['mode'] == "metrics") ? "metrics" : "status";
$scope = drsm_scope_from_request();
$sites = drsm_scope_sites($scope);
$hosts = drsm_load_hosts($scope);
// Tier counts on the site cards are for every host, the tiles and
// totals for the tier filter
$alltiers = drsm_tiers($hosts);
$tiercounts = array();
foreach($hosts as $hst) {
  $t = drsm_tier_id($hst["group"]);
  if(!isset($tiercounts[$hst["site"]])) $tiercounts[$hst["site"]] = array();
  $tiercounts[$hst["site"]][$t] = isset($tiercounts[$hst["site"]][$t]) ? $tiercounts[$hst["site"]][$t] + 1 : 1;
}
$tier = drsm_tier_from_request();
$hosts = drsm_tier_filter($hosts, $tier);
$bysite = drsm_hosts_by_site($hosts, $sites);
// With a tier picked, only the sites that have hosts in it
if($tier != "") {
  foreach($sites as $id => $s) {
    if(count($bysite[$id]) == 0) unset($sites[$id], $bysite[$id]);
  }
}
$orgs = drsm_orgs($sites);

// Site summaries, and totals for the bar at the top
$sum = array();
$tot = array("orgs" => count($orgs), "sites" => count($sites), "hosts" => count($hosts),
             "OK" => 0, "WARNING" => 0, "ERROR" => 0, "STALE" => 0, "down" => 0);
$overall = "OK";
foreach($sites as $id => $s) {
  $sum[$id] = drsm_site_summary($s, $bysite[$id]);
  foreach(array("OK", "WARNING", "ERROR", "STALE") as $k) $tot[$k] += $sum[$id]["counts"][$k];
  if($sum[$id]["down"]) $tot["down"]++;
  $overall = drsm_worst($overall, $sum[$id]["state"]);
}
if(count($sites) == 0) $overall = "UNKNOWN";

// Worst site first inside each organization, worst organization first
$orgstate = array();
foreach($orgs as $oid => $o) {
  $st = "OK";
  foreach($o["sites"] as $id => $s) $st = drsm_worst($st, $sum[$id]["state"]);
  $orgstate[$oid] = $st;
  uksort($orgs[$oid]["sites"], function($a, $b) use ($sum, $sites) {
    $d = drsm_state_rank($sum[$b]["state"]) - drsm_state_rank($sum[$a]["state"]);
    return ($d != 0) ? $d : strcmp($sites[$a]["name"], $sites[$b]["name"]);
  });
}
uksort($orgs, function($a, $b) use ($orgstate, $orgs) {
  $d = drsm_state_rank($orgstate[$b]) - drsm_state_rank($orgstate[$a]);
  return ($d != 0) ? $d : strcmp($orgs[$a]["name"], $orgs[$b]["name"]);
});

// What a scoped view is limited to: an organization or one site
$scopename = "";
if($scope != "") $scopename = isset($orgs[$scope]) ? $orgs[$scope]["name"] : drsm_site_label($scope);

function drsm_orgs_link($mode, $scope, $tier = null)
{
  $args = array();
  if($mode != "status") $args["mode"] = $mode;
  // Always name the scope, so "" clears the site picker cookie
  $args["site"] = $scope;
  if($tier !== null) $args["tier"] = $tier;
  return drsm_url("orgs.php", $args);
}

drsm_page_start("Organizations", "orgs", $overall);
?>
<section class="page-head">
  <div>
    <h1>Organizations</h1>
    <p class="muted"><?php echo $mode == "status" ? "Every site at a glance. Each tile is one host, worst first. Select a tile for its report." : "Resource use on each host: the tile shows its busiest resource."; ?></p>
<?php if($scope != "") { ?>
    <p class="scope-note">Showing <strong><?php echo h($scopename); ?></strong> only. <a class="link" href="<?php echo h(drsm_orgs_link($mode, "")); ?>" data-show-all>Show all organizations</a></p>
<?php } ?>
  </div>
  <div class="head-actions">
    <?php echo drsm_tier_buttons($alltiers, $tier, function($t) use ($mode, $scope) { return drsm_orgs_link($mode, $scope, $t); }); ?>
    <div class="seg" role="group" aria-label="Tile type">
      <a href="<?php echo h(drsm_orgs_link("status", $scope)); ?>"<?php if($mode == "status") echo ' class="active" aria-current="page"'; ?>>Check status</a>
      <a href="<?php echo h(drsm_orgs_link("metrics", $scope)); ?>"<?php if($mode == "metrics") echo ' class="active" aria-current="page"'; ?>>Resource use</a>
    </div>
  </div>
</section>

<section class="kpis org-kpis" aria-label="Totals">
  <div class="kpi"><span class="kpi-label">Organizations</span><span class="kpi-value"><?php echo (int)$tot["orgs"]; ?></span><span class="kpi-sub"><?php echo (int)$tot["sites"]; ?> site<?php echo $tot["sites"] == 1 ? "" : "s"; ?></span></div>
  <div class="kpi"><span class="kpi-label">Hosts</span><span class="kpi-value"><?php echo (int)$tot["hosts"]; ?></span><span class="kpi-sub">reporting to <?php echo (int)$tot["sites"]; ?> site<?php echo $tot["sites"] == 1 ? "" : "s"; ?></span></div>
  <div class="kpi ok"><span class="kpi-label">Healthy</span><span class="kpi-value"><?php echo (int)$tot["OK"]; ?></span><span class="kpi-sub"><?php echo $tot["hosts"] ? round($tot["OK"] / $tot["hosts"] * 100) : 0; ?>% of hosts</span></div>
  <div class="kpi warn"><span class="kpi-label">Warning</span><span class="kpi-value"><?php echo (int)$tot["WARNING"]; ?></span><span class="kpi-sub">hosts</span></div>
  <div class="kpi err"><span class="kpi-label">Error</span><span class="kpi-value"><?php echo (int)$tot["ERROR"]; ?></span><span class="kpi-sub">hosts</span></div>
  <div class="kpi stale"><span class="kpi-label">Not reporting</span><span class="kpi-value"><?php echo (int)$tot["STALE"]; ?></span><span class="kpi-sub"><?php echo (int)$tot["down"]; ?> collector<?php echo $tot["down"] == 1 ? "" : "s"; ?> down</span></div>
</section>

<?php if(count($sites) == 0) { ?>
<section class="panel"><div class="empty"><p><?php echo $tier != "" ? "No " . h(drsm_tier_label($tier)) . " hosts in these sites." : "No sites to show."; ?></p></div></section>
<?php } ?>
<?php foreach($orgs as $oid => $o) { ?>
<section class="org" aria-labelledby="org-<?php echo h($oid); ?>">
  <div class="org-head">
    <h2 id="org-<?php echo h($oid); ?>"><span class="dot-lg <?php echo h(drsm_state_class($orgstate[$oid])); ?>" aria-hidden="true"></span><?php echo h($o["name"]); ?></h2>
    <?php echo drsm_badge($orgstate[$oid]); ?>
    <span class="muted"><?php echo count($o["sites"]); ?> site<?php echo count($o["sites"]) == 1 ? "" : "s"; ?><?php if($o["contact"] != "") echo " &middot; " . h($o["contact"]); ?></span>
  </div>
  <div class="site-grid">
<?php   foreach($o["sites"] as $id => $s) {
          $sm = $sum[$id];
          $tiles = $bysite[$id];
          uasort($tiles, "drsm_cmp_worst");
          $sitescope = drsm_url("index.php", array("site" => $id)); ?>
    <article class="site-card <?php echo h(drsm_state_class($sm["state"])); ?>" data-site="<?php echo h($id); ?>">
      <header>
        <div class="site-title">
          <h3><a href="<?php echo h($sitescope); ?>"><?php echo h($s["name"]); ?></a></h3>
          <p class="muted"><?php echo h($s["location"] != "" ? $s["location"] : ($s["legacy"] ? "Hosts in no site" : $id)); ?></p>
        </div>
        <?php echo drsm_badge($sm["state"]); ?>
      </header>
<?php     if($sm["down"]) { ?>
      <div class="callout stale small"><?php echo drsm_icon("alert"); ?><span>Collector not reporting, last heard from <?php echo drsm_time_html($sm["seen"]); ?></span></div>
<?php     } ?>
      <ul class="site-counts" aria-label="Hosts by state">
        <li><strong><?php echo (int)$sm["total"]; ?></strong> host<?php echo $sm["total"] == 1 ? "" : "s"; ?></li>
<?php     foreach(array("ERROR", "WARNING", "STALE", "OK") as $k) {
            if($sm["counts"][$k] == 0) continue; ?>
        <li class="<?php echo h(drsm_state_class($k)); ?>"><span class="dot"></span><?php echo (int)$sm["counts"][$k]; ?> <?php echo h(strtolower(drsm_state_label($k))); ?></li>
<?php     } ?>
      </ul>
<?php     if(isset($tiercounts[$id])) { ?>
      <ul class="tier-counts" aria-label="Hosts by tier">
<?php       foreach(drsm_tiers(array_map(function($t) { return array("group" => $t); }, array_keys($tiercounts[$id]))) as $t) { ?>
        <li<?php if($tier == $t) echo ' class="active"'; ?>><span class="tier tier-<?php echo h($t); ?>"><?php echo h(drsm_tier_label($t)); ?></span><?php echo (int)$tiercounts[$id][$t]; ?></li>
<?php       } ?>
      </ul>
<?php     } ?>
<?php     if(count($tiles) == 0) { ?>
      <p class="muted small">No host reports yet.</p>
<?php     } else { ?>
      <div class="matrix tiles<?php echo $mode == "metrics" ? " metric" : ""; ?>" role="list">
<?php       foreach($tiles as $hst) {
              $url = drsm_host_url("readreport.php", $hst);
              if($mode == "metrics") {
                list($peak, $plabel) = drsm_host_peak($hst);
                $cls = ($peak === null) ? "none" : "h" . drsm_heat_level($peak);
                $tip = $hst["name"] . " - " . ($peak === null ? "no resource data" : "{$plabel} " . round($peak) . "%");
                foreach(drsm_metric_columns() as $k => $col) {
                  if($k != "load" && isset($hst["metrics"][$k])) $tip .= "\n{$col["title"]} {$hst["metrics"][$k]["text"]}";
                }
              }
              else {
                $cls = drsm_state_class($hst["state"]);
                $tip = $hst["name"] . " (" . drsm_tier_label(drsm_tier_id($hst["group"])) . ") - " . drsm_state_label($hst["state"]) . ($hst["description"] != "" ? " - " . $hst["description"] : "");
                foreach(array_slice($hst["report"]["messages"], 0, 3) as $msg) $tip .= "\n" . $msg["text"];
              } ?>
        <a role="listitem" class="cell <?php echo h($cls); ?>" href="<?php echo h($url); ?>" title="<?php echo h($tip); ?>"><span class="sr"><?php echo h($tip); ?></span></a>
<?php       } ?>
      </div>
<?php     } ?>
      <footer>
        <span class="muted"><?php echo drsm_icon("net"); ?><?php echo h($s["collector"] != "" ? $s["collector"] : ($s["legacy"] ? "This server" : "Collector unknown")); ?></span>
        <span class="muted"><?php echo drsm_time_html($sm["seen"]); ?></span>
      </footer>
      <nav class="site-links" aria-label="<?php echo h($s["name"]); ?> pages">
        <a href="<?php echo h($sitescope); ?>">Overview</a>
        <a href="<?php echo h(drsm_url("heatmap.php", array("site" => $id))); ?>">Heat map</a>
        <a href="<?php echo h(drsm_url("reports.php", array("site" => $id))); ?>">Hosts</a>
        <a href="<?php echo h(drsm_url("checks.php", array("site" => $id))); ?>">Connectivity</a>
      </nav>
    </article>
<?php   } ?>
  </div>
</section>
<?php } ?>
<?php if(count($sites) > 0) { ?>
<div class="legend<?php echo $mode == "metrics" ? " scale" : ""; ?>">
<?php   if($mode == "status") { ?>
  <span><i class="ok"></i>OK</span><span><i class="warn"></i>Warning</span><span><i class="err"></i>Error</span><span><i class="stale"></i>Stale</span><span><i class="unk"></i>Unknown</span>
<?php   } else { ?>
  <span>0%</span><i class="h0"></i><i class="h1"></i><i class="h2"></i><i class="h3"></i><i class="h4"></i><i class="h5"></i><span>100%</span><span class="muted">Highest of CPU, memory, disk, load per CPU and swap.</span>
<?php   } ?>
</div>
<?php } ?>
<?php
drsm_page_end();

// SCRIPT CONTENT ENDS ABOVE.
// ----------------------------------------------------------- //
// ------------------------------- //
// --------- End of File --------- //
// ------------------------------- //
?>
