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

Admin guide, printed by help.php?p=admin inside the page layout: the
day-to-day jobs of whoever runs DRSM. help_doc() links to the full
documentation at $DOCSurl. A site replaces this guide with its own
${SITEincludes}/help_admin.php.
*/
// ----------------------------------------------------------- //
// SCRIPT CONTENT STARTS BELOW.

// Only inside help.php
if(!function_exists("drsm_page_start")) exit;
if(!function_exists("help_doc")) {
  function help_doc($page, $text) { return h($text); }
}
?>
  <h1>Admin guide</h1>
  <p class="muted">The jobs that come up while DRSM is running: hosts in and out, thresholds, notices for users, upgrades and finding out why something is red. Everything is plain text files and a few scripts. The full documentation: <?php echo help_doc("index.html", "DRSM docs"); ?>.</p>
  <p>Commands below use <code>~/drsm</code> and <code>~/.drsm.sh</code>. If your install uses <code>DRSM_CONFIG</code>, put <code>DRSM_CONFIG=&lt;your config&gt;</code> in front of each command. Scripts that change files show a dry run first and need <code>--apply</code>.</p>

  <h2>Where things are</h2>
  <table class="table">
    <tbody>
      <tr><td>Install settings</td><td><code>~/.drsm.sh</code> (or the file <code>DRSM_CONFIG</code> names)</td></tr>
      <tr><td>Hosts</td><td><code>~/drsm/etc/hosts/&lt;host&gt;.conf</code>, defaults for all hosts in <code>_defaults.conf</code></td></tr>
      <tr><td>Organizations and sites</td><td><code>~/drsm/etc/sites/&lt;org&gt;/&lt;site&gt;.site</code></td></tr>
      <tr><td>Checks</td><td><code>~/drsm/plugins/&lt;category&gt;/&lt;name&gt;</code>, your own in <code>plugins/local</code></td></tr>
      <tr><td>Dashboard settings and menus</td><td><code>$CONFIGdir/drsm.php</code></td></tr>
      <tr><td>Dashboard colors</td><td><code>$WWWdir/site/custom.css</code></td></tr>
      <tr><td>Status messages</td><td><code>$CONFIGdir/messages.conf</code></td></tr>
      <tr><td>Run logs</td><td><code>$LOGdir/drsm_run*.log</code></td></tr>
    </tbody>
  </table>

  <h2>Every day</h2>
  <ul>
    <li>Open the Overview: the banner and <strong>Needs attention</strong> list what is wrong, worst first.</li>
    <li>Check that reports are current. A host shown as Stale (purple) means its checks did not run: look at cron and the run logs.</li>
    <li>Alerts go to the addresses in <code>alert.email.list</code> or the site's <code>ALERT_EMAIL</code>. See <?php echo help_doc("alerts.html", "Thresholds and alerts"); ?>.</li>
  </ul>

  <h2>Add a host</h2>
  <h3>Linux host from a host file</h3>
<pre><code>$ cp ~/drsm/etc/hosts/example.conf_example ~/drsm/etc/hosts/web2.conf
$ vi ~/drsm/etc/hosts/web2.conf          # HOST, DESCRIPTION, IMPACT, GROUP
$ ~/drsm/bin/drsm_run.sh -n -H web2 -v   # one run, no alerts</code></pre>
  <p>The monitor account's SSH key must be in the host's <code>authorized_keys</code>.</p>
  <h3>Linux host from Ansible</h3>
  <p>With <code>ANSIBLE_INVENTORY</code> (or Ansible Automation Platform, <code>ANSIBLE_AAP_URL</code>) set, add the host to a group under one of the <code>ANSIBLE_TIERS</code> groups in Ansible. DRSM checks it from the next run. <code>utils/drsm_ansible_hosts.sh</code> lists what DRSM takes from Ansible.</p>
  <h3>Windows host</h3>
  <p>Install the DataReel Reporting Agent. When its first report arrives, <code>utils/wra_hosts.sh</code> (dry run, then <code>--apply</code>) makes its host file.</p>
  <h3>Network device or address</h3>
  <p>A host file with <code>COLLECTOR=none</code>, <code>PLUGINS=""</code> and <code>PROBES="network/ping"</code> (add <code>network/https</code> for a web service).</p>

  <h2>Remove a host</h2>
<pre><code>$ ~/drsm/utils/drsm_remove_host.sh web2              # dry run
$ ~/drsm/utils/drsm_remove_host.sh --apply web2
$ ~/drsm/utils/drsm_remove_host.sh --apply -f retired.txt   # one host per line</code></pre>
  <p>This removes the host file (a copy goes to <code>etc/hosts/removed</code>) and its reports. A host that comes from Ansible is removed in Ansible; with <code>ANSIBLE_EXCLUSIVE=yes</code> its checks stop at once.</p>

  <h2>Change a threshold</h2>
  <p>Every plugin setting has a default in <code>plugins/&lt;category&gt;/&lt;name&gt;/plugin.conf</code>. Override it for all hosts in <code>etc/hosts/_defaults.conf</code>, for a site in its site file, or for one host in its host file, as <code>&lt;category&gt;_&lt;name&gt;_&lt;SETTING&gt;=value</code>:</p>
<pre><code>storage_disk_WARN=85
storage_disk_SKIP="/mnt/scratch"
core_cpu_TIMEOUT=60</code></pre>

  <h2>Status messages</h2>
  <p>Tell everyone about an outage or maintenance: the message scrolls across the top of every page. <a href="<?php echo h(drsm_url("messages.php")); ?>">Messages</a> lists the current ones.</p>
<pre><code>$ ~/drsm/utils/drsm_message.sh --apply add warning "Mail relay maintenance 18:00 to 19:00" --until "2026-11-03 19:00"
$ ~/drsm/utils/drsm_message.sh list
$ ~/drsm/utils/drsm_message.sh --apply remove 1</code></pre>

  <h2>Your own scripts and pages</h2>
  <ul>
    <li>A new check on a host: write a plugin in <code>plugins/local</code>. See <?php echo help_doc("plugins.html", "Plugins"); ?>.</li>
    <li>A script that already writes a report file: list it in <code>$EXTreports</code> to show it on the dashboard with a state. Start status lines with ERROR, WARNING or INFO and write a <code>REPORT_ETIME:</code> line with the run time.</li>
    <li>Menus, logo, footer and site links: <code>$CONFIGdir/drsm.php</code> and the site file. See <?php echo help_doc("dashboard.html", "Web dashboard"); ?>.</li>
  </ul>

  <h2>Upgrade</h2>
  <ol>
    <li>Unpack the new release beside the old source.</li>
    <li>Run <code>utils/install.sh</code> from it as the DRSM user. Host files, site files, <code>plugins/local</code>, <code>_defaults.conf</code>, <code>config/drsm.php</code> (the new one is written as <code>drsm.php_install_new</code>) and <code>$WWWdir/site</code> are kept.</li>
    <li>Compare <code>drsm.php_install_new</code> with <code>drsm.php</code> for new settings, and read <?php echo help_doc("changelog.html", "What's new"); ?>.</li>
    <li><code>drsm_run.sh -l</code>, then one run with <code>-n</code>.</li>
  </ol>

  <h2>Troubleshooting</h2>
  <table class="table">
    <thead><tr><th>Symptom</th><th>Look at</th></tr></thead>
    <tbody>
      <tr><td>Host is Stale</td><td>Cron, <code>$LOGdir/drsm_run*.log</code>, <code>drsm_run.sh -n -H &lt;host&gt; -v</code></td></tr>
      <tr><td>Host is red</td><td>Its report page: the first ERROR line under its check</td></tr>
      <tr><td>A check is Unknown</td><td>A command in the plugin's <code>REQUIRES</code> is missing on the host</td></tr>
      <tr><td>Host waits for its first report</td><td>It is new, or its report folder is left from a removed host (<code>drsm_remove_host.sh</code>)</td></tr>
      <tr><td>Page blank or wrong</td><td>The Web server error log, <code>php -l</code> on the page</td></tr>
      <tr><td>No alert email</td><td><code>-n</code> on the cron line, the address lists, the mail relay</td></tr>
    </tbody>
  </table>

  <h2>AI assistants</h2>
  <p>The DRSM source has <code>AGENTS.md</code> (read by most AI coding assistants) with <code>.github/copilot-instructions.md</code>, <code>GEMINI.md</code> and <code>CLAUDE.md</code> pointing to it, and task guides in <code>docs/ai</code>. Ask an assistant to add a host, write a plugin or change the dashboard and it follows the DRSM rules. See <?php echo help_doc("ai-assistants.html", "AI assistants"); ?>.</p>
<?php
// SCRIPT CONTENT ENDS ABOVE.
// ----------------------------------------------------------- //
// ------------------------------- //
// --------- End of File --------- //
// ------------------------------- //
?>
