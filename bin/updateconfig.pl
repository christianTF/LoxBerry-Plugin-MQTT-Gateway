#!/usr/bin/perl
use FindBin qw($Bin);
use lib "$Bin/libs";

use LoxBerry::Log;
use warnings;
use strict;
use CGI;

use LoxBerry::JSON::JSONIO;

use Data::Dumper;

my $cfgfile = "$lbpconfigdir/mqtt.json";
my $credfile = "$lbpconfigdir/cred.json";

my $json;
my $cfg;
my $cfg_timestamp;
my $nextconfigpoll;
my $mqtt;
my @subscriptions;

		

my $cgi = CGI->new;
my $q = $cgi->Vars;

my $log = LoxBerry::Log->new (
    name => 'Update Configuration',
	stdout => defined $q->{param} ? 0 : 1 ,
	loglevel => 7,
);

LOGSTART "Updating configuration during plugin installation";

$json = LoxBerry::JSON::JSONIO->new();
$cfg = $json->open(filename => $cfgfile);

if(!$cfg) {
	LOGCRIT "Could not read json configuration. Possibly not a valid json?";
	return;
}

# Function to read parameters from shell scripts
if($q->{section} and $q->{param}) {
	LOGTITLE "Query value from shell";
	my $val = $cfg->{$q->{section}}{$q->{param}};
	print $val;
	if ( $val =~ /^[0-9,.E]+$/ ) { 
		exit ($val);
	} elsif (is_enabled($val)) {
		exit 1;
	} elsif (is_disabled($val)) {
		exit 0;
	}
}

update_config();

