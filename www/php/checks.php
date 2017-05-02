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

System connectivity check processing script.
*/
// ----------------------------------------------------------- // 
// SCRIPT CONTENT STARTS BELOW.

require_once("../config/drsm.php");

$fname = "${REPORTdir}/system_check_report.txt";

if(file_exists("${SITEincludes}/page_header.php")) {
  include_once("${SITEincludes}/page_header.php");
}
else {
  include_once("${WWWdir}/php/default_header.php");
}

echo "<p><b>Connectivity tests</b><br />\n";

if(file_exists("$fname")) {

echo "<a href=\"${REPORTarchivevpath}\">Archived Reports</a><br /><br />\n";

echo "<pre>\n";
include("$fname");
echo "</pre>\n";
}
else {
  echo "<p><font color=\"red\">No system check file posted</font></p>\n";
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

