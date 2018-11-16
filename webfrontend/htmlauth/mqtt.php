<?php
require_once "loxberry_system.php";
$cfgfile = "$lbpconfigdir/mqtt.json";
$jsoncontent = file_get_contents($cfgfile); 

$json = json_decode($jsoncontent, True); 
// var_dump($json);

$udpinport = $json['Main']['udpinport'];

$topic = $_GET['topic'];
$value = $_GET['value'];

if(empty($topic) or empty($value)) 
	syntaxhelp();

$address = "udp://127.0.0.1:$udpinport";
$socket = fsockopen($address);
$written = fwrite($socket, "$topic $value");

print "<p>$topic $value</p>";
if($written == 0) {
	print "<p style='color:red'>Could not write to udp address $address</p>";
}
else {
	print "<p style='color:green'>$written bytes written to udp address $address</p>";
}

exit(0);

function syntaxhelp()
{
	global $topic, $value;
	print "<p style='color:red;'>ERROR with parameters</p>";
	print "<p>Usage:</p>\n";
	print htmlentities("http://" . "<user>:<pass>@ " . lbhostname() . ":" . lbwebserverport() . "/admin/plugins/mqttgateway/mqtt.php?topic=homematic/temperature/livingroom&value=21.3");
	exit(1);
}