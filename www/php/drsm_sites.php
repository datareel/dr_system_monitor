<?php
// ------------------------------- //
// -------- Start of File -------- //
// ------------------------------- //
// ----------------------------------------------------------- //
// PHP Source Code File
// PHP Version: 7.2 or higher, tested with PHP 8
// Original Author(s): DataReel Software Development 
// File Creation Date: 10/27/2026
// Date Last Modified: 10/27/2026
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

Organizations and sites for the DRSM Web pages. bin/drsm_run.sh
writes each site to ${REPORTdir}/orgs/<org>/<site> with a site.json,
and each organization's org.json to ${REPORTdir}/orgs/<org>. Hosts in
no site are in the default/default site, which keeps the reports in
${REPORTdir} as before sites.

A host is found by its name and site: n=<host>&site=<org>/<site>, or
n=<org>/<site>/<host>. A plain host name works when only one visible
site has that host.

The site picker sets the scope of the list pages: every site, one
organization or one site. It is kept in a cookie, since the pages run
without a PHP session when login is off. Which sites a user may see is
decided by drsm_auth.php, the scope only narrows that.

Keep this file PHP 7.2 compatible.
*/
// ----------------------------------------------------------- //
// SCRIPT CONTENT STARTS BELOW.

define("DRSM_LEGACY_SITE", "default/default");

$DRSMscope = null;

function drsm_valid_id($s)
{
  return is_string($s) && (bool)preg_match('/^[a-z0-9][a-z0-9_-]*$/', $s);
}

function drsm_valid_site($s)
{
  return is_string($s) && (bool)preg_match('/^[a-z0-9][a-z0-9_-]*\/[a-z0-9][a-z0-9_-]*$/', $s);
}

// A scope is "" for every site, an organization ID, or org/site
function drsm_valid_scope($s)
{
  return $s === "" || drsm_valid_id($s) || drsm_valid_site($s);
}

function drsm_site_dir($site)
{
  global $REPORTdir;
  if($site == DRSM_LEGACY_SITE) return $REPORTdir;
  return "{$REPORTdir}/orgs/{$site}";
}

function drsm_site_vpath($site)
{
  global $REPORTvpath;
  if($site == DRSM_LEGACY_SITE) return $REPORTvpath;
  return "{$REPORTvpath}/orgs/{$site}";
}

function drsm_read_json($fname)
{
  $data = @file_get_contents($fname, false, null, 0, DRSM_MAX_REPORT_BYTES);
  if($data === false) return null;
  $d = json_decode($data, true);
  return is_array($d) ? $d : null;
}

function drsm_dir_has_hosts($dir)
{
  if(!is_dir($dir)) return false;
  foreach(scandir($dir) ?: array() as $name) {
    if(substr($name, 0, 1) != "." && drsm_valid_host($name) && is_dir("{$dir}/{$name}")) return true;
  }
  return false;
}

function drsm_site_record($id, $js, $org)
{
  global $STALEminutes;
  $legacy = ($id == DRSM_LEGACY_SITE);
  list($o, $s) = explode("/", $id, 2);
  $stale = (is_array($js) && isset($js["stale_minutes"]) && (int)$js["stale_minutes"] > 0) ? (int)$js["stale_minutes"] : $STALEminutes;
  return array(
    "id" => $id,
    "org" => $o,
    "site" => $s,
    "legacy" => $legacy,
    "name" => (is_array($js) && isset($js["name"]) && $js["name"] != "") ? (string)$js["name"] : ($legacy ? "Default site" : $s),
    "location" => (is_array($js) && isset($js["location"])) ? (string)$js["location"] : "",
    "collector" => (is_array($js) && isset($js["collector"])) ? (string)$js["collector"] : "",
    "time" => (is_array($js) && isset($js["time"])) ? drsm_demo_time((int)$js["time"]) : 0,
    "posted" => is_array($js),
    "stale_minutes" => $stale,
    "orgname" => (is_array($org) && isset($org["name"]) && $org["name"] != "") ? (string)$org["name"] : ($legacy ? "Default" : $o),
    "contact" => (is_array($org) && isset($org["contact"])) ? (string)$org["contact"] : ""
  );
}

