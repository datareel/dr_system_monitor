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

System reports processing script.
*/
// ----------------------------------------------------------- // 
// SCRIPT CONTENT STARTS BELOW.

require_once("../config/drsm.php");

// Our required includes
require_once("${WWWdir}/php/query_post_validation.php");

$dir = "${REPORTdir}/systems";
$myDirectory = opendir($dir);
while($entryName = readdir($myDirectory)) {
  $dirArray[] = $entryName;
}

closedir($myDirectory);
$indexCount = count($dirArray);

if(file_exists("${SITEincludes}/page_header.php")) {
  include_once("${SITEincludes}/page_header.php");
}
else {
  include_once("${WWWdir}/php/default_header.php");
}

sort($dirArray);
echo "<p><b>System Health Check Reports</b><br />\n";
for($index=0; $index < $indexCount; $index++) {
  $fname = "$dir/$dirArray[$index]/$dirArray[$index]_report.txt";
  if (substr("$dirArray[$index]", 0, 1) != "."){ // don't list hidden files                                                 
    if(!file_exists("$fname")) {
      echo "<li>$dirArray[$index] - <font color=\"red\">No report posted</font></li><br />\n";
      continue;
    }
    $fp = fopen("$fname", "r");
    if(!$fp) {
      echo "<li>$dirArray[$index] - <font color=\"red\">Cannot open system report</font></li><br />\n";
      continue;
    }

    $REPORT_TIME = "";
    $HOSTNAME = "";
    $DESCRIPTION = "";
    $IMPACT = "";
    $IS_WEB_SERVER = "";
    $WEBPROTOS = "";
    $IS_LINUX = "";
    $IS_CLUSTER_IP = "";
    $CAN_PING = "";
    $CAN_SSH = "";
    $has_errors = "0";
    $has_warnings = "0";

    while (($buffer = fgets($fp, 1024)) !== false) {

      if(strstr($buffer, "ERROR - ")) $has_errors = "1";
      if(strstr($buffer, "WARNING - ")) $has_warnings = "1";

      if(preg_match('/REPORT_TIME:/', $buffer)) {
	$outarr = preg_split('/:/', $buffer);
	$REPORT_TIME = $outarr[1];
      } 
      if(preg_match('/HOSTNAME:/', $buffer)) {
	$outarr = preg_split('/:/', $buffer);
	$HOSTNAME = $outarr[1];
      } 
      if(preg_match('/DESCRIPTION:/', $buffer)) {
	$outarr = preg_split('/:/', $buffer);
	$DESCRIPTION = $outarr[1];
      } 
      if(preg_match('/IMPACT:/', $buffer)) {
	$outarr = preg_split('/:/', $buffer);
	$IMPACT = $outarr[1];
      } 
      if(preg_match('/IS_WEB_SERVER:/', $buffer)) {
	$outarr = preg_split('/:/', $buffer);
	$IS_WEB_SERVER = $outarr[1];
      } 
      if(preg_match('/WEBPROTOS:/', $buffer)) {
	$outarr = preg_split('/:/', $buffer);
	$WEBPROTOS = $outarr[1];
      } 
      if(preg_match('/IS_LINUX:/', $buffer)) {
	$outarr = preg_split('/:/', $buffer);
	$IS_LINUX = $outarr[1];
      } 
      if(preg_match('/IS_CLUSTER_IP:/', $buffer)) {
	$outarr = preg_split('/:/', $buffer);
	$IS_CLUSTER_IP = $outarr[1];
      } 
      if(preg_match('/CAN_PING:/', $buffer)) {
	$outarr = preg_split('/:/', $buffer);
	$CAN_PING = $outarr[1];
      } 
      if(preg_match('/CAN_SSH:/', $buffer)) {
	$outarr = preg_split('/:/', $buffer);
	$CAN_SSH = $outarr[1];
      } 
    }
    fclose($fp);
    $status = "<img src=\"${WWWvpath}/images/circle2.jpg\" height=\"12\" width=\"12\">";
    if($has_warnings == "1") $status = "<img src=\"${WWWvpath}/images/circle3.jpg\" height=\"12\" width=\"12\">";
    if($has_errors == "1") $status = "<img src=\"${WWWvpath}/images/circle1.jpg\" height=\"12\" width=\"12\">";

    putenv("TZ=GMT");
    $lasttime = date("m/d/Y h:i A T", (int)$REPORT_TIME);

    echo "<li><a href=\"${WWWvpath}/php/readreport.php?n=$dirArray[$index]\" title=\"${lasttime}\">$dirArray[$index]</a> - ${DESCRIPTION} ${status}</li><br />\n";
  }
}

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

