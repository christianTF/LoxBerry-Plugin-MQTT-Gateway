#!/usr/bin/perl

use LoxBerry::Web;
use CGI;
#require "$lbpbindir/libs/LoxBerry/JSON/JSONIO.pm";

my $cfgfile = "$lbpconfigdir/mqtt.json";
my $extplugindatafile = "/dev/shm/mqttgateway_extplugindata.json";

my $cgi = CGI->new;
my $q = $cgi->Vars;

my %pids;

my $template;

if( $q->{ajax} ) {
	
	## Handle all ajax requests 
	
	require JSON;
	require Time::HiRes;
	my %response;
	ajax_header();
	
	# GetPids
	if( $q->{ajax} eq "getpids" ) {
		pids();
		$response{pids} = \%pids;
		print JSON::encode_json(\%response);
	}
	
	# Purge Mosquitto DB
	if( $q->{ajax} eq "mosquitto_purgedb" ) {
		qx( sudo $lbpbindir/sudo/mosq_purgedb.sh );
		# Now restart the Gateway
		$q->{ajax} = "restartgateway";
	}
	
	# Restart Mosquitto
	if( $q->{ajax} eq "mosquitto_restart" ) {
		qx( sudo $lbpbindir/sudo/mosq_restart.sh );
		# Now restart the Gateway
		$q->{ajax} = "restartgateway";
	}
	
	# Restart Gateway
	if( $q->{ajax} eq "restartgateway" ) {
		pkill('mqttgateway.pl');
		`cd $lbpbindir ; $lbpbindir/mqttgateway.pl > /dev/null 2>&1 &`;
		pids();
		$response{pids} = \%pids;
		print JSON::encode_json(\%response);
	}
	
	# Send Reconnect
	if( $q->{ajax} eq "reconnect" ) {
		if (defined $q->{udpinport} and $q->{udpinport} ne "0") {
			require IO::Socket;
			my $udpoutsock = IO::Socket::INET->new(
				Proto    => 'udp',
				PeerPort => $q->{udpinport},
				PeerAddr => 'localhost',
			) or print STDERR "MQTT index.cgi: Could not create udp socket to gateway: $!\n";

			$udpoutsock->send('reconnect');
			$udpoutsock->close;
			print STDERR "MQTT index.cgi: Ajax reconnect sent\n";
			
		} else {
			print STDERR "MQTT index.cgi: Ajax reconnect FAILED\n";
		}
		print JSON::encode_json(\%response);
	}
	
	# Relayed topics for Incoming Overview
	if( $q->{ajax} eq "relayed_topics" ) {
		
		if (defined $q->{udpinport} and $q->{udpinport} ne "0") {
			require IO::Socket;
			my $udpoutsock = IO::Socket::INET->new(
				Proto    => 'udp',
				PeerPort => $q->{udpinport},
				PeerAddr => 'localhost',
			) or print STDERR "MQTT index.cgi: Could not create udp socket to gateway: $!\n";

			$udpoutsock->send('save_relayed_states');
			$udpoutsock->close;
		}
		
		my $datafile = "/dev/shm/mqttgateway_topics.json";
		print LoxBerry::System::read_file($datafile);
	}
	
	# Delete topic
	if( $q->{ajax} eq "retain" ) {
		
		if (defined $q->{udpinport} and $q->{udpinport} ne "0") {
			require IO::Socket;
			my $udpoutsock = IO::Socket::INET->new(
				Proto    => 'udp',
				PeerPort => $q->{udpinport},
				PeerAddr => 'localhost',
			) or print STDERR "MQTT index.cgi: Could not create udp socket to gateway: $!\n";

			$udpoutsock->send("retain $q->{topic}");
			$udpoutsock->close;
			
		}
		
		my $datafile = "/dev/shm/mqttgateway_topics.json";
		print LoxBerry::System::read_file($datafile);
	}
	
	# Disable cache of topic
	if( $q->{ajax} eq "disablecache" ) {
		require LoxBerry::JSON;
		my $json = LoxBerry::JSON->new();
		my $cfg = $json->open(filename => $cfgfile);
		if (!$cfg) {
			exit;
		}
		
		print STDERR "Cache-related topic: " . $q->{topic} . " is now " . $q->{disablecache} . "\n";
		if(!is_enabled($q->{disablecache})) {
			delete $cfg->{Noncached}->{$q->{topic}};
		} else {
			$cfg->{Noncached}->{$q->{topic}} = $q->{disablecache};
		}
		$json->write();
	
	}
	
	# Set resetAfterSend for a topic
	if( $q->{ajax} eq "resetAfterSend" ) {
		require LoxBerry::JSON;
		my $json = LoxBerry::JSON->new();
		my $cfg = $json->open(filename => $cfgfile);
		if (!$cfg) {
			exit;
		}
		
		print STDERR "Reset-After-Send topic: " . $q->{topic} . " is now " . $q->{resetAfterSend} . "\n";
		if(!is_enabled($q->{resetAfterSend})) {
			delete $cfg->{resetAfterSend}->{$q->{topic}};
		} else {
			$cfg->{resetAfterSend}->{$q->{topic}} = $q->{resetAfterSend};
		}
		$json->write();
	
	}


	
	exit;

} else {
	
	## Normal request (not ajax)
	
	# Init template
	
	$template = HTML::Template->new(
		filename => "$lbptemplatedir/mqtt.html",
		global_vars => 1,
		loop_context_vars => 1,
		die_on_bad_params => 0,
	);
	
	
	# Push json config to template
	
	my $cfgfilecontent = LoxBerry::System::read_file($cfgfile);
	$cfgfilecontent = jsescape($cfgfilecontent);
	$template->param('JSONCONFIG', $cfgfilecontent);
	
	
	# Switch between forms
	
	if( !$q->{form} or $q->{form} eq "settings" ) {
		$navbar{10}{active} = 1;
		$template->param("FORM_SETTINGS", 1);
		settings_form(); 
	}
	elsif ( $q->{form} eq "subscriptions" ) {
		$navbar{20}{active} = 1;
		$template->param("FORM_SUBSCRIPTIONS", 1);
		subscriptions_form();
	}
	elsif ( $q->{form} eq "conversions" ) {
		$navbar{30}{active} = 1;
		$template->param("FORM_CONVERSIONS", 1);
		conversions_form();
	}
	elsif ( $q->{form} eq "topics" ) {
		$navbar{40}{active} = 1;
		$template->param("FORM_TOPICS", 1);
		$template->param("FORM_DISABLE_BUTTONS", 1);
		# $template->param("FORM_DISABLE_JS", 1);
		topics_form();
	}
	elsif ( $q->{form} eq "logs" ) {
		$navbar{90}{active} = 1;
		$template->param("FORM_LOGS", 1);
		$template->param("FORM_DISABLE_BUTTONS", 1);
		$template->param("FORM_DISABLE_JS", 1);
		logs_form();
	}
}

print_form();

exit;

######################################################################
# Print Form
######################################################################
sub print_form
{
	my $plugintitle = "MQTT Gateway v" . LoxBerry::System::pluginversion();
	my $helplink = "https://www.loxwiki.eu/x/S4ZYAg";
	my $helptemplate = "help.html";
	
	our %navbar;
	$navbar{10}{Name} = "Settings";
	$navbar{10}{URL} = 'index.cgi';
 
 	$navbar{20}{Name} = "Subscriptions";
	$navbar{20}{URL} = 'index.cgi?form=subscriptions';
 
	$navbar{30}{Name} = "Conversions";
	$navbar{30}{URL} = 'index.cgi?form=conversions';
 
 	$navbar{40}{Name} = "Incoming overview";
	$navbar{40}{URL} = 'index.cgi?form=topics';
 
	$navbar{90}{Name} = "Logfiles";
	$navbar{90}{URL} = 'index.cgi?form=logs';
		
	LoxBerry::Web::lbheader($plugintitle, $helplink, $helptemplate);

	print $template->output();

	LoxBerry::Web::lbfooter();


}


########################################################################
# Settings Form 
########################################################################
sub settings_form
{

	my $mslist_select_html = LoxBerry::Web::mslist_select_html( FORMID => 'Main.msno', LABEL => 'Receiving Miniserver', DATA_MINI => "0" );
	$template->param('mslist_select_html', $mslist_select_html);

}

########################################################################
# Subscriptions Form 
########################################################################
sub subscriptions_form
{

	# Send external plugin settings to template
	my $extpluginfilecontent = LoxBerry::System::read_file($extplugindatafile);
	$extpluginfilecontent = jsescape($extpluginfilecontent);
	$template->param('EXTPLUGINSETTINGS', $extpluginfilecontent);

}

########################################################################
# Conversions Form 
########################################################################
sub conversions_form
{

	# Send external plugin settings to template
	my $extpluginfilecontent = LoxBerry::System::read_file($extplugindatafile);
	$extpluginfilecontent = jsescape($extpluginfilecontent);
	$template->param('EXTPLUGINSETTINGS', $extpluginfilecontent);

}

########################################################################
# Topics Form 
########################################################################
sub topics_form
{
	
	# Donate
	my $donate = "Thanks to all that have already donated for my special Test-Miniserver, making things much more easier than testing on the \"production\" house! Also, I'm buying (not <i>really</i> needed) hardware devices (e.g. Shelly's and other equipment) to test it with LoxBerry and plugins. As I'm spending my time, hopefully you support my expenses for my test environment. About a donation of about 5 or 10 Euros, or whatever amount it is worth for you, I will be very happy!";
	my $donate_done_remove = "Done! Remove this!";
	$template->param("donate", $donate);
	$template->param("donate_done_remove", $donate_done_remove);
	
}


########################################################################
# Logs Form 
########################################################################
sub logs_form
{

	$template->param('loglist_html', loglist_html());

}



######################################################################
# AJAX functions
######################################################################

sub pids 
{
	
	$pids{'mqttgateway'} = trim(`pgrep mqttgateway.pl`) ;
	$pids{'mosquitto'} = trim(`pgrep mosquitto`) ;

}	

sub pkill 
{
	my ($process) = @_;
	`pkill $process`;
	Time::HiRes::sleep(0.2);
	`pkill --signal SIGKILL $process`;
	

}	
	
sub ajax_header
{
	print $cgi->header(
			-type => 'application/json',
			-charset => 'utf-8',
			-status => '200 OK',
	);	
}	
	

#################################################################################
# Escape a json string for JavaScript code
#################################################################################
sub jsescape
{
	my ($stringToEscape) = shift;
		
	my $resultjs;
	
	if($stringToEscape) {
		my %translations = (
		"\r" => "\\r",
		"\n" => "\\n",
		"'"  => "\\'",
		"\\" => "\\\\",
		);
		my $meta_chars_class = join '', map quotemeta, keys %translations;
		my $meta_chars_re = qr/([$meta_chars_class])/;
		$stringToEscape =~ s/$meta_chars_re/$translations{$1}/g;
	}
	return $stringToEscape;
}