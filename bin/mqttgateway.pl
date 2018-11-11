#!/usr/bin/perl
use Time::HiRes;
use LoxBerry::IO;
use LoxBerry::Log;
use warnings;
use strict;

use Data::Dumper;

require "./libs/Net/MQTT/Simple.pm";
require "./libs/LoxBerry/JSON/JSONIO.pm";

my $cfgfile = "$lbpconfigdir/mqtt.json";
my $json;
my $cfg;
my $cfg_timestamp;
my $mqtt;
my @subscriptions;

print "Configfile: $cfgfile\n";
while (! -e $cfgfile) {
	print "ERROR: Cannot find config file $cfgfile";
	sleep(5);
}

my $log = LoxBerry::Log->new (
    name => 'MQTT Gateway',
	filename => "$lbplogdir/mqttgateway.log",
	append => 1,
	stdout => 1,
	loglevel => 7
);

LOGINF "KEEP IN MIND: LoxBerry MQTT only sends CHANGED values to the Miniserver.";
LOGINF "If you use UDP Monitor, you have to take actions that changes are pushed.";
LoxBerry::IO::msudp_send(1, 6666, "MQTT", "KEEP IN MIND: LoxBerry MQTT only sends CHANGED values to the Miniserver.");

my %miniservers;
%miniservers = LoxBerry::System::get_miniservers();

read_config();

# Capture messages
while(1) {
	if(time%5 == 0) {
		read_config();
	}
	$mqtt->tick();
	Time::HiRes::sleep(0.1);
}



sub received
{
	
	my ($topic, $message) = @_;
	LOGINF "$topic: $message";
	if(is_enabled($cfg->{Main}{convert_booleans}) and is_enabled($message)) {
		#LOGDEB "  Converting $message to 1";
		$message = "1";
	} elsif ( is_enabled($cfg->{Main}{convert_booleans}) and is_disabled($message) ) {
		#LOGDEB "  Converting $message to 0";
		$message = "0";
	}
	if( is_enabled($cfg->{Main}{use_udp}) ) {
		if( $cfg->{Main}{msno} and $cfg->{Main}{udpport} and $miniservers{$cfg->{Main}{msno}}) {
			LoxBerry::IO::msudp_send_mem($cfg->{Main}{msno}, $cfg->{Main}{udpport}, "MQTT", $topic, $message);
		}
	}
	if( is_enabled($cfg->{Main}{use_http}) and $miniservers{$cfg->{Main}{msno}} ) {
		$topic =~ s/\//_/g;
		LOGDEB "  Sending as $topic to MS No. " . $cfg->{Main}{msno};
		LoxBerry::IO::mshttp_send_mem($cfg->{Main}{msno},  $topic, $message);
	}
}

sub read_config
{
	my $mtime = (stat($cfgfile))[9];
	if($cfg_timestamp and $cfg_timestamp == $mtime and $cfg) {
		return;
	}
	
	$cfg_timestamp = $mtime;
	
	LOGOK "Reading config changes";
	# $LoxBerry::JSON::JSONIO::DEBUG = 1;

	$json = LoxBerry::JSON::JSONIO->new();
	$cfg = $json->open(filename => $cfgfile, readonly => 1);

	if(!$cfg) {
		LOGERR "Could not read json configuration. Possibly not a valid json?";
		return;
	} else {

	# Setting default values
		if(! defined $cfg->{Main}{msno}) { $cfg->{Main}{msno} = 1; }
		if(! defined $cfg->{Main}{udpport}) { $cfg->{Main}{udpport} = 11883; }
		# if(! defined $cfg->{Main}{brokeraddress}) { $cfg->{Main}{brokeraddress} = 'localhost:1883'; }

		LOGDEB "JSON Dump:";
		LOGDEB Dumper($cfg);

		LOGINF "MSNR: " . $cfg->{Main}{msno};
		LOGINF "UDPPort: " . $cfg->{Main}{udpport};
		
		
		# Unsubscribe old topics
		if($mqtt) {
			foreach my $topic (@subscriptions) {
				LOGINF "UNsubscribing $topic";
				$mqtt->unsubscribe($topic);
			}
		}
		
		undef $mqtt;
		
		# Reconnect MQTT broker
		LOGINF "Connecting broker $cfg->{Main}{brokeraddress}";
		$mqtt = Net::MQTT::Simple->new($cfg->{Main}{brokeraddress});
		
		@subscriptions = @{$cfg->{subscriptions}};
		# Re-Subscribe new topics
		foreach my $topic (@subscriptions) {
			LOGINF "Subscribing $topic";
			$mqtt->subscribe($topic, \&received);
		}
		
	}
}