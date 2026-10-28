<?php
// ------------------------------- //
// -------- Start of File -------- //
// ------------------------------- //
// ----------------------------------------------------------- //
// PHP Source Code File
// PHP Version: 7.2 or higher, tested with PHP 8
// Original Author(s): DataReel Software Development
// File Creation Date: 10/28/2026
// Date Last Modified: 10/28/2026
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

Status messages page: every current message with its level, link and
end time, then the ones that ended. The message bar links here.
*/
// ----------------------------------------------------------- //
// SCRIPT CONTENT STARTS BELOW.

require_once("../config/drsm.php");

// Our required includes
require_once("{$WWWdir}/php/query_post_validation.php");
require_once("{$WWWdir}/php/drsm_lib.php");

$all = drsm_messages(true);
$now = array_filter($all, function($m) { return !$m["expired"]; });
$old = array_filter($all, function($m) { return $m["expired"]; });
$state = "OK";
foreach($now as $m) $state = drsm_worst($state, $m["level"] == "critical" ? "ERROR" : ($m["level"] == "warning" ? "WARNING" : "OK"));

function drsm_message_rows($list)
{
  foreach($list as $m) { ?>
        <tr id="m<?php echo (int)$m["id"]; ?>" class="row-<?php echo h($m["level"] == "critical" ? "err" : ($m["level"] == "warning" ? "warn" : "ok")); ?>">
          <td><span class="msg-level msg-<?php echo h($m["level"]); ?>" style="display:inline-block"><?php echo h(ucfirst($m["level"])); ?></span></td>
          <td><strong><?php echo h($m["text"]); ?></strong><?php if($m["link"] != "") { ?><div class="small"><a href="<?php echo h($m["link"]); ?>">Details</a></div><?php } ?></td>
          <td class="hide-sm"><?php echo ($m["until"] > 0) ? h(date("Y-m-d H:i T", $m["until"])) : "<span class=\"muted\">Until removed</span>"; ?></td>
        </tr>
<?php }
}

drsm_page_start("Status messages", "messages", $state);
?>
<section class="page-head">
  <div>
    <h1>Status messages</h1>
    <p class="muted">Notices from the system admins. They also scroll across the top of every page.</p>
  </div>
</section>
<section class="panel flush">
<?php if(count($now) == 0) { ?>
  <div class="empty ok"><?php echo drsm_icon("check"); ?><p>No status messages right now.</p></div>
<?php } else { ?>
  <div class="table-wrap">
    <table class="table">
      <thead><tr><th scope="col">Level</th><th scope="col">Message</th><th scope="col" class="hide-sm">Until</th></tr></thead>
      <tbody>
<?php drsm_message_rows($now); ?>
      </tbody>
    </table>
  </div>
<?php } ?>
</section>
<?php if(count($old) > 0) { ?>
<details class="panel">
  <summary>Ended messages (<?php echo count($old); ?>)</summary>
  <div class="table-wrap">
    <table class="table">
      <tbody>
<?php drsm_message_rows($old); ?>
      </tbody>
    </table>
  </div>
</details>
<?php } ?>
<?php
drsm_page_end();

// SCRIPT CONTENT ENDS ABOVE.
// ----------------------------------------------------------- //
// ------------------------------- //
// --------- End of File --------- //
// ------------------------------- //
?>
