<?php
// ------------------------------- //
// -------- Start of File -------- //
// ------------------------------- //
// ----------------------------------------------------------- //
// PHP Source Code File
// PHP Version: 5.1.6 or higher
// Original Author(s): DataReel Software Development 
// File Creation Date: 05/25/2013
// Date Last Modified: 05/02/2017
//
// Version control: 1.09
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

DRSM index page.
*/
// ----------------------------------------------------------- // 
// SCRIPT CONTENT STARTS BELOW.

require_once("../config/drsm.php");

  // Our required includes
require_once("${WWWdir}/php/query_post_validation.php");

function CheckServerStatus($servername, &$status, &$has_errors, &$has_warnings)
{
  $fname = "${REPORTdir}/systems/${servername}/${servername}_report.txt";
  $has_errors = "0";
  $has_warnings = "0";
  $status = "ERROR - ${servername} not reporting";
  if(!file_exists("${fname}")) return 0;
  $fp = fopen("$fname", "r");
  if(!$fp) return 0;
  if($fp) {
    while (($buffer = fgets($fp, 1024)) !== false) {
      if(strstr($buffer, "ERROR - ")) $has_errors = "1";
      if(strstr($buffer, "WARNING - ")) $has_warnings = "1";
    }
    fclose($fp);
  }
  $status = "<img src=\"${WWWvpath}/images/circle2.jpg\" height=\"12\" width=\"12\">";
  if($has_warnings == "1") $status = "<img src=\"${WWWvpath}/images/circle3.jpg\" height=\"12\" width=\"12\">";
  if($has_errors == "1") $status = "<img src=\"${WWWvpath}/images/circle1.jpg\" height=\"12\" width=\"12\">";
    return 1;
}

if(file_exists("${SITEincludes}/page_header.php")) {
  include_once("${SITEincludes}/page_header.php");
}
else {
  include_once("${WWWdir}/php/default_header.php");
}

echo "<b>All systems connectivity tests</b><br />\n";
echo "<ul>\n";
$fname = "${REPORTdir}/system_check_report.txt";
$has_errors = "0";
$has_warnings = "0";
if(file_exists("${fname}")) {
$fp = fopen("$fname", "r");
if($fp) {
  while (($buffer = fgets($fp, 1024)) !== false) {
    if(strstr($buffer, "ERROR - ")) $has_errors = "1";
    if(strstr($buffer, "WARNING - ")) $has_warnings = "1";
  }
  fclose($fp);
}
else {
     $has_errors = 1;
}
}
else {
     $has_errors = 1;
}

$status = "<img src=\"${WWWvpath}/images/circle2.jpg\" height=\"12\" width=\"12\">";
if($has_warnings == "1") $status = "<img src=\"${WWWvpath}/images/circle3.jpg\" height=\"12\" width=\"12\">";
if($has_errors == "1") $status = "<img src=\"${WWWvpath}/images/circle1.jpg\" height=\"12\" width=\"12\">";
echo "<li><a href=\"${WWWvpath}/php/checks.php\">Systems Connectivity Tests</a> ${status}</li>\n";
echo "</ul>\n";

echo "<b>All systems health checks</b><br />\n";
echo "<ul>\n";
$fname = "${REPORTdir}/system_health_report.txt";
$has_errors = "0";
$has_warnings = "0";
if(file_exists("${fname}")) {
$fp = fopen("$fname", "r");
if($fp) {
  while (($buffer = fgets($fp, 1024)) !== false) {
    if(strstr($buffer, "ERROR - ")) $has_errors = "1";
    if(strstr($buffer, "WARNING - ")) $has_warnings = "1";
  }
  fclose($fp);
}
else {
     $has_errors = 1;
}
}
else {
     $has_errors = 1;
}

$status = "<img src=\"${WWWvpath}/images/circle2.jpg\" height=\"12\" width=\"12\">";
if($has_warnings == "1") $status = "<img src=\"${WWWvpath}/images/circle3.jpg\" height=\"12\" width=\"12\">";
if($has_errors == "1") $status = "<img src=\"${WWWvpath}/images/circle1.jpg\" height=\"12\" width=\"12\">";
echo "<li><a href=\"${WWWvpath}/php/reports.php\">Systems Reporting Page</a> ${status}</li>\n";
echo "</ul>\n";

if(file_exists("${SITEincludes}/page_footer.php")) {
  include_once("${SITEincludes}/page_footer.php");
}
else {
  include_once("${WWWdir}/php/default_footer.php");   
}

// SCRIPT CONTENT ENDS ABOVE.
// ----------------------------------------------------------- //
// ------------------------------- //
// --------- End of File --------- //
// ------------------------------- //
?>

