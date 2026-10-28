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

Users guide: how to read the dashboard, for people who only look at
it. The footer's Help link opens it. A site can replace the guide with
its own ${SITEincludes}/help_users.php, which is printed inside the
page layout. Admin documentation is in the docs folder of the DRSM
install (docs/admin.html and docs/ai-assistants.html).
*/
// ----------------------------------------------------------- //
// SCRIPT CONTENT STARTS BELOW.

require_once("../config/drsm.php");

// Our required includes
require_once("{$WWWdir}/php/query_post_validation.php");
require_once("{$WWWdir}/php/drsm_lib.php");

drsm_page_start("Help", "help");
?>
<section class="panel help-page">
<?php if(isset($SITEincludes) && file_exists("{$SITEincludes}/help_users.php")) {
        include("{$SITEincludes}/help_users.php");
      } else { ?>
  <h1>Users guide</h1>
  <p class="muted">How to read <?php echo h($SITEtitle); ?>. Nothing to set up: open the pages and look.</p>

  <h2>What the colors mean</h2>
  <table class="table">
    <tbody>
      <tr><td><?php echo drsm_badge("OK"); ?></td><td>Working normally.</td></tr>
      <tr><td><?php echo drsm_badge("WARNING"); ?></td><td>Something to look at soon. Nothing is down.</td></tr>
      <tr><td><?php echo drsm_badge("ERROR"); ?></td><td>Something is down or failing. Tell your system admins if it stays.</td></tr>
      <tr><td><?php echo drsm_badge("STALE"); ?></td><td>No new report has come in for a while, so the state may be old.</td></tr>
      <tr><td><?php echo drsm_badge("UNKNOWN"); ?></td><td>A check could not run, or a new host is waiting for its first report.</td></tr>
    </tbody>
  </table>

  <h2>The pages</h2>
  <ul>
    <li><strong>Overview</strong>: the first page. The banner says if anything needs attention. "Needs attention" lists the problems, worst first. Each card is one host: select it for its full report.</li>
    <li><strong>Heat map</strong>: one row per host and one column per check, for a quick scan. "Resource use" shows CPU, memory and disk.</li>
    <li><strong>Hosts</strong>: every host in a table. Select a column title to sort, type in the search box to find a host.</li>
    <li><strong>Trends</strong>: CPU, memory, disk and network over days and months, for planning.</li>
    <li><strong>Connectivity</strong>: which hosts answer ping and their web services.</li>
    <li><strong>Messages</strong> scroll across the top of the page when your admins post one. Select a message for its details.</li>
  </ul>

  <h2>Handy controls</h2>
  <ul>
    <li><strong>Live</strong> (top right): the page refreshes by itself. Select it to pause.</li>
    <li>The <strong>expand</strong> button shows the page full screen, for a wall display. <kbd>Esc</kbd> leaves.</li>
    <li>The <strong>sun / moon</strong> button switches between light and dark.</li>
    <li><strong>Site links</strong> (the link icon) opens the consoles and documents your admins listed.</li>
  </ul>

  <h2>Questions</h2>
  <h3>A host is purple (Stale). Is it down?</h3>
  <p>Not always. Its report is late. If it stays that way, tell your system admins.</p>
  <h3>Who do I tell about a problem?</h3>
  <p>Your system admins. The host's report page shows what failed and when, which helps them.</p>
<?php } ?>
</section>
<?php
drsm_page_end();

// SCRIPT CONTENT ENDS ABOVE.
// ----------------------------------------------------------- //
// ------------------------------- //
// --------- End of File --------- //
// ------------------------------- //
?>
