#!/usr/bin/perl
use utf8;
use FindBin qw($Bin);
use lib "$Bin/libs";

use Time::HiRes;
use LoxBerry::IO;
use LoxBerry::Log;
use LoxBerry::JSON;
use warnings;
use strict;

use Net::MQTT::Simple;
# use Hash::Flatten;
use File::Monitor;

use Data::Dumper;

$SIG{INT} = sub { 
	LOGTITLE "MQTT Finder interrupted by Ctrl-C"; 
	LOGEND(); 
	exit 1;
};

$SIG{TERM} = sub { 
	LOGTITLE "MQTT Finder requested to stop"; 
	LOGEND();
	exit 1;	
};


#require "$lbpbindir/libs/Net/MQTT/Simple.pm";
#require "$lbpbindir/libs/Net/MQTT/Simple/Auth.pm";
#require "$lbpbindir/libs/LoxBerry/JSON/JSONIO.pm";

my $cfgfile = "$lbpconfigdir/mqtt.json";
my $credfile = "$lbpconfigdir/cred.json";
my $datafile = "/dev/shm/mqttfinder.json";

my $json;
my $json_cred;
my $cfg;
my $cfg_cred;

my %sendhash;

my $nextconfigpoll;
my $nextsavedatafile;
my $mqtt;

my $pollms = 20;
my $mqtt_data_received = 0;

print "Configfile: $cfgfile\n";
while (! -e $cfgfile) {
	print "ERROR: Cannot find config file $cfgfile";
	sleep(5);
}

my $log = LoxBerry::Log->new (
    name => 'MQTT Finder',
	filename => "$lbplogdir/mqttfinder.log",
	append => 1,
	stdout => 1,
	# loglevel => 7,
	addtime => 1
);

LOGSTART "MQTT Finder started";

# Create monitor to handle config file changes
my $monitor = File::Monitor->new();

read_config();
	
# Capture messages
while(1) {
	if(time>$nextconfigpoll) {
		if(!$mqtt->{socket}) {
			LOGWARN "No connection to MQTT broker $cfg->{Main}{brokeraddress} - Check host/port/user/pass and your connection.";
			
		} 
		
		read_config();
	}
	eval {
		$mqtt->tick();
	};
	
	
	if( $mqtt_data_received == 0 ) {
		Time::HiRes::sleep( $pollms/1000 );
	}
	
	if( time>$nextsavedatafile ) {
		save_data();
		$nextsavedatafile = Time::HiRes::time()+1;
	}
	
	
}


sub received
{
	
	my ($topic, $message) = @_;
	
	utf8::encode($topic);
	LOGOK "MQTT received: $topic: $message";
	
	# Remember that we have currently have received data
	$mqtt_data_received = 1;
	
	$sendhash{$topic}{msg} = $message;
	$sendhash{$topic}{time} = Time::HiRes::time();
	
	
}

sub read_config
{
	my $configs_changed = 0;
	$nextconfigpoll = time+5;
	
	
	# Also watch own config
	$monitor->watch( $cfgfile );
	$monitor->watch( $credfile );
		
		
		
	
	
	my @changes = $monitor->scan;
	
	
	if(!defined $cfg or @changes) {
		$configs_changed = 1;
	}
	
	if($configs_changed == 0) {
		return;
	}
	
	LOGOK "Reading config changes";
	# $LoxBerry::JSON::JSONIO::DEBUG = 1;

	# Config file
	$json = LoxBerry::JSON->new();
	$cfg = $json->open(filename => $cfgfile, readonly => 1);
	# Credentials file
	$json_cred = LoxBerry::JSON->new();
	$cfg_cred = $json->open(filename => $credfile, readonly => 1);
	
	if(!$cfg) {
		LOGERR "Could not read json configuration. Possibly not a valid json?";
		return;
	} elsif (!$cfg_cred) {
		LOGERR "Could not read credentials json configuration. Possibly not a valid json?";
		return;

	} else {
	
	# Setting default values
		if(! defined $cfg->{Main}{brokeraddress}) { $cfg->{Main}{brokeraddress} = 'localhost'; }
		if(! defined $pollms ) {
			$pollms = 50; 
		}
		
		# Unsubscribe old topics
		if($mqtt) {
			eval {
				LOGINF "UNsubscribing #";
				$mqtt->unsubscribe('#');
			};
			if ($@) {
				LOGERR "Exception catched on unsubscribing old topics: $!";
			}
		}
		
		undef $mqtt;
		
		# Reconnect MQTT broker
		LOGINF "Connecting broker $cfg->{Main}{brokeraddress}";
		eval {
			
			$ENV{MQTT_SIMPLE_ALLOW_INSECURE_LOGIN} = 1;
			
			$mqtt = Net::MQTT::Simple->new($cfg->{Main}{brokeraddress});
			
			if($cfg_cred->{Credentials}{brokeruser} or $cfg_cred->{Credentials}{brokerpass}) {
				LOGINF "Login at broker";
				$mqtt->login($cfg_cred->{Credentials}{brokeruser}, $cfg_cred->{Credentials}{brokerpass});
			}
			
			LOGINF "Subscribing #";
			$mqtt->subscribe('#', \&received);
		};
		if ($@) {
			LOGERR "Exception catched on reconnecting and subscribing: $@";
		}
	}
}

sub save_data
{
		
	# LOGINF "Relayed topics are saved on RAMDISK for UI";
	unlink $datafile;
	my $relayjsonobj = LoxBerry::JSON->new();
	my $relayjson = $relayjsonobj->open(filename => $datafile);

	
	$relayjson->{incoming} = \%sendhash;

	
	$relayjsonobj->write();
	undef $relayjsonobj;

	
}


END
{
	if($mqtt) {
		$mqtt->disconnect()
	}
	
	if($log) {
		LOGEND "MQTT Finder exited";
	}
}

