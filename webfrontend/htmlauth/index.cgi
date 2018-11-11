#!/usr/bin/perl

use LoxBerry::Web;
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

print $template->output();

LoxBerry::Web::lbfooter();
