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

System report processing script.
*/
// ----------------------------------------------------------- // 
// SCRIPT CONTENT STARTS BELOW.

require_once("../config/drsm.php");

  // Our required includes
require_once("{$WWWdir}/php/query_post_validation.php");

$n = isset($_GET['n']) ? CleanQueryAsString($_GET['n'], 255) : "";

// Only accept a plain host name, this blocks ../ path traversal
if(!preg_match('/^[A-Za-z0-9][A-Za-z0-9._-]*$/', $n) || strpos($n, "..") !== false) {
  $n = "";
}

$dir = "{$REPORTdir}/systems";
$fname = "{$dir}/{$n}/{$n}_report.txt";

if(file_exists("{$SITEincludes}/page_header.php")) {
  include_once("{$SITEincludes}/page_header.php");
}
else {
  include_once("{$WWWdir}/php/default_header.php");
}

if(($n == "") || !file_exists("{$fname}")) {
  http_response_code(404);
  echo "<p><b>ERROR - Request is not a valid server</b></p>\n";
  echo "<p>Check all required input variables</p>\n";
}
else {
  $host = htmlspecialchars($n);
  echo "<p><b>{$host} Health Check Report</b><br />\n";
  echo "<a href=\"{$REPORTvpath}/systems/{$host}/archive\">Archived Reports</a><br /><br />\n";
  // Print the report as text. The report holds remote command output,
  // so escape it and never include() it as PHP code.
  echo "<pre>\n";
  echo htmlspecialchars(file_get_contents($fname));
  echo "</pre>\n";
}

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

