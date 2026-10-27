<?php
// ------------------------------- //
// -------- Start of File -------- //
// ------------------------------- //
// ----------------------------------------------------------- //
// PHP Source Code File
// PHP Version: 7.2 or higher, tested with PHP 8
// Original Author(s): DataReel Software Development
// File Creation Date: 10/26/2026
// Date Last Modified: 10/26/2026
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

Trend analysis for trends.php. Reads the per host metrics history
written by bin/drsm_run.sh (lib/drsm_history.sh), one line per report:

  <epoch><TAB>name{labels}=value<TAB>name=value ...

and works out usage series, capacity statistics, normal baselines and
values outside them. Counters such as CPU ticks, NIC bytes and disk
I/O operations become rates from the change between two reports.

Keep this file PHP 7.2 compatible, see drsm_lib.php.

Optional settings, set them in config/drsm.php:

$TRENDheadroom = 30;   // Percent of each resource kept free when
                       // working out what a host needs
$TRENDsigma    = 3;    // Baseline width in robust standard deviations
$TRENDshared   = array();  // Host names of shared hosting accounts.
                       // Their CPU, memory and disk figures are the
                       // provider's whole server, so they get no sizing
*/
// ----------------------------------------------------------- //
// SCRIPT CONTENT STARTS BELOW.

if(!isset($TRENDheadroom)) $TRENDheadroom = 30;
if(!isset($TRENDsigma)) $TRENDsigma = 3;
if(!isset($TRENDshared) || !is_array($TRENDshared)) $TRENDshared = array();

define("DRSM_HISTORY_FILE", "metrics_history.tsv");
// Longest gap between two reports that still gives a counter rate
define("DRSM_TREND_MAX_GAP", 3 * 3600);

function drsm_trend_ranges()
{
  return array(
    "7d"  => array("label" => "7 days",   "secs" => 7 * 86400),
    "30d" => array("label" => "30 days",  "secs" => 30 * 86400),
    "90d" => array("label" => "90 days",  "secs" => 90 * 86400),
    "1y"  => array("label" => "1 year",   "secs" => 365 * 86400),
    "all" => array("label" => "All",      "secs" => 0)
  );
}

// Usage series shown on the page: label, unit, chart maximum, and the
// smallest change from normal that is flagged
function drsm_trend_series_info($key)
{
  $base = $key;
  $sub = "";
  if(($p = strpos($key, ":")) !== false) {
    $base = substr($key, 0, $p);
    $sub = substr($key, $p + 1);
  }
  $info = array(
    "cpu"    => array("label" => "CPU used", "unit" => "%", "max" => 100, "min_delta" => 10),
    "steal"  => array("label" => "CPU steal", "unit" => "%", "max" => 100, "min_delta" => 5),
    "load"   => array("label" => "Load per CPU", "unit" => "%", "max" => 0, "min_delta" => 15),
    "mem"    => array("label" => "Memory used", "unit" => "%", "max" => 100, "min_delta" => 5),
    "mem_mb" => array("label" => "Memory used", "unit" => "MB", "max" => 0, "min_delta" => 256),
    "swap_mb" => array("label" => "Swap used", "unit" => "MB", "max" => 0, "min_delta" => 256),
    "disk"   => array("label" => "Disk used {$sub}", "unit" => "%", "max" => 100, "min_delta" => 3),
    "diskmb" => array("label" => "Disk used {$sub}", "unit" => "MB", "max" => 0, "min_delta" => 1024),
    "tx"     => array("label" => "Network out", "unit" => "B/s", "max" => 0, "min_delta" => 32768),
    "rx"     => array("label" => "Network in", "unit" => "B/s", "max" => 0, "min_delta" => 32768),
    "iops"   => array("label" => "Disk IOPS {$sub}", "unit" => "IOPS", "max" => 0, "min_delta" => 50),
    "iobw"   => array("label" => "Disk throughput {$sub}", "unit" => "B/s", "max" => 0, "min_delta" => 1048576),
    "iopeak" => array("label" => "Disk IOPS sample {$sub}", "unit" => "IOPS", "max" => 0, "min_delta" => 100)
  );
  return isset($info[$base]) ? $info[$base] : array("label" => $key, "unit" => "", "max" => 0, "min_delta" => 0);
}