// Every site with reports, before access checks. The default site is
// listed when it has hosts, or when there is no other site.
function drsm_all_sites()
{
  global $REPORTdir;
  static $cache = null;
  if($cache !== null) return $cache;
  $sites = array();
  $odirs = glob("{$REPORTdir}/orgs/*", GLOB_ONLYDIR) ?: array();
  sort($odirs);
  foreach($odirs as $odir) {
    $o = basename($odir);
    if(!drsm_valid_id($o)) continue;
    $org = drsm_read_json("{$odir}/org.json");
    $sdirs = glob("{$odir}/*", GLOB_ONLYDIR) ?: array();
    sort($sdirs);
    foreach($sdirs as $sdir) {
      $s = basename($sdir);
      if(!drsm_valid_id($s)) continue;
      $js = drsm_read_json("{$sdir}/site.json");
      if($js === null && !is_dir("{$sdir}/systems")) continue;
      $sites["{$o}/{$s}"] = drsm_site_record("{$o}/{$s}", $js, $org);
    }
  }
  if(count($sites) == 0 || drsm_dir_has_hosts("{$REPORTdir}/systems")) {
    $sites = array(DRSM_LEGACY_SITE => drsm_site_record(DRSM_LEGACY_SITE, null, null)) + $sites;
  }
  $cache = $sites;
  return $cache;
}

function drsm_site_allowed($site)
{
  return function_exists("drsm_auth_site_allowed") ? drsm_auth_site_allowed($site) : true;
}

// The sites this visitor may see
function drsm_sites()
{
  $out = array();
  foreach(drsm_all_sites() as $id => $s) {
    if(drsm_site_allowed($id)) $out[$id] = $s;
  }
  return $out;
}

function drsm_multi_site()
{
  return count(drsm_sites()) > 1;
}

// Visible sites in a scope
function drsm_scope_sites($scope)
{
  $out = array();
  foreach(drsm_sites() as $id => $s) {
    if($scope == "" || $scope == $id || $scope == $s["org"]) $out[$id] = $s;
  }
  return $out;
}

// Organizations of the visible sites: ID => name, contact, sites
function drsm_orgs($sites = null)
{
  if($sites === null) $sites = drsm_sites();
  $orgs = array();
  foreach($sites as $id => $s) {
    if(!isset($orgs[$s["org"]])) $orgs[$s["org"]] = array("id" => $s["org"], "name" => $s["orgname"], "contact" => $s["contact"], "sites" => array());
    $orgs[$s["org"]]["sites"][$id] = $s;
  }
  return $orgs;
}

// "Organization / Site" for a site, used next to host names
function drsm_site_label($site)
{
  $all = drsm_all_sites();
  if(!isset($all[$site])) return $site;
  $s = $all[$site];
  if($s["legacy"]) return $s["name"];
  return "{$s["orgname"]} / {$s["name"]}";
}

function drsm_scope_label($scope)
{
  if($scope == "") return "All sites";
  if(drsm_valid_site($scope)) return drsm_site_label($scope);
  $orgs = drsm_orgs();
  return isset($orgs[$scope]) ? $orgs[$scope]["name"] : $scope;
}

/*
Scope of a list page, from site= in the URL, else the last one picked.
List pages call drsm_scope_from_request() before drsm_scope(), host
pages leave the remembered scope alone.
*/
function drsm_scope_from_request()
{
  global $DRSMscope, $WWWvpath;
  if(!isset($_GET["site"]) || !is_string($_GET["site"])) return drsm_scope();
  $v = strtolower(trim($_GET["site"]));
  if(!drsm_valid_scope($v) || ($v != "" && count(drsm_scope_sites($v)) == 0)) return drsm_scope();
  $DRSMscope = $v;
  if(!headers_sent()) {
    $path = ($WWWvpath != "") ? "{$WWWvpath}/" : "/";
    if($v == "") header("Set-Cookie: drsm_site=; Path={$path}; Max-Age=0; SameSite=Lax", false);
    else header("Set-Cookie: drsm_site=" . rawurlencode($v) . "; Path={$path}; Max-Age=31536000; SameSite=Lax", false);
  }
  return $DRSMscope;
}

function drsm_scope()
{
  global $DRSMscope;
  if($DRSMscope !== null) return $DRSMscope;
  $DRSMscope = "";
  $v = (isset($_COOKIE["drsm_site"]) && is_string($_COOKIE["drsm_site"])) ? strtolower($_COOKIE["drsm_site"]) : "";
  if($v != "" && drsm_valid_scope($v) && count(drsm_scope_sites($v)) > 0) $DRSMscope = $v;
  return $DRSMscope;
}

// URL arguments that open host $hst on a page
function drsm_host_args($hst, $extra = array())
{
  $args = array("n" => $hst["name"]);
  if(isset($hst["site"]) && $hst["site"] != DRSM_LEGACY_SITE) $args["site"] = $hst["site"];
  return $args + $extra;
}

