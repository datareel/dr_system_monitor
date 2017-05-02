<?php
// ------------------------------- //
// -------- Start of File -------- //
// ------------------------------- //
// ----------------------------------------------------------- //
// PHP Source Code File
// PHP Version: 5.1.6 or higher
// Original Author(s): DataReel Software Development 
// File Creation Date: 02/05/2009
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

PHP validation functions for all page the accept $_GET[] and
$_POST[] variables:

function ValidateQuery($request, $validation_str, &$clean_str)
function ValidateQueryWithRegEx($request, $regex, &$clean_str)
function ValidateQueryWithArray($request, $validation_array, &$clean_str)
function ValidateQueryWithRegExArray($request, $regex_array, &$clean_str)
*/
// ----------------------------------------------------------- // 
// SCRIPT CONTENT STARTS BELOW.

function CleanQueryAsString($unsafe_buffer, $max_len = 255)
{
  // Our main driver function
  
  $safe_buffer = "";
  if(!isSet($unsafe_buffer)) return $safe_buffer;

  if(strlen($unsafe_buffer) > $max_len) {
    // If we went past this length some is trying to buffer overflow this GET or POST
    $safe_buffer = "";
    return $safe_buffer;
  }
  
  // Check for hackers that input HTML/XML code as a post or query
  $ascii_buffer = htmlentities($unsafe_buffer);
  // Strip any HTML/XML TAGs the may have escaped htmlentities() call 
  $safe_buffer = strip_tags($ascii_buffer);

  // Input we always reject no matter what.
  // This check protects against hackers trying to buffer overflow into
  // our system path or try to break in with malicious scripting 
  $reject_always = array("/etc", "/usr", "/var",
			 "/home", "/boot",
			 "/proc", "/opt", "/root",
			 "javascript", "vbscript"
			 );
  foreach($reject_always as $key=>$val) {
    if(version_compare(PHP_VERSION, '5.0.0', '<')) {
      $pos = strpos($safe_buffer, $val);
    }
    else {
      $pos = stripos($safe_buffer, $val);
    }
    if($pos !== false) {
      // We have been hacked so reset this string
      $safe_buffer = "";
      break;
    }
  }
  return $safe_buffer;
}

function CleanQueryAsInt($unsafe_buffer, $low_range = 0, $high_range = 255) {
  $safe_buffer = CleanQueryAsString($unsafe_buffer);
  if(!$safe_buffer) return 0;
  if(($safe_buffer < $low_range) || ($safe_buffer > $high_range)) {
    return 0;
  }
  return $safe_buffer;
}

function ValidateQuery($request, $validation_str, &$clean_str)
{
  if(!isSet($request)) return 0;

  $has_str = 0;
  $safe_buffer = CleanQueryAsString($request);
  if($safe_buffer) {
    if(version_compare(PHP_VERSION, '5.0.0', '<')) {
      $pos = strpos($safe_buffer, $validation_str);
    }
    else {
      $pos = stripos($safe_buffer, $validation_str);
    }
    if($pos !== false) {
      // We have found the validation string
      $has_str = 1;
    }
  }
  $clean_str = $safe_buffer;
  return $has_str;
}

function ValidateQueryWithRegEx($request, $regex, &$clean_str)
{
  if(!isSet($request)) return 0;
  
  $has_str = 0;
  $safe_buffer = CleanQueryAsString($request);
  if($safe_buffer) {
    if(preg_match($regex, $safe_buffer)) {
      // We have found the validation regular expression
      $has_str = 1;
    }
  }

  $clean_str = $safe_buffer;
  return $has_str;
}

function ValidateQueryWithArray($request, $validation_array, &$clean_str)
{
  $has_str = 0;
  reset($validation_array);
  foreach($validation_array as $key=>$val) {
    if(ValidateQuery($request, $val, $clean_str)) {
      $has_str = 1;
      break;
    }
  }
  return $has_str;
}

function ValidateQueryWithRegExArray($request, $regex_array, &$clean_str)
{
  $has_str = 0;
  reset($regex_array);
  foreach($regex_array as $key=>$val) {
    if(ValidateQueryWithRegEx($request, $val, $clean_str)) {
      $has_str = 1;
      break;
    }
  }
  return $has_str;
}

function HasPattern($s, $p)
{
  $pos = strpos($s, $p);
  if($pos === false) {
    return false;
  }
  return true;
}

function HasSpammerTags($field)
{
  // TODO: Add all spammer checks here
  if(HasPattern("$field", "://")) {
    return true;
  }
  
  // This field is ok
  return false;
}

function CleanBodyText($unsafe_buffer, $max_len = 65535)
{
  $safe_buffer = "";
  if(!isSet($unsafe_buffer)) return $safe_buffer;

  if(strlen($unsafe_buffer) > $max_len) {
    // If we went past this length some is trying to buffer overflow this GET or POST
    $safe_buffer = "";
    return $safe_buffer;
  }
  
  // Check for hackers that input HTML/XML code as a post or query 
  $safe_buffer = htmlentities($unsafe_buffer);

  return $safe_buffer;
}

function AddToBlacklist($fname, $email)
{
  if(file_exists("$fname")) {
    $fp = fopen("$fname", 'r+');
    if($fp) {
      while(!feof($fp)) {
	$line = fgets($fp, 1024);
	$line = chop($line); // Remove line feeds
	$line = trim($line); // Remove leading and trailing spaces
	if(($email) == ($line)) {
	  // This email address has been added
	  fclose($fp);
	  return;
	}
      }
      $line = $email . "\n";
      fwrite($fp, "$line");
      fclose($fp);
    }
  }
}

function IsBlacklisted($fname, $email)
{
  if(file_exists("$fname")) {
    $fp = fopen("$fname",'r');
    if($fp) {
      while(!feof($fp)) {
	$line = fgets($fp, 1024);
	$line = chop($line); // Remove line feeds
	$line = trim($line); // Remove leading and trailing spaces
	if(($email) == ($line)) {
	  // Email address has been blacklisted
	  return true;
	  fclose($fp);
	}
      }
      fclose($fp);
    }
  }
  return false;
}

function clean_args($var,$default='',$method='GET',$replace='[^\\n\/A-Za-z0-9:().\\\-_ ]') 
{
  if($method=='GET') {
    $info=isset($_GET[$var])?$_GET[$var]:$default;
  }
  elseif($method=='POST') {
    $info=isset($_POST[$var])?$_POST[$var]:$default;
  }
  else {
    $info=isset($_REQUEST[$var])?$_REQUEST[$var]:$default;
  }
  $info=$replace?preg_replace('/'.$replace.'/','',$info):$info;
  return $info;
}

// SCRIPT CONTENT ENDS ABOVE.
// ----------------------------------------------------------- //
// ------------------------------- //
// --------- End of File --------- //
// ------------------------------- //
?>
