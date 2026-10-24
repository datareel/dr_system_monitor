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

DRSM login page for access from outside the internal networks, and
the target of the sign out button. Only used when $AUTHenable is set,
see drsm_auth.php.
*/
// ----------------------------------------------------------- //
// SCRIPT CONTENT STARTS BELOW.

define("DRSM_LOGIN_PAGE", 1);

require_once("../config/drsm.php");

// Our required includes
require_once("{$WWWdir}/php/query_post_validation.php");
require_once("{$WWWdir}/php/drsm_lib.php");

function drsm_login_redirect($url)
{
  http_response_code(303);
  header("Location: {$url}");
  exit;
}

if(!drsm_auth_enabled()) drsm_login_redirect(drsm_url("index.php"));

drsm_auth_headers();
header("Content-Security-Policy: frame-ancestors 'none'; form-action 'self'");

$ip = drsm_client_ip();
$next = drsm_auth_safe_next(isset($_REQUEST["next"]) && is_string($_REQUEST["next"]) ? $_REQUEST["next"] : "");
$post = (isset($_SERVER["REQUEST_METHOD"]) && $_SERVER["REQUEST_METHOD"] == "POST");
$action = ($post && isset($_POST["action"]) && is_string($_POST["action"])) ? $_POST["action"] : "";
$error = "";
$notice = "";

// Inside the network there is nothing to log in to
if(drsm_auth_internal($ip) && $action != "logout") drsm_login_redirect($next);

drsm_session_start();

if($action == "logout") {
  if(drsm_csrf_check(isset($_POST["csrf"]) ? $_POST["csrf"] : "")) {
    drsm_session_destroy();
    drsm_session_start();
    $notice = "You are signed out.";
  }
}
else if($action == "login") {
  $user = (isset($_POST["user"]) && is_string($_POST["user"])) ? trim($_POST["user"]) : "";
  $pass = (isset($_POST["password"]) && is_string($_POST["password"])) ? $_POST["password"] : "";
  if($AUTHhttps && !drsm_auth_https()) {
    $error = "Login needs an HTTPS connection. Open this page with https://.";
  }
  else if(!drsm_csrf_check(isset($_POST["csrf"]) ? $_POST["csrf"] : "")) {
    $error = "The login form expired. Please try again.";
  }
  else {
    $error = drsm_auth_login($user, $pass, $ip);
    if($error == "") drsm_login_redirect($next);
  }
}

if(drsm_auth_user() != "") drsm_login_redirect($next);

$csrf = drsm_csrf_token();
$insecure = ($AUTHhttps && !drsm_auth_https());
$lastuser = (isset($user) && strlen($user) <= 64) ? $user : "";
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="color-scheme" content="dark light">
<meta name="robots" content="noindex, nofollow">
<title><?php echo h("Sign in - {$SITEtitle}"); ?></title>
<?php echo drsm_head_assets(); ?>
</head>
<body class="login-body" data-refresh="0" data-page="login">
<div class="login-tools">
  <button type="button" class="tool icon-only" data-action="theme" title="Switch light or dark theme"><?php echo drsm_icon("sun"); ?><?php echo drsm_icon("moon"); ?><span class="sr">Switch theme</span></button>
</div>
<main id="main" class="login">
  <section class="panel login-card">
    <div class="login-brand">
      <span class="brand-mark" aria-hidden="true"><span></span><span></span><span></span></span>
      <span><?php echo h($SITEtitle); ?></span>
    </div>
    <div>
      <h1>Sign in</h1>
      <p class="muted">You are connecting from outside the internal network, so this dashboard needs a login.</p>
    </div>
<?php if($error != "") { ?>
    <div class="callout err" role="alert"><?php echo drsm_icon("alert"); ?><span><?php echo h($error); ?></span></div>
<?php } else if($notice != "") { ?>
    <div class="callout ok" role="status"><?php echo drsm_icon("check"); ?><span><?php echo h($notice); ?></span></div>
<?php } ?>
<?php if($insecure) { ?>
    <div class="callout warn"><?php echo drsm_icon("lock"); ?><span>This connection is not encrypted. Open the dashboard with https:// to sign in.</span></div>
<?php } ?>
    <form method="post" action="<?php echo h(drsm_url("login.php")); ?>" class="login-form">
      <input type="hidden" name="action" value="login">
      <input type="hidden" name="csrf" value="<?php echo h($csrf); ?>">
      <input type="hidden" name="next" value="<?php echo h($next); ?>">
      <div class="field">
        <label for="user">User name</label>
        <input id="user" name="user" type="text" autocomplete="username" autocapitalize="none" spellcheck="false" maxlength="64" required value="<?php echo h($lastuser); ?>"<?php if($lastuser == "") echo " autofocus"; ?>>
      </div>
      <div class="field">
        <label for="password">Password</label>
        <input id="password" name="password" type="password" autocomplete="current-password" maxlength="1024" required<?php if($lastuser != "") echo " autofocus"; ?>>
      </div>
      <button type="submit" class="button block"<?php if($insecure) echo " disabled"; ?>><?php echo drsm_icon("lock"); ?>Sign in</button>
    </form>
    <p class="login-foot muted small">Your address <?php echo h($ip != "" ? $ip : "unknown"); ?> is not on the internal network list.</p>
  </section>
</main>
<footer class="footer">
  <span>DataReel System Monitor</span>
</footer>
</body>
</html>
<?php
// SCRIPT CONTENT ENDS ABOVE.
// ----------------------------------------------------------- //
// ------------------------------- //
// --------- End of File --------- //
// ------------------------------- //
?>
