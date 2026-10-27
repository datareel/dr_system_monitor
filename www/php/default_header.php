<?php
// DRSM default page header. Pages set $PAGEtitle, $PAGEactive and
// $PAGEstate through drsm_page_start() in drsm_lib.php. To use your
// own header, create ${SITEincludes}/page_header.php and print
// drsm_head_assets() inside its <head> to keep the DRSM styles.

$drsm_title = (isset($PAGEtitle) && $PAGEtitle != "") ? "{$PAGEtitle} - {$SITEtitle}" : $SITEtitle;
$drsm_state = (isset($PAGEstate) && $PAGEstate != "") ? $PAGEstate : "";
$drsm_sites = drsm_sites();
$drsm_nav = array();
// The Organizations page leads when there is more than one site
if(count($drsm_sites) > 1) $drsm_nav["orgs"] = array("Organizations", "orgs.php", "building");
$drsm_nav += array(
  "overview" => array("Overview", "index.php", "grid"),
  "heatmap" => array("Heat map", "heatmap.php", "heat"),
  "hosts" => array("Hosts", "reports.php", "list"),
  "trends" => array("Trends", "trends.php", "trend"),
  "checks" => array("Connectivity", "checks.php", "net")
);
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="color-scheme" content="dark light">
<meta name="robots" content="noindex, nofollow">
<title><?php echo h(($drsm_state != "" && $drsm_state != "OK" ? "(" . drsm_state_label($drsm_state) . ") " : "") . $drsm_title); ?></title>
<?php if($REFRESHseconds > 0) { ?>
<noscript><meta http-equiv="refresh" content="<?php echo (int)$REFRESHseconds; ?>"></noscript>
<?php } ?>
<?php echo drsm_head_assets(); ?>
</head>
<body data-refresh="<?php echo (int)$REFRESHseconds; ?>" data-page="<?php echo h($PAGEactive); ?>">
<a class="skip" href="#main">Skip to content</a>
<header class="topbar">
  <div class="topbar-inner">
    <a class="brand" href="<?php echo h(drsm_url(count($drsm_sites) > 1 ? "orgs.php" : "index.php")); ?>">
      <span class="brand-mark <?php echo h(drsm_state_class($drsm_state != "" ? $drsm_state : "OK")); ?>" aria-hidden="true"><span></span><span></span><span></span></span>
      <span class="brand-text"><?php echo h($SITEtitle); ?></span>
    </a>
    <nav class="nav" aria-label="Main">
<?php foreach($drsm_nav as $key => $item) { ?>
      <a href="<?php echo h(drsm_url($item[1])); ?>"<?php if($PAGEactive == $key) echo ' class="active" aria-current="page"'; ?>><?php echo drsm_icon($item[2]); ?><span><?php echo h($item[0]); ?></span></a>
<?php } ?>
    </nav>
    <div class="tools">
<?php if(count($drsm_sites) > 1) {
        $drsm_scope = drsm_scope();
        $drsm_pick = isset($drsm_nav[$PAGEactive]) ? $drsm_nav[$PAGEactive][1] : "index.php"; ?>
      <form class="site-picker select" method="get" action="<?php echo h(drsm_url($drsm_pick)); ?>">
        <label class="sr" for="site-pick">Site</label>
        <select id="site-pick" name="site" data-autosubmit title="Organizations and sites shown">
          <option value="">All sites</option>
<?php   foreach(drsm_orgs($drsm_sites) as $o) { ?>
          <optgroup label="<?php echo h($o["name"]); ?>">
<?php     if(count($o["sites"]) > 1) { ?>
            <option value="<?php echo h($o["id"]); ?>"<?php if($drsm_scope == $o["id"]) echo " selected"; ?>><?php echo h($o["name"]); ?>, all sites</option>
<?php     } ?>
<?php     foreach($o["sites"] as $sid => $st) { ?>
            <option value="<?php echo h($sid); ?>"<?php if($drsm_scope == $sid) echo " selected"; ?>><?php echo h($st["name"]); ?></option>
<?php     } ?>
          </optgroup>
<?php   } ?>
        </select>
        <noscript><button class="tool" type="submit">Show</button></noscript>
      </form>
<?php } ?>
      <button type="button" class="tool" data-action="refresh" title="Auto refresh" aria-pressed="true">
        <svg class="ring" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="9"/><circle class="ring-fill" cx="12" cy="12" r="9"/></svg>
        <span class="refresh-label">Live</span>
      </button>
      <button type="button" class="tool icon-only" data-action="wall" title="Wall display (full screen)"><?php echo drsm_icon("expand"); ?><span class="sr">Wall display</span></button>
      <button type="button" class="tool icon-only" data-action="theme" title="Switch light or dark theme"><?php echo drsm_icon("sun"); ?><?php echo drsm_icon("moon"); ?><span class="sr">Switch theme</span></button>
<?php if(isset($AUTHuser) && $AUTHuser != "") { ?>
      <form class="signout" method="post" action="<?php echo h(drsm_url("login.php")); ?>">
        <input type="hidden" name="action" value="logout">
        <input type="hidden" name="csrf" value="<?php echo h($AUTHcsrf); ?>">
        <button type="submit" class="tool icon-only" title="Sign out <?php echo h($AUTHuser); ?>"><?php echo drsm_icon("logout"); ?><span class="sr">Sign out</span></button>
      </form>
<?php } ?>
    </div>
  </div>
</header>
<main id="main" class="page">
