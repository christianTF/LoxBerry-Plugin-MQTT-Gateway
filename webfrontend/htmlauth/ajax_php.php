<?php
// require_once "loxberry_system.php";
// $cfgfile = "$lbpconfigdir/mqtt.json";
// $jsoncontent = file_get_contents($cfgfile); 
// $json = json_decode($jsoncontent, True); 
// $udpinport = $json['Main']['udpinport'];

header('Content-Type: application/json; charset=UTF-8');

if( @$_POST['ajax'] == 'relayed_topics' ) {
	if( !empty($_POST['udpinport'] ) ) {
		$address = "udp://127.0.0.1:".$_POST['udpinport'];
		$socket = fsockopen($address);
		fwrite($socket, 'save_relayed_states' );
		
		// How to get a response via udp?
		// stream_set_blocking($socket, 0);
		// echo fread($socket, 10);
		fclose($socket);
	}
	$datafile = "/dev/shm/mqttgateway_topics.json";
	if( file_exists( $datafile ) ) {
		readfile( $datafile );
	}
}
