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

use Net::MQTT::Simple;
use LoxBerry::JSON::JSONIO;

use Data::Dumper;

$SIG{INT} = sub { 
	LOGTITLE "MQTT Gateway interrupted by Ctrl-C"; 
	LOGEND(); 
	exit 1;
};

$SIG{TERM} = sub { 
	LOGTITLE "MQTT Gateway requested to stop"; 
	LOGEND();
	exit 1;	
};


#require "$lbpbindir/libs/Net/MQTT/Simple.pm";
#require "$lbpbindir/libs/Net/MQTT/Simple/Auth.pm";
#require "$lbpbindir/libs/LoxBerry/JSON/JSONIO.pm";

my $cfgfile = "$lbpconfigdir/mqtt.json";
my $credfile = "$lbpconfigdir/cred.json";
my $json;
my $json_cred;
my $cfg;
my $cfg_cred;
my $cfg_timestamp;
my $cfg_cred_timestamp;

my $nextconfigpoll;
my $mqtt;

# Subscriptions
my @subscriptions;

# Conversions
my %conversions;

# Hash to store all submitted topics
my %relayed_topics_udp;
my %relayed_topics_http;
my %health_state;
my $nextrelayedstatepoll = 0;

# UDP
my $udpinsock;
my $udpmsg;
my $udpremhost;
my $udpMAXLEN = 1024;
		
# Own MQTT Gateway topic
my $gw_topicbase;

print "Configfile: $cfgfile\n";
while (! -e $cfgfile) {
	print "ERROR: Cannot find config file $cfgfile";
	sleep(5);
	$health_state{configfile}{message} = "Cannot find config file";
	$health_state{configfile}{error} = 1;
	$health_state{configfile}{count} += 1;
}

$health_state{configfile}{message} = "Configfile present";
$health_state{configfile}{error} = 0;
$health_state{configfile}{count} = 0;

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
		if(!$mqtt->{socket}) {
			LOGWARN "No connection to MQTT broker $cfg->{Main}{brokeraddress} - Check host/port/user/pass and your connection.";
			$health_state{broker}{message} = "No connection to MQTT broker $cfg->{Main}{brokeraddress} - Check host/port/user/pass and your connection.";
			$health_state{broker}{error} = 1;
			$health_state{broker}{count} += 1;
		} else {
			$health_state{broker}{message} = "Connected and subscribed to broker";
			$health_state{broker}{error} = 0;
			$health_state{broker}{count} = 0;
		}
		
		read_config();
		if(!$udpinsock) {
			create_in_socket();
		}
	}
	eval {
		$mqtt->tick();
	};
	
	# UDP Receive data from UDP socket
	eval {
		$udpinsock->recv($udpmsg, $udpMAXLEN);
	};
	if($udpmsg) {
		udpin();
	} 
	
	## Save relayed_topics_http and relayed_topics_udp
	## and send a ping to Miniserver
	if (time > $nextrelayedstatepoll) {
		save_relayed_states();
		$mqtt->retain($gw_topicbase . "keepaliveepoch", time);
	}
	
	Time::HiRes::sleep($cfg->{Main}{pollms}/1000);
}

