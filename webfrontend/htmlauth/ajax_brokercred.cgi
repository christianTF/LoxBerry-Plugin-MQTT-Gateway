#!/usr/bin/perl
#use LoxBerry::IO;
#use LoxBerry::Log;
use LoxBerry::System;
use CGI;
use JSON;
use warnings;
use strict;

require "$lbpbindir/libs/LoxBerry/JSON/JSONIO.pm";

#$LoxBerry::JSON::JSONIO::DEBUG = 1;

my $cfgfile = "$lbpconfigdir/mqtt.json";
my $credfile = "$lbpconfigdir/cred.json";
my $json;
my $cfg;
my %response;
$response{error} = 1;
$response{message} = "Unspecified error";

my $cgi = CGI->new;
my $q = $cgi->Vars;

# We only check SecurePIN if we are not root
if($> != 0) {
	my $pincheck = checksecpin($q->{secpin});
	if ($pincheck) {
		response();
	}	
}

my $credobj = LoxBerry::JSON::JSONIO->new();
my $cred = $credobj->open(filename => $credfile);
# use Data::Dumper;
# print Dumper($cred);
my $action = $q->{action} ? $q->{action} : "";
if ($action eq "getcred") { getcred(); }
elsif ($action eq "setcred") { setcred($q->{brokeruser}, $q->{brokerpass}, $q->{enable_mosquitto}, $q->{brokerpsk}); }
else  { 
	$response{message} = "The requested operation is not permitted.";
	$response{error} = 1;
}

response();
exit($response{error});



			
# ########################################################################
# # Save JSON 
# ########################################################################
# sub save_json
# {
	# open(my $fh, '>', $cfgfile) or return "Could not open file '$cfgfile' $!";
	# print $fh $jsoninput;
	# close $fh;	
	# return;
# }

sub checksecpin
{
	my ($secpin) = @_;
	my $checkres = LoxBerry::System::check_securepin($secpin);
	if ( $checkres and $checkres == 1 ) {
		$response{message} = "The entered SecurePIN is wrong. Please try again.";
		$response{error} = 1;
    } elsif ( $checkres and $checkres == 2) {
		$response{message} = "Your SecurePIN file could not be opened.";
		$response{error} = 2;
	} else {
    		$response{message} = "You have entered the correct SecurePIN.";
			$response{error} = 0;
	}

	return $response{error};

}

sub getcred
{
	if($cred) {
		%response = (%response, %$cred);
	}

}

sub setcred
{
	my ($brokeruser, $brokerpass, $enable_mosquitto, $brokerpsk) = @_;
	my %Credentials;
	
	$Credentials{brokeruser} = $brokeruser;
	$Credentials{brokerpass} = $brokerpass;
	if (defined $brokerpsk) {
		$Credentials{brokerpsk} = $brokerpsk;
	} elsif (defined $cred->{Credentials}->{brokerpsk}) {
		$Credentials{brokerpsk} = $cred->{Credentials}->{brokerpsk};
	}
	
	$cred->{Credentials} = \%Credentials;
	$credobj->write();

	if($cred) {
		%response = (%response, %$cred);
	}

	# print STDERR "enable_mosquitto: " . is_enabled($enable_mosquitto) . "\n";
	
	if( is_enabled($enable_mosquitto) ) {
	
		my $mosq_cfgfile = "$lbpconfigdir/mosquitto.conf";
		my $mosq_passwdfile = "$lbpconfigdir/mosq_passwd";
		my $mosq_pskfile = "$lbpconfigdir/mosq_psk";
		
		# Create and write config file
		my $mosq_config;
		
		$mosq_config = "# This file is directly managed by the MQTT-Gateway plugin.\n";
		$mosq_config .= "# Do not change this file, as your changes will be lost on saving in the MQTT-Gateway webinterface.\n\n";
		
		$mosq_config .= "port 1883\n";
			
		# User and pass, or anonymous
		if(!$brokeruser and !$brokerpass) {
			# Anonymous when no credentials are provided
			$mosq_config .= "allow_anonymous true\n";
		} else {
			# User/Pass and password file when credentials are provided
			$mosq_config .= "allow_anonymous false\n";
			$mosq_config .= "password_file $mosq_passwdfile\n";
		}
		
		# TLS listener
		if ($Credentials{brokerpsk}) {
			$mosq_config .= "# TLS-PSK listener\n";
			$mosq_config .= "listener 8883\n";
			$mosq_config .= "use_identity_as_username true\n";
			$mosq_config .= "tls_version tlsv1.2\n";
			$mosq_config .= "psk_hint mqttgateway_psk\n";
			$mosq_config .= "psk_file $mosq_pskfile\n";
		}
		
		open(my $fh, '>', $mosq_cfgfile) or 
		do {
			$response{message} = "Could not open $mosq_cfgfile: $!";
			$response{error} = 1;
		};
		print $fh $mosq_config;
		close $fh;
		`chown loxberry:loxberry $mosq_cfgfile`;
		
		# (Re-)Create symlink
		`sudo $lbpbindir/sudo/mosq_symlink.sh`;
				
		# Passwords
		unlink $mosq_passwdfile;
		if ($brokeruser or $brokerpass) {
			`touch $mosq_passwdfile`;
			my $res = qx { mosquitto_passwd -b $mosq_passwdfile $brokeruser $brokerpass };
		}
		`chown loxberry:loxberry $mosq_passwdfile`;
		
		# PSK file
		open(my $pskfh, '>', $mosq_pskfile) or 
		do {
			$response{message} = "Could not open $mosq_pskfile: $!";
			$response{error} = 1;
		};
		print $pskfh "loxberry:$Credentials{brokerpsk}\n";
		close $pskfh;
		`chown loxberry:loxberry $mosq_pskfile`;
		
		# HUP to re-read Mosquitto config
		`sudo $lbpbindir/sudo/mosq_readconfig.sh`;
		
	}
	
}

########################################################################
# Response
########################################################################
sub response 
{
	print $cgi->header(
		-type => 'application/json',
		-charset => 'utf-8',
		-status => '200 OK',
	);	
	print encode_json(\%response);
	exit($response{error});
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