function drsm_history_path($host, $site = DRSM_LEGACY_SITE)
{
  return drsm_site_dir($site) . "/systems/{$host}/" . DRSM_HISTORY_FILE;
}

// Move $fh to the first line at or after $since. The lines are in time
// order, so a binary search on file offsets skips the older years.
function drsm_history_seek($fh, $since)
{
  $st = fstat($fh);
  $lo = 0;
  $hi = $st["size"];
  while($hi - $lo > 65536) {
    $mid = (int)(($lo + $hi) / 2);
    fseek($fh, $mid);
    fgets($fh);
    $line = fgets($fh);
    if($line === false || (int)$line >= $since) $hi = $mid;
    else $lo = $mid;
  }
  fseek($fh, $lo);
  if($lo > 0) fgets($fh);
}

// Split name{labels} into the name and its first label value
function drsm_trend_key($key, &$label)
{
  $label = "";
  $p = strpos($key, "{");
  if($p === false) return $key;
  if(preg_match('/="([^"]*)"/', substr($key, $p), $m)) $label = $m[1];
  return substr($key, 0, $p);
}

function drsm_trend_push(&$series, $key, $t, $v)
{
  if(!isset($series[$key])) $series[$key] = array("t" => array(), "v" => array());
  $series[$key]["t"][] = $t;
  $series[$key]["v"][] = $v;
}

