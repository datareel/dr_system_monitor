<?php
// ------------------------------- //
// -------- Start of File -------- //
// ------------------------------- //
// ----------------------------------------------------------- //
// PHP Source Code File
// PHP Version: 7.2 or higher, tested with PHP 8
// Original Author(s): DataReel Software Development
// File Creation Date: 10/24/2026
// Date Last Modified: 10/24/2026
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

DRSM archived reports, read through PHP so the login in drsm_auth.php
covers them. The pages link here instead of the report directory
listings when $AUTHenable is set. Lists the group archive, or a
host's archive (h=host), and shows one file (f=file).
*/
// ----------------------------------------------------------- //
// SCRIPT CONTENT STARTS BELOW.

require_once("../config/drsm.php");

// Our required includes
require_once("{$WWWdir}/php/query_post_validation.php");
require_once("{$WWWdir}/php/drsm_lib.php");

$host = isset($_GET['h']) ? CleanQueryAsString($_GET['h'], 255) : "";
$site = (isset($_GET['site']) && is_string($_GET['site'])) ? strtolower($_GET['site']) : "";
if($host != "") {
  // A host's archive: only plain names, in a site this visitor may see
  $res = drsm_resolve_host($host, $site);
  if($res["status"] == "ambiguous") {
    drsm_ambiguous_page($res, "archive.php", "h");
    exit;
  }
  $host = $res["name"];
  $site = $res["site"];
}
else {
  // The group archive of one site
  $visible = drsm_sites();
  if(!drsm_valid_site($site) || !isset($visible[$site])) $site = isset($visible[DRSM_LEGACY_SITE]) ? DRSM_LEGACY_SITE : (string)key($visible);
}
$prefix = isset($_GET['p']) ? CleanQueryAsString($_GET['p'], 128) : "";
if(!preg_match('/^[A-Za-z0-9_-]+$/', $prefix)) $prefix = "";
$file = isset($_GET['f']) ? CleanQueryAsString($_GET['f'], 255) : "";
// A plain file name in the archive folder, nothing with a path
if(!preg_match('/^[A-Za-z0-9][A-Za-z0-9._-]*\.txt$/', $file) || strpos($file, "..") !== false) $file = "";

$sitearg = ($site != DRSM_LEGACY_SITE) ? array("site" => $site) : array();
if($site == "") $dir = "";
else if($host != "") $dir = drsm_site_dir($site) . "/systems/{$host}/archive";
else $dir = ($site == DRSM_LEGACY_SITE) ? $REPORTarchive : drsm_site_dir($site) . "/archive";
$title = ($host != "") ? "{$host} archived reports" : "Archived reports";
if($host == "" && $site != DRSM_LEGACY_SITE && $site != "") $title = drsm_site_label($site) . " archived reports";
$back = ($host != "") ? drsm_url("readreport.php", array("n" => $host) + $sitearg) : drsm_url("checks.php", $sitearg);
$backlabel = ($host != "") ? $host : "Connectivity";

$files = array();
if($dir != "" && is_dir($dir)) {
  foreach(scandir($dir) ?: array() as $name) {
    if(!preg_match('/^[A-Za-z0-9][A-Za-z0-9._-]*\.txt$/', $name)) continue;
    if($prefix != "" && strpos($name, $prefix) !== 0) continue;
    $files[$name] = (int)@filemtime("{$dir}/{$name}");
  }
}
arsort($files);

if($file != "") {
  // Only files the listing would show, read from the folder itself
  if(!isset($files[$file])) $file = "";
}

if($file != "") {
  $lines = drsm_read_lines("{$dir}/{$file}");
  drsm_page_start($file, ($host != "") ? "hosts" : "checks");
?>
<nav class="crumbs" aria-label="Breadcrumb"><a href="<?php echo h(drsm_url("archive.php", array_filter(array("h" => $host, "p" => $prefix)) + $sitearg)); ?>"><?php echo drsm_icon("back"); ?><?php echo h($title); ?></a></nav>
<section class="page-head">
  <div>
    <h1 class="truncate"><?php echo h($file); ?></h1>
    <p class="muted">Archived <?php echo drsm_time_html(drsm_demo_time((int)@filemtime("{$dir}/{$file}"))); ?></p>
  </div>
</section>
<section class="panel">
  <pre class="report"><?php
  foreach($lines ?: array() as $line) {
    $lvl = drsm_line_level($line);
    $cls = ($lvl == "INFO") ? "info" : (($lvl == "ERROR" || $lvl == "WARNING" || $lvl == "UNKNOWN") ? drsm_state_class($lvl) : "");
    echo ($cls != "") ? "<span class=\"l-{$cls}\">" . h($line) . "</span>\n" : h($line) . "\n";
  } ?></pre>
</section>
<?php
  drsm_page_end();
  exit;
}

drsm_page_start($title, ($host != "") ? "hosts" : "checks");
?>
<nav class="crumbs" aria-label="Breadcrumb"><a href="<?php echo h($back); ?>"><?php echo drsm_icon("back"); ?><?php echo h($backlabel); ?></a></nav>
<section class="page-head">
  <div>
    <h1><?php echo h($title); ?></h1>
    <p class="muted"><?php echo count($files); ?> file<?php echo count($files) == 1 ? "" : "s"; ?><?php if($prefix != "") { ?> starting with <code><?php echo h($prefix); ?></code> &middot; <a href="<?php echo h(drsm_url("archive.php", array_filter(array("h" => $host)) + $sitearg)); ?>">show all</a><?php } ?></p>
  </div>
</section>
<section class="panel flush">
<?php if(count($files) == 0) { ?>
  <div class="empty"><p>No archived reports yet.</p></div>
<?php } else { ?>
  <div class="table-wrap">
    <table class="table">
      <thead><tr><th scope="col">Report</th><th scope="col">Archived</th></tr></thead>
      <tbody>
<?php   foreach(array_slice($files, 0, 1000, true) as $name => $mtime) { ?>
        <tr>
          <td><a href="<?php echo h(drsm_url("archive.php", array_filter(array("h" => $host, "p" => $prefix, "f" => $name)) + $sitearg)); ?>"><?php echo h($name); ?></a></td>
          <td><?php echo drsm_time_html(drsm_demo_time($mtime)); ?></td>
        </tr>
<?php   } ?>
      </tbody>
    </table>
  </div>
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
