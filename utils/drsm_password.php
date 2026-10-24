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

Makes a password hash for a dashboard login. Asks for the password
twice without showing it, so it does not land in the shell history,
and prints the line to add to $AUTHusers in config/drsm.php. Run it
on any machine with PHP 7.2 or higher, the hash works everywhere.

Usage: php utils/drsm_password.php [user]

To read the password from a pipe instead: ... | php utils/drsm_password.php user
*/
// ----------------------------------------------------------- //
// SCRIPT CONTENT STARTS BELOW.

if(PHP_SAPI != "cli") exit(1);

$user = isset($argv[1]) ? $argv[1] : "";
$tty = function_exists("posix_isatty") ? posix_isatty(STDIN) : true;

function ask($prompt, $hide)
{
  fwrite(STDERR, $prompt);
  if($hide) @shell_exec("stty -echo 2>/dev/null");
  $line = fgets(STDIN);
  if($hide) {
    @shell_exec("stty echo 2>/dev/null");
    fwrite(STDERR, "\n");
  }
  return ($line === false) ? false : rtrim($line, "\r\n");
}

if($user == "") $user = ask("User name: ", false);
if($user === false || !preg_match('/^[A-Za-z0-9._@-]{1,64}$/', $user)) {
  fwrite(STDERR, "ERROR - User names are 1 to 64 letters, digits, and . _ @ -\n");
  exit(1);
}

$pass = ask("Password: ", $tty);
if($tty && $pass !== false && ask("Same password again: ", true) !== $pass) {
  fwrite(STDERR, "ERROR - The passwords do not match\n");
  exit(1);
}
if($pass === false || strlen($pass) < 10) {
  fwrite(STDERR, "ERROR - Use a password of at least 10 characters\n");
  exit(1);
}

echo "  '{$user}' => '" . password_hash($pass, PASSWORD_DEFAULT) . "',\n";
exit(0);

// SCRIPT CONTENT ENDS ABOVE.
// ----------------------------------------------------------- //
// ------------------------------- //
// --------- End of File --------- //
// ------------------------------- //
?>
