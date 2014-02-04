<?php

function login($sUsername, $sPassword){
	$sSSH = new Net_SSH2("127.0.0.1");
	try {
		if (!$sSSH->login($sUsername, $sPassword)) {
			return $sResult = array("result" => "Incorrect login, please try again.");
		} else {
			$_SESSION['username'] = $sUsername;
			$_SESSION['password'] = $sPassword;
			$_SESSION['login'] = 1;
		}
	} catch (Exception $e) { 
		return $sResult = array("result" => "Incorrect login, please try again.");
	}
}

function logout(){
	session_destroy();
	header("Location: index.php");
}