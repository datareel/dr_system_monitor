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

System reports processing script: a sortable table of every host
with its state, tier, plugin results, resource use and last report
time. tier= (or the drsm_tier cookie) shows one tier.
*/
// ----------------------------------------------------------- //
// SCRIPT CONTENT STARTS BELOW.

require_once("../config/drsm.php");

// Our required includes
require_once("{$WWWdir}/php/query_post_validation.php");
require_once("{$WWWdir}/php/drsm_lib.php");

$scope = drsm_scope_from_request();
$multi = (count(drsm_scope_sites($scope)) > 1);
$hosts = drsm_load_hosts($scope);
$alltiers = drsm_tiers($hosts);
$tier = drsm_tier_from_request();
$hosts = drsm_tier_filter($hosts, $tier);
$overall = "OK";
foreach($hosts as $hst) $overall = drsm_worst($overall, $hst["state"]);

drsm_page_start("Hosts", "hosts", $overall);
?>
<section class="page-head">
  <div>
    <h1>System health check reports</h1>
    <p class="muted"><?php echo count($hosts); ?> host<?php echo count($hosts) == 1 ? "" : "s"; ?><?php if(drsm_multi_site()) echo " in " . h(drsm_scope_label($scope)); ?>. Select a column to sort, select a host for its full report.</p>
  </div>
  <div class="head-actions filters" data-filter-scope="host-table">
    <label class="search"><?php echo drsm_icon("search"); ?><span class="sr">Search hosts</span><input type="search" placeholder="Search hosts" data-filter-text autocomplete="off"></label>
    <?php echo drsm_tier_buttons($alltiers, $tier, function($t) { return drsm_url("reports.php", array("tier" => $t)); }); ?>
  </div>
</section>

<section class="panel flush">
<?php if(count($hosts) == 0) { ?>
  <div class="empty"><p>No hosts have posted a report to <code><?php echo h("{$REPORTdir}/systems"); ?></code> yet.</p></div>
<?php } else { ?>
  <div class="table-wrap">
    <table class="table sortable" id="host-table">
      <thead>
        <tr>
          <th scope="col" data-sort="text">Host</th>
          <th scope="col" data-sort="num" class="sorted-desc">State</th>
<?php if($multi) { ?>
          <th scope="col" data-sort="text" class="hide-md">Organization</th>
          <th scope="col" data-sort="text" class="hide-sm">Site</th>
<?php } ?>
          <th scope="col" data-sort="text" class="hide-sm">Description</th>
          <th scope="col" data-sort="text" class="hide-md">Tier</th>
          <th scope="col" data-sort="num" class="hide-sm">Checks</th>
          <th scope="col" data-sort="num" class="hide-md num">CPU</th>
          <th scope="col" data-sort="num" class="hide-md num">Memory</th>
          <th scope="col" data-sort="num" class="hide-md num">Disk</th>
          <th scope="col" data-sort="num">Last report</th>
        </tr>
      </thead>
      <tbody>
<?php   foreach($hosts as $hst) {
          $nok = 0; $nwarn = 0; $nerr = 0;
          foreach($hst["plugins"] as $p) {
            if($p["state"] == "ERROR") $nerr++;
            else if($p["state"] == "WARNING") $nwarn++;
            else $nok++;
          } ?>
        <tr class="row-<?php echo h(drsm_state_class($hst["state"])); ?>" data-state="<?php echo h($hst["state"]); ?>" data-group="<?php echo h($hst["group"]); ?>" data-text="<?php echo h(strtolower($hst["name"] . " " . $hst["description"] . " " . $hst["group"] . ($multi ? " " . $hst["site"] . " " . drsm_site_label($hst["site"]) : ""))); ?>">
          <td data-v="<?php echo h($hst["name"]); ?>"><a class="strong" href="<?php echo h(drsm_host_url("readreport.php", $hst)); ?>"><?php echo h($hst["name"]); ?></a><span class="show-md-inline"><?php echo drsm_tier_badge($hst["group"]); ?></span><div class="show-sm muted small"><?php echo h(implode(" - ", array_filter(array($multi ? drsm_site_label($hst["site"]) : "", $hst["description"]), "strlen"))); ?></div></td>
          <td data-v="<?php echo drsm_state_rank($hst["state"]); ?>"><?php echo drsm_badge($hst["state"]); ?></td>
<?php     if($multi) {
            $st = drsm_all_sites();
            $st = isset($st[$hst["site"]]) ? $st[$hst["site"]] : array("orgname" => "", "name" => $hst["site"]); ?>
          <td class="hide-md" data-v="<?php echo h($st["orgname"]); ?>"><?php echo h($st["orgname"]); ?></td>
          <td class="hide-sm" data-v="<?php echo h($st["name"]); ?>"><a href="<?php echo h(drsm_url("reports.php", array("site" => $hst["site"]))); ?>"><?php echo h($st["name"]); ?></a></td>
<?php     } ?>
          <td class="hide-sm" data-v="<?php echo h($hst["description"]); ?>"><?php echo h($hst["description"]); ?><?php if($hst["note"] != "") echo "<div class=\"small muted\">" . h($hst["note"]) . "</div>"; ?></td>
          <td class="hide-md" data-v="<?php echo h(drsm_tier_id($hst["group"])); ?>"><?php echo drsm_tier_badge($hst["group"]); ?></td>
          <td class="hide-sm" data-v="<?php echo $nerr * 10000 + $nwarn * 100 + $nok; ?>">
<?php     if(count($hst["plugins"]) == 0) { ?>
            <span class="muted">&ndash;</span>
<?php     } else { ?>
            <span class="tally"><?php if($nerr) echo "<span class=\"err\">" . (int)$nerr . "</span>"; ?><?php if($nwarn) echo "<span class=\"warn\">" . (int)$nwarn . "</span>"; ?><?php if($nok || (!$nerr && !$nwarn)) echo "<span class=\"ok\">" . (int)$nok . "</span>"; ?></span>
<?php     } ?>
          </td>
<?php     foreach(array("cpu", "mem", "disk") as $key) {
            $mt = isset($hst["metrics"][$key]) ? $hst["metrics"][$key] : null; ?>
          <td class="hide-md num" data-v="<?php echo $mt ? round($mt["pct"], 1) : -1; ?>"><?php echo $mt ? "<span class=\"mval h" . drsm_heat_level($mt["pct"]) . "\">" . h($mt["text"]) . "</span>" : "<span class=\"muted\">&ndash;</span>"; ?></td>
<?php     } ?>
          <td data-v="<?php echo (int)$hst["time"]; ?>"><?php echo drsm_time_html($hst["time"]); ?></td>
        </tr>
<?php   } ?>
      </tbody>
    </table>
  </div>
  <p class="empty filtered" hidden>No hosts match the filter.</p>
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
