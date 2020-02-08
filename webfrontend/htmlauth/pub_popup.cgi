#!/usr/bin/perl

use LoxBerry::Web;
use CGI;

my $template;

my $plugintitle = "Quick Publisher";
my $helplink = "nopanels";
  
LoxBerry::Web::lbheader($plugintitle, $helplink, undef);

$template = HTML::Template->new(
		filename => "$lbptemplatedir/pub_popup.html",
		global_vars => 1,
		loop_context_vars => 1,
		die_on_bad_params => 0,
	);

print $template->output();

# LoxBerry::Web::lbfooter();
