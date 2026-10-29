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

Vulnerability scan results for the Vulnerabilities page. The
linux/vulnerabilities plugin reads the scan results in each DataReel
Reporting Agent for Linux report and prints "VULN kind|field|..."
lines in its report section: summary, advisory, unfixed (CVEs with no
fix yet, from CSAF/VEX scans), compliance and rule.
*/
// ----------------------------------------------------------- //
// SCRIPT CONTENT STARTS BELOW.

define("DRSM_VULN_PLUGIN", "linux/vulnerabilities");

// Severities, most severe first: label => CSS state class
function drsm_vuln_severities()
{
  return array("Critical" => "err", "Important" => "warn", "Moderate" => "stale", "Low" => "unk", "Unknown" => "unk");
}

function drsm_vuln_rank($sev)
{
  $i = array_search($sev, array_keys(drsm_vuln_severities()));
  return $i === false ? 9 : $i;
}

/*
A host's linux/vulnerabilities section, or null. Returns source,
scan_time, status, counts (severity => n), total, cves, advisories
(id, severity, issued, cves, packages, title), unfixed (cve, severity,
packages, state), nunfixed (null when the scan cannot tell), compliance (profile,
score, pass, fail, time) or null, rules (rule, severity), state and
the host.
*/
function drsm_vuln_parse($host)
{
  if(!isset($host["report"]["sections"])) return null;
  foreach($host["report"]["sections"] as $s) {
    if($s["id"] != DRSM_VULN_PLUGIN) continue;
    $v = array("source" => "", "scan_time" => 0, "status" => "", "counts" => array(), "total" => 0, "cves" => 0,
               "advisories" => array(), "unfixed" => array(), "nunfixed" => null, "compliance" => null, "rules" => array(), "state" => $s["state"], "host" => $host);
    foreach(array_keys(drsm_vuln_severities()) as $sev) $v["counts"][$sev] = 0;
    foreach($s["lines"] as $line) {
      if(!preg_match('/^VULN ([a-z]+)\|(.*)$/', $line, $m)) continue;
      $f = explode("|", $m[2]);
      switch($m[1]) {
      case "summary":
        if(count($f) < 10) break;
        $v["source"] = $f[0];
        $v["scan_time"] = ctype_digit($f[1]) ? drsm_demo_time((int)$f[1]) : 0;
        $sevs = array_keys(drsm_vuln_severities());
        for($i = 0; $i < 5; $i++) $v["counts"][$sevs[$i]] = (int)$f[2 + $i];
        $v["total"] = (int)$f[7];
        $v["cves"] = (int)$f[8];
        $v["status"] = $f[9];
        if(isset($f[10]) && ctype_digit($f[10])) $v["nunfixed"] = (int)$f[10];
        break;
      case "unfixed":
        if(count($f) < 4) break;
        $v["unfixed"][] = array("cve" => $f[0], "severity" => isset(drsm_vuln_severities()[$f[1]]) ? $f[1] : "Unknown",
                                "packages" => $f[2] == "" ? array() : explode(",", $f[2]), "state" => $f[3]);
        break;
      case "advisory":
        if(count($f) < 6) break;
        $v["advisories"][] = array("id" => $f[0], "severity" => isset(drsm_vuln_severities()[$f[1]]) ? $f[1] : "Unknown",
                                   "issued" => $f[2], "cves" => $f[3] == "" ? array() : explode(",", $f[3]),
                                   "packages" => $f[4] == "" ? array() : explode(",", $f[4]),
                                   "title" => implode("|", array_slice($f, 5)));
        break;
      case "compliance":
        if(count($f) < 5) break;
        $v["compliance"] = array("profile" => $f[0], "score" => $f[1], "pass" => (int)$f[2], "fail" => (int)$f[3],
                                 "time" => ctype_digit($f[4]) ? drsm_demo_time((int)$f[4]) : 0);
        break;
      case "rule":
        if(count($f) >= 2) $v["rules"][] = array("rule" => $f[0], "severity" => $f[1]);
        break;
      }
    }
    if($host["stale"]) $v["state"] = drsm_worst($v["state"], "STALE");
    return $v;
  }
  return null;
}

