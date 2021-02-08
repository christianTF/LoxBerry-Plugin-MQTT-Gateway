#!/usr/bin/perl
use FindBin qw($Bin);
use lib "$Bin/../libs";
use PIDController;

my $pid = new PIDController( P => 1.2, I => 1, D => 0.001 );
$pid->{setPoint} = 1;
while(1) {
	$input = int(rand()*100);
	print "Input: $input Result: " . $pid->update($input) . " setPoint: ".$pid->{setPoint}."\n";
	sleep 2;
}