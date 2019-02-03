#!/usr/bin/perl


my $key = generate_hexkey(0);

print "Key: $key\n";

################################################
# Generate a key in hex string representation
# Parameter is keylength in bit
################################################
sub generate_hexkey
{

	my ($keybits) = @_;
	
	if (! $keybits or $keybits < 40) {
		$keybits = 128;
	}
	
	my $keybytes = int($keybits/8+0.5);
	# print STDERR "Keybits: $keybits Keybytes: $keybytes\n";
	my $hexstr = "";
	
	for(1...$keybytes) { 
		my $rand = int(rand(256));
		$hexstr .= sprintf('%02X', $rand);
		# print STDERR "Rand: $rand \tHEX: $hexstr\n";
	}
	
	if ( length($hexstr) < ($keybytes*2) ) {
		return undef;
	}
	return $hexstr;

}
