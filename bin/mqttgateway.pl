#!/usr/bin/perl
use FindBin qw($Bin);
use lib "$Bin/libs";

use Time::HiRes;
use LoxBerry::IO;
use LoxBerry::Log;
use warnings;
use strict;
use IO::Socket;
use Scalar::Util qw(looks_like_number);

use Net::MQTT::Simple::Auth;
use LoxBerry::JSON::JSONIO;

use Data::Dumper;

$SIG{INT} = sub { 
	LOGTITLE "MQTT Gateway interrupted by Ctrl-C"; 
	LOGEND(); 
};

$SIG{TERM} = sub { 
	LOGTITLE "MQTT Gateway requested to stop"; 
	LOGEND(); 
};


#require "$lbpbindir/libs/Net/MQTT/Simple.pm";
#require "$lbpbindir/libs/Net/MQTT/Simple/Auth.pm";
#require "$lbpbindir/libs/LoxBerry/JSON/JSONIO.pm";

my $cfgfile = "$lbpconfigdir/mqtt.json";
my $json;
my $cfg;
my $cfg_timestamp;
my $nextconfigpoll;
my $mqtt;

# Subscriptions
my @subscriptions;

# Conversions
my %conversions;

# Hash to store all submitted topics
my %relayed_topics_udp;
my %relayed_topics_http;
my $nextrelayedstatepoll = 0;

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
	
	# Save relayed_topics_http and relayed_topics_udp
	if (time > $nextrelayedstatepoll) {
		save_relayed_states();
	}
	
	Time::HiRes::sleep(0.05);
}



