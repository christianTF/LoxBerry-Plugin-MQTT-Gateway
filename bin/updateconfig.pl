#!/usr/bin/perl
use FindBin qw($Bin);
use lib "$Bin/libs";

use Time::HiRes;
use LoxBerry::IO;
use LoxBerry::Log;
use warnings;
use strict;

use LoxBerry::JSON::JSONIO;

use Data::Dumper;

my $cfgfile = "$lbpconfigdir/mqtt.json";
my $json;
my $cfg;
my $cfg_timestamp;
my $nextconfigpoll;
my $mqtt;
my @subscriptions;

		
print "Configfile: $cfgfile\n";

my $log = LoxBerry::Log->new (
    name => 'Update Configuration',
	stdout => 1,
	loglevel => 7,
);

LOGSTART "Updating configuration during plugin installation";


update_config();
LOGEND "Config updated";

sub update_config
{
	my $changed = 0;
	LOGOK "Reading config file";
	# $LoxBerry::JSON::JSONIO::DEBUG = 1;

	$json = LoxBerry::JSON::JSONIO->new();
	$cfg = $json->open(filename => $cfgfile);

	if(!$cfg) {
		LOGCRIT "Could not read json configuration. Possibly not a valid json?";
		return;
	} else {

	# Setting default values
		LOGOK "Config was read. Checking values";
		if(! defined $cfg->{Main}{msno}) { 
			$cfg->{Main}{msno} = 1;
			LOGINF "Setting Miniserver to " . $cfg->{Main}{msno};
			$changed++;
			}
		if(! defined $cfg->{Main}{udpport}) { 
			$cfg->{Main}{udpport} = 11883; 
			LOGINF "Setting Miniserver UDP Out-Port to " . $cfg->{Main}{udpport};
			$changed++;
			}
		if(! defined $cfg->{Main}{enable_mosquitto}) { 
			$cfg->{Main}{enable_mosquitto} = '1'; 
			LOGINF "Setting 'Enable local Mosquitto broker' to " . $cfg->{Main}{enable_mosquitto};
			$changed++;
			}
		if(! defined $cfg->{Main}{brokeraddress}) { 
			$cfg->{Main}{brokeraddress} = 'localhost'; 
			LOGINF "Setting MQTT broker address to " . $cfg->{Main}{brokeraddress};
			$changed++;
			}
		if(! defined $cfg->{Main}{convert_booleans}) { 
			$cfg->{Main}{convert_booleans} = 1; 
			LOGINF "Setting 'Convert booleans' to " . $cfg->{Main}{convert_booleans};
			$changed++;
			}
		
		if(! defined $cfg->{Main}{udpinport}) { 
			$cfg->{Main}{udpinport} = 11883; 
			LOGINF "Setting MQTT gateway UDP In-Port to " . $cfg->{Main}{udpinport};
			$changed++;
			}
		
		$json->write();
		
		LOGINF "Config:";
		LOGDEB Dumper($cfg);
		if($changed == 0) {
			LOGOK "No changes in your configuration.";
			LOGTITLE "No settings updated";
		} else {
			LOGWARN "$changed parameters updated. Check the new settings if it matches your configuration.";
			LOGTITLE "$changed parameters updated";
		}
	}
}

