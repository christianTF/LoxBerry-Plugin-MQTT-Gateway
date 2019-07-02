#!/usr/bin/perl

use LoxBerry::Log;
use LoxBerry::JSON;
use Time::HiRes;
use Net::MQTT::Simple;
my $cfgfile = "$lbpconfigdir/mqtt.json";
my $credfile = "$lbpconfigdir/cred.json";
my $testdata_topic = "testdata";


# Config file
$json = LoxBerry::JSON->new();
$cfg = $json->open(filename => $cfgfile, readonly => 1);
# Credentials file
$json_cred = LoxBerry::JSON->new();
$cfg_cred = $json->open(filename => $credfile, readonly => 1);

LOGINF "Connecting broker $cfg->{Main}{brokeraddress}";
eval {
	
	$ENV{MQTT_SIMPLE_ALLOW_INSECURE_LOGIN} = 1;
	
	$mqtt = Net::MQTT::Simple->new($cfg->{Main}{brokeraddress});
	
	if($cfg_cred->{Credentials}{brokeruser} or $cfg_cred->{Credentials}{brokerpass}) {
		LOGINF "Login at broker";
		$mqtt->login($cfg_cred->{Credentials}{brokeruser}, $cfg_cred->{Credentials}{brokerpass});
	}
	
	
	
};
if ($@) {
	LOGERR "Could not connect to broker";
	exit(1);
}

# Publish test data
LOGINF "Sending test data to testdata/# ...";
for(my $x = 1; $x <= 500 ; $x++) {
	my $randval = int(rand(100));
	LOGDEB "$x: $randval";
	$mqtt->publish($testdata_topic . "/testdata_$x", $randval);
	Time::HiRes::sleep(0.1);
}
LOGOK "Finished";
