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

External reports page: the reports listed in $EXTreports with their
state (?s=<section> for one section), or one report file shown in the
dashboard (?v=<id>). Only files listed in $EXTreports can be shown.
See drsm_ext.php for the file format.
*/
// ----------------------------------------------------------- //
// SCRIPT CONTENT STARTS BELOW.

require_once("../config/drsm.php");

// Our required includes
require_once("{$WWWdir}/php/query_post_validation.php");
require_once("{$WWWdir}/php/drsm_lib.php");

$sections = drsm_ext_sections();
$sid = isset($_GET["s"]) ? strtolower((string)$_GET["s"]) : "";
$vid = isset($_GET["v"]) ? (string)$_GET["v"] : "";
if($sid != "" && !isset($sections[$sid])) $sid = "";

function drsm_ext_lines($lines)
{
  $out = "";
  foreach($lines as $line) {
    $cls = "";
    if(strpos($line, "ERROR") !== false || strpos($line, "FAILED") !== false) $cls = "l-err";
    else if(strpos($line, "WARNING") !== false) $cls = "l-warn";
    else if(strpos($line, "INFO") === 0) $cls = "l-info";
    $out .= ($cls != "") ? "<span class=\"{$cls}\">" . h($line) . "</span>\n" : h($line) . "\n";
  }
  return $out;
}

// One report in the dashboard
if($vid != "") {
  $it = drsm_ext_find($vid);
  if($it === null || $it["file"] == "" || !is_file($it["file"])) {
    http_response_code(404);
    drsm_page_start($EXTtitle, "ext", "UNKNOWN");
    echo "<div class=\"callout err\">" . drsm_icon("alert") . "<span>No such report.</span></div>\n";
    drsm_page_end();
    exit;
  }
  $st = drsm_ext_state($it);
  $back = drsm_url("extreports.php", array("s" => substr($it["id"], 0, strrpos($it["id"], "-"))));
  drsm_page_start($it["title"], "ext", $st["state"]);
?>
<section class="page-head">
  <div>
    <h1><?php echo h($it["title"]); ?></h1>
    <p class="muted"><?php echo h(basename($it["file"])); ?><?php if($st["time"] > 0) { ?> &middot; updated <?php echo drsm_time_html($st["time"]); ?><?php } ?></p>
  </div>
  <div class="head-actions">
    <?php if($st["state"] != "") echo drsm_badge($st["state"]); ?>
    <a class="button ghost" href="<?php echo h($back); ?>"><?php echo drsm_icon("back"); ?>All reports</a>
  </div>
</section>
<?php if($st["note"] != "") { ?>
<div class="callout <?php echo h(drsm_state_class($st["state"])); ?>"><?php echo drsm_icon("alert"); ?><span><?php echo h($st["note"]); ?></span></div>
<?php } ?>
<section class="panel">
  <pre class="report"><?php echo drsm_ext_lines(drsm_read_lines($it["file"]) ?: array()); ?></pre>
</section>
<?php
  drsm_page_end();
  exit;
}

$show = ($sid != "") ? array($sid => $sections[$sid]) : $sections;
$overall = "OK";
$rows = array();
foreach($show as $id => $sec) {
  foreach($sec["items"] as $it) {
    $st = drsm_ext_state($it);
    if($st["state"] != "") $overall = drsm_worst($overall, $st["state"]);
    $rows[$id][] = array("it" => $it, "st" => $st);
  }
}
drsm_page_start(($sid != "") ? $sections[$sid]["title"] : $EXTtitle, "ext", $overall);
?>
<section class="page-head">
  <div>
    <h1><?php echo h(($sid != "") ? $sections[$sid]["title"] : $EXTtitle); ?></h1>
    <p class="muted">Reports written by other scripts</p>
  </div>
<?php if(count($sections) > 1) { ?>
  <div class="head-actions">
    <div class="seg" role="group" aria-label="Section">
      <a href="<?php echo h(drsm_url("extreports.php")); ?>"<?php if($sid == "") echo ' class="active"'; ?>>All</a>
<?php   foreach($sections as $id => $sec) {
          $sum = drsm_ext_summary($sec); ?>
      <a href="<?php echo h(drsm_url("extreports.php", array("s" => $id))); ?>"<?php if($sid == $id) echo ' class="active"'; ?>><?php if($sum["state"] != "") { ?><span class="dot <?php echo h(drsm_state_class($sum["state"])); ?>"></span><?php } ?><?php echo h($sec["title"]); ?></a>
<?php   } ?>
    </div>
  </div>
<?php } ?>
</section>
<?php if(count($sections) == 0) { ?>
<div class="callout"><?php echo drsm_icon("alert"); ?><span>No reports are set up. Set <code>$EXTreports</code> in config/drsm.php, see php/drsm_ext.php.</span></div>
<?php } ?>
<?php foreach($show as $id => $sec) { ?>
<section class="panel flush" id="<?php echo h($id); ?>">
  <div class="panel-head pad"><h2><?php echo drsm_icon("file"); ?><?php echo h($sec["title"]); ?></h2><span class="count"><?php echo count($sec["items"]); ?></span></div>
  <div class="table-wrap">
    <table class="table ext-table">
      <thead>
        <tr>
          <th scope="col">Report</th>
          <th scope="col">State</th>
          <th scope="col" class="hide-sm">Updated</th>
        </tr>
      </thead>
      <tbody>
<?php   foreach(isset($rows[$id]) ? $rows[$id] : array() as $r) {
          $it = $r["it"];
          $st = $r["st"];
          $href = drsm_ext_href($it); ?>
        <tr<?php if($st["state"] != "") echo ' class="row-' . h(drsm_state_class($st["state"])) . '"'; ?>>
          <td><?php if($href != "") { ?><a class="strong" href="<?php echo h($href); ?>"><?php echo h($it["title"]); ?></a><?php } else { ?><span class="strong"><?php echo h($it["title"]); ?></span><?php } ?><?php if($st["note"] != "") { ?><div class="small muted"><?php echo h($st["note"]); ?></div><?php } ?></td>
          <td><?php echo ($st["state"] != "") ? drsm_badge($st["state"]) : "<span class=\"muted\">Link</span>"; ?></td>
          <td class="hide-sm"><?php echo ($st["time"] > 0) ? drsm_time_html($st["time"]) : "<span class=\"muted\">&ndash;</span>"; ?></td>
        </tr>
<?php   } ?>
      </tbody>
    </table>
  </div>
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
