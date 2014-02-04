<?php
include('./includes/loader.php');

if($sLogin == 1){
	header("Location: dashboard.php");
	die();
}

if($_GET['id'] == 1){
	$sErrors = login($_POST['username'], $_POST['password']);
}

echo(Templater::AdvancedParse($sSettings["panel_template"].'/login', $locale->strings, array("Errors" => $sErrors)));
?>
