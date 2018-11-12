#!/usr/bin/perl

use LoxBerry::Web;
require "$lbpbindir/libs/LoxBerry/JSON/JSONIO.pm";

my $cfgfile = "$lbpconfigdir/mqtt.json";

my $plugintitle = "MQTT Gateway v" . LoxBerry::System::pluginversion();
my $helplink = "https://www.loxwiki.eu";
my $helptemplate = "help.html";

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