/*
Load one host's history from $since (0 for all of it). Returns:
  series  key => array(t => times, v => values), see drsm_trend_series_info
  sizes   latest cpu_count, mem_total_mb, swap_total_mb, disk_size_mb
          and ebs_volume_gib values
  totals  bytes sent and received, and seconds the counters covered
  first, last, count
*/
function drsm_trend_load($host, $since, $site = DRSM_LEGACY_SITE)
{
  $d = array("series" => array(), "sizes" => array("disk" => array(), "ebs" => array()),
             "totals" => array("tx" => 0, "rx" => 0, "net_secs" => 0, "io" => array()),
             "first" => 0, "last" => 0, "count" => 0, "exists" => false);
  $fname = drsm_history_path($host, $site);
  if(!drsm_valid_host($host) || !is_readable($fname)) return $d;
  $fh = @fopen($fname, "r");
  if($fh === false) return $d;
  $d["exists"] = true;
  // Sample data times move with $DEMObuilt, compare in file times
  if($since > 0) $since -= drsm_demo_time(1) - 1;
  if($since > 0) drsm_history_seek($fh, $since);

  $prev = null;
  $prevt = 0;
  $cpus = 0;
  $memtotal = 0;
  while(($line = fgets($fh)) !== false) {
    $parts = explode("\t", rtrim($line, "\r\n"));
    $t = (int)$parts[0];
    if($t <= 0 || $t < $since || $t <= $prevt) continue;
    $m = array();
    $lab = array();
    for($i = 1; $i < count($parts); $i++) {
      $eq = strrpos($parts[$i], "=");
      if($eq === false) continue;
      $label = "";
      $name = drsm_trend_key(substr($parts[$i], 0, $eq), $label);
      $v = (float)substr($parts[$i], $eq + 1);
      if($label != "") $lab[$name][$label] = $v;
      else $m[$name] = $v;
    }
    // Pushed reports (Windows agent) carry the time the counters were
    // read. A report drsm_run.sh saw twice is one sample, and rates use
    // the time between reports, not between runs.
    $st = isset($m["sample_etime"]) ? $m["sample_etime"] : 0;
    if($st > 0 && $prev !== null && $st == $prev["st"]) continue;
    $t = drsm_demo_time($t);
    if($d["first"] == 0) $d["first"] = $t;
    $d["last"] = $t;
    $d["count"]++;
    $dt = ($prev !== null) ? $t - $prev["t"] : 0;
    if($st > 0 && $prev !== null && $prev["st"] > 0) $dt = $st - $prev["st"];
    $rate_ok = ($dt > 0 && $dt <= DRSM_TREND_MAX_GAP);

    if(isset($m["cpu_count"]) && $m["cpu_count"] > 0) $cpus = $m["cpu_count"];
    if(isset($m["mem_total_mb"]) && $m["mem_total_mb"] > 0) $memtotal = $m["mem_total_mb"];

    // CPU: the average over the whole interval from the tick counters,
    // else the short sample the plugin took
    $cpu = isset($m["cpu_used_pct"]) ? $m["cpu_used_pct"] : null;
    $steal = isset($m["cpu_steal_pct"]) ? $m["cpu_steal_pct"] : null;
    if($rate_ok && isset($m["cpu_ticks_total"]) && isset($prev["m"]["cpu_ticks_total"])) {
      $dtot = $m["cpu_ticks_total"] - $prev["m"]["cpu_ticks_total"];
      $didle = $m["cpu_ticks_idle"] - $prev["m"]["cpu_ticks_idle"];
      if($dtot > 0 && $didle >= 0 && $didle <= $dtot) {
        $cpu = ($dtot - $didle) / $dtot * 100;
        if(isset($m["cpu_ticks_steal"]) && isset($prev["m"]["cpu_ticks_steal"])) {
          $steal = max(0, $m["cpu_ticks_steal"] - $prev["m"]["cpu_ticks_steal"]) / $dtot * 100;
        }
      }
    }
    if($cpu !== null) drsm_trend_push($d["series"], "cpu", $t, $cpu);
    if($steal !== null) drsm_trend_push($d["series"], "steal", $t, $steal);
    if(isset($m["load_15m"]) && $cpus > 0) drsm_trend_push($d["series"], "load", $t, $m["load_15m"] / $cpus * 100);

    if(isset($m["mem_available_mb"]) && $memtotal > 0) {
      $used = max(0, $memtotal - $m["mem_available_mb"]);
      drsm_trend_push($d["series"], "mem", $t, $used / $memtotal * 100);
      drsm_trend_push($d["series"], "mem_mb", $t, $used);
    }
    if(isset($m["swap_used_mb"])) drsm_trend_push($d["series"], "swap_mb", $t, $m["swap_used_mb"]);

    if(isset($lab["disk_used_pct"])) {
      foreach($lab["disk_used_pct"] as $mount => $v) drsm_trend_push($d["series"], "disk:{$mount}", $t, $v);
    }
    if(isset($lab["disk_used_mb"])) {
      foreach($lab["disk_used_mb"] as $mount => $v) drsm_trend_push($d["series"], "diskmb:{$mount}", $t, $v);
    }
    if(isset($lab["disk_size_mb"])) $d["sizes"]["disk"] = $lab["disk_size_mb"];
    if(isset($lab["ebs_volume_gib"])) $d["sizes"]["ebs"] = $lab["ebs_volume_gib"];

    // Network: bytes per second over the interval, all NICs together. A
    // counter that went down (reboot, NIC reset) gives no rate.
    if($rate_ok) {
      foreach(array("tx" => "nic_tx_bytes", "rx" => "nic_rx_bytes") as $key => $name) {
        if(!isset($lab[$name]) || !isset($prev["lab"][$name])) continue;
        $sum = 0;
        $have = false;
        foreach($lab[$name] as $nic => $v) {
          if(!isset($prev["lab"][$name][$nic])) continue;
          $delta = $v - $prev["lab"][$name][$nic];
          if($delta < 0) continue;
          $sum += $delta;
          $have = true;
        }
        if(!$have) continue;
        drsm_trend_push($d["series"], $key, $t, $sum / $dt);
        $d["totals"][$key] += $sum;
        if($key == "tx") $d["totals"]["net_secs"] += $dt;
      }

      // Disk I/O per disk: operations and bytes per second
      if(isset($lab["diskio_write_ops"]) && isset($prev["lab"]["diskio_write_ops"])) {
        foreach($lab["diskio_write_ops"] as $dev => $wops) {
          if(!isset($prev["lab"]["diskio_write_ops"][$dev]) || !isset($lab["diskio_read_ops"][$dev])) continue;
          $ops = ($wops - $prev["lab"]["diskio_write_ops"][$dev]) + ($lab["diskio_read_ops"][$dev] - $prev["lab"]["diskio_read_ops"][$dev]);
          $bytes = 0;
          if(isset($lab["diskio_read_bytes"][$dev]) && isset($prev["lab"]["diskio_read_bytes"][$dev])) {
            $bytes = ($lab["diskio_read_bytes"][$dev] - $prev["lab"]["diskio_read_bytes"][$dev]) + ($lab["diskio_write_bytes"][$dev] - $prev["lab"]["diskio_write_bytes"][$dev]);
          }
          if($ops < 0 || $bytes < 0) continue;
          drsm_trend_push($d["series"], "iops:{$dev}", $t, $ops / $dt);
          drsm_trend_push($d["series"], "iobw:{$dev}", $t, $bytes / $dt);
        }
      }
    }
    if(isset($lab["diskio_sample_iops"])) {
      foreach($lab["diskio_sample_iops"] as $dev => $v) drsm_trend_push($d["series"], "iopeak:{$dev}", $t, $v);
    }

    $prev = array("t" => $t, "st" => $st, "m" => $m, "lab" => $lab);
    $prevt = (int)$parts[0];
  }
  fclose($fh);
  if($cpus > 0) $d["sizes"]["cpu_count"] = $cpus;
  if($memtotal > 0) $d["sizes"]["mem_total_mb"] = $memtotal;
  if($prev !== null && isset($prev["m"]["swap_total_mb"])) $d["sizes"]["swap_total_mb"] = $prev["m"]["swap_total_mb"];
  return $d;
}

