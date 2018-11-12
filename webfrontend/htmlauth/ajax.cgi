#!/usr/bin/perl
use LoxBerry::IO;
use LoxBerry::Log;
use warnings;
use strict;

require "$lbpbindir/libs/Net/MQTT/Simple.pm";
require "$lbpbindir/libs/LoxBerry/JSON/JSONIO.pm";

my $cfgfile = "$lbpconfigdir/mqtt.json";
my $json;
my $cfg;