sub udpin
{

	my($port, $ipaddr) = sockaddr_in($udpinsock->peername);
	$udpremhost = gethostbyaddr($ipaddr, AF_INET);
	LOGOK "UDP IN: $udpremhost (" .  inet_ntoa($ipaddr) . "): $udpmsg";
	## Send to MQTT Broker
	# Check incoming message
	
	$udpmsg = trim($udpmsg);
	my ($command, $udptopic, $udpmessage) = split(/\ /, $udpmsg, 3);
	
	if(lc($command) ne 'publish' and lc($command) ne 'retain' and lc($command) ne "reconnect") {
		# Old syntax - move around the values
		$udpmessage = trim($udptopic . " " . $udpmessage);
		$udptopic = $command;
		$command = 'publish';
	}
	$command = lc($command);
	if($command eq 'publish') {
		LOGDEB "Publishing: '$udptopic'='$udpmessage'";
		eval {
			$mqtt->publish($udptopic, $udpmessage);
		};
		if($@) {
			LOGERR "Catched exception on publishing to MQTT: $!";
		}
	} elsif($command eq 'retain') {
		LOGDEB "Publish (retain): '$udptopic'='$udpmessage'";
		eval {
			$mqtt->retain($udptopic, $udpmessage);
		};
		if($@) {
			LOGERR "Catched exception on publishing (retain) to MQTT: $!";
		}
	} elsif($command eq 'reconnect') {
		LOGOK "Forcing reconnection and retransmission to Miniserver";
		$cfg_timestamp = 0;
	} else {
		LOGERR "Unknown incoming UDP command";
	}
	
	# $udpinsock->send("CONFIRM: $udpmsg ");

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
			if($@) { 
				LOGERR "Error on JSON expansion: $!";
				$health_state{jsonexpansion}{message} = "There were errors expanding incoming JSON.";
				$health_state{jsonexpansion}{error} = 1;
				$health_state{jsonexpansion}{count} += 1;
			} 
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
			if( defined $conversions{ $sendhash{$sendtopic} } ) {
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
			my $udpresp = LoxBerry::IO::msudp_send_mem($cfg->{Main}{msno}, $cfg->{Main}{udpport}, "MQTT", %sendhash);
			if (!$udpresp) {
				$health_state{udpsend}{message} = "There were errors sending values via UDP to the Miniserver.";
				$health_state{udpsend}{error} = 1;
				$health_state{udpsend}{count} += 1;
			}
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
		my $httpresp = LoxBerry::IO::mshttp_send_mem($cfg->{Main}{msno},  %sendhash);
		# if (!$httpresp) {
			# LOGDEB "  HTTP: Virtual input not available?";
		# } elsif ($httpresp eq "1") {
			# LOGDEB "  HTTP: Values are equal to cache";
		# } else {
			# foreach my $sendtopic (keys %$httpresp) {
				# if (!$httpresp->{$sendtopic}) {
					# LOGDEB "  Virtual Input $sendtopic failed to send - Virtual Input not available?";
					# $relayed_topics_http{$sendtopic}{error} = 1;
					# $health_state{httpsend}{message} = "There were errors sending values via HTTP to the Miniserver";
					# $health_state{jsonexpansion}{error} = 1;
					# $health_state{jsonexpansion}{count} += 1;
				# }
			# }
		# }
	}
}

sub read_config
{
	my $configs_changed = 0;
	$nextconfigpoll = time+5;
	my $mtime;
	
	# Check cfg timestamp
	$mtime = (stat($cfgfile))[9];
	if(!defined $cfg_timestamp or $cfg_timestamp != $mtime or !defined $cfg) {
		LOGDEB "cfg mtime: $mtime";
		$configs_changed = 1;
	}
	$cfg_timestamp = $mtime;
	
	# Check cred timestamp
	$mtime = (stat($credfile))[9];
	if(!defined $cfg_cred_timestamp or $cfg_cred_timestamp != $mtime or  !defined $cfg_cred) {
		LOGDEB "cred mtime: $mtime";
		$configs_changed = 1;
	}
	$cfg_cred_timestamp = $mtime;

	if($configs_changed == 0) {
		return;
	}

	
	LOGOK "Reading config changes";
	# $LoxBerry::JSON::JSONIO::DEBUG = 1;

	# Own topic
	$gw_topicbase = lbhostname() . "/mqttgateway/";
	LOGOK "MQTT Gateway topic base is $gw_topicbase";
	
	# Config file
	$json = LoxBerry::JSON::JSONIO->new();
	$cfg = $json->open(filename => $cfgfile, readonly => 1);
	# Credentials file
	$json_cred = LoxBerry::JSON::JSONIO->new();
	$cfg_cred = $json->open(filename => $credfile, readonly => 1);
	
	if(!$cfg) {
		LOGERR "Could not read json configuration. Possibly not a valid json?";
		$health_state{configfile}{message} = "Could not read json configuration. Possibly not a valid json?";
		$health_state{configfile}{error} = 1;
		$health_state{configfile}{count} += 1;
		return;
	} elsif (!$cfg_cred) {
		LOGERR "Could not read credentials json configuration. Possibly not a valid json?";
		$health_state{configfile}{message} = "Could not read credentials json configuration. Possibly not a valid json?";
		$health_state{configfile}{error} = 1;
		$health_state{configfile}{count} += 1;
		return;

	} else {
	
	# Setting default values
		if(! defined $cfg->{Main}{msno}) { $cfg->{Main}{msno} = 1; }
		if(! defined $cfg->{Main}{udpport}) { $cfg->{Main}{udpport} = 11883; }
		if(! defined $cfg->{Main}{brokeraddress}) { $cfg->{Main}{brokeraddress} = 'localhost'; }
		if(! defined $cfg->{Main}{udpinport}) { $cfg->{Main}{udpinport} = 11883; }
		if(! defined $cfg->{Main}{pollms}) { $cfg->{Main}{pollms} = 50; }
		
		
		
		LOGDEB "JSON Dump:";
		LOGDEB Dumper($cfg);

		LOGINF "MSNR: " . $cfg->{Main}{msno};
		LOGINF "UDPPort: " . $cfg->{Main}{udpport};
		
		# Unsubscribe old topics
		if($mqtt) {
			eval {
				$mqtt->retain($gw_topicbase . "status", "Disconnected");
				
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
			
			$ENV{MQTT_SIMPLE_ALLOW_INSECURE_LOGIN} = 1;
			
			$mqtt = Net::MQTT::Simple->new($cfg->{Main}{brokeraddress});
			
			if($cfg_cred->{Credentials}{brokeruser} or $cfg_cred->{Credentials}{brokerpass}) {
				LOGINF "Login at broker";
				$mqtt->login($cfg_cred->{Credentials}{brokeruser}, $cfg_cred->{Credentials}{brokerpass});
			}
			
			LOGINF "Sending Last Will and Testament"; 
			$mqtt->last_will($gw_topicbase . "status", "Disconnected", 1);
		
			$mqtt->retain($gw_topicbase . "status", "Joining");
			
			@subscriptions = @{$cfg->{subscriptions}};
			push @subscriptions, $gw_topicbase . "#";
			# Re-Subscribe new topics
			foreach my $topic (@subscriptions) {
				LOGINF "Subscribing $topic";
				$mqtt->subscribe($topic, \&received);
			}
		};
		if ($@) {
			eval {
				$mqtt->retain($gw_topicbase . "status", "Disconnected");
			
			};
			LOGERR "Exception catched on reconnecting and subscribing: $!";
			$health_state{broker}{message} = "Exception catched on reconnecting and subscribing: $!";
			$health_state{broker}{error} = 1;
			$health_state{broker}{count} += 1;
			
		} else {
			eval {
				$mqtt->retain($gw_topicbase . "status", "Connected");
			};
			$health_state{broker}{message} = "Connected and subscribed successfully";
			$health_state{broker}{error} = 0;
			$health_state{broker}{count} = 0;
			
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
	# sleep 1;
	# UDP in socket
	LOGDEB "Creating udp-in socket";
	$udpinsock = IO::Socket::INET->new(
		# LocalAddr => 'localhost', 
		LocalPort => $cfg->{Main}{udpinport}, 
		# MultiHomed => 1,
		#Blocking => 0,
		Proto => 'udp') or 
	do {
		LOGERR "Could not create UDP IN socket: $@";
		$health_state{udpinsocket}{message} = "Could not create UDP IN socket: $@";
		$health_state{udpinsocket}{error} = 1;
		$health_state{udpinsocket}{count} += 1;
	};	
		
	if($udpinsock) {
		IO::Handle::blocking($udpinsock, 0);
		LOGOK "UDP-IN listening on port " . $cfg->{Main}{udpinport};
		$health_state{udpinsocket}{message} = "UDP-IN socket connected";
		$health_state{udpinsocket}{error} = 0;
		$health_state{udpinsocket}{count} = 0;
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
	$relayjson->{health_state} = \%health_state;
	$relayjsonobj->write();
	undef $relayjsonobj;

	# # Publish current health state
	# foreach my $okey ( keys %health_state ) { 
		# my $inner = $health_state{$okey};
		# foreach my $ikey ( keys %$inner ) { 
			# LOGDEB $okey . " " . $ikey . " " . $inner->{$ikey};
		# }
	# }
	
	
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
	if($mqtt) {
		$mqtt->retain($gw_topicbase . "status", "Disconnected");
		$mqtt->disconnect()
	}
	
	if($log) {
		LOGEND "MQTT Gateway exited";
	}
}