// Percentile $p (0 to 100) of a sorted list
function drsm_pct_sorted($s, $p)
{
  $n = count($s);
  if($n == 0) return null;
  $pos = ($n - 1) * $p / 100;
  $lo = (int)floor($pos);
  $hi = (int)ceil($pos);
  return $s[$lo] + ($s[$hi] - $s[$lo]) * ($pos - $lo);
}

function drsm_trend_stats($vals)
{
  $n = count($vals);
  if($n == 0) return null;
  $s = $vals;
  sort($s);
  return array("n" => $n, "min" => $s[0], "avg" => array_sum($s) / $n, "p50" => drsm_pct_sorted($s, 50),
               "p95" => drsm_pct_sorted($s, 95), "max" => $s[$n - 1]);
}

// Median and median absolute deviation
function drsm_median_mad($vals)
{
  $s = $vals;
  sort($s);
  $med = drsm_pct_sorted($s, 50);
  $dev = array();
  foreach($s as $v) $dev[] = abs($v - $med);
  sort($dev);
  return array($med, drsm_pct_sorted($dev, 50));
}

/*
Normal range for a series. With three days or more of data it is set
for each hour of the day, since use follows the working day and the
nightly jobs. The range is the median plus or minus $TRENDsigma robust
standard deviations (1.4826 x MAD), and never narrower than the
series' min_delta, so a host that idles at 0% is not flagged at 2%.
*/
function drsm_trend_baseline($ser, $info)
{
  global $TRENDsigma;
  $n = count($ser["v"]);
  $bl = array("mode" => "none", "hours" => array(), "all" => null, "n" => $n);
  if($n < 24 || end($ser["t"]) - $ser["t"][0] < 86400) return $bl;
  $max = $info["max"];

  $make = function($vals) use ($info, $max, $TRENDsigma) {
    list($med, $mad) = drsm_median_mad($vals);
    $w = max($TRENDsigma * 1.4826 * $mad, $info["min_delta"]);
    $lo = max(0, $med - $w);
    $hi = $med + $w;
    if($max > 0) $hi = min($max, $hi);
    return array("med" => $med, "lo" => $lo, "hi" => $hi);
  };
  $bl["all"] = $make($ser["v"]);
  $bl["mode"] = "overall";

  $span = end($ser["t"]) - $ser["t"][0];
  if($span >= 3 * 86400) {
    $byhour = array();
    foreach($ser["t"] as $i => $t) $byhour[(int)date("G", $t)][] = $ser["v"][$i];
    foreach($byhour as $hr => $vals) {
      if(count($vals) >= 6) $bl["hours"][$hr] = $make($vals);
    }
    if(count($bl["hours"]) > 0) $bl["mode"] = "hourly";
  }
  return $bl;
}

function drsm_trend_band($bl, $t)
{
  if($bl["mode"] == "none") return null;
  $hr = (int)date("G", $t);
  return isset($bl["hours"][$hr]) ? $bl["hours"][$hr] : $bl["all"];
}

