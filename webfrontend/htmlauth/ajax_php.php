<?php
// require_once "loxberry_system.php";
// $cfgfile = "$lbpconfigdir/mqtt.json";
// $jsoncontent = file_get_contents($cfgfile); 
// $json = json_decode($jsoncontent, True); 
// $udpinport = $json['Main']['udpinport'];

header('Content-Type: application/json; charset=UTF-8');

$cfgfile = "mqtt.json";
$datafile = "/dev/shm/mqttgateway_topics.json";
$ajax = !empty( $_POST['ajax'] ) ? $_POST['ajax'] : "";

if( $ajax == 'relayed_topics' ) {
	if( !empty($_POST['udpinport'] ) ) {
		$address = "udp://127.0.0.1:".$_POST['udpinport'];
		$socket = fsockopen($address);
		fwrite($socket, 'save_relayed_states' );
		
		// How to get a response via udp?
		// stream_set_blocking($socket, 0);
		// echo fread($socket, 10);
		fclose($socket);
	}
	
	if( file_exists( $datafile ) ) {
		readfile( $datafile );
	}
} 
elseif ( $ajax == 'retain' ) {
		
		if ( !empty($_POST['udpinport']) and $_POST['udpinport'] != "0") {
			$address = "udp://127.0.0.1:".$_POST['udpinport'];
			$socket = fsockopen($address);
			
			$dataToUDP = array(
				"topic" => $_POST['topic'],
				"retain" => true,
			);
			
			fwrite( $socket, json_encode($dataToUDP) );
			fclose( $socket );
		}
				
		if( file_exists( $datafile ) ) {
			readfile( $datafile );
		}
}
elseif ( $ajax == 'disablecache' ) {
	
	require_once "loxberry_system.php";
	$fullcfgfile = LBPCONFIGDIR.'/'.$cfgfile;
	$topic = $_POST['topic'];
	
	if( !file_exists( $fullcfgfile ) ) {
		error_log("File does not exist: " . $fullcfgfile);
	}
	$fp = fopen($fullcfgfile, "c");
	flock($fp, LOCK_EX);

	$cfg = json_decode( file_get_contents($fullcfgfile) );
	
	if( empty( $cfg ) ) {
		error_log( "JSON is empty");
		exit();
	}
	
	if( !is_enabled( $_POST['disablecache'] ) ) {
		unset($cfg->{'Noncached'}->{$topic});
	} else {
		$cfg->{'Noncached'}->{$topic} = "true";
	}
	
	file_put_contents( $fullcfgfile, json_encode($cfg, JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES|JSON_UNESCAPED_LINE_TERMINATORS|JSON_UNESCAPED_UNICODE) );
	flock($fp, LOCK_UN);
	fclose($fp);
	readfile( $fullcfgfile );
}	
elseif ( $ajax == 'resetAfterSend' ) {
	
	require_once "loxberry_system.php";
	$fullcfgfile = LBPCONFIGDIR.'/'.$cfgfile;
	$topic = $_POST['topic'];
	
	if( !file_exists( $fullcfgfile ) ) {
		error_log("File does not exist: " . $fullcfgfile);
	}
	$fp = fopen($fullcfgfile, "c");
	flock($fp, LOCK_EX);

	$cfg = json_decode( file_get_contents($fullcfgfile) );
	
	if( empty( $cfg ) ) {
		error_log( "JSON is empty");
		exit();
	}
	
	if( !is_enabled( $_POST['resetAfterSend'] ) ) {
		unset($cfg->{'resetAfterSend'}->{$topic});
	} else {
		$cfg->{'resetAfterSend'}->{$topic} = "true";
	}
	
	file_put_contents( $fullcfgfile, json_encode($cfg, JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES|JSON_UNESCAPED_LINE_TERMINATORS|JSON_UNESCAPED_UNICODE) );
	flock($fp, LOCK_UN);
	fclose($fp);
	readfile( $fullcfgfile );
}	
elseif ( $ajax == 'doNotForward' ) {
	
	require_once "loxberry_system.php";
	$fullcfgfile = LBPCONFIGDIR.'/'.$cfgfile;
	$topic = $_POST['topic'];
	
	if( !file_exists( $fullcfgfile ) ) {
		error_log("File does not exist: " . $fullcfgfile);
	}
	$fp = fopen($fullcfgfile, "c");
	flock($fp, LOCK_EX);

	$cfg = json_decode( file_get_contents($fullcfgfile) );
	
	if( empty( $cfg ) ) {
		error_log( "JSON is empty");
		exit();
	}
	
	if( !is_enabled( $_POST['doNotForward'] ) ) {
		unset($cfg->{'doNotForward'}->{$topic});
	} else {
		$cfg->{'doNotForward'}->{$topic} = "true";
	}
	
	file_put_contents( $fullcfgfile, json_encode($cfg, JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES|JSON_UNESCAPED_LINE_TERMINATORS|JSON_UNESCAPED_UNICODE) );
	flock($fp, LOCK_UN);
	fclose($fp);
	readfile( $fullcfgfile );
}	

