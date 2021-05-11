#!/usr/bin/perl
#use LoxBerry::IO;
#use LoxBerry::Log;
use LoxBerry::System;
use CGI;
use JSON;
use warnings;
use strict;

#require "$lbpbindir/libs/Net/MQTT/Simple.pm";
#require "$lbpbindir/libs/LoxBerry/JSON/JSONIO.pm";

my $cfgfile = "$lbpconfigdir/mqtt.json";
my $json;
my $cfg;
my $error;

my $cgi = CGI->new;

# Check input
my $jsoninput = $cgi->param( 'POSTDATA' );
eval {
	$cfg = decode_json($jsoninput);
};
if ($@) {
	$error = $@ . "JSON: $jsoninput";
	print STDERR "Not a valid json: $@\n";
}

if(!$error) {
	$error = save_json();
}

if($error) {
	print $cgi->header(
		-type => 'application/json',
		-charset => 'utf-8',
		-status => '400 Bad Request',
	);	
	print '{"error": "' . $error . '"}';
} else {
	# Return something
	print $cgi->header(
		-type => 'application/json',
		-charset => 'utf-8',
		-status => '204 NO CONTENT',
	);	
}	
			
########################################################################
# Save JSON 
########################################################################
sub save_json
{
	open(my $fh, '>', $cfgfile) or return "Could not open file '$cfgfile' $!";
	print $fh $jsoninput;
	close $fh;	
	
	# LoxBerry::System::General, from LB2.2
	my $generaljsonobj;
	my $generaljson;
	eval {
		require LoxBerry::System::General;
		$generaljsonobj = LoxBerry::System::General->new();
		$generaljson = $generaljsonobj->open( writeonclose => 1 );
	
		my ($brokerhost, $brokerport) = split( ":", $cfg->{Main}->{brokeraddress} , 2 );
		$brokerport = defined $brokerport ? $brokerport : "1883";
		
		$generaljson->{Mqtt}->{Brokerhost} = $brokerhost;
		$generaljson->{Mqtt}->{Brokerport} = $brokerport;
		
		$generaljson->{Mqtt}->{Udpinport} = $cfg->{Main}->{udpinport};
	
	};

	
	
	
	
	return;
}