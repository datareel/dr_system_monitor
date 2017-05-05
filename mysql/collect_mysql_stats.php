<?php
// ------------------------------- //
// -------- Start of File -------- //
// ------------------------------- //
// ----------------------------------------------------------- //
// PHP Source Code File
// PHP Version: 5.1.6 or higher
// Original Author(s): DataReel Software Development 
// File Creation Date: 04/04/2013
// Date Last Modified: 05/05/2017
//
// Version control: 1.14
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

Collect and analyse database and table statistics.

*/
// ----------------------------------------------------------- // 
// SCRIPT CONTENT STARTS BELOW.

$cli_mode = false;
if ( isset($_SERVER['argc']) && $_SERVER['argc']>=1 ) {
  $cli_mode = true;
} 

if($cli_mode == false) {
  echo "ERROR - This utitliy can only be ran from command line PHP\n";
}

if($argc < 4) {
  echo 'ERROR - You must supply hostname, username, pw, $DRSMHOME, $VARdir, and $LOGdir to this script';
  echo "\n";
  echo "USAGE:\n";
  echo '       source ~/.drsm.sh';
  echo "\n";
  echo '       php collect_mysql_stats.php mysqlhost username \'pw\' $DRSMHOME $VARdir $LOGdir';
  echo "\n";
  exit(1);
}

$mysqlip = $argv[1];
$mysqluser = $argv[2];
$mysqlpass = $argv[3];

$DRSMHOME = $argv[4];
$VARdir = $argv[5];
$LOGdir = $argv[6];

$OUTPUTdir = "${VARdir}/collect_mysql_stats.tmp";
$logfile = "${LOGdir}/collect_mysql_stats_php.log";
$verbose = false;

if(!file_exists("${DRSMHOME}")) {
  echo "ERROR - Bad DRSMHOME, missing ${DRSMHOME}\n";
  exit(1);

}

if(!file_exists("${VARdir}")) mkdir("${VARdir}");
if(!file_exists("${LOGdir}")) mkdir("${LOGdir}");
if(!file_exists("${OUTPUTdir}")) mkdir("${OUTPUTdir}");

if(!file_exists("${VARdir}")) { 
  echo "ERROR - Cannot create DIR ${VARdir}\n";
  exit(1);
}

if(!file_exists("${LOGdir}")) { 
  echo "ERROR - Cannot create DIR ${LOGdir}\n";
  exit(1);
}

if(!file_exists("${OUTPUTdir}")) { 
  echo "ERROR - Cannot create DIR ${OUTPUTdir}\n";
  exit(1);
}

// NOTE: Add this line to all PHP script to get rid of timezone notice
date_default_timezone_set("UTC");

function WriteMySQLStat($host, $user, $pass, $ofname, $verbose)
{
  if($verbose) echo "Connecting to $host as user $user\n";
  if($verbose) echo "Writing stats output to $ofname\n";

  $fp = @fopen($ofname, "w") or die("Could not open $ofname\n");
  $link = mysql_connect($host, $user, $pass);
  if (!$link) die("\n\nCan not connect to Database Server\n\n");
  
  $array = explode("  ", mysql_stat());
  foreach ($array as $value){
    fputs($fp, "${value}\n");
  }
  
  $result = mysql_query('SHOW STATUS', $link);
  while ($row = mysql_fetch_assoc($result)) {
    $mesg = $row['Variable_name'] . ': ' . $row['Value'] . "\n";
    fputs($fp, "${mesg}");
  }
  if($verbose) echo "Stat collection complete\n";
  mysql_close($link);
  fclose($fp);

  $stat_array = array();
  $fp = fopen($ofname, "r");
  while (($row = fgetcsv($fp, 1000, ":")) !== FALSE) {
    $stat_array[$row[0]] = $row[1];
  }
  fclose($fp);
  return $stat_array;
}

