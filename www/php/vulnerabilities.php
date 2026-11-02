<?php
// ------------------------------- //
// -------- Start of File -------- //
// ------------------------------- //
// ----------------------------------------------------------- //
// PHP Source Code File
// PHP Version: 7.2 or higher, tested with PHP 8
// Original Author(s): DataReel Software Development
// File Creation Date: 10/29/2026
// Date Last Modified: 10/29/2026
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

DRSM vulnerabilities: the security advisories (Red Hat errata and
their CVEs) that apply to each host running the DataReel Reporting
Agent for Linux, from the agent's OpenSCAP, CSAF/VEX or dnf scan, read
through the linux/vulnerabilities plugin, and the security updates
(KB numbers, MSRC severity, CVEs) that hosts running the DataReel
Reporting Agent for Windows still need, from the agent's Windows
Update scan, read through the windows/vulnerabilities plugin. The
fleet view lists hosts and the advisories that affect the most hosts;
?n=<host> shows one host's advisories, packages, compliance results
and its OpenSCAP HTML report.

The menu shows it when a host runs either plugin.
On the server that receives the agent uploads, set the agent server's
reports_dir in config/drsm.php for the OpenSCAP HTML reports:
  $LRAreportsDir = "/var/www/html/linux/reports";
*/
// ----------------------------------------------------------- //
// SCRIPT CONTENT STARTS BELOW.

require_once("../config/drsm.php");

// Our required includes
require_once("{$WWWdir}/php/query_post_validation.php");
require_once("{$WWWdir}/php/drsm_lib.php");

$hosts = drsm_load_hosts();
$vulns = drsm_vulns($hosts);
$sevs = drsm_vuln_severities();
$sev = (isset($_GET['sev']) && isset($sevs[$_GET['sev']])) ? $_GET['sev'] : "";

// One host, picked from the loaded list by name and site
$one = null;
if(isset($_GET['n']) && is_string($_GET['n'])) {
  $site = (isset($_GET['site']) && is_string($_GET['site'])) ? $_GET['site'] : DRSM_LEGACY_SITE;
  foreach($vulns as $key => $v) {
    if($v["host"]["name"] === $_GET['n'] && $v["host"]["site"] === $site) $one = $v;
  }
}

$overall = "OK";
foreach($vulns as $v) $overall = drsm_worst($overall, $v["state"]);
drsm_page_start($one ? "Vulnerabilities - " . $one["host"]["name"] : "Vulnerabilities", "vulnerabilities", count($vulns) ? $overall : "");

// Count cells for the host table, colored by severity
function vuln_counts_cells($v)
{
  $sevs = drsm_vuln_severities();
  $out = "";
  foreach(array("Critical", "Important", "Moderate", "Low") as $s) {
    $n = (int)$v["counts"][$s];
    $out .= "<td class=\"num\">" . ($n > 0 ? "<span class=\"badge {$sevs[$s]}\">{$n}</span>" : "<span class=\"muted\">0</span>") . "</td>";
  }
  return $out;
}

// Notice for hosts with no vulnerability scan yet: the agent does not
// scan on a schedule ([scan] enabled=0) and no one has run "drra scan"
// (Linux) or "drra_svc.exe scan" (Windows). $names empty for the one
// host view; $oses the host OSes (linux, windows) the text is for
function vuln_off_callout($names = array(), $oses = array("linux"))
{
  $who = count($names) == 0 ? "this host" : count($names) . (count($names) == 1 ? " host: " : " hosts: ") . implode(", ", array_map("h", $names));
  $how = array();
  if(in_array("linux", $oses)) $how[] = "Run <code>sudo drra scan</code> on " . (in_array("windows", $oses) ? "a Linux host" : "the host") .
                                 " or schedule scans with <code>[scan] enabled=1</code> in <code>/etc/drra/drra.ini</code>.";
  if(in_array("windows", $oses)) $how[] = "Run <code>drra_svc.exe scan</code> from an administrator command prompt on " .
                                   (in_array("linux", $oses) ? "a Windows host" : "the host") .
                                   " or schedule scans with <code>[scan] enabled=1</code> in its <code>drra.ini</code>.";
  return "<div class=\"callout\">" . drsm_icon("lock") . "<span>No vulnerability scan yet on {$who}. " . implode(" ", $how) .
    " A scan run by hand sends the results right away.</span></div>\n";
}

function vuln_scan_text($v)
{
  if($v["status"] == "disabled") return "<span class=\"muted\">no scan yet</span>";
  if($v["status"] == "pending") return "<span class=\"muted\">first scan pending</span>";
  if($v["status"] == "failed") return drsm_badge("WARNING", " scan failed");
  $names = array("oval" => "OpenSCAP OVAL", "csaf" => "CSAF/VEX", "dnf" => "dnf updateinfo", "wua" => "Windows Update");
  $src = isset($names[$v["source"]]) ? $names[$v["source"]] : $v["source"];
  return drsm_time_html($v["scan_time"]) . " <span class=\"tag\">" . h($src) . "</span>";
}
?>
<section class="page-head">
  <div>
    <h1><?php echo $one ? h($one["host"]["name"]) . " vulnerabilities" : "Vulnerabilities"; ?></h1>
    <p class="muted">Security advisories and updates that agent hosts still need, from each Linux host's OpenSCAP, CSAF/VEX or dnf scan and each Windows host's Windows Update scan</p>
  </div>
<?php if($one) { ?>
  <div class="head-actions">
    <a class="btn" href="<?php echo h(drsm_url("vulnerabilities.php")); ?>"><?php echo drsm_icon("back"); ?>All hosts</a>
    <a class="btn" href="<?php echo h(drsm_host_url("readreport.php", $one["host"], array(), drsm_plugin_anchor($one["plugin"]))); ?>"><?php echo drsm_icon("file"); ?>Host report</a>
  </div>
<?php } ?>
</section>
<?php
if(count($vulns) == 0) {
?>
<section class="panel">
  <div class="empty">
    <?php echo drsm_icon("lock"); ?>
    <p>No host reports vulnerability scan results yet.</p>
    <p class="muted">Install the DataReel Reporting Agent for Linux on a host, add it with <code>COLLECTOR=lra</code> and <code>linux/vulnerabilities</code> in its <code>PLUGINS</code>, or the DataReel Reporting Agent for Windows (3.5 or later) with <code>COLLECTOR=wra</code> and <code>windows/vulnerabilities</code>; results show here after the agent's first scan and the next DRSM run.</p>
  </div>
</section>
<?php
  drsm_page_end();
  exit;
}

