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

System connectivity check processing script. Shows the group
connectivity report (default) or the group health report (r=health)
for a host group (g=group, default production).
*/
// ----------------------------------------------------------- //
// SCRIPT CONTENT STARTS BELOW.

require_once("../config/drsm.php");

// Our required includes
require_once("{$WWWdir}/php/query_post_validation.php");
require_once("{$WWWdir}/php/drsm_lib.php");

$kind = (isset($_GET['r']) && $_GET['r'] == "health") ? "health" : "check";
$group = isset($_GET['g']) ? CleanQueryAsString($_GET['g'], 64) : "production";
if(!preg_match('/^[A-Za-z0-9-]+$/', $group)) $group = "production";

// The site whose group reports are shown: site= when it names a site
// this visitor may see, else the first site in the picked scope. The
// choice here does not change the picked scope.
$visible = drsm_sites();
$scopesites = drsm_scope_sites(drsm_scope());
$site = (isset($_GET['site']) && is_string($_GET['site'])) ? strtolower($_GET['site']) : "";
if(!drsm_valid_site($site) || !isset($visible[$site])) $site = (string)key($scopesites);
if(!isset($scopesites[$site]) && isset($visible[$site])) $scopesites[$site] = $visible[$site];
$sitearg = ($site != DRSM_LEGACY_SITE) ? array("site" => $site) : array();

$fname = drsm_group_report_file($kind, $group, $site);
$rep = drsm_parse_report($fname);
$state = $rep["exists"] ? $rep["state"] : "ERROR";
$title = ($kind == "check") ? "Connectivity tests" : "Health checks";

$archprefix = ($kind == "check") ? (($group == "production") ? "system_check_report_" : "system_check_{$group}_report_")
                                 : (($group == "production") ? "system_health_report_" : "system_health_report_{$group}_");

$nerr = 0; $nwarn = 0;
foreach($rep["messages"] as $msg) {
  if($msg["level"] == "ERROR") $nerr++;
  if($msg["level"] == "WARNING") $nwarn++;
}

// Every group with a report of this kind, for the switcher
$tabs = array();
foreach(drsm_site_group_reports($site) as $gr) {
  if($gr["kind"] == $kind) $tabs[$gr["group"]] = $gr["state"];
}

function drsm_check_lines($lines)
{
  $out = "";
  foreach($lines as $line) {
    if(preg_match('/^=== (\S+) \[([A-Z]+)\] (\d+)s ===$/', $line, $m)) {
      $out .= "<span class=\"l-head " . h(drsm_state_class($m[2])) . "\">" . h($line) . "</span>\n";
      continue;
    }
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

drsm_page_start($title, ($kind == "check") ? "checks" : "overview", $state);
?>
<section class="page-head">
  <div>
    <h1><?php echo h($title); ?></h1>
    <p class="muted"><?php if(drsm_multi_site()) echo h(drsm_site_label($site)) . " &middot; "; ?><?php echo h(ucfirst($group)); ?> group<?php if($rep["exists"]) { ?> &middot; posted <?php echo drsm_time_html($rep["mtime"]); ?><?php } ?></p>
  </div>
  <div class="head-actions">
    <div class="seg" role="group" aria-label="Report">
      <a href="<?php echo h(drsm_url("checks.php", array("g" => $group) + $sitearg)); ?>"<?php if($kind == "check") echo ' class="active"'; ?>>Connectivity</a>
      <a href="<?php echo h(drsm_url("checks.php", array("r" => "health", "g" => $group) + $sitearg)); ?>"<?php if($kind == "health") echo ' class="active"'; ?>>Health</a>
    </div>
<?php if(count($scopesites) > 1) { ?>
    <form class="host-pick select" method="get" action="<?php echo h(drsm_url("checks.php")); ?>">
      <input type="hidden" name="r" value="<?php echo h($kind); ?>">
      <input type="hidden" name="g" value="<?php echo h($group); ?>">
      <label class="sr" for="check-site">Site</label>
      <select id="check-site" name="site" data-autosubmit>
<?php   foreach($scopesites as $sid => $st) { ?>
        <option value="<?php echo h($sid); ?>"<?php if($sid == $site) echo " selected"; ?>><?php echo h(drsm_site_label($sid)); ?></option>
<?php   } ?>
      </select>
      <noscript><button class="button" type="submit">Show</button></noscript>
    </form>
<?php } ?>
<?php if(count($tabs) > 1) { ?>
    <div class="seg" role="group" aria-label="Group">
<?php   foreach($tabs as $g => $st) { ?>
      <a href="<?php echo h(drsm_url("checks.php", array("r" => $kind, "g" => $g) + $sitearg)); ?>"<?php if($g == $group) echo ' class="active"'; ?>><span class="dot <?php echo h(drsm_state_class($st)); ?>"></span><?php echo h(ucfirst($g)); ?></a>
<?php   } ?>
    </div>
<?php } ?>
    <a class="button ghost" href="<?php echo h(drsm_archive_url("", $archprefix, $site)); ?>" title="Archived reports start with <?php echo h($archprefix); ?>"><?php echo drsm_icon("archive"); ?>Archived reports</a>
  </div>
</section>

<?php if(!$rep["exists"]) { ?>
<div class="callout err"><?php echo drsm_icon("alert"); ?><span>No <?php echo h(strtolower($title)); ?> report posted for the <?php echo h($group); ?> group.</span></div>
<?php } else { ?>
<section class="kpis small">
  <div class="kpi <?php echo h(drsm_state_class($state)); ?>"><span class="kpi-label">Status</span><span class="kpi-value"><?php echo h(drsm_state_label($state)); ?></span></div>
  <div class="kpi err"><span class="kpi-label">Errors</span><span class="kpi-value"><?php echo (int)$nerr; ?></span></div>
  <div class="kpi warn"><span class="kpi-label">Warnings</span><span class="kpi-value"><?php echo (int)$nwarn; ?></span></div>
  <div class="kpi"><span class="kpi-label">Checks</span><span class="kpi-value"><?php echo count($rep["sections"]) > 0 ? count($rep["sections"]) : "&ndash;"; ?></span></div>
</section>

<?php   if(count($rep["messages"]) > 0) { ?>
<section class="panel">
  <div class="panel-head"><h2><?php echo drsm_icon("alert"); ?>Problems</h2><span class="count"><?php echo count($rep["messages"]); ?></span></div>
  <ul class="alert-lines flat">
<?php     foreach($rep["messages"] as $msg) { ?>
    <li class="<?php echo h(drsm_state_class($msg["level"])); ?>"><span><?php if($msg["plugin"] != "") { ?><span class="chip-id"><?php echo h($msg["plugin"]); ?></span><?php } ?><?php echo h(preg_replace('/^(ERROR|WARNING|UNKNOWN) - /', "", $msg["text"])); ?></span></li>
<?php     } ?>
  </ul>
</section>
<?php   } ?>

<section class="panel">
  <div class="panel-head"><h2>Report</h2></div>
  <pre class="report"><?php echo drsm_check_lines(drsm_read_lines($fname) ?: array()); ?></pre>
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