function anaylze_stats($mysqlip, $stat_array)
{
  $stats_string = "MySQL flagged STATS for ${mysqlip} server:\n";
  $stats_sub_string = "\nMySQL non-zero value STATS for ${mysqlip} server:\n";
  $Key_read_requests = 0;
  $Key_reads = 0;
  
  foreach ($stat_array as $key => $value) {
    if($value > 0) {
      switch($key) {
	case "Uptime":
	  $NumOfDays = $value / 86400;
	  $days = floor($NumOfDays);
	  $value = $value % 86400;
	  $hours = gmdate("H",$value);
	  $minutes = gmdate("i",$value);
	  $seconds = gmdate("s",$value);
	  $stats_string .= "Uptime = $days Days, $hours Hours, $minutes Minutes, $seconds Seconds\n";
	  break;
	case "Uptime_since_flush_status":
	  $NumOfDays = $value / 86400;
	  $days = floor($NumOfDays);
	  $value = $value % 86400;
	  $hours = gmdate("H",$value);
	  $minutes = gmdate("i",$value);
	  $seconds = gmdate("s",$value);
	  $stats_string .= "Uptime since flush = $days Days, $hours Hours, $minutes Minutes, $seconds Seconds\n";
	  break;
	case "Connections":
	  $stats_string .= "${value} number of connection attempts (successful or not)\n";
	  break;
	case "Aborted_clients":
	  $stats_string .= "${value} connections aborted because client died without closing the connection properly\n";
	  break;
	case "Aborted_connects":
	  $stats_string .= "${value} failed attempts to connect to the MySQL server\n";
	  break;
	case "Open_tables":
	  $stats_string .= "${value} tables are open. If Open_tables value remains high may need to increase table_open_cache\n"; 
	  break;
	case "Qcache_lowmem_prunes":
	  $stats_string .= "${value} queries were deleted from the query cache because of low memory\n";
	  break;
	case "Queries":
	  $stats_string .= "${value} statements executed by the server\n";
	  break;
	case "Threads_created":
	  $stats_string .= "${value} threads created to handle connections If Threads_created high increase thread_cache_size\n";
	  break;
	case "Table_locks_waited":
	  $stats_string .= "${value} table locks could not be granted immediately, performance problem optimize queries or split tables\n";
	  break;
	case "Key_read_requests":
	  $Key_read_requests = $value;
	  $stats_sub_string .= "$key = $value\n";
	  break;
	case "Key_reads":
	  $Key_reads = $value;
	  $stats_sub_string .= "$key = $value\n";	  
	  break;
	default:
	  $stats_sub_string .= "$key = $value\n";	  
      }
    }
  }

  if(($Key_read_requests > 0) && ($Key_reads > 0)) {
    $cache_missrate = floor($Key_reads / $Key_read_requests);
    $stats_string .=  "Cache miss rate is ${cache_missrate}\n";
  }
  
  $stats_sub_string .= "\nMySQL zero value STATS for ${mysqlip} server:\n";
  foreach ($stat_array as $key => $value) {
    if($value <= 0) {
      $stats_sub_string .= "$key = $value\n";
    }
  }
  
  $stats_string .= $stats_sub_string;
  
  return $stats_string;
}

$PROCdir = "${OUTPUTdir}/${mysqlip}";
if(!file_exists("${PROCdir}")) mkdir("${PROCdir}");

echo "Collecting MySQL database stats for ${mysqlip}\n";
$stat_array = WriteMySQLStat($mysqlip, $mysqluser, $mysqlpass, "${PROCdir}/${mysqlip}_mysql_stats_phpout.txt", $verbose); 
$stats = anaylze_stats($mysqlip, $stat_array); 

echo $stats;
echo "\n";
echo "Collecting MySQL table stats for ${mysqlip}\n";
system("${DRSMHOME}/mysql/mysql_defragment.sh ${mysqlip} ${mysqluser} '${mysqlpass}' NO");   

$fname = "${PROCdir}/table_stats/numfrag.txt";
$fp = fopen($fname, "r");
$numfrag = fgets($fp);
$numfrag = trim($numfrag, "\n");
$opt_message = "Database optimization is required on ${mysqlip}\n";

if($numfrag > 0) {
  echo "\n";
  echo $opt_message;
}

exit(0);
// SCRIPT CONTENT ENDS ABOVE.
// ----------------------------------------------------------- //
// ------------------------------- //
// --------- End of File --------- //
// ------------------------------- //
?>

