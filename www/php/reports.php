<?php
// ------------------------------- //
// -------- Start of File -------- //
// ------------------------------- //
// ----------------------------------------------------------- //
// PHP Source Code File
// PHP Version: 7.4 or higher, tested with PHP 8
// Original Author(s): DataReel Software Development 
// File Creation Date: 05/25/2013
// Date Last Modified: 10/23/2026
//
// Version control: 1.10
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

System reports processing script.
*/
// ----------------------------------------------------------- // 
// SCRIPT CONTENT STARTS BELOW.

require_once("../config/drsm.php");

// Our required includes
require_once("{$WWWdir}/php/query_post_validation.php");

$dir = "{$REPORTdir}/systems";
$dirArray = array();
if(is_dir($dir)) {
  foreach(scandir($dir) as $entryName) {
    // Skip hidden files and anything that is not a host directory
    if(substr($entryName, 0, 1) == ".") continue;
    if(!is_dir("{$dir}/{$entryName}")) continue;
    $dirArray[] = $entryName;
  }
}

if(file_exists("{$SITEincludes}/page_header.php")) {
  include_once("{$SITEincludes}/page_header.php");
}
else {
  include_once("{$WWWdir}/php/default_header.php");
}

// Report times are stored as UNIX epoch seconds in the ETIME field
date_default_timezone_set("UTC");

sort($dirArray);
echo "<p><b>System Health Check Reports</b></p>\n";
echo "<ul>\n";
foreach($dirArray as $hostdir) {
  $fname = "{$dir}/{$hostdir}/{$hostdir}_report.txt";
  $host = htmlspecialchars($hostdir);
  if(!file_exists("$fname")) {
    echo "<li>{$host} - <font color=\"red\">No report posted</font></li>\n";
    continue;
  }
  $fp = fopen("$fname", "r");
  if(!$fp) {
    echo "<li>{$host} - <font color=\"red\">Cannot open system report</font></li>\n";
    continue;
  }

  $fields = array("ETIME" => "", "DESCRIPTION" => "");
  $has_errors = "0";
  $has_warnings = "0";

  while (($buffer = fgets($fp, 4096)) !== false) {
    if(strstr($buffer, "ERROR - ")) $has_errors = "1";
    if(strstr($buffer, "WARNING - ")) $has_warnings = "1";

    // Header fields are NAME:value, split on the first colon only
    // since values such as descriptions can contain colons
    $outarr = explode(":", rtrim($buffer, "\r\n"), 2);
    if((count($outarr) == 2) && array_key_exists($outarr[0], $fields) && ($fields[$outarr[0]] == "")) {
      $fields[$outarr[0]] = trim($outarr[1]);
    }
  }
  fclose($fp);
  $status = "<img src=\"{$WWWvpath}/images/circle2.jpg\" height=\"12\" width=\"12\" alt=\"OK\">";
  if($has_warnings == "1") $status = "<img src=\"{$WWWvpath}/images/circle3.jpg\" height=\"12\" width=\"12\" alt=\"Warning\">";
  if($has_errors == "1") $status = "<img src=\"{$WWWvpath}/images/circle1.jpg\" height=\"12\" width=\"12\" alt=\"Error\">";

  $lasttime = "unknown";
  if(ctype_digit($fields["ETIME"])) $lasttime = date("m/d/Y h:i A T", (int)$fields["ETIME"]);
  $description = htmlspecialchars($fields["DESCRIPTION"]);

  echo "<li><a href=\"{$WWWvpath}/php/readreport.php?n=" . urlencode($hostdir) . "\" title=\"Last report {$lasttime}\">{$host}</a> - {$description} {$status}</li>\n";
}
echo "</ul>\n";

if(file_exists("{$SITEincludes}/page_footer.php")) {
  include_once("{$SITEincludes}/page_footer.php");
}
else {
  include_once("{$WWWdir}/php/default_footer.php");   
}

// SCRIPT CONTENT ENDS ABOVE.
// ----------------------------------------------------------- //
// ------------------------------- //
// --------- End of File --------- //
// ------------------------------- //
?>

