#!/usr/bin/perl
use FindBin qw($Bin);
use lib "$Bin/libs";

use Time::HiRes;
use LoxBerry::IO;
use LoxBerry::Log;
use warnings;
use strict;
use IO::Socket;

use Net::MQTT::Simple::Auth;
use LoxBerry::JSON::JSONIO;

use Data::Dumper;

#require "$lbpbindir/libs/Net/MQTT/Simple.pm";
#require "$lbpbindir/libs/Net/MQTT/Simple/Auth.pm";
#require "$lbpbindir/libs/LoxBerry/JSON/JSONIO.pm";

my $cfgfile = "$lbpconfigdir/mqtt.json";
my $json;
my $cfg;
my $cfg_timestamp;
my $nextconfigpoll;
my $mqtt;
my @subscriptions;

# UDP
my $udpinsock;
my $udpmsg;
my $udpremhost;
my $udpMAXLEN = 1024;
		
	
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
	loglevel => 7,
	addtime => 1
	
);

LOGSTART "MQTT Gateway started";

LOGINF "KEEP IN MIND: LoxBerry MQTT only sends CHANGED values to the Miniserver.";
LOGINF "If you use UDP Monitor, you have to take actions that changes are pushed.";
LoxBerry::IO::msudp_send(1, 6666, "MQTT", "KEEP IN MIND: LoxBerry MQTT only sends CHANGED values to the Miniserver.");

my %miniservers;
%miniservers = LoxBerry::System::get_miniservers();

read_config();
create_in_socket();
	
# Capture messages
while(1) {
	if(time>$nextconfigpoll) {
		LOGWARN "No connection to MQTT broker $cfg->{Main}{brokeraddress} - Check host/port/user/pass and your connection." if(!$mqtt->{socket});
		
		read_config();
		if(!$udpinsock) {
			create_in_socket();
		}
	}
	$mqtt->tick();
	
	# UDP Receive data from UDP socket
	eval {
		$udpinsock->recv($udpmsg, $udpMAXLEN);
	};
	if($udpmsg) {
		my($port, $ipaddr) = sockaddr_in($udpinsock->peername);
		$udpremhost = gethostbyaddr($ipaddr, AF_INET);
		LOGOK "UDP IN: $udpremhost (" .  inet_ntoa($ipaddr) . "): $udpmsg";
		## Send to MQTT Broker
		# Check incoming message
		my ($udptopic, $udpmessage) = split(/\ /, trim($udpmsg));
		LOGDEB "Relaying: '$udptopic'='$udpmessage'";
		eval {
			$mqtt->publish($udptopic, $udpmessage);
		};
		if($@) {
			LOGERR "Catched exception on sending to MQTT: $!";
		}
		
		# $udpinsock->send("CONFIRM: $udpmsg ");
	} 
	
	Time::HiRes::sleep(0.05);
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
			LOGDEB "  UDP: Sending as $topic to MS No. " . $cfg->{Main}{msno};
			LoxBerry::IO::msudp_send_mem($cfg->{Main}{msno}, $cfg->{Main}{udpport}, "MQTT", $topic, $message);
		}
	}
	if( is_enabled($cfg->{Main}{use_http}) and $miniservers{$cfg->{Main}{msno}} ) {
		$topic =~ s/\//_/g;
		LOGDEB "  HTTP: Sending as $topic to MS No. " . $cfg->{Main}{msno};
		LoxBerry::IO::mshttp_send_mem($cfg->{Main}{msno},  $topic, $message);
	}
}

sub read_config
{
	$nextconfigpoll = time+5;
	
	my $mtime = (stat($cfgfile))[9];
	if(defined $cfg_timestamp and $cfg_timestamp == $mtime and defined $cfg) {
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
		if(! defined $cfg->{Main}{brokeraddress}) { $cfg->{Main}{brokeraddress} = 'localhost'; }
		if(! defined $cfg->{Main}{udpinport}) { $cfg->{Main}{udpinport} = 11883; }
		

		LOGDEB "JSON Dump:";
		LOGDEB Dumper($cfg);

		LOGINF "MSNR: " . $cfg->{Main}{msno};
		LOGINF "UDPPort: " . $cfg->{Main}{udpport};
		
		
		# Unsubscribe old topics
		if($mqtt) {
			eval {
				foreach my $topic (@subscriptions) {
					LOGINF "UNsubscribing $topic";
					$mqtt->unsubscribe($topic);
				}
			};
			if ($@) {
				LOGERR "Exception catched on unsubscribing old topics: $!";
			}
		}
		
		undef $mqtt;
		
		# Reconnect MQTT broker
		LOGINF "Connecting broker $cfg->{Main}{brokeraddress}";
		eval {
			#$mqtt = Net::MQTT::Simple->new($cfg->{Main}{brokeraddress});
			$mqtt = Net::MQTT::Simple::Auth->new($cfg->{Main}{brokeraddress}, $cfg->{Main}{brokeruser}, $cfg->{Main}{brokerpass});
			#$mqtt = Net::MQTT::Simple::Auth->new($cfg->{Main}{brokeraddress}, "loxberry", "loxberry");
			#$mqtt = Net::MQTT::Simple::Auth->new($cfg->{Main}{brokeraddress});
			
			@subscriptions = @{$cfg->{subscriptions}};
			# Re-Subscribe new topics
			foreach my $topic (@subscriptions) {
				LOGINF "Subscribing $topic";
				$mqtt->subscribe($topic, \&received);
			}
		};
		if ($@) {
			LOGERR "Exception catched on reconnecting and subscribing: $!";
		}
		
		# Clean UDP socket
		create_in_socket();
	
	}
}



sub create_in_socket 
{

	undef $udpinsock;
	# UDP in socket
	LOGDEB "Creating udp-in socket";
	$udpinsock = IO::Socket::INET->new(
		# LocalAddr => 'localhost', 
		LocalPort => $cfg->{Main}{udpinport}, 
		#Blocking => 0,
		Proto => 'udp') or LOGERR "Could not create UDP IN socket: $@";
		
	if($udpinsock) {
		IO::Handle::blocking($udpinsock, 0);
		LOGOK "UDP-IN listening on port " . $cfg->{Main}{udpinport};
	}
}

END
{
	if($log) {
		LOGEND "MQTT Gateway exited";
	}
}