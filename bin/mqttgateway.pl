#/usr/bin/perl
use Time::HiRes;
use LoxBerry::IO;
use LoxBerry::Log;
use warnings;
use strict;

use Data::Dumper;

require "./libs/Net/MQTT/Simple.pm";
require "./libs/LoxBerry/JSON/JSONIO.pm";

$cfgfile = "$lbpplugindir/mqtt.json";

my $log = LoxBerry::Log->new (
    name => 'MQTT Gateway',
	filename => "$lbplogdir/mqttgateway.log",
	append => 1,
	stdout => 1,
	loglevel => 7
);

# $LoxBerry::JSON::JSONIO::DEBUG = 1;

my $json = LoxBerry::JSON::JSONIO->new();
my $cfg = $json->open(filename => $cfgfile);

# Setting default values
if(! defined $cfg->{Main}{msno}) { $cfg->{Main}{msno} = 1; }
if(! defined $cfg->{Main}{udpport}) { $cfg->{Main}{udpport} = 11883; }
if(! defined $cfg->{Main}{brokeraddress}) { $cfg->{Main}{brokeraddress} = 'localhost:1883'; }

LOGDEB "JSON Dump:";
LOGDEB Dumper($cfg);

LOGINF "MSNR: " . $cfg->{Main}{msno};
LOGINF "UDPPort: " . $cfg->{Main}{udpport};

LOGINF "KEEP IN MIND: LoxBerry only sends CHANGED values to the Miniserver.";
LOGINF "If you use UDP Monitor, you have to take actions that changes are pushed.";

my %miniservers;
%miniservers = LoxBerry::System::get_miniservers();

LOGINF "Subscriptions: " . join(", ", @{$cfg->{subscriptions}}) . "\n";

my $mqtt = Net::MQTT::Simple->new($cfg->{Main}{brokeraddress});

# Subscribe
foreach my $topic (@{$cfg->{subscriptions}}) {
	LOFINF "Subscribing $topic";
	$mqtt->subscribe($topic, \&received);
}

# Capture messages
while(1) {
	$mqtt->tick();
	Time::HiRes::sleep(0.1);
}



sub received
{

	my ($topic, $message) = @_;
	LOGDEB "$topic: $message\n";
	if(is_enabled($cfg->{Main}{convert_booleans}) and is_enabled($message)) {
		LOGDEB "Converting $message to 1";
		$message = "1";
	} elsif ( is_enabled($cfg->{Main}{convert_booleans}) and is_disabled($message) ) {
		LOGDEB "Converting $message to 0";
		$message = "0";
	}
	if( $cfg->{Main}{msno} and $cfg->{Main}{udpport} and $miniservers{$cfg->{Main}{msno}}) {
		LoxBerry::IO::msudp_send_mem($cfg->{Main}{msno}, $cfg->{Main}{udpport}, "MQTT", $topic, $message);
	}
}
