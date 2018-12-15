#!/usr/bin/perl
use FindBin qw($Bin);
use lib "$Bin/../libs";
use strict;
use warnings;
use LoxBerry::System;
use JSON;
#use LoxBerry::JSON;
use Data::Dumper;

print "JSON V$JSON::VERSION\n";

#use JSON::Tiny;
# print "JSON::Tiny V$JSON::Tiny::VERSION\n";


my $cfgfile = "jsontestdata3.json";
 
my $jsonstr = LoxBerry::System::read_file($cfgfile);

my $json = JSON->new;
#$json->boolean_values(\0, \1);

#(my $false,  my $true) = $json->get_boolean_values;

my $cfg = $json->decode($jsonstr);
# $JSON::Tiny::FALSE = 0;
# $JSON::Tiny::TRUE = 1;

# my $cfg = JSON::Tiny::decode_json($jsonstr);

#print Dumper($cfg);

# process($cfg);

# sub process
# {
	# my ($obj) = @_;
	# print $obj;
	

# }



# my $cfg = from_json($jsonstr);


####################################
###### Hash::Flatten #####
####################################
use Hash::Flatten;

my $o = new Hash::Flatten({
        HashDelimiter => '_', 
        ArrayDelimiter => '_',
        OnRefScalar => 'warn',
		#DisableEscapes => 'true',
		EscapeSequence => '#',
		OnRefGlob => '',
		OnRefScalar  => '',
		OnRefRef => '',
});

my $flat_hash = $o->flatten($cfg);

foreach my $key (keys %$flat_hash) {
	print "$key: $flat_hash->{$key}\n";

}



####################################
###### Data::Visitor::Callback #####
####################################
#use Data::Visitor::Callback;



####################################
###### Data::Walk			########
####################################

# # apt-get install libdata-walk-perl
# use Data::Walk;

# my @tree;
# my %normalized;
# my $hashkey;
# my $lastdepth;

# # #eval {
 # walk { wanted => \&process_node }, $cfg ;
# # #};

# sub preprocess 
# {
	# print "PREPROCESS $Data::Walk::container\n";

# }

# sub process_node 
# {
	# #print 
	# if($Data::Walk::type eq "ARRAY") {
		# if($lastdepth < $Data::Walk::depth) {
			# push @tree, $Data::Walk::index;
		# } elsif ($lastdepth > $Data::Walk::depth) {
			# pop @tree;
		# }
	# }
	
	# if($Data::Walk::type eq "HASH" ) {
		# if($lastdepth < $Data::Walk::depth) {
			# push @tree, $_;
		# } elsif ($lastdepth > $Data::Walk::depth) {
			# pop @tree;
		# }
		
		# print "$Data::Walk::depth|$Data::Walk::index $_ \t$Data::Walk::type $Data::Walk::container\n";
	# }
	# #$count++;
# }

#####################################
