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

Optional login for the DRSM Web pages. Requests from the internal
networks in $AUTHnetworks get open access. Requests from anywhere
else are sent to login.php and need a user name and password. Plain
PHP, so it works on shared hosting with no server changes.

Login is off unless $AUTHenable is set. Settings, in config/drsm.php:

$AUTHenable   = 1;     // 1 requires a login from outside $AUTHnetworks
$AUTHnetworks = array('127.0.0.1/32', '::1/128', '10.0.0.0/8',
                      '172.16.0.0/12', '192.168.0.0/16');
$AUTHusers    = array(
  // User name => password hash. Make a hash with
  // php utils/drsm_password.php, never store a plain password.
  'admin' => '$2y$10$...'
);
$AUTHproxies  = array();  // Reverse proxies or CDNs in front of the
                          // site, as CIDRs. X-Forwarded-For is only
                          // read when the request comes from one.
$AUTHhttps    = 1;        // 1 refuses logins over plain HTTP, so a
                          // password is never sent unencrypted
$AUTHidleminutes = 60;    // Sign out after this long with no page loads
$AUTHmaxhours    = 12;    // Sign out this long after login, any activity
$AUTHmaxfails    = 5;     // Failed logins from one address before a lock
$AUTHlockminutes = 15;    // How long a lock lasts
$AUTHstatedir = '/path';  // Failed login counts, must be writable by the
                          // Web server. Default ${CONFIGdir}/auth
$AUTHsessiondir = '';     // PHP session files, default is PHP's own

Keep this file PHP 7.2 compatible, see drsm_lib.php.
*/
// ----------------------------------------------------------- //
// SCRIPT CONTENT STARTS BELOW.