// Values outside the normal range, newest first
function drsm_trend_anomalies($ser, $bl, $key)
{
  $out = array();
  if($bl["mode"] == "none") return $out;
  foreach($ser["t"] as $i => $t) {
    $b = drsm_trend_band($bl, $t);
    $v = $ser["v"][$i];
    if($v > $b["hi"]) $out[] = array("key" => $key, "t" => $t, "v" => $v, "band" => $b, "dir" => "high");
    else if($v < $b["lo"]) $out[] = array("key" => $key, "t" => $t, "v" => $v, "band" => $b, "dir" => "low");
  }
  return array_reverse($out);
}

// Least squares slope of a series, in units per day
function drsm_trend_slope($ser)
{
  $n = count($ser["t"]);
  if($n < 2) return null;
  $t0 = $ser["t"][0];
  $sx = $sy = $sxx = $sxy = 0;
  for($i = 0; $i < $n; $i++) {
    $x = ($ser["t"][$i] - $t0) / 86400;
    $y = $ser["v"][$i];
    $sx += $x; $sy += $y; $sxx += $x * $x; $sxy += $x * $y;
  }
  $den = $n * $sxx - $sx * $sx;
  if($den <= 0) return null;
  return ($n * $sxy - $sx * $sy) / $den;
}

function drsm_fmt_bytes($b, $dec = 1)
{
  $units = array("B", "KB", "MB", "GB", "TB", "PB");
  $i = 0;
  while(abs($b) >= 1024 && $i < count($units) - 1) { $b /= 1024; $i++; }
  return round($b, $i == 0 ? 0 : $dec) . " " . $units[$i];
}

function drsm_fmt_value($v, $unit)
{
  if($v === null) return "-";
  if($unit == "%") return round($v, $v < 10 ? 1 : 0) . "%";
  if($unit == "MB") return drsm_fmt_bytes($v * 1048576);
  if($unit == "B/s") return drsm_fmt_bytes($v) . "/s";
  if($unit == "IOPS") return round($v, $v < 10 ? 1 : 0) . " IOPS";
  return (string)round($v, 2);
}

