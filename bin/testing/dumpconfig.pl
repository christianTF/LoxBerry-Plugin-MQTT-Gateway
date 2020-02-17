#!/usr/bin/perl
use LoxBerry::System;
use LoxBerry::JSON;

my $cfgfile = "$lbpconfigdir/mqtt.json"; 
$json = LoxBerry::JSON->new(); 
$cfg = $json->open(filename => $cfgfile, readonly => 1);

# $json->dump($cfg);
my $elem = keys @{$cfg->{subscriptions}};
print "subscriptions: " . ref $cfg->{subscriptions} ."\n";
print "($elem elements)\n";
print "val: " . $cfg->{subscriptions}[0] . "\n";

$elem = keys @{$cfg->{subscriptions_old}};
print "subscriptions_old: " . ref $cfg->{subscriptions_old} ."\n";
print "($elem elements)\n";
print "val: " . $cfg->{subscriptions_old}[0] . "\n";

print "\n";
print "ref sub: " . ref($cfg->{subscriptions}[0]) . "\n";
print "ref old: " . ref($cfg->{subscriptions_old}[0]) . "\n";


