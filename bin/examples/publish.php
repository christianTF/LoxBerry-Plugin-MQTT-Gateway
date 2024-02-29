#!/usr/bin/env php
<?php
require_once "loxberry_io.php";
require_once "phpMQTT/phpMQTT.php";
 
// Get the MQTT Gateway connection details from LoxBerry
$creds = mqtt_connectiondetails();
 
// MQTT requires a unique client id
$client_id = uniqid(gethostname()."_client");
 
// Value we'd like to publish
$value = 12345;
 
// Be careful about the required namespace on instancing new objects:
$mqtt = new Bluerhinos\phpMQTT($creds['brokerhost'],  $creds['brokerport'], $client_id);
    if( $mqtt->connect(true, NULL, $creds['brokeruser'], $creds['brokerpass'] ) ) {
        $mqtt->publish("testing/topic", $value, 0, 1);
        $mqtt->close();
    } else {
        echo "MQTT connection failed";
    }