sub received
{
	
	my ($topic, $message) = @_;
	my $is_json = 1;
	my %sendhash;
	my $contjson;
	
	LOGINF "$topic: $message";
	
	if( is_enabled($cfg->{Main}{expand_json}) and is_enabled($cfg->{Main}{use_http}) ) {
		# Check if message is a json (only required if use_http is also enabled)
		eval {
			$contjson = decode_json($message);
		};
		if($@) {
			LOGDEB "  Not a valid json message";
			$is_json = 0;
			$sendhash{$topic} = $message;
		} else {
			LOGDEB "  Expanding json message";
			LOGDEB Dumper($contjson);
			$is_json = 1;
			undef $@;
			eval {
				for my $record ( keys %$contjson ) {
					my $val = $contjson->{$record};
					$sendhash{"$topic/$record"} = $val;
					#LOGDEB "  It is $record: $val";
				}
			};
			if($@) { LOGERR "Error $!";}
		}
	}
	else {
		# JSON expansion is disabled
		$is_json = 0;
		$sendhash{$topic} = $message;
	}
	
	# Boolean conversion
	if( is_enabled($cfg->{Main}{convert_booleans}) ) {
		
		foreach my $sendtopic (keys %sendhash) {
			if( is_enabled($sendhash{$sendtopic}) ) {
				#LOGDEB "  Converting $message to 1";
				$sendhash{$sendtopic} = "1";
			} elsif ( is_disabled($sendhash{$sendtopic}) ) {
				#LOGDEB "  Converting $message to 0";
				$sendhash{$sendtopic} = "0";
			}
		}
	} 
	
	# User defined conversion
	if ( %conversions ) {
		foreach my $sendtopic (keys %sendhash) {
			if( defined %conversions{ $sendhash{$sendtopic} } ) {
				$sendhash{$sendtopic} = $conversions{ $sendhash{$sendtopic} };
			}
		}
	}
	
	
	if( is_enabled($cfg->{Main}{use_udp}) ) {
		if( $cfg->{Main}{msno} and $cfg->{Main}{udpport} and $miniservers{$cfg->{Main}{msno}}) {
			#LoxBerry::IO::msudp_send_mem($cfg->{Main}{msno}, $cfg->{Main}{udpport}, "MQTT", $topic, $message);
			foreach my $sendtopic (keys %sendhash) {
				$relayed_topics_udp{$sendtopic}{timestamp} = time;
				$relayed_topics_udp{$sendtopic}{message} = $sendhash{$sendtopic};
				LOGDEB "  UDP: Sending as $sendtopic to MS No. " . $cfg->{Main}{msno};
			}	
			LoxBerry::IO::msudp_send_mem($cfg->{Main}{msno}, $cfg->{Main}{udpport}, "MQTT", %sendhash);
		}
	}
	if( is_enabled($cfg->{Main}{use_http}) and $miniservers{$cfg->{Main}{msno}} ) {
		foreach my $sendtopic (keys %sendhash) {
			my $newtopic = $sendtopic;
			$newtopic =~ s/\//_/g;
			$sendhash{$newtopic} = delete $sendhash{$sendtopic};
		}
		foreach my $sendtopic (keys %sendhash) {
			$relayed_topics_http{$sendtopic}{timestamp} = time;
			$relayed_topics_http{$sendtopic}{message} = $sendhash{$sendtopic};
			LOGDEB "  HTTP: Sending to input $sendtopic: $sendhash{$sendtopic}";
		}
		#LOGDEB "  HTTP: Sending as $topic to MS No. " . $cfg->{Main}{msno};
		#LoxBerry::IO::mshttp_send_mem($cfg->{Main}{msno},  $topic, $message);
		LoxBerry::IO::mshttp_send_mem($cfg->{Main}{msno},  %sendhash);
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
		
		# Conversions
		undef %conversions;
		if ($cfg->{conversions}) {
			LOGOK "Processing conversions";
			foreach my $conversion (@{$cfg->{conversions}}) {
				my ($text, $value) = split('=', $conversion, 2);
				$text = trim($text);
				$value = trim($value);
				if($text eq "" or $value eq "") {
					LOGWARN "Ignoring conversion setting: $conversion (a part seems to be empty)";
					next;
				}
				if(!looks_like_number($value)) {
					LOGWARN "Conversion entry: Convert '$text' to '$value' - Conversion is used, but '$value' seems not to be a number";
				} else {
					LOGINF "Conversion entry: Convert '$text' to '$value'";
				}
				if(defined $conversions{$text}) {
					LOGWARN "Conversion entry: '$text=$value' overwrites '$text=$conversions{$text}' - You have a DUPLICATE";
				}
				$conversions{$text} = $value;
			}
		} else {
			LOGOK "No conversions set";
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
		# MultiHomed => 1,
		#Blocking => 0,
		Proto => 'udp') or LOGERR "Could not create UDP IN socket: $@";
		
	if($udpinsock) {
		IO::Handle::blocking($udpinsock, 0);
		LOGOK "UDP-IN listening on port " . $cfg->{Main}{udpinport};
	}
}

sub save_relayed_states
{
	$nextrelayedstatepoll = time + 60;
	
	LOGINF "Relayed topics are saved on RAMDISK for UI";
	
	my $datafile = "/dev/shm/mqttgateway_topics.json";
	
	unlink $datafile;
	my $relayjsonobj = LoxBerry::JSON::JSONIO->new();
	my $relayjson = $relayjsonobj->open(filename => $datafile);

	$relayjson->{udp} = \%relayed_topics_udp;
	$relayjson->{http} = \%relayed_topics_http;
	
	$relayjsonobj->write();
	undef $relayjsonobj;

	## Delete memory elements older than one day
	
	# Delete udp messages
	foreach my $sendtopic (keys %relayed_topics_udp) {
		if(	$relayed_topics_udp{$sendtopic}{timestamp} < (time - 24*60*60) ) {
			delete $relayed_topics_udp{$sendtopic};
		}
	}
	
	# Delete http message
	foreach my $sendtopic (keys %relayed_topics_http) {
		if(	$relayed_topics_http{$sendtopic}{timestamp} < (time - 24*60*60) ) {
			delete $relayed_topics_http{$sendtopic};
		}
	}
	
}


END
{
	if($log) {
		LOGEND "MQTT Gateway exited";
	}
}