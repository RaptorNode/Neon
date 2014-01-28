<?php
include('./includes/loader.php');

echo(Templater::AdvancedParse($sSetting["panel_template"].'/login', $locale->strings, array()));
?>
