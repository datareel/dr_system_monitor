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

Status messages: notices the admins post for everyone, such as a
planned outage or a known problem. They scroll across the top of every
page and run as a large ticker in wall display mode. Messages are kept
in a file, one per line (utils/drsm_message.sh adds and removes them):

  level | message | link | until | options

- level: info, warning or critical
- link: a page with the details. Empty links to messages.php, the list
  of every current message.
- until: when the message ends, YYYY-MM-DD HH:MM in the server's time
  zone. Empty keeps it until it is removed.
- options: pin keeps the message in view at the start of the bar
  instead of scrolling with the rest.

# starts a comment line. Setting in config/drsm.php:

$MESSAGESfile = '/path/messages.conf';  // default ${CONFIGdir}/messages.conf
*/
// ----------------------------------------------------------- //
// SCRIPT CONTENT STARTS BELOW.

function drsm_messages_file()
{
  global $MESSAGESfile, $CONFIGdir;
  if(isset($MESSAGESfile) && $MESSAGESfile != "") return $MESSAGESfile;
  return isset($CONFIGdir) ? "{$CONFIGdir}/messages.conf" : "";
}

// Messages from the file: current ones, or with $all also the expired
function drsm_messages($all = false)
{
  static $cache = array();
  $key = $all ? "all" : "now";
  if(isset($cache[$key])) return $cache[$key];
  $out = array();
  $f = drsm_messages_file();
  if($f != "" && is_readable($f)) {
    $n = 0;
    foreach(file($f, FILE_IGNORE_NEW_LINES) ?: array() as $line) {
      $line = trim($line);
      if($line == "" || $line[0] == "#") continue;
      $p = array_map("trim", explode("|", $line));
      while(count($p) < 5) $p[] = "";
      $level = strtolower($p[0]);
      if(!in_array($level, array("info", "warning", "critical"))) continue;
      if($p[1] == "") continue;
      $until = ($p[3] != "") ? strtotime($p[3]) : 0;
      $expired = ($until !== false && $until > 0 && $until < time());
      $n++;
      if($expired && !$all) continue;
      // Only http(s) and site relative links
      $link = $p[2];
      if($link != "" && !preg_match('#^(https?://|/)[^\s"<>]*$#i', $link)) $link = "";
      $out[] = array("id" => $n, "level" => $level, "text" => $p[1], "link" => $link, "until" => ($until ? $until : 0),
                     "pin" => (strpos(strtolower($p[4]), "pin") !== false), "expired" => $expired);
    }
  }
  // Critical first, then warning, then info, file order within a level
  $rank = array("critical" => 0, "warning" => 1, "info" => 2);
  usort($out, function($a, $b) use ($rank) {
    $d = $rank[$a["level"]] - $rank[$b["level"]];
    return ($d != 0) ? $d : $a["id"] - $b["id"];
  });
  $cache[$key] = $out;
  return $out;
}

function drsm_message_href($m)
{
  return ($m["link"] != "") ? $m["link"] : drsm_url("messages.php") . "#m" . (int)$m["id"];
}

function drsm_message_html($m)
{
  $icon = array("critical" => "alert", "warning" => "alert", "info" => "file");
  return "<a class=\"msg msg-" . h($m["level"]) . "\" href=\"" . h(drsm_message_href($m)) . "\">"
    . drsm_icon($icon[$m["level"]]) . "<span class=\"msg-level\">" . h(ucfirst($m["level"])) . "</span>"
    . "<span class=\"msg-text\">" . h($m["text"]) . "</span></a>";
}

// The message bar: pinned messages first, the rest scroll. Empty when
// there are no current messages.
function drsm_messages_bar($class = "")
{
  $msgs = drsm_messages();
  if(count($msgs) == 0) return "";
  $pinned = "";
  $rest = array();
  $worst = "info";
  foreach($msgs as $m) {
    if($m["level"] == "critical" || ($m["level"] == "warning" && $worst == "info")) $worst = $m["level"];
    if($m["pin"]) $pinned .= drsm_message_html($m);
    else $rest[] = drsm_message_html($m);
  }
  $out = "<div class=\"msgbar msgbar-" . h($worst) . ($class != "" ? " " . h($class) : "") . "\" role=\"region\" aria-label=\"Status messages\">";
  if($pinned != "") $out .= "<div class=\"msg-pinned\">{$pinned}</div>";
  if(count($rest) > 0) {
    $run = implode("<span class=\"msg-sep\" aria-hidden=\"true\">&bull;</span>", $rest);
    // The run twice for a seamless loop; the copy is hidden from screen readers
    $secs = max(20, 8 * count($rest) + (int)(strlen(strip_tags($run)) / 12));
    $out .= "<div class=\"msg-scroll\"><div class=\"msg-track\" style=\"animation-duration:{$secs}s\">"
      . "<div class=\"msg-run\">{$run}</div><div class=\"msg-run\" aria-hidden=\"true\">" . str_replace("<a ", "<a tabindex=\"-1\" ", $run) . "</div></div></div>";
  }
  return $out . "</div>";
}

// SCRIPT CONTENT ENDS ABOVE.
// ----------------------------------------------------------- //
// ------------------------------- //
// --------- End of File --------- //
// ------------------------------- //
?>