function drsm_host_url($page, $hst, $extra = array(), $anchor = "")
{
  return drsm_url($page, drsm_host_args($hst, $extra)) . ($anchor != "" ? "#{$anchor}" : "");
}

// Key of a host in drsm_load_hosts(): its name in the default site,
// org/site/host in the others
function drsm_host_key($name, $site)
{
  return ($site == DRSM_LEGACY_SITE) ? $name : "{$site}/{$name}";
}

/*
Find a host from n= and site=. n can also be org/site/host. site can
be an organization, to look only in its sites. Only visible sites are
searched. Returns status ok, notfound or ambiguous, with the host
name, its site and every site that matched.
*/
function drsm_resolve_host($n, $site = "")
{
  $r = array("status" => "notfound", "name" => "", "site" => "", "matches" => array());
  $n = is_string($n) ? $n : "";
  $site = is_string($site) ? strtolower($site) : "";
  if(preg_match('/^([a-z0-9][a-z0-9_-]*\/[a-z0-9][a-z0-9_-]*)\/([^\/]+)$/', $n, $m)) {
    if($site != "" && $site != $m[1]) return $r;
    $site = $m[1];
    $n = $m[2];
  }
  if(!drsm_valid_host($n) || !drsm_valid_scope($site)) return $r;
  foreach(drsm_scope_sites($site) as $id => $s) {
    if(is_dir(drsm_site_dir($id) . "/systems/{$n}")) $r["matches"][] = $id;
  }
  if(count($r["matches"]) == 1) {
    $r["status"] = "ok";
    $r["name"] = $n;
    $r["site"] = $r["matches"][0];
  }
  else if(count($r["matches"]) > 1) {
    $r["status"] = "ambiguous";
    $r["name"] = $n;
  }
  return $r;
}

/*
Summary of one site from its hosts: worst state, host counts, the
newest report, and whether its collector stopped reporting. A site's
collector rewrites site.json on every run, so an old site.json means
the collector is down even when nothing else is known.
*/
function drsm_site_summary($site, $hosts)
{
  $c = array("OK" => 0, "WARNING" => 0, "ERROR" => 0, "STALE" => 0, "UNKNOWN" => 0);
  $state = "OK";
  $latest = 0;
  foreach($hosts as $hst) {
    $c[$hst["state"]] = isset($c[$hst["state"]]) ? $c[$hst["state"]] + 1 : 1;
    $state = drsm_worst($state, $hst["state"]);
    if($hst["time"] > $latest) $latest = $hst["time"];
  }
  $seen = $site["posted"] ? $site["time"] : $latest;
  $down = ($site["stale_minutes"] > 0 && $seen > 0 && time() - $seen > $site["stale_minutes"] * 60);
  if($down) $state = drsm_worst($state, "STALE");
  if(count($hosts) == 0) $state = $down ? "STALE" : "UNKNOWN";
  return array("state" => $state, "counts" => $c, "total" => count($hosts), "latest" => $latest,
               "seen" => $seen, "down" => $down);
}

// Worst-first order for hosts, then by name
function drsm_cmp_worst($a, $b)
{
  $d = drsm_state_rank($b["state"]) - drsm_state_rank($a["state"]);
  return ($d != 0) ? $d : strcmp($a["name"], $b["name"]);
}

// Highest of a host's resource percentages, for metric tiles
function drsm_host_peak($hst)
{
  $best = null;
  $label = "";
  $cols = drsm_metric_columns();
  foreach(array("cpu", "mem", "disk", "load", "swap") as $k) {
    if(!isset($hst["metrics"][$k])) continue;
    if($best === null || $hst["metrics"][$k]["pct"] > $best) {
      $best = $hst["metrics"][$k]["pct"];
      $label = $cols[$k]["label"];
    }
  }
  return array($best, $label);
}

// Page for a host name found in more than one site
function drsm_ambiguous_page($res, $page, $param = "n")
{
  http_response_code(409);
  drsm_page_start("Choose a site", "hosts", "");
?>
<section class="panel">
  <div class="empty">
    <h1><?php echo h($res["name"]); ?> is in more than one site</h1>
    <p>Pick the site:</p>
    <ul class="site-pick">
<?php foreach($res["matches"] as $id) { ?>
      <li><a class="button ghost" href="<?php echo h(drsm_url($page, array($param => $res["name"], "site" => $id))); ?>"><?php echo h(drsm_site_label($id)); ?></a></li>
<?php } ?>
    </ul>
  </div>
</section>
<?php
  drsm_page_end();
}

// SCRIPT CONTENT ENDS ABOVE.
// ----------------------------------------------------------- //
// ------------------------------- //
// --------- End of File --------- //
// ------------------------------- //
?>
