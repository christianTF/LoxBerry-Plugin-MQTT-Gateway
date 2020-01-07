<?php
require_once "loxberry_system.php";
$cfgfile = "$lbpconfigdir/mqtt.json";
$jsoncontent = file_get_contents($cfgfile); 

$json = json_decode($jsoncontent, True); 
// var_dump($json);

$udpinport = $json['Main']['udpinport'];

@$topic = $_GET['topic'];
@$value = $_GET['value'];
@$retain = $_GET['retain'];

echo "topic: $topic\n";
echo "value: $value\n";
echo "retain: $retain\n";

if(empty($topic)) 
	syntaxhelp();

$address = "udp://127.0.0.1:$udpinport";
$socket = fsockopen($address);
if (is_enabled($retain)) {
	$written = fwrite($socket, json_encode( array ( "topic" => $topic, "value" => $value, "retain" => true) ) );
} else {
	$written = fwrite($socket, json_encode( array ( "topic" => $topic, "value" => $value ) ) );
}

print "<p>$topic $value</p>";
if($written == 0) {
	print "<p style='color:red'>Could not write to udp address $address</p>\n";
}
else {
	print "<p style='color:green'>$written bytes written to udp address $address</p>\n";
}

exit(0);

function syntaxhelp()
{
	global $topic, $value;
	print "<p style='color:red;'>ERROR with parameters</p>";
	print "<p>Usage:</p>\n";
	print htmlentities("Publish: http://" . "<user>:<pass>@ " . lbhostname() . ":" . lbwebserverport() . "/admin/plugins/mqttgateway/mqtt.php?topic=homematic/temperature/livingroom&value=21.3");
	print "<br>\n";
	print htmlentities("With retain: http://" . "<user>:<pass>@ " . lbhostname() . ":" . lbwebserverport() . "/admin/plugins/mqttgateway/mqtt.php?retain=1&topic=homematic/temperature/livingroom&value=21.3");
	print "<br>\n";
	print htmlentities("Delete value: http://" . "<user>:<pass>@ " . lbhostname() . ":" . lbwebserverport() . "/admin/plugins/mqttgateway/mqtt.php?retain=1&topic=homematic/temperature/livingroom");
	print "<br>\n";
	exit(1);
}
