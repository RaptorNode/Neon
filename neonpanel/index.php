<?php
include('./includes/loader.php');

echo(Templater::AdvancedParse($sSettings["panel_template"].'/login', $locale->strings, array()));
?>
