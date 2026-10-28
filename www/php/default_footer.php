<?php
// DRSM default page footer. To use your own footer, create
// ${SITEincludes}/page_footer.php
?>
</main>
<footer class="footer">
  <span><?php echo h(isset($SITEfooter) && $SITEfooter != "" ? $SITEfooter : "DataReel System Monitor"); ?><?php if(!isset($SITEhelp) || $SITEhelp !== "") { ?> &middot; <a href="<?php echo h(isset($SITEhelp) ? $SITEhelp : drsm_url("help.php")); ?>">Help</a><?php } ?></span>
  <span class="muted">Page generated <?php echo drsm_time_html(time(), true); ?></span>
</footer>
</body>
</html>