/*
Capacity rows for one host: what it has, what it uses, and what it
needs with $TRENDheadroom percent kept free. verdict is one of
over (paying for more than it uses), ok, under, or "" when unknown.
*/
function drsm_trend_capacity($d, $shared = false)
{
  global $TRENDheadroom;
  $target = max(0.1, 1 - $TRENDheadroom / 100);
  $rows = array();
  $S = $d["series"];
  $sizes = $d["sizes"];
  $span_days = max(0, ($d["last"] - $d["first"]) / 86400);

  $verdict = function($ratio) use ($shared) {
    if($ratio === null || $shared) return "";
    if($ratio > 1) return "under";
    if($ratio < 0.5) return "over";
    return "ok";
  };

  // CPU, in busy CPUs so hosts of different sizes compare
  if(isset($S["cpu"])) {
    $st = drsm_trend_stats($S["cpu"]["v"]);
    $cpus = isset($sizes["cpu_count"]) ? $sizes["cpu_count"] : 0;
    $need = null;
    $ratio = null;
    $note = "";
    if($cpus > 0) {
      $busy = $st["p95"] / 100 * $cpus;
      $need = max(1, (int)ceil($busy / $target));
      $ratio = $need / $cpus;
      $note = round($busy, 2) . " CPUs busy at the 95th percentile";
    }
    if(isset($S["steal"])) {
      $ss = drsm_trend_stats($S["steal"]["v"]);
      if($ss["p95"] >= 5) $note .= ($note != "" ? "; " : "") . "steal " . round($ss["p95"]) . "% at p95, the host is short of CPU time";
    }
    $rows[] = array("id" => "cpu", "label" => "CPU", "have" => $cpus > 0 ? $cpus . " CPU" . ($cpus == 1 ? "" : "s") : "-",
                    "avg" => drsm_fmt_value($st["avg"], "%"), "p95" => drsm_fmt_value($st["p95"], "%"), "max" => drsm_fmt_value($st["max"], "%"),
                    "need" => $need !== null ? $need . " CPU" . ($need == 1 ? "" : "s") : "-", "need_raw" => $need,
                    "verdict" => $verdict($ratio), "note" => $note);
  }

  // Memory, sized near the peak since running out is worse than a
  // slow CPU. The 99th percentile leaves out a single odd spike.
  if(isset($S["mem_mb"]) && isset($sizes["mem_total_mb"])) {
    $st = drsm_trend_stats($S["mem_mb"]["v"]);
    $s = $S["mem_mb"]["v"];
    sort($s);
    $p99 = drsm_pct_sorted($s, 99);
    $total = $sizes["mem_total_mb"];
    $needmb = $p99 / $target;
    $needgb = max(0.5, ceil($needmb / 1024 * 2) / 2);
    $rows[] = array("id" => "mem", "label" => "Memory", "have" => drsm_fmt_bytes($total * 1048576),
                    "avg" => drsm_fmt_bytes($st["avg"] * 1048576), "p95" => drsm_fmt_bytes($st["p95"] * 1048576), "max" => drsm_fmt_bytes($st["max"] * 1048576),
                    "need" => $needgb . " GB", "need_raw" => $needgb, "verdict" => $verdict($needmb / $total),
                    "note" => "Sized on the 99th percentile, " . drsm_fmt_bytes($p99 * 1048576) . ", page cache not counted");
  }
  if(isset($S["swap_mb"]) && isset($sizes["swap_total_mb"]) && $sizes["swap_total_mb"] > 0) {
    $st = drsm_trend_stats($S["swap_mb"]["v"]);
    $rows[] = array("id" => "swap", "label" => "Swap", "have" => drsm_fmt_bytes($sizes["swap_total_mb"] * 1048576),
                    "avg" => drsm_fmt_bytes($st["avg"] * 1048576), "p95" => drsm_fmt_bytes($st["p95"] * 1048576), "max" => drsm_fmt_bytes($st["max"] * 1048576),
                    "need" => "-", "need_raw" => null, "verdict" => "", "note" => $st["max"] > 0 ? "Steady swap use means memory is short" : "");
  }

  // Disks: today's use plus a year of growth
  foreach($S as $key => $ser) {
    if(strpos($key, "diskmb:") !== 0) continue;
    $mount = substr($key, 7);
    $size = isset($sizes["disk"][$mount]) ? $sizes["disk"][$mount] : 0;
    $now = end($ser["v"]);
    $slope = ($span_days >= 2) ? drsm_trend_slope($ser) : null;
    $year = $now + max(0, (float)$slope) * 365;
    $needgb = (int)ceil($year / $target / 1024);
    $note = "";
    if($slope === null) $note = "Growth needs 2 days of history";
    else {
      $note = "Growth " . ($slope >= 0 ? "" : "-") . drsm_fmt_bytes(abs($slope) * 30 * 1048576) . " a month";
      if($slope > 0 && $size > 0) {
        $days = ($size * 0.9 - $now) / $slope;
        if($days <= 0) $note .= ", already over 90% full";
        else if($days < 3650) $note .= ", 90% full in " . drsm_age_text($days * 86400);
      }
    }
    $st = drsm_trend_stats($ser["v"]);
    $rows[] = array("id" => "disk:{$mount}", "label" => "Disk {$mount}", "have" => $size > 0 ? drsm_fmt_bytes($size * 1048576, 0) : "-",
                    "avg" => drsm_fmt_bytes($st["avg"] * 1048576), "p95" => drsm_fmt_bytes($st["p95"] * 1048576), "max" => drsm_fmt_bytes($st["max"] * 1048576),
                    "now" => drsm_fmt_bytes($now * 1048576), "need" => max(1, $needgb) . " GB", "need_raw" => max(1, $needgb),
                    "verdict" => $size > 0 ? $verdict($needgb * 1024 / $size) : "", "note" => $note);
  }
  if($shared) {
    foreach($rows as $i => $r) {
      $rows[$i]["need"] = "-";
      $rows[$i]["need_raw"] = null;
      $rows[$i]["note"] = "Shared hosting, these are the provider's whole server";
    }
  }
  return $rows;
}