if($one === null) {
  // ---------------------------------------------------------- fleet view
  $adv = drsm_vuln_advisories($vulns);
  $tot = array();
  foreach(array_keys($sevs) as $s) $tot[$s] = 0;
  $cves = array();
  $hosts_crit = 0;
  $oldest = 0;
  $unfixed = array();
  foreach($vulns as $v) {
    foreach($v["unfixed"] as $u) $unfixed[$u["cve"]] = $u["severity"];
    if($v["counts"]["Critical"] > 0) $hosts_crit++;
    if($v["scan_time"] > 0 && ($oldest == 0 || $v["scan_time"] < $oldest)) $oldest = $v["scan_time"];
  }
  foreach($adv as $a) {
    $tot[$a["severity"]]++;
    foreach($a["cves"] as $c) $cves[$c] = 1;
  }
  $order = $vulns;
  uasort($order, function($a, $b) {
    foreach(array("Critical", "Important", "Moderate", "Low") as $s) {
      if($a["counts"][$s] != $b["counts"][$s]) return $b["counts"][$s] - $a["counts"][$s];
    }
    return strcmp($a["host"]["name"], $b["host"]["name"]);
  });
?>
<?php
  $off = array();
  $off_os = array();
  foreach($order as $v) if($v["status"] == "disabled") { $off[] = $v["host"]["name"]; $off_os[$v["os"]] = $v["os"]; }
  if(count($off) > 0) echo vuln_off_callout($off, array_values($off_os));
?>
<section class="kpis" aria-label="Summary">
  <div class="kpi <?php echo h(drsm_state_class($overall)); ?>"><span class="kpi-label">Hosts scanned</span><span class="kpi-value"><?php echo count($vulns); ?></span><span class="kpi-sub"><?php echo (int)$hosts_crit; ?> with critical advisories</span></div>
  <a class="kpi <?php echo $tot["Critical"] > 0 ? "err" : "ok"; ?>" href="<?php echo h(drsm_url("vulnerabilities.php", array("sev" => "Critical"))); ?>#vuln-adv"><span class="kpi-label">Critical</span><span class="kpi-value"><?php echo (int)$tot["Critical"]; ?></span><span class="kpi-sub">advisories</span></a>
  <a class="kpi <?php echo $tot["Important"] > 0 ? "warn" : "ok"; ?>" href="<?php echo h(drsm_url("vulnerabilities.php", array("sev" => "Important"))); ?>#vuln-adv"><span class="kpi-label">Important</span><span class="kpi-value"><?php echo (int)$tot["Important"]; ?></span><span class="kpi-sub">advisories</span></a>
  <a class="kpi <?php echo $tot["Moderate"] + $tot["Low"] > 0 ? "stale" : "ok"; ?>" href="<?php echo h(drsm_url("vulnerabilities.php", array("sev" => "Moderate"))); ?>#vuln-adv"><span class="kpi-label">Moderate and low</span><span class="kpi-value"><?php echo (int)($tot["Moderate"] + $tot["Low"]); ?></span><span class="kpi-sub">advisories</span></a>
  <div class="kpi"><span class="kpi-label">CVEs</span><span class="kpi-value"><?php echo count($cves); ?></span><span class="kpi-sub">oldest scan <?php echo $oldest ? drsm_time_html($oldest) : "none"; ?></span></div>
  <div class="kpi <?php echo in_array("Critical", $unfixed) ? "warn" : ""; ?>"><span class="kpi-label">No fix yet</span><span class="kpi-value"><?php echo count($unfixed); ?></span><span class="kpi-sub">CVEs, from CSAF/VEX scans</span></div>
</section>
<section class="panel flush">
  <div class="panel-head pad"><h2><?php echo drsm_icon("list"); ?>Hosts</h2><span class="muted small">Select a host for its advisories and packages</span></div>
  <div class="table-wrap">
    <table class="table">
      <thead><tr><th scope="col">Host</th><th scope="col">State</th><th scope="col" class="num">Critical</th><th scope="col" class="num">Important</th><th scope="col" class="num">Moderate</th><th scope="col" class="num">Low</th><th scope="col" class="num">CVEs</th><th scope="col" class="num">No fix</th><th scope="col">Compliance</th><th scope="col">Last scan</th></tr></thead>
      <tbody>
<?php foreach($order as $key => $v) { $hst = $v["host"]; ?>
        <tr class="<?php echo $v["counts"]["Critical"] > 0 ? "row-err" : ""; ?>">
          <th scope="row"><a href="<?php echo h(drsm_host_url("vulnerabilities.php", $hst)); ?>"><strong><?php echo h($hst["name"]); ?></strong></a><?php if($hst["site"] != DRSM_LEGACY_SITE) { ?> <span class="tag"><?php echo h($hst["site"]); ?></span><?php } ?></th>
          <td><?php echo drsm_badge($v["state"]); ?></td>
          <?php echo vuln_counts_cells($v); ?>

          <td class="num"><?php echo (int)$v["cves"]; ?></td>
          <td class="num"><?php echo $v["nunfixed"] === null ? "<span class=\"muted\" title=\"Only CSAF/VEX scans list CVEs with no fix\">n/a</span>" : (int)$v["nunfixed"]; ?></td>
          <td class="small"><?php echo $v["compliance"] ? h($v["compliance"]["profile"] . " " . $v["compliance"]["score"]) : "<span class=\"muted\">none</span>"; ?></td>
          <td class="small"><?php echo vuln_scan_text($v); ?></td>
        </tr>
<?php } ?>
      </tbody>
    </table>
  </div>
</section>
<section class="panel flush" id="vuln-adv">
  <div class="panel-head pad wrap"><h2><?php echo drsm_icon("alert"); ?>Advisories</h2>
    <div class="seg" role="group" aria-label="Severity">
      <a class="<?php echo $sev == "" ? "active" : ""; ?>" href="<?php echo h(drsm_url("vulnerabilities.php")); ?>#vuln-adv">All</a>
<?php foreach($sevs as $s => $cls) { if($s == "Unknown" && $tot["Unknown"] == 0) continue; ?>
      <a class="<?php echo $sev == $s ? "active" : ""; ?>" href="<?php echo h(drsm_url("vulnerabilities.php", array("sev" => $s))); ?>#vuln-adv"><span class="dot" style="--tone: var(--<?php echo h($cls); ?>)"></span><?php echo h($s); ?> <?php echo (int)$tot[$s]; ?></a>
<?php } ?>
    </div>
  </div>
  <div class="table-wrap">
    <table class="table">
      <thead><tr><th scope="col">Advisory</th><th scope="col">Severity</th><th scope="col">Title</th><th scope="col">Issued</th><th scope="col" class="num">CVEs</th><th scope="col">Hosts</th></tr></thead>
      <tbody>
<?php
  $shown = 0;
  foreach($adv as $id => $a) {
    if($sev != "" && $a["severity"] != $sev) continue;
    if(++$shown > 500) break;
    $names = array();
    foreach($a["hosts"] as $k) $names[] = "<a href=\"" . h(drsm_host_url("vulnerabilities.php", $vulns[$k]["host"])) . "\">" . h($vulns[$k]["host"]["name"]) . "</a>";
?>
        <tr>
          <th scope="row"><?php echo drsm_vuln_link($id); ?></th>
          <td><?php echo drsm_vuln_badge($a["severity"]); ?></td>
          <td class="small"><?php echo h($a["title"]); ?></td>
          <td class="small"><?php echo h($a["issued"]); ?></td>
          <td class="num"><?php echo count($a["cves"]); ?></td>
          <td class="small"><?php echo count($names); ?>: <?php echo implode(", ", $names); ?></td>
        </tr>
<?php } ?>
<?php if($shown == 0) { ?>
        <tr><td colspan="6" class="muted">No <?php echo h($sev != "" ? strtolower($sev) . " " : ""); ?>advisories apply to any host.</td></tr>
<?php } else if($shown > 500) { ?>
        <tr><td colspan="6" class="muted">Only the first 500 advisories are shown.</td></tr>
<?php } ?>
      </tbody>
    </table>
  </div>
</section>
<?php
}
else {
  // ---------------------------------------------------------- one host
  $v = $one;
  $hst = $v["host"];
  $scap = drsm_vuln_html_path($hst["name"], "scap");
  $comp = drsm_vuln_html_path($hst["name"], "compliance");
?>
<?php if($v["status"] == "disabled") echo vuln_off_callout(array(), array($v["os"])); ?>
<section class="kpis" aria-label="Summary">
  <div class="kpi <?php echo h(drsm_state_class($v["state"])); ?>"><span class="kpi-label">State</span><span class="kpi-value"><?php echo h(drsm_state_label($v["state"])); ?></span><span class="kpi-sub"><?php echo vuln_scan_text($v); ?></span></div>
<?php foreach(array("Critical", "Important", "Moderate", "Low") as $s) { ?>
  <div class="kpi <?php echo $v["counts"][$s] > 0 ? h($sevs[$s]) : "ok"; ?>"><span class="kpi-label"><?php echo h($s); ?></span><span class="kpi-value"><?php echo (int)$v["counts"][$s]; ?></span><span class="kpi-sub"><?php echo $v["os"] == "windows" ? "updates" : "advisories"; ?></span></div>
<?php } ?>
</section>
<?php if($scap != "" || $comp != "") { ?>
<section class="panel">
  <div class="panel-head"><h2><?php echo drsm_icon("file"); ?>OpenSCAP reports</h2></div>
  <p>
<?php if($scap != "") { ?>
    <a class="btn" href="<?php echo h(drsm_url("scap_report.php", array("n" => $hst["name"], "site" => $hst["site"], "kind" => "scap"))); ?>" target="_blank" rel="noopener"><?php echo drsm_icon("external"); ?>Vulnerability scan report</a>
    <span class="muted small">saved <?php echo drsm_time_html(drsm_demo_time((int)filemtime($scap))); ?></span>
<?php } ?>
<?php if($comp != "") { ?>
    <a class="btn" href="<?php echo h(drsm_url("scap_report.php", array("n" => $hst["name"], "site" => $hst["site"], "kind" => "compliance"))); ?>" target="_blank" rel="noopener"><?php echo drsm_icon("external"); ?>Compliance scan report</a>
<?php } ?>
  </p>
</section>
<?php } ?>
<section class="panel flush">
  <div class="panel-head pad"><h2><?php echo drsm_icon("alert"); ?><?php echo $v["os"] == "windows" ? "Security updates" : "Advisories"; ?></h2><span class="muted small"><?php echo (int)$v["total"]; ?> <?php echo $v["os"] == "windows" ? ($v["total"] == 1 ? "security update" : "security updates") : ($v["total"] == 1 ? "advisory" : "advisories"); ?>, <?php echo (int)$v["cves"]; ?> <?php echo $v["cves"] == 1 ? "CVE" : "CVEs"; ?>. <?php if($v["os"] == "windows") { ?>Install the updates with Windows Update (Settings &gt; Windows Update) or your WSUS or Intune server.<?php } else { ?>Install the updates with <code>dnf update --advisory=&lt;id&gt;</code> or <code>dnf update --security</code>.<?php } ?></span></div>
  <div class="table-wrap">
    <table class="table">
      <thead><tr><th scope="col"><?php echo $v["os"] == "windows" ? "Update" : "Advisory"; ?></th><th scope="col">Severity</th><th scope="col">Title</th><th scope="col">Issued</th><th scope="col"><?php echo $v["os"] == "windows" ? "Products" : "Fixed packages"; ?></th><th scope="col">CVEs</th></tr></thead>
      <tbody>
<?php foreach($v["advisories"] as $a) {
  $cl = array();
  foreach($a["cves"] as $c) $cl[] = drsm_vuln_link($c, $v["os"]);
?>
        <tr>
          <th scope="row"><?php echo drsm_vuln_link($a["id"], $v["os"]); ?></th>
          <td><?php echo drsm_vuln_badge($a["severity"]); ?></td>
          <td class="small"><?php echo h($a["title"]); ?></td>
          <td class="small"><?php echo h($a["issued"]); ?></td>
          <td class="small"><?php if(count($a["packages"]) == 0) { ?><span class="muted">none listed</span><?php } else { ?><code><?php echo implode("</code><br><code>", array_map("h", array_slice($a["packages"], 0, 6))); ?></code><?php } ?><?php if(count($a["packages"]) > 6) echo " <span class=\"muted\">+" . (count($a["packages"]) - 6) . " more</span>"; ?></td>
          <td class="small"><?php if(count($cl) <= 4) { echo implode(", ", $cl); } else { ?><details><summary><?php echo count($cl); ?> CVEs</summary><?php echo implode(", ", $cl); ?></details><?php } ?></td>
        </tr>
<?php } ?>
<?php if(count($v["advisories"]) == 0) { ?>
        <tr><td colspan="6" class="muted"><?php echo $v["status"] == "ok" ? ($v["os"] == "windows" ? "No security updates to install on this host." : "No security advisories apply to this host.") : ($v["status"] == "disabled" ? "No vulnerability scan yet on this host." : "No scan results."); ?></td></tr>
<?php } ?>
      </tbody>
    </table>
  </div>
</section>
<?php if(count($v["other"]) > 0) { ?>
<section class="panel flush">
  <div class="panel-head pad"><h2><?php echo drsm_icon("list"); ?>Other updates</h2><span class="muted small"><?php echo count($v["other"]); ?> updates waiting that are not security updates: drivers, definitions, feature and preview updates</span></div>
  <div class="table-wrap">
    <table class="table">
      <thead><tr><th scope="col">Update</th><th scope="col">Classification</th><th scope="col">Title</th><th scope="col">Issued</th></tr></thead>
      <tbody>
<?php foreach($v["other"] as $o) { ?>
        <tr>
          <th scope="row"><?php echo drsm_vuln_link($o["id"], $v["os"]); ?></th>
          <td class="small"><?php echo h($o["classification"]); ?></td>
          <td class="small"><?php echo h($o["title"]); ?></td>
          <td class="small"><?php echo h($o["issued"]); ?></td>
        </tr>
<?php } ?>
      </tbody>
    </table>
  </div>
</section>
<?php } ?>
<?php if(count($v["unfixed"]) > 0) { ?>
<section class="panel flush">
  <div class="panel-head pad"><h2><?php echo drsm_icon("alert"); ?>No fix yet</h2><span class="muted small"><?php echo (int)$v["nunfixed"]; ?> CVEs affect installed packages and Red Hat has no update for them yet</span></div>
  <div class="table-wrap">
    <table class="table">
      <thead><tr><th scope="col">CVE</th><th scope="col">Severity</th><th scope="col">Packages</th><th scope="col">Red Hat state</th></tr></thead>
      <tbody>
<?php foreach($v["unfixed"] as $u) { ?>
        <tr>
          <th scope="row"><?php echo drsm_vuln_link($u["cve"]); ?></th>
          <td><?php echo drsm_vuln_badge($u["severity"]); ?></td>
          <td class="small"><code><?php echo implode("</code>, <code>", array_map("h", $u["packages"])); ?></code></td>
          <td class="small"><?php echo h($u["state"]); ?></td>
        </tr>
<?php } ?>
      </tbody>
    </table>
  </div>
</section>
<?php } ?>
<?php if($v["compliance"]) { $c = $v["compliance"]; ?>
<section class="panel flush">
  <div class="panel-head pad"><h2><?php echo drsm_icon("check"); ?>Compliance: <?php echo h($c["profile"]); ?></h2><span class="muted small">score <?php echo h($c["score"]); ?>, <?php echo (int)$c["pass"]; ?> rules pass, <?php echo (int)$c["fail"]; ?> fail, scanned <?php echo drsm_time_html($c["time"]); ?></span></div>
  <div class="table-wrap">
    <table class="table">
      <thead><tr><th scope="col">Failed rule</th><th scope="col">Severity</th></tr></thead>
      <tbody>
<?php foreach($v["rules"] as $r) { ?>
        <tr><td><code><?php echo h($r["rule"]); ?></code></td><td><?php echo drsm_vuln_badge(ucfirst($r["severity"]) == "High" ? "Important" : (ucfirst($r["severity"]) == "Medium" ? "Moderate" : ucfirst($r["severity"]))); ?></td></tr>
<?php } ?>
<?php if(count($v["rules"]) == 0) { ?>
        <tr><td colspan="2" class="muted">No failed rules.</td></tr>
<?php } ?>
      </tbody>
    </table>
  </div>
</section>
<?php } ?>
<?php
}
drsm_page_end();

// SCRIPT CONTENT ENDS ABOVE.
// ----------------------------------------------------------- //
// ------------------------------- //
// --------- End of File --------- //
// ------------------------------- //
?>
