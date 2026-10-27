<?php
// DRSM default page header. Pages set $PAGEtitle, $PAGEactive and
// $PAGEstate through drsm_page_start() in drsm_lib.php. To use your
// own header, create ${SITEincludes}/page_header.php and print
// drsm_head_assets() inside its <head> to keep the DRSM styles.

$drsm_title = (isset($PAGEtitle) && $PAGEtitle != "") ? "{$PAGEtitle} - {$SITEtitle}" : $SITEtitle;
$drsm_state = (isset($PAGEstate) && $PAGEstate != "") ? $PAGEstate : "";
$drsm_sites = drsm_sites();
$drsm_nav = array();
// The Organizations page leads when there is more than one site. Its
// links clear the site picker scope, so it always opens on every site.
if(count($drsm_sites) > 1) $drsm_nav["orgs"] = array("Organizations", "orgs.php", "building", array("site" => ""));
$drsm_nav += array(
  "overview" => array("Overview", "index.php", "grid"),
  "heatmap" => array("Heat map", "heatmap.php", "heat"),
  "hosts" => array("Hosts", "reports.php", "list"),
  "trends" => array("Trends", "trends.php", "trend"),
  "checks" => array("Connectivity", "checks.php", "net")
);
// Submenus: page views a menu item can open straight into
$drsm_sub = array();
if(isset($drsm_nav["orgs"])) {
  $drsm_sub["orgs"] = array(array("All organizations", drsm_url("orgs.php", array("site" => ""))));
  foreach(drsm_orgs($drsm_sites) as $o) $drsm_sub["orgs"][] = array($o["name"], drsm_url("orgs.php", array("site" => $o["id"])));
}
$drsm_sub["heatmap"] = array(array("Check status", drsm_url("heatmap.php", array("mode" => "status"))),
                             array("Resource use", drsm_url("heatmap.php", array("mode" => "metrics"))));
if(count(drsm_scope_sites(drsm_scope())) > 1) $drsm_sub["heatmap"][] = array("By site", drsm_url("heatmap.php", array("by" => "site")));
$drsm_sub["checks"] = array(array("Connectivity tests", drsm_url("checks.php")),
                            array("Health reports", drsm_url("checks.php", array("r" => "health"))));
// Other script reports, see extreports.php
if(drsm_ext_enabled()) {
  $drsm_nav["ext"] = array($EXTtitle, "extreports.php", "file");
  $drsm_sub["ext"] = array();
  foreach(drsm_ext_sections() as $sid => $sec) $drsm_sub["ext"][] = array($sec["title"], drsm_url("extreports.php", array("s" => $sid)));
  if(count($drsm_sub["ext"]) < 2) unset($drsm_sub["ext"]);
}
// Site menu items from config/drsm.php $NAVextra, see drsm_lib.php
foreach(drsm_nav_extra() as $key => $item) {
  $drsm_nav[$key] = array($item["label"], $item["url"], $item["icon"], null, true);
  if(count($item["sub"]) > 0) $drsm_sub[$key] = $item["sub"];
}
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
<header class="topbar<?php if(count($drsm_nav) > 6) echo " nav-wide"; ?>">
  <div class="topbar-inner">
    <a class="brand" href="<?php echo h(count($drsm_sites) > 1 ? drsm_url("orgs.php", array("site" => "")) : drsm_url("index.php")); ?>">
<?php if(isset($SITElogo) && $SITElogo != "") { ?>
      <img class="brand-logo" src="<?php echo h($SITElogo); ?>" alt="" aria-hidden="true">
<?php } ?>
      <span class="brand-mark <?php echo h(drsm_state_class($drsm_state != "" ? $drsm_state : "OK")); ?>" aria-hidden="true"><span></span><span></span><span></span></span>
      <span class="brand-text"><?php echo h($SITEtitle); ?></span>
    </a>
    <nav class="nav" aria-label="Main">
<?php foreach($drsm_nav as $key => $item) {
        $drsm_href = !empty($item[4]) ? $item[1] : drsm_url($item[1], isset($item[3]) ? $item[3] : array());
        $drsm_link = '<a href="' . h($drsm_href) . '" title="' . h($item[0]) . '"' . ($PAGEactive == $key ? ' class="active" aria-current="page"' : '') . '>' . drsm_icon($item[2]) . '<span>' . h($item[0]) . '</span></a>';
        if(!isset($drsm_sub[$key])) { ?>
      <?php echo $drsm_link; ?>

<?php     continue;
        } ?>
      <div class="nav-item<?php if($PAGEactive == $key) echo " active"; ?>"><?php echo $drsm_link; ?><details class="menu nav-menu" data-menu><summary title="<?php echo h($item[0]); ?> views"><?php echo drsm_icon("chevron"); ?><span class="sr"><?php echo h($item[0]); ?> views</span></summary><div class="menu-panel"><ul class="menu-tree">
<?php     foreach($drsm_sub[$key] as $sub) { ?>
        <li><a href="<?php echo h($sub[1]); ?>"><?php echo h($sub[0]); ?></a></li>
<?php     } ?>
      </ul></div></details></div>
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
<?php   // Site links for one site, else the org links in the scope
        if(isset($drsm_sites[$drsm_scope])) echo drsm_links_menu($drsm_scope, drsm_tier_from_request(), "links-menu");
        else echo drsm_org_links_menu($drsm_scope, drsm_tier_from_request());
      }
      // One site: its Site links, when its site file has LINK lines
      else if(count($drsm_sites) == 1) {
        $drsm_ids = array_keys($drsm_sites);
        echo drsm_links_menu($drsm_ids[0], drsm_tier_from_request(), "links-menu");
      } ?>
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