// Network and disk I/O, the items cloud providers bill on use
function drsm_trend_traffic($d)
{
  $out = array("net" => null, "io" => array());
  $S = $d["series"];
  $secs = $d["totals"]["net_secs"];
  if($secs > 0 && isset($S["tx"])) {
    $tx = drsm_trend_stats($S["tx"]["v"]);
    $rx = isset($S["rx"]) ? drsm_trend_stats($S["rx"]["v"]) : null;
    $out["net"] = array(
      "secs" => $secs,
      "tx_total" => $d["totals"]["tx"], "rx_total" => $d["totals"]["rx"],
      "tx_month" => $d["totals"]["tx"] / $secs * 30 * 86400,
      "rx_month" => $d["totals"]["rx"] / $secs * 30 * 86400,
      "tx" => $tx, "rx" => $rx
    );
  }
  foreach($S as $key => $ser) {
    if(strpos($key, "iops:") !== 0) continue;
    $dev = substr($key, 5);
    $bw = isset($S["iobw:{$dev}"]) ? drsm_trend_stats($S["iobw:{$dev}"]["v"]) : null;
    $pk = isset($S["iopeak:{$dev}"]) ? drsm_trend_stats($S["iopeak:{$dev}"]["v"]) : null;
    $out["io"][$dev] = array("iops" => drsm_trend_stats($ser["v"]), "bw" => $bw, "peak" => $pk);
  }
  return $out;
}

// "Key: value" lines of one plugin section of a parsed report
function drsm_section_facts($rep, $id)
{
  $facts = array();
  foreach($rep["sections"] as $s) {
    if($s["id"] != $id) continue;
    foreach($s["lines"] as $line) {
      if(preg_match('/^([A-Z][A-Za-z0-9 ]+): (.+)$/', $line, $m)) $facts[$m[1]] = trim($m[2]);
    }
  }
  return $facts;
}

/*
Line chart as inline SVG: the average of each time bucket, the normal
range as a band, and values outside it as markers. The buckets also go
in data-points for the hover read out in drsm.js.
*/
function drsm_trend_chart($ser, $bl, $anoms, $info, $from, $to)
{
  $W = 720; $H = 220;
  $L = 56; $R = 12; $T = 12; $B = 28;
  $pw = $W - $L - $R;
  $ph = $H - $T - $B;
  $n = count($ser["t"]);
  if($n == 0) return "";
  if($to <= $from) $to = $from + 1;

  // Buckets: about one per 3 pixels
  $nb = max(1, min(240, $n));
  $bw = ($to - $from) / $nb;
  $sum = array_fill(0, $nb, 0.0);
  $cnt = array_fill(0, $nb, 0);
  foreach($ser["t"] as $i => $t) {
    $b = min($nb - 1, max(0, (int)(($t - $from) / $bw)));
    $sum[$b] += $ser["v"][$i];
    $cnt[$b]++;
  }

  $ymax = $info["max"];
  if($ymax <= 0) {
    // Scale to the data, the band may run off the top when the
    // smallest flagged change is larger than the values
    $top = max($ser["v"]);
    if($bl["mode"] != "none") $top = max($top, min($bl["all"]["hi"], 2 * $top));
    $ymax = drsm_nice_ceil($top * 1.1);
  }
  if($ymax <= 0) $ymax = 1;
  $x = function($t) use ($from, $to, $L, $pw) { return $L + ($t - $from) / ($to - $from) * $pw; };
  $y = function($v) use ($ymax, $T, $ph) { return $T + $ph - max(0, min($v, $ymax)) / $ymax * $ph; };

  $svg = "<svg class=\"trend-svg\" viewBox=\"0 0 {$W} {$H}\" role=\"img\" aria-label=\"" . h($info["label"]) . " trend\">";

  // Grid and y labels
  for($i = 0; $i <= 4; $i++) {
    $v = $ymax * $i / 4;
    $yy = round($y($v), 1);
    $svg .= "<line class=\"grid\" x1=\"{$L}\" x2=\"" . ($W - $R) . "\" y1=\"{$yy}\" y2=\"{$yy}\"/>";
    $svg .= "<text class=\"ax\" x=\"" . ($L - 6) . "\" y=\"" . ($yy + 4) . "\" text-anchor=\"end\">" . h(drsm_fmt_axis($v, $info["unit"])) . "</text>";
  }
  // X labels: dates, or times for spans under two days
  $span = $to - $from;
  $fmt = ($span < 2 * 86400) ? "g A" : "M j";
  for($i = 0; $i <= 4; $i++) {
    $t = $from + $span * $i / 4;
    $anchor = ($i == 0) ? "start" : (($i == 4) ? "end" : "middle");
    $svg .= "<text class=\"ax\" x=\"" . round($x($t), 1) . "\" y=\"" . ($H - 8) . "\" text-anchor=\"{$anchor}\">" . h(date($fmt, (int)$t)) . "</text>";
  }

  // Normal range band
  $pts = array();
  if($bl["mode"] != "none") {
    $band = "";
    for($b = 0; $b < $nb; $b++) {
      $tc = $from + ($b + 0.5) * $bw;
      $r = drsm_trend_band($bl, (int)$tc);
      $x0 = round($x($from + $b * $bw), 1);
      $w = round($pw / $nb + 0.4, 2);
      $y1 = round($y($r["hi"]), 1);
      $h2 = round($y($r["lo"]) - $y1, 1);
      $band .= "<rect x=\"{$x0}\" y=\"{$y1}\" width=\"{$w}\" height=\"" . max(0.5, $h2) . "\"/>";
    }
    $svg .= "<g class=\"band\">{$band}</g>";
  }

  // Average line, broken where there is no data
  $path = "";
  $pen = false;
  for($b = 0; $b < $nb; $b++) {
    if($cnt[$b] == 0) { $pen = false; continue; }
    $tc = $from + ($b + 0.5) * $bw;
    $v = $sum[$b] / $cnt[$b];
    $path .= ($pen ? "L" : "M") . round($x($tc), 1) . " " . round($y($v), 1);
    $pen = true;
    $r = drsm_trend_band($bl, (int)$tc);
    $pts[] = array((int)$tc, round($v, 3), $r ? round($r["lo"], 3) : null, $r ? round($r["hi"], 3) : null);
  }
  $svg .= "<path class=\"line\" d=\"{$path}\"/>";

  // Values outside the normal range
  $shown = 0;
  foreach($anoms as $a) {
    if($a["t"] < $from || $shown >= 400) continue;
    $shown++;
    $tip = date("M j g:i A", $a["t"]) . ": " . drsm_fmt_value($a["v"], $info["unit"]) . ", normal " . drsm_fmt_value($a["band"]["lo"], $info["unit"]) . " to " . drsm_fmt_value($a["band"]["hi"], $info["unit"]);
    $svg .= "<circle class=\"anom " . ($a["dir"] == "high" ? "hi" : "lo") . "\" cx=\"" . round($x($a["t"]), 1) . "\" cy=\"" . round($y($a["v"]), 1) . "\" r=\"4\"><title>" . h($tip) . "</title></circle>";
  }
  $svg .= "<line class=\"xhair\" x1=\"0\" x2=\"0\" y1=\"{$T}\" y2=\"" . ($T + $ph) . "\"/>";
  $svg .= "</svg>";

  $meta = array("unit" => $info["unit"], "from" => $from, "to" => $to, "l" => $L, "w" => $pw, "vw" => $W, "pts" => $pts);
  return "<div class=\"trend-plot\" data-trend=\"" . h(json_encode($meta)) . "\">{$svg}<div class=\"trend-tip\" hidden></div></div>";
}

function drsm_nice_ceil($v)
{
  if($v <= 0) return 0;
  $e = pow(10, floor(log10($v)));
  foreach(array(1, 2, 2.5, 5, 10) as $m) {
    if($m * $e >= $v) return $m * $e;
  }
  return 10 * $e;
}

function drsm_fmt_axis($v, $unit)
{
  if($unit == "%") return round($v) . "%";
  if($unit == "MB") return drsm_fmt_bytes($v * 1048576, 0);
  if($unit == "B/s") return drsm_fmt_bytes($v, 0) . "/s";
  return (string)round($v);
}

// SCRIPT CONTENT ENDS ABOVE.
// ----------------------------------------------------------- //
// ------------------------------- //
// --------- End of File --------- //
// ------------------------------- //
?>