if(!isset($AUTHenable)) $AUTHenable = 0;
if(!isset($AUTHnetworks) || !is_array($AUTHnetworks)) {
  $AUTHnetworks = array("127.0.0.1/32", "::1/128", "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "fc00::/7");
}
if(!isset($AUTHusers) || !is_array($AUTHusers)) $AUTHusers = array();
if(!isset($AUTHproxies) || !is_array($AUTHproxies)) $AUTHproxies = array();
if(!isset($AUTHhttps)) $AUTHhttps = 1;
if(!isset($AUTHidleminutes)) $AUTHidleminutes = 60;
$AUTHuser = "";
$AUTHcsrf = "";
if(!isset($AUTHmaxhours)) $AUTHmaxhours = 12;
if(!isset($AUTHmaxfails)) $AUTHmaxfails = 5;
if(!isset($AUTHlockminutes)) $AUTHlockminutes = 15;
if(!isset($AUTHstatedir) || $AUTHstatedir == "") $AUTHstatedir = "{$CONFIGdir}/auth";
if(!isset($AUTHsessiondir)) $AUTHsessiondir = "";

// A user name with no account still checks a hash, so a wrong user
// takes as long as a wrong password
define("DRSM_AUTH_DUMMY_HASH", '$2y$10$UpXyFi1YL84UIjKyik8VBun9MF9JReGdU2VC9zmZHyisGHkizG6je');

// Users get this many times $AUTHmaxfails before their name is locked,
// so one address can not lock out a real user by itself
define("DRSM_AUTH_USER_FACTOR", 4);

function drsm_auth_enabled()
{
  global $AUTHenable;
  return (bool)$AUTHenable;
}

// Binary address, IPv4 mapped IPv6 addresses become plain IPv4
function drsm_ip_bin($ip)
{
  $bin = @inet_pton(trim((string)$ip));
  if($bin === false) return false;
  if(strlen($bin) == 16 && substr($bin, 0, 12) == "\0\0\0\0\0\0\0\0\0\0\xff\xff") $bin = substr($bin, 12);
  return $bin;
}

// True when $ip is inside $cidr, such as 10.0.0.0/8 or 2001:db8::/32.
// A plain address with no /bits matches only itself.
function drsm_ip_in_cidr($ip, $cidr)
{
  $ipbin = drsm_ip_bin($ip);
  if($ipbin === false) return false;
  $parts = explode("/", trim((string)$cidr), 2);
  $net = drsm_ip_bin($parts[0]);
  if($net === false || strlen($net) != strlen($ipbin)) return false;
  $max = strlen($net) * 8;
  $bits = $max;
  if(count($parts) == 2) {
    if(!ctype_digit($parts[1])) return false;
    $bits = (int)$parts[1];
    if($bits > $max) return false;
  }
  $whole = intdiv($bits, 8);
  if(substr($ipbin, 0, $whole) !== substr($net, 0, $whole)) return false;
  $rest = $bits % 8;
  if($rest == 0) return true;
  $mask = (0xff << (8 - $rest)) & 0xff;
  return (ord($ipbin[$whole]) & $mask) == (ord($net[$whole]) & $mask);
}

function drsm_ip_in_list($ip, $list)
{
  foreach($list as $cidr) {
    if(drsm_ip_in_cidr($ip, $cidr)) return true;
  }
  return false;
}

/*
Address of the browser. REMOTE_ADDR is the only value the client can
not forge, so it is used as is unless it is one of $AUTHproxies.
Then X-Forwarded-For is read from the right, skipping our own
proxies, and the first address that is not one of them is the client.
Anything to the left of that came from the client and is ignored.
*/
function drsm_client_ip($server = null)
{
  global $AUTHproxies;
  if($server === null) $server = $_SERVER;
  $remote = isset($server["REMOTE_ADDR"]) ? trim((string)$server["REMOTE_ADDR"]) : "";
  if(drsm_ip_bin($remote) === false) return "";
  if(count($AUTHproxies) == 0 || !drsm_ip_in_list($remote, $AUTHproxies)) return $remote;
  if(!isset($server["HTTP_X_FORWARDED_FOR"])) return $remote;
  $hops = array_reverse(explode(",", (string)$server["HTTP_X_FORWARDED_FOR"]));
  $client = $remote;
  foreach($hops as $hop) {
    $hop = trim($hop);
    if(drsm_ip_bin($hop) === false) break;
    $client = $hop;
    if(!drsm_ip_in_list($hop, $AUTHproxies)) break;
  }
  return $client;
}

function drsm_auth_internal($ip = null)
{
  global $AUTHnetworks;
  if($ip === null) $ip = drsm_client_ip();
  return ($ip != "" && drsm_ip_in_list($ip, $AUTHnetworks));
}

function drsm_auth_https()
{
  if(!empty($_SERVER["HTTPS"]) && strtolower((string)$_SERVER["HTTPS"]) != "off") return true;
  if(isset($_SERVER["SERVER_PORT"]) && (int)$_SERVER["SERVER_PORT"] == 443) return true;
  // Only believe the proxy header from one of our own proxies
  global $AUTHproxies;
  $remote = isset($_SERVER["REMOTE_ADDR"]) ? (string)$_SERVER["REMOTE_ADDR"] : "";
  if(isset($_SERVER["HTTP_X_FORWARDED_PROTO"]) && count($AUTHproxies) > 0 && drsm_ip_in_list($remote, $AUTHproxies)) {
    return strtolower(trim((string)$_SERVER["HTTP_X_FORWARDED_PROTO"])) == "https";
  }
  return false;
}

function drsm_session_start()
{
  global $WWWvpath, $AUTHsessiondir, $AUTHmaxhours;
  if(session_status() == PHP_SESSION_ACTIVE) return true;
  if($AUTHsessiondir != "") session_save_path($AUTHsessiondir);
  ini_set("session.use_strict_mode", "1");
  ini_set("session.use_only_cookies", "1");
  ini_set("session.use_trans_sid", "0");
  ini_set("session.cookie_httponly", "1");
  ini_set("session.gc_maxlifetime", (string)max(1440, (int)$AUTHmaxhours * 3600));
  session_name("DRSMSESSID");
  $path = ($WWWvpath != "") ? rtrim($WWWvpath, "/") . "/" : "/";
  $secure = drsm_auth_https();
  if(PHP_VERSION_ID >= 70300) {
    session_set_cookie_params(array("lifetime" => 0, "path" => $path, "secure" => $secure,
                                    "httponly" => true, "samesite" => "Lax"));
  }
  else {
    // PHP 7.2 has no samesite option, it rides along on the path
    session_set_cookie_params(0, "{$path}; samesite=Lax", "", $secure, true);
  }
  return @session_start();
}

function drsm_session_destroy()
{
  if(session_status() != PHP_SESSION_ACTIVE) return;
  $_SESSION = array();
  $p = session_get_cookie_params();
  if(PHP_VERSION_ID >= 70300) {
    setcookie(session_name(), "", array("expires" => time() - 3600, "path" => $p["path"], "secure" => $p["secure"],
                                        "httponly" => true, "samesite" => "Lax"));
  }
  else {
    setcookie(session_name(), "", time() - 3600, $p["path"], "", $p["secure"], true);
  }
  session_destroy();
}

// Signed in user name, or "" when there is no valid login
function drsm_auth_user()
{
  global $AUTHidleminutes, $AUTHmaxhours, $AUTHusers;
  if(session_status() != PHP_SESSION_ACTIVE || !isset($_SESSION["drsm_user"])) return "";
  $now = time();
  $user = (string)$_SESSION["drsm_user"];
  $start = isset($_SESSION["drsm_login"]) ? (int)$_SESSION["drsm_login"] : 0;
  $seen = isset($_SESSION["drsm_seen"]) ? (int)$_SESSION["drsm_seen"] : 0;
  $expired = ($AUTHmaxhours > 0 && $now - $start > $AUTHmaxhours * 3600) ||
             ($AUTHidleminutes > 0 && $now - $seen > $AUTHidleminutes * 60);
  // A user taken out of the config is signed out on the next page
  if($expired || !isset($AUTHusers[$user])) {
    unset($_SESSION["drsm_user"], $_SESSION["drsm_login"], $_SESSION["drsm_seen"]);
    return "";
  }
  $_SESSION["drsm_seen"] = $now;
  return $user;
}

function drsm_csrf_token()
{
  if(session_status() != PHP_SESSION_ACTIVE) return "";
  if(!isset($_SESSION["drsm_csrf"]) || !is_string($_SESSION["drsm_csrf"]) || strlen($_SESSION["drsm_csrf"]) != 64) {
    $_SESSION["drsm_csrf"] = bin2hex(random_bytes(32));
  }
  return $_SESSION["drsm_csrf"];
}

function drsm_csrf_check($token)
{
  if(session_status() != PHP_SESSION_ACTIVE || !isset($_SESSION["drsm_csrf"]) || !is_string($token)) return false;
  return hash_equals((string)$_SESSION["drsm_csrf"], $token);
}

// Only send people back to one of our own pages after login
function drsm_auth_safe_next($next)
{
  global $WWWvpath;
  $home = drsm_url("index.php");
  if(!is_string($next) || $next == "" || strlen($next) > 1024) return $home;
  if(preg_match('/[\x00-\x20\\\\]/', $next)) return $home;
  if(substr($next, 0, 1) != "/" || substr($next, 0, 2) == "//") return $home;
  $base = rtrim($WWWvpath, "/") . "/";
  if($base != "/" && strpos($next, $base) !== 0) return $home;
  if(strpos($next, "/php/login.php") !== false) return $home;
  return $next;
}

// ---------- Failed login limits ----------

function drsm_auth_state_dir()
{
  global $AUTHstatedir;
  if(!is_dir($AUTHstatedir)) @mkdir($AUTHstatedir, 0700, true);
  if(is_dir($AUTHstatedir) && !file_exists("{$AUTHstatedir}/.htaccess")) {
    @file_put_contents("{$AUTHstatedir}/.htaccess", "Require all denied\n");
  }
  return (is_dir($AUTHstatedir) && is_writable($AUTHstatedir)) ? $AUTHstatedir : "";
}

function drsm_auth_state_file($key)
{
  $dir = drsm_auth_state_dir();
  return ($dir == "") ? "" : "{$dir}/fail_" . hash("sha256", $key) . ".json";
}

// Read or update one failure counter while holding a lock on its file.
// $add 0 reads, 1 adds a failure, -1 clears it. Returns the record.
function drsm_auth_counter($key, $limit, $add)
{
  global $AUTHlockminutes;
  $rec = array("fails" => 0, "first" => 0, "until" => 0);
  $fname = drsm_auth_state_file($key);
  if($fname == "") return false;
  $fp = @fopen($fname, "c+");
  if($fp === false) return false;
  flock($fp, LOCK_EX);
  $data = json_decode((string)stream_get_contents($fp), true);
  if(is_array($data)) $rec = array_merge($rec, $data);
  $now = time();
  $window = max(1, (int)$AUTHlockminutes) * 60;
  if($rec["until"] > 0 && $rec["until"] <= $now) $rec = array("fails" => 0, "first" => 0, "until" => 0);
  if($rec["first"] > 0 && $now - $rec["first"] > $window && $rec["until"] == 0) $rec = array("fails" => 0, "first" => 0, "until" => 0);
  if($add > 0) {
    if($rec["fails"] == 0) $rec["first"] = $now;
    $rec["fails"]++;
    if($rec["fails"] >= $limit) $rec["until"] = $now + $window;
  }
  else if($add < 0) {
    $rec = array("fails" => 0, "first" => 0, "until" => 0);
  }
  if($add != 0) {
    ftruncate($fp, 0);
    rewind($fp);
    fwrite($fp, json_encode($rec));
    fflush($fp);
  }
  flock($fp, LOCK_UN);
  fclose($fp);
  if($add < 0) @unlink($fname);
  return $rec;
}

// Seconds until a login from this address or for this user is allowed,
// 0 when it is allowed now, -1 when failures can not be counted
function drsm_auth_locked($ip, $user)
{
  global $AUTHmaxfails, $AUTHusers;
  $wait = 0;
  $checks = array(array("ip:{$ip}", (int)$AUTHmaxfails));
  if(isset($AUTHusers[$user])) $checks[] = array("user:" . strtolower($user), (int)$AUTHmaxfails * DRSM_AUTH_USER_FACTOR);
  foreach($checks as $c) {
    $rec = drsm_auth_counter($c[0], max(1, $c[1]), 0);
    if($rec === false) return -1;
    if($rec["until"] > 0) $wait = max($wait, $rec["until"] - time());
  }
  return $wait;
}

function drsm_auth_record($ip, $user, $ok)
{
  global $AUTHmaxfails;
  // Now and then remove counters nobody has touched in a day
  if(!$ok && mt_rand(1, 50) == 1) {
    $old = glob(drsm_auth_state_dir() . "/fail_*.json");
    if(is_array($old)) foreach($old as $f) if(@filemtime($f) < time() - 86400) @unlink($f);
  }
  drsm_auth_counter("ip:{$ip}", max(1, (int)$AUTHmaxfails), $ok ? -1 : 1);
  if($user != "") {
    drsm_auth_counter("user:" . strtolower($user), max(1, (int)$AUTHmaxfails * DRSM_AUTH_USER_FACTOR), $ok ? -1 : 1);
  }
}

// Check a user name and password, with the failed login limits.
// Returns "" when signed in, otherwise a message for the login page.
function drsm_auth_login($user, $pass, $ip)
{
  global $AUTHusers;
  $user = (string)$user;
  $pass = (string)$pass;
  if(count($AUTHusers) == 0) return "No accounts are set up. Add one to \$AUTHusers in config/drsm.php.";
  if(strlen($user) > 64 || strlen($pass) > 1024) return "Wrong user name or password.";
  $wait = drsm_auth_locked($ip, $user);
  if($wait < 0) return "Login is turned off because the failed login folder can not be written. Check \$AUTHstatedir.";
  if($wait > 0) return "Too many failed logins. Try again in " . drsm_age_text($wait) . ".";

  $known = isset($AUTHusers[$user]);
  $hash = $known ? (string)$AUTHusers[$user] : DRSM_AUTH_DUMMY_HASH;
  $ok = (password_verify($pass, $hash) && $known);
  // Only real accounts get a user counter, made up names would just
  // fill the folder with files
  drsm_auth_record($ip, $known ? $user : "", $ok);
  if(!$ok) {
    error_log("DRSM login failed for user '" . preg_replace('/[^A-Za-z0-9._@-]/', "?", $user) . "' from {$ip}");
    // Slow down guessing a little more
    usleep(400000);
    return "Wrong user name or password.";
  }

  // New session id at login, so a planted session id is worth nothing
  session_regenerate_id(true);
  $_SESSION["drsm_user"] = $user;
  $_SESSION["drsm_login"] = time();
  $_SESSION["drsm_seen"] = time();
  $_SESSION["drsm_csrf"] = bin2hex(random_bytes(32));
  return "";
}

function drsm_auth_headers()
{
  if(headers_sent()) return;
  header("X-Frame-Options: DENY");
  header("X-Content-Type-Options: nosniff");
  header("Referrer-Policy: same-origin");
  header("Cache-Control: no-store, private");
}

/*
Called by every page through drsm_lib.php. Internal addresses and
sites with login turned off go straight through. Everyone else needs
a valid login or is sent to login.php.
*/
function drsm_auth_require()
{
  global $AUTHuser, $AUTHcsrf;
  if(!drsm_auth_enabled()) return;
  drsm_auth_headers();
  if(drsm_auth_internal()) return;
  // Only browsers that already have a session cookie get a session,
  // so robots hitting the pages do not leave session files behind
  if(isset($_COOKIE["DRSMSESSID"])) {
    drsm_session_start();
    $AUTHuser = drsm_auth_user();
  }
  if($AUTHuser != "") {
    // Token for the sign out button, then free the session file so
    // other pages from the same browser do not wait on its lock
    $AUTHcsrf = drsm_csrf_token();
    session_write_close();
    return;
  }
  $here = isset($_SERVER["REQUEST_URI"]) ? (string)$_SERVER["REQUEST_URI"] : "";
  $url = drsm_url("login.php", ($here != "") ? array("next" => drsm_auth_safe_next($here)) : array());
  if(!headers_sent()) {
    http_response_code(302);
    header("Location: {$url}");
  }
  echo "<!DOCTYPE html><title>Login required</title><p><a href=\"" . h($url) . "\">Log in</a> to see this page.</p>\n";
  exit;
}

// SCRIPT CONTENT ENDS ABOVE.
// ----------------------------------------------------------- //
// ------------------------------- //
// --------- End of File --------- //
// ------------------------------- //
?>
