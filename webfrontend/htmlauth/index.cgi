#!/usr/bin/perl

use LoxBerry::Web;
use CGI;
#require "$lbpbindir/libs/LoxBerry/JSON/JSONIO.pm";

my $cfgfile = "$lbpconfigdir/mqtt.json";

my $cgi = CGI->new;
my $q = $cgi->Vars;

my %pids;

if( $q->{ajax} ) {
	require JSON;
	my %response;
	ajax_header();
	if( $q->{ajax} eq "getpids" ) {
		pids();
		$response{pids} = \%pids;
		print JSON::encode_json(\%response);
	}
	if( $q->{ajax} eq "restartgateway" ) {
		pkill('mqttgateway.pl');
		`cd $lbpbindir ; $lbpbindir/mqttgateway.pl > /dev/null 2>&1 &`;
		pids();
		$response{pids} = \%pids;
		print JSON::encode_json(\%response);
	}
	if( $q->{ajax} eq "relayed_topics" ) {
		my $datafile = "/dev/shm/mqttgateway_topics.json";
		print LoxBerry::System::read_file($datafile);
	}
	exit;

} else {
	main_form();
}
exit;

########################################################################
# Main Form 
########################################################################
sub main_form
{

	my $plugintitle = "MQTT Gateway v" . LoxBerry::System::pluginversion();
	my $helplink = "https://www.loxwiki.eu";
	my $helptemplate = "help.html";

	our %navbar;
	$navbar{1}{Name} = "Settings";
	$navbar{1}{URL} = 'index.cgi';
 
	$navbar{2}{Name} = "Logfiles";
	$navbar{2}{URL} = LoxBerry::Web::loglist_url();
	
	$navbar{1}{active} = 1;
	
	LoxBerry::Web::lbheader($plugintitle, $helplink, $helptemplate);

	my $template = HTML::Template->new(
		filename => "$lbptemplatedir/mqtt.html",
		global_vars => 1,
		loop_context_vars => 1,
		die_on_bad_params => 0,
	);


	my $cfgfilecontent = LoxBerry::System::read_file($cfgfile);
	$cfgfilecontent =~ s/[\r\n]//g;

	$template->param('JSONCONFIG', $cfgfilecontent);

	my $mslist_select_html = LoxBerry::Web::mslist_select_html( FORMID => 'Main.msno', LABEL => 'Miniserver to relay to' );
	$template->param('mslist_select_html', $mslist_select_html);



	print $template->output();

	LoxBerry::Web::lbfooter();

}


sub pids 
{
	
	$pids{'mqttgateway'} = trim(`pgrep mqttgateway.pl`) ;
	$pids{'mosquitto'} = trim(`pgrep mosquitto`) ;

}	

sub pkill 
{
	my ($process) = @_;
	return `pkill $process`;

}	

	
	
sub ajax_header
{
	print $cgi->header(
			-type => 'application/json',
			-charset => 'utf-8',
			-status => '200 OK',
	);	
}	
	
	
