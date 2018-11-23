#!/usr/bin/perl
#use LoxBerry::IO;
#use LoxBerry::Log;
use LoxBerry::System;
use CGI;
use JSON;
use warnings;
use strict;

require "$lbpbindir/libs/LoxBerry/JSON/JSONIO.pm";

$LoxBerry::JSON::JSONIO::DEBUG = 1;

my $cfgfile = "$lbpconfigdir/mqtt.json";
my $credfile = "$lbpconfigdir/cred.json";
my $json;
my $cfg;
my %response;
$response{error} = 1;
$response{message} = "Unspecified error";

my $cgi = CGI->new;
my $q = $cgi->Vars;

my $pincheck = checksecpin($q->{secpin});
if ($pincheck) {
	response();
}	

my $credobj = LoxBerry::JSON::JSONIO->new();
my $cred = $credobj->open(filename => $credfile);
# use Data::Dumper;
# print Dumper($cred);
my $action = $q->{action} ? $q->{action} : "";
if ($action eq "getcred") { getcred(); }
elsif ($action eq "setcred") { setcred($q->{brokeruser}, $q->{brokerpass}); }
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
	my ($brokeruser, $brokerpass) = @_;
	my %Credentials;
	$Credentials{brokeruser} =$brokeruser;
	$Credentials{brokerpass} =$brokerpass;
	$cred->{Credentials} = \%Credentials;
	$credobj->write();

	if($cred) {
		%response = (%response, %$cred);
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