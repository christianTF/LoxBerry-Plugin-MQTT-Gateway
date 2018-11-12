#!/usr/bin/perl

use LoxBerry::Web;
use CGI;
#require "$lbpbindir/libs/LoxBerry/JSON/JSONIO.pm";

my $cfgfile = "$lbpconfigdir/mqtt.json";

my $cgi = CGI->new;
my $q = $cgi->Vars;

if($q->{save}) {
	save_json();
} else {
	main_form();
}


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


