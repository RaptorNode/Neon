<?php
include('./includes/loader.php');

if($sLogin != 1){
	header("Location: index.php");
	die();
}

echo(Templater::AdvancedParse($sSettings["panel_template"].'/dashboard', $locale->strings, array("Errors" => $sErrors)));
?>