// Hosts with a linux/vulnerabilities section, by host key
function drsm_vulns($hosts)
{
  $out = array();
  foreach($hosts as $key => $hst) {
    $v = drsm_vuln_parse($hst);
    if($v !== null) $out[$key] = $v;
  }
  return $out;
}

/*
Advisories across hosts, most severe and most widespread first: id =>
severity, title, issued, cves, hosts (host keys)
*/
function drsm_vuln_advisories($vulns)
{
  $out = array();
  foreach($vulns as $key => $v) {
    foreach($v["advisories"] as $a) {
      if(!isset($out[$a["id"]])) $out[$a["id"]] = $a + array("hosts" => array());
      $out[$a["id"]]["hosts"][] = $key;
    }
  }
  uasort($out, function($a, $b) {
    $d = drsm_vuln_rank($a["severity"]) - drsm_vuln_rank($b["severity"]);
    if($d != 0) return $d;
    $d = count($b["hosts"]) - count($a["hosts"]);
    return $d != 0 ? $d : strcmp($b["id"], $a["id"]);
  });
  return $out;
}

// Link for an advisory or CVE id: Red Hat errata and CVE pages, EPEL
// updates in Bodhi
function drsm_vuln_url($id)
{
  if(preg_match('/^RH[SBE]A-\d{4}:\d+$/', $id)) return "https://access.redhat.com/errata/{$id}";
  if(preg_match('/^CVE-\d{4}-\d+$/', $id)) return "https://access.redhat.com/security/cve/{$id}";
  if(preg_match('/^FEDORA-EPEL-[0-9A-Za-z-]+$/', $id)) return "https://bodhi.fedoraproject.org/updates/{$id}";
  return "";
}

function drsm_vuln_link($id)
{
  $url = drsm_vuln_url($id);
  if($url == "") return h($id);
  return "<a href=\"" . h($url) . "\" target=\"_blank\" rel=\"noopener noreferrer\">" . h($id) . "</a>";
}

function drsm_vuln_badge($sev)
{
  $sevs = drsm_vuln_severities();
  $cls = isset($sevs[$sev]) ? $sevs[$sev] : "unk";
  return "<span class=\"badge {$cls}\">" . h($sev) . "</span>";
}

/*
Path of a host's OpenSCAP HTML report from the Linux agent ($kind scap
or compliance), or "" when there is none. The reports are in
$LRAreportsDir, the agent server's reports_dir, which only exists on
the server that receives the uploads.
*/
function drsm_vuln_html_path($hostname, $kind)
{
  global $LRAreportsDir;
  if(!isset($LRAreportsDir) || $LRAreportsDir == "") return "";
  if(!drsm_valid_host($hostname) || ($kind != "scap" && $kind != "compliance")) return "";
  $name = strtolower(preg_replace('/\..*$/', "", $hostname));
  $f = rtrim($LRAreportsDir, "/") . "/{$name}_linux_{$kind}_report.html";
  return is_file($f) && is_readable($f) ? $f : "";
}

// True when any host in scope runs the linux/vulnerabilities plugin
function drsm_vulns_present()
{
  static $present = null;
  if($present !== null) return $present;
  $present = false;
  foreach(drsm_scope_sites(drsm_scope()) as $site => $s) {
    $files = glob(drsm_site_dir($site) . "/systems/*/status.json");
    if($files === false) continue;
    foreach($files as $f) {
      $json = @file_get_contents($f, false, null, 0, 65536);
      if($json === false) continue;
      if(strpos($json, "\"" . str_replace("/", "\\/", DRSM_VULN_PLUGIN) . "\"") !== false ||
         strpos($json, "\"" . DRSM_VULN_PLUGIN . "\"") !== false) {
        $present = true;
        return $present;
      }
    }
  }
  return $present;
}

// SCRIPT CONTENT ENDS ABOVE.
// ----------------------------------------------------------- //
// ------------------------------- //
// --------- End of File --------- //
// ------------------------------- //
?>
