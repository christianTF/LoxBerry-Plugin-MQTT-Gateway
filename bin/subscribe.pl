#/usr/bin/perl
use Time::HiRes;
use LoxBerry::IO;
use warnings;
use strict;

use Data::Dumper;

require "./libs/Net/MQTT/Simple.pm";
require "./libs/LoxBerry/JSON/JSONIO.pm";

$cfgfile = "$lbpplugindir/mqtt.json";


# $LoxBerry::JSON::JSONIO::DEBUG = 1;

my $json = LoxBerry::JSON::JSONIO->new();
my $cfg = $json->open(filename => $cfgfile);

print "JSON Dump:\n";
print Dumper($cfg);

print "MSNR: " . $cfg->{Main}{msno} . "\n";
print "UDPPort: " . $cfg->{Main}{udpport} . "\n";

print "KEEP IN MIND: LoxBerry only sends CHANGED values to the Miniserver.\n";
print "              If you use UDP Monitor, you have to take actions that changes are pushed.\n";



my %miniservers;
%miniservers = LoxBerry::System::get_miniservers();

print "Subscriptions: " . join(", ", @{$cfg->{subscriptions}}) . "\n";

my $mqtt = Net::MQTT::Simple->new("localhost");

# Subscribe
foreach my $topic (@{$cfg->{subscriptions}}) {
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
	print "$topic: $message\n";
	if( $cfg->{Main}{msno} and $cfg->{Main}{udpport} and $miniservers{$cfg->{Main}{msno}}) {
		LoxBerry::IO::msudp_send_mem($cfg->{Main}{msno}, $cfg->{Main}{udpport}, "MQTT", $topic, $message);
	}
}
