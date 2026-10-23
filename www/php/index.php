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

DRSM situational awareness page: overall state, host counts, group
checks, the problems that need attention, and a card for every host.
*/
// ----------------------------------------------------------- //
// SCRIPT CONTENT STARTS BELOW.

require_once("../config/drsm.php");

// Our required includes
require_once("{$WWWdir}/php/query_post_validation.php");
require_once("{$WWWdir}/php/drsm_lib.php");

$hosts = drsm_load_hosts();
$counts = drsm_host_counts($hosts);
$groupreports = drsm_group_reports();
$groups = drsm_groups($hosts);

$overall = "OK";
foreach($hosts as $hst) $overall = drsm_worst($overall, $hst["state"]);
foreach($groupreports as $gr) $overall = drsm_worst($overall, $gr["state"]);
if(count($hosts) == 0) $overall = "UNKNOWN";

$latest = 0;
foreach($hosts as $hst) if($hst["time"] > $latest) $latest = $hst["time"];

// Problems first, worst host first
$problems = array();
foreach($hosts as $hst) {
  $msgs = array();
  foreach($hst["report"]["messages"] as $msg) {
    if($msg["level"] == "ERROR" || $msg["level"] == "WARNING") $msgs[] = $msg;
  }
  if($hst["note"] != "") $msgs[] = array("level" => $hst["stale"] ? "STALE" : "ERROR", "text" => $hst["note"], "plugin" => "");
  if(count($msgs) > 0) $problems[] = array("host" => $hst, "msgs" => $msgs);
}
usort($problems, function($a, $b) {
  $d = drsm_state_rank($b["host"]["state"]) - drsm_state_rank($a["host"]["state"]);
  return ($d != 0) ? $d : strcmp($a["host"]["name"], $b["host"]["name"]);
});

$bad = $counts["ERROR"] + $counts["WARNING"] + $counts["STALE"];
if(count($hosts) == 0) {
  $headline = "No host reports yet";
  $subline = "Run bin/drsm_run.sh or system_report.sh to post the first reports.";
}
else if($overall == "OK") {
  $headline = "All systems operational";
  $subline = "{$counts["total"]} hosts and {$counts["checks"]} checks are reporting normally.";
}
else if($bad == 0) {
  $headline = "Group checks need attention";
  $subline = "Every host checks good, but a connectivity or health report has problems.";
}
else {
  $headline = ($bad == 1) ? "1 host needs attention" : "{$bad} hosts need attention";
  $parts = array();
  if($counts["ERROR"] > 0) $parts[] = "{$counts["ERROR"]} in error";
  if($counts["WARNING"] > 0) $parts[] = "{$counts["WARNING"]} with warnings";
  if($counts["STALE"] > 0) $parts[] = "{$counts["STALE"]} not reporting";
  $subline = ucfirst(implode(", ", $parts)) . ", out of {$counts["total"]} hosts.";
}

// Host cards, worst first so problems are seen first
$cards = $hosts;
uasort($cards, function($a, $b) {
  $d = drsm_state_rank($b["state"]) - drsm_state_rank($a["state"]);
  return ($d != 0) ? $d : strcmp($a["name"], $b["name"]);
});

$metriccols = drsm_metric_columns();

drsm_page_start("Overview", "overview", $overall);
?>
<section class="hero <?php echo h(drsm_state_class($overall)); ?>">
  <div class="hero-status">
    <span class="pulse" aria-hidden="true"></span>
    <div>
      <h1><?php echo h($headline); ?></h1>
      <p><?php echo h($subline); ?></p>
    </div>
  </div>
  <div class="hero-meta">
    <span class="muted">Latest report</span>
    <strong><?php echo drsm_time_html($latest); ?></strong>
  </div>
</section>

<section class="kpis" aria-label="Host counts">
  <a class="kpi" href="#hosts" data-set-filter="all"><span class="kpi-label">Hosts</span><span class="kpi-value"><?php echo (int)$counts["total"]; ?></span><span class="kpi-sub"><?php echo count($groups); ?> group<?php echo count($groups) == 1 ? "" : "s"; ?></span></a>
  <a class="kpi ok" href="#hosts" data-set-filter="OK"><span class="kpi-label">Healthy</span><span class="kpi-value"><?php echo (int)$counts["OK"]; ?></span><span class="kpi-sub"><?php echo $counts["total"] ? round($counts["OK"] / $counts["total"] * 100) : 0; ?>% of hosts</span></a>
  <a class="kpi warn" href="#hosts" data-set-filter="WARNING"><span class="kpi-label">Warning</span><span class="kpi-value"><?php echo (int)$counts["WARNING"]; ?></span><span class="kpi-sub">hosts</span></a>
  <a class="kpi err" href="#hosts" data-set-filter="ERROR"><span class="kpi-label">Error</span><span class="kpi-value"><?php echo (int)$counts["ERROR"]; ?></span><span class="kpi-sub">hosts</span></a>
  <a class="kpi stale" href="#hosts" data-set-filter="STALE"><span class="kpi-label">Not reporting</span><span class="kpi-value"><?php echo (int)$counts["STALE"]; ?></span><span class="kpi-sub"><?php echo $STALEminutes > 0 ? "over " . h(drsm_age_text($STALEminutes * 60)) : "check off"; ?></span></a>
  <a class="kpi" href="<?php echo h(drsm_url("heatmap.php")); ?>"><span class="kpi-label">Checks failing</span><span class="kpi-value"><?php echo (int)$counts["checks_bad"]; ?></span><span class="kpi-sub">of <?php echo (int)$counts["checks"]; ?> plugin checks</span></a>
</section>

<div class="split">
  <section class="panel">
    <div class="panel-head">
      <h2><?php echo drsm_icon("alert"); ?>Needs attention</h2>
      <span class="count"><?php echo count($problems); ?></span>
    </div>
<?php if(count($problems) == 0) { ?>
    <div class="empty ok"><?php echo drsm_icon("check"); ?><p>Nothing needs attention right now.</p></div>
<?php } else { ?>
    <ul class="alerts">
<?php   foreach($problems as $pr) {
          $hst = $pr["host"];
          $shown = array_slice($pr["msgs"], 0, 4); ?>
      <li class="alert <?php echo h(drsm_state_class($hst["state"])); ?>">
        <a class="alert-host" href="<?php echo h(drsm_url("readreport.php", array("n" => $hst["name"]))); ?>">
          <?php echo drsm_badge($hst["state"]); ?>
          <strong><?php echo h($hst["name"]); ?></strong>
          <span class="muted truncate"><?php echo h($hst["description"]); ?></span>
        </a>
        <ul class="alert-lines">
<?php     foreach($shown as $msg) {
            $link = drsm_url("readreport.php", array("n" => $hst["name"])) . ($msg["plugin"] != "" ? "#" . drsm_plugin_anchor($msg["plugin"]) : ""); ?>
          <li class="<?php echo h(drsm_state_class($msg["level"])); ?>"><a href="<?php echo h($link); ?>"><?php if($msg["plugin"] != "") { ?><span class="chip-id"><?php echo h($msg["plugin"]); ?></span><?php } ?><?php echo h(preg_replace('/^(ERROR|WARNING) - /', "", $msg["text"])); ?></a></li>
<?php     } ?>
<?php     if(count($pr["msgs"]) > count($shown)) { ?>
          <li class="more"><a href="<?php echo h(drsm_url("readreport.php", array("n" => $hst["name"]))); ?>"><?php echo count($pr["msgs"]) - count($shown); ?> more</a></li>
<?php     } ?>
        </ul>
      </li>
<?php   } ?>
    </ul>
<?php } ?>
  </section>

  <aside class="side">
    <section class="panel">
      <div class="panel-head"><h2><?php echo drsm_icon("net"); ?>Group checks</h2></div>
      <ul class="group-list">
<?php foreach($groupreports as $gr) {
        $label = ($gr["kind"] == "check") ? "Connectivity" : "Health checks";
        $url = ($gr["kind"] == "check") ? drsm_url("checks.php", $gr["group"] == "production" ? array() : array("g" => $gr["group"]))
                                        : drsm_url("checks.php", array("r" => "health", "g" => $gr["group"])); ?>
        <li>
          <a href="<?php echo h($url); ?>">
            <span class="dot-lg <?php echo h(drsm_state_class($gr["state"])); ?>" aria-hidden="true"></span>
            <span class="grow"><strong><?php echo h($label); ?></strong><span class="muted"><?php echo h(ucfirst($gr["group"])); ?> &middot; <?php echo $gr["exists"] ? drsm_time_html($gr["time"]) : "not posted"; ?></span></span>
            <?php echo drsm_badge($gr["state"]); ?>
          </a>
        </li>
<?php } ?>
      </ul>
    </section>

    <section class="panel">
      <div class="panel-head"><h2><?php echo drsm_icon("heat"); ?>Host matrix</h2><a class="link" href="<?php echo h(drsm_url("heatmap.php")); ?>">Heat map</a></div>
      <div class="matrix" role="list">
<?php foreach($hosts as $hst) { ?>
        <a role="listitem" class="cell <?php echo h(drsm_state_class($hst["state"])); ?>" href="<?php echo h(drsm_url("readreport.php", array("n" => $hst["name"]))); ?>" title="<?php echo h($hst["name"] . " - " . drsm_state_label($hst["state"]) . ($hst["description"] != "" ? " - " . $hst["description"] : "")); ?>"><span class="sr"><?php echo h($hst["name"]); ?></span></a>
<?php } ?>
      </div>
      <div class="legend">
        <span><i class="ok"></i>OK</span><span><i class="warn"></i>Warning</span><span><i class="err"></i>Error</span><span><i class="stale"></i>Stale</span><span><i class="unk"></i>Unknown</span>
      </div>
    </section>
  </aside>
</div>

<section class="panel" id="hosts">
  <div class="panel-head wrap">
    <h2><?php echo drsm_icon("grid"); ?>Hosts</h2>
    <div class="filters" data-filter-scope="host-cards">
      <label class="search"><?php echo drsm_icon("search"); ?><span class="sr">Search hosts</span><input type="search" placeholder="Search hosts" data-filter-text autocomplete="off"></label>
      <div class="seg" role="group" aria-label="Filter by state">
        <button type="button" data-filter-state="all" class="active">All</button>
        <button type="button" data-filter-state="problem">Problems</button>
        <button type="button" data-filter-state="ERROR">Error</button>
        <button type="button" data-filter-state="WARNING">Warning</button>
        <button type="button" data-filter-state="OK">OK</button>
      </div>
<?php if(count($groups) > 1) { ?>
      <label class="select"><span class="sr">Group</span>
        <select data-filter-group>
          <option value="">All groups</option>
<?php   foreach($groups as $g) { ?>
          <option value="<?php echo h($g); ?>"><?php echo h(ucfirst($g)); ?></option>
<?php   } ?>
        </select>
      </label>
<?php } ?>
    </div>
  </div>
<?php if(count($hosts) == 0) { ?>
  <div class="empty"><p>No hosts have posted a report to <code><?php echo h("{$REPORTdir}/systems"); ?></code> yet.</p></div>
<?php } ?>
  <div class="cards" id="host-cards">
<?php foreach($cards as $hst) { ?>
    <article class="card <?php echo h(drsm_state_class($hst["state"])); ?>" data-state="<?php echo h($hst["state"]); ?>" data-group="<?php echo h($hst["group"]); ?>" data-text="<?php echo h(strtolower($hst["name"] . " " . $hst["description"] . " " . $hst["group"] . " " . implode(" ", array_keys($hst["plugins"])))); ?>">
      <a class="card-link" href="<?php echo h(drsm_url("readreport.php", array("n" => $hst["name"]))); ?>">
        <header>
          <h3><?php echo h($hst["name"]); ?></h3>
          <?php echo drsm_badge($hst["state"]); ?>
        </header>
        <p class="desc"><?php echo $hst["description"] != "" ? h($hst["description"]) : "<span class=\"muted\">No description</span>"; ?></p>
<?php   if(isset($hst["metrics"]) && count($hst["metrics"]) > 0) { ?>
        <div class="bars">
<?php     foreach(array("cpu", "mem", "disk") as $key) {
            if(!isset($hst["metrics"][$key])) continue;
            $mt = $hst["metrics"][$key]; ?>
          <div class="bar" title="<?php echo h($metriccols[$key]["title"] . " " . $mt["text"] . (isset($mt["detail"]) && $mt["detail"] != "" ? " (" . $mt["detail"] . ")" : "")); ?>">
            <span class="bar-label"><?php echo h($metriccols[$key]["label"]); ?></span>
            <span class="bar-track"><span class="bar-fill h<?php echo drsm_heat_level($mt["pct"]); ?>" style="width:<?php echo max(2, min(100, round($mt["pct"]))); ?>%"></span></span>
            <span class="bar-value"><?php echo h($mt["text"]); ?></span>
          </div>
<?php     } ?>
        </div>
<?php   } ?>
<?php   if(count($hst["plugins"]) > 0) { ?>
        <ul class="chips">
<?php     foreach($hst["plugins"] as $id => $p) { ?>
          <li class="chip <?php echo h(drsm_state_class($p["state"])); ?>" title="<?php echo h($id . ": " . drsm_state_label($p["state"]) . (count($p["msgs"]) ? " - " . implode(" | ", $p["msgs"]) : "")); ?>"><span class="dot"></span><?php echo h(drsm_plugin_short($id)); ?></li>
<?php     } ?>
        </ul>
<?php   } else if($hst["note"] != "") { ?>
        <p class="note"><?php echo h($hst["note"]); ?></p>
<?php   } ?>
        <footer>
          <span class="tag"><?php echo h($hst["group"]); ?></span>
          <span class="muted"><?php echo drsm_time_html($hst["time"]); ?></span>
        </footer>
      </a>
    </article>
<?php } ?>
  </div>
  <p class="empty filtered" hidden>No hosts match the filter.</p>
</section>
<?php
drsm_page_end();

// SCRIPT CONTENT ENDS ABOVE.
// ----------------------------------------------------------- //
// ------------------------------- //
// --------- End of File --------- //
// ------------------------------- //
?>