sub update_config
{
	my $changed = 0;
	LOGOK "Reading config file";
	# $LoxBerry::JSON::JSONIO::DEBUG = 1;

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
		$cfg->{Main}{brokeraddress} = 'localhost:1883'; 
		LOGINF "Setting MQTT broker address to " . $cfg->{Main}{brokeraddress};
		$changed++;
		}
	if(! defined $cfg->{Main}{convert_booleans}) { 
		$cfg->{Main}{convert_booleans} = 1; 
		LOGINF "Setting 'Convert booleans' to " . $cfg->{Main}{convert_booleans};
		$changed++;
		}
	if(! defined $cfg->{Main}{expand_json}) { 
		$cfg->{Main}{expand_json} = 1; 
		LOGINF "Setting 'Expand JSON' to " . $cfg->{Main}{expand_json};
		$changed++;
		}
	if(! defined $cfg->{Main}{udpinport}) { 
		$cfg->{Main}{udpinport} = 11884; 
		LOGINF "Setting MQTT gateway UDP In-Port to " . $cfg->{Main}{udpinport};
		$changed++;
		}
	
	if(! defined $cfg->{Main}{pollms}) { 
		$cfg->{Main}{pollms} = 50; 
		LOGINF "Setting poll time for MQTT and UDP connection to " . $cfg->{Main}{pollms} . " milliseconds";
		$changed++;
		}
	if(! defined $cfg->{Main}{resetaftersendms}) { 
		$cfg->{Main}{resetaftersendms} = 10; 
		LOGINF "Setting Reset-After-Send delay to " . $cfg->{Main}{resetaftersendms} . " milliseconds";
		$changed++;
		}
	if(! defined $cfg->{Main}{toMS_delimiter}) { 
		$cfg->{Main}{toMS_delimiter} = '|'; 
		LOGINF "Setting delimiter for subscription miniserver list to " . $cfg->{Main}{toMS_delimiter};
		$changed++;
		}


		
	# Migrate credentials from mqtt.json to cred.json
	if(defined $cfg->{Main}{brokeruser} or defined $cfg->{Main}{brokerpass}) {
		unlink $credfile;
		my $credobj = LoxBerry::JSON::JSONIO->new();
		my $cred = $credobj->open(filename => $credfile);
		my %Credentials;
		$Credentials{brokeruser} = $cfg->{Main}{brokeruser};
		$Credentials{brokerpass} = $cfg->{Main}{brokerpass};
		$cred->{Credentials} = \%Credentials;
		$credobj->write();
		delete $cfg->{Main}{brokeruser};
		delete $cfg->{Main}{brokerpass};
		LOGWARN "Migrated MQTT credentials.";
		LOGWARN "Please double-check in the plugin settings, if everything is still cool!";
		$changed++;
	}
	
	# Migrate simple subscription array to subscription object array (V1.1)
	if( defined $cfg->{subscriptions} ) {
		my $elem_count = keys @{$cfg->{subscriptions}};
		LOGINF "$elem_count subscriptions are defined";
		if( $elem_count > 0 ) {
			if( ref($cfg->{subscriptions}[0]) ne "HASH" ) {
				# Old string array to convert
				LOGINF "Your subscriptions config is updated to the new data format";
				my @subs_new;
				foreach my $sub_old ( @{$cfg->{subscriptions}} ) {
					my @toMS = ();
					my %sub_new;
					$sub_new{id} = $sub_old;
					$sub_new{toMS} = \@toMS;
					push @subs_new, \%sub_new;
				}
				$cfg->{subscriptions} = \@subs_new;
				$changed++;
				
			}
		}
	}
	
	# Create Mosquitto config and password
	if( is_enabled($cfg->{Main}{enable_mosquitto}) ) { 
		my $credobj = LoxBerry::JSON::JSONIO->new();
		my $cred = $credobj->open(filename => $credfile);
		my %Credentials;
		
		if( !defined $cred->{Credentials}->{brokeruser} ) {
			$Credentials{brokeruser} = 'loxberry';
			$Credentials{brokerpass} = generate(16);
			LOGWARN "New Mosquitto configuration was created with a generated password.";
			LOGWARN "Check the plugin settings to see and change your new credentials.";
		} else {
			$Credentials{brokeruser} = $cred->{Credentials}->{brokeruser};
			$Credentials{brokerpass} = $cred->{Credentials}->{brokerpass};
		}
		
		if( !$cred->{Credentials}->{brokerpsk} or $cred->{Credentials}->{brokerpsk} eq "null") {
			$Credentials{brokerpsk} = generate_hexkey(240);
			LOGWARN "New 240-bit TLS Pre-Shared key was created.";
		} else {
			$Credentials{brokerpsk} = $cred->{Credentials}->{brokerpsk};
		}
		
		$cred->{Credentials} = \%Credentials;
		$credobj->write();
		
		print STDERR "COMMAND: $lbphtmlauthdir/ajax_brokercred.cgi action=setcred brokeruser=$Credentials{brokeruser} brokerpass=$Credentials{brokerpass} brokerpsk=$Credentials{brokerpsk} enable_mosquitto=$cfg->{Main}{enable_mosquitto}\n";
		
		`$lbphtmlauthdir/ajax_brokercred.cgi action=setcred brokeruser=$Credentials{brokeruser} brokerpass=$Credentials{brokerpass} brokerpsk=$Credentials{brokerpsk} enable_mosquitto=$cfg->{Main}{enable_mosquitto}`;
		
		`sudo $lbpbindir/sudo/mosq_readconfig.sh`; 
		
	}
	
	$json->write();
	`chown loxberry:loxberry $cfgfile`;
	`chown loxberry:loxberry $credfile`;
	
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

#####################################################
# Random Sub
#####################################################
sub generate {
        my ($count) = @_;
        my($zufall,@words,$more);

        if($count =~ /^\d+$/){
                $more = $count;
        }else{
                $more = 10;
        }

        @words = qw(A B C D E F G H I J K L M N O P Q R S T U V W X Y Z a b c d e f g h i j k l m n o p q r s t u v w x y z 0 1 2 3 4 5 6 7 8 9);

        foreach (1..$more){
                $zufall .= $words[int rand($#words+1)];
        }

        return($zufall);
}


################################################
# Generate a key in hex string representation
# Parameter is keylength in bit
################################################
sub generate_hexkey
{

	my ($keybits) = @_;
	
	if (! $keybits or $keybits < 40) {
		$keybits = 128;
	}
	
	my $keybytes = int($keybits/8+0.5);
	# print STDERR "Keybits: $keybits Keybytes: $keybytes\n";
	my $hexstr = "";
	
	for(1...$keybytes) { 
		my $rand = int(rand(256));
		$hexstr .= sprintf('%02X', $rand);
		# print STDERR "Rand: $rand \tHEX: $hexstr\n";
	}
	
	if ( length($hexstr) < ($keybytes*2) ) {
		return undef;
	}
	return $hexstr;

}



END 
{
	if ($log) {
		$log->LOGEND();
	}
}
