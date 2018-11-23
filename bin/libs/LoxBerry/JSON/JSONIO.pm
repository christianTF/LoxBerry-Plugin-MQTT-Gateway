#!/usr/bin/perl
use JSON;
use File::Copy;
use warnings;
use strict;

package LoxBerry::JSON::JSONIO;

our $DEBUG;
our $DUMP = 0;

if ($DEBUG) {
	print STDERR "JSONIO: Developer warning - DEBUG mode is enabled in module file\n" if ($DEBUG);
}

sub new 
{
	print STDERR "JSONIO->new: Called\n" if ($DEBUG);

	my $class = shift;
	my $self = {};
	bless $self, $class;
	return $self;
}

sub open
{
	print STDERR "JSONIO->open: Called\n" if ($DEBUG);
	
	my $self = shift;
	
	if (@_ % 2) {
		print STDERR "JSONIO->open: ERROR Illegal parameter list has odd number of values\n" if ($DEBUG);
		Carp::croak "Illegal parameter list has odd number of values\n" . join("\n", @_) . "\n";
	}
	
	my %params = @_;
	
	$self->{filename} = $params{filename};
	$self->{writeonclose} = $params{writeonclose};
	$self->{readonly} = $params{readonly};
	

	print STDERR "JSONIO->open: filename is $self->{filename}\n" if ($DEBUG);
	print STDERR "JSONIO->open: writeonclose is ", $self->{writeonclose} ? "ENABLED" : "DISABLED", "\n" if ($DEBUG);
	
	if (! -e $self->{filename}) {
		print STDERR "JSONIO->open: WARNING $self->{filename} does not exist - write will create it\n" if ($DEBUG);
		my $objref = undef;
		$self->{createfile} = 1;
		$self->{jsoncontent} = "";
		$self->{jsonobj} = JSON::from_json('{}');
		$self->dump($self->{jsonobj}, "Empty object") if ($DUMP);
		return $self->{jsonobj};
	}
	
	print STDERR "JSONIO->open: Reading file $self->{filename}\n" if ($DEBUG);
	CORE::open my $fh, '<', $self->{filename} or do { 
		print STDERR "JSONIO->open: ERROR Can't open $self->{filename} -> returning undef : $!\n" if ($DEBUG);
		return undef; 
	};
	
	local $/;
	$self->{jsoncontent} = <$fh>;
	close $fh;

	print STDERR "JSONIO->open: Check if file has content\n" if ($DEBUG);

	# Check for content
	if (!$self->{jsoncontent}) {
		print STDERR "JSONIO->open: ERROR file seems to be empty -> Returning undef\n" if ($DEBUG);
		return undef;
	}
	
	print STDERR "JSONIO->open: Convert to json and return json object\n" if ($DEBUG);
	eval {
		$self->{jsonobj} = JSON::from_json($self->{jsoncontent});
	};
	if ($@) {
		print STDERR "JSONIO->open: ERROR parsing JSON file - Returning undef $@\n" if ($DEBUG);
		return undef;
	};
	$self->dump($self->{jsonobj}, "Loaded object") if ($DUMP);
	return $self->{jsonobj};
	
}
	
sub write
{
	print STDERR "JSONIO->write: Called\n" if ($DEBUG);
	my $self = shift;
	
	if ($self->{readonly}) {
		print STDERR "JSONIO->write: Opened with READONLY - Leaving write\n" if ($DEBUG);
		return;		
	}
	
	print STDERR "No jsonobj\n" if (! defined $self->{jsonobj});
	
	my $jsoncontent_new;
	eval {
		$jsoncontent_new = JSON->new->pretty->canonical(1)->encode($self->{jsonobj});
		}; 
	if ($@) {
		print STDERR "JSONIO->write: JSON Encoder sent an error\n$@" if ($DEBUG);
		return;
	}
		
	# Compare if json was changed
	if ($jsoncontent_new eq $self->{jsoncontent}) {
		print STDERR "JSONIO->write: JSON are equal - nothing to do\n" if ($DEBUG);
		return;
	}
	
	print STDERR "JSONIO->write: JSON has changed - write to $self->{filename}\n" if ($DEBUG);
	
	CORE::open(my $fh, '>', $self->{filename} . ".tmp") or print STDERR "Error opening file: $!@\n";
	print $fh $jsoncontent_new;
	close($fh);
	rename $self->{filename}, $self->{filename} . ".bkp";
	rename $self->{filename} . ".tmp", $self->{filename};
	$self->{jsoncontent} = $jsoncontent_new;
	
}

sub filename
{
	my $self = shift;
	return $self->{filename};
}

sub find
{
	my $self = shift;
		
	my ($obj, $evalexpr) = @_;
	
	my @result;
	
	$self->dump($obj, "Find in object (datatype " . ref($obj) . ")") if ($DUMP);
		
	print STDERR "JSONIO->find: Condition: $evalexpr\n" if ($DEBUG);
	
	# ARRAY handling
	if (ref($obj) eq 'ARRAY')
	{
		foreach (0 ... $#{$obj}) {
			my $key = $_;
			$_ = ${$obj}[$key];
			if ( eval "$evalexpr" ) {
				push @result, $key;
			}
		}
	} 
	# HASH handling
	elsif (ref($obj) eq 'HASH') {
		foreach (keys %{$obj}) {
			my $key = $_;
			$_ = $obj->{$key};
			if ( eval "$evalexpr" ) {
				push @result, $key;
			}
		}
	}
	print STDERR "JSONIO->find: Found " . scalar @result . " elements\n" if ($DEBUG);
	return @result;

}

sub dump
{
	my $self = shift;
	my ($obj, $comment) = @_;

	require Data::Dumper;
	$comment = "" if (!$comment);
	print STDERR "DUMP $comment\n";
	print STDERR Data::Dumper::Dumper($obj);
	
}

sub DESTROY
{
	my $self = shift;
	print STDERR "JSONIO->DESTROY: Called\n" if ($DEBUG);
	
	if (! defined $self->{jsonobj} or ! defined $self->{filename}) {
		print STDERR "JSONIO->DESTROY: Object seems not to be correctly initialized - doing nothing\n" if ($DEBUG);
		return;
	}	
	if ($self->{writeonclose}) {
		print STDERR "JSONIO->DESTROY: writeonclose is enabled, calling write\n" if ($DEBUG);
		$self->write();
	} else {
		print STDERR "JSONIO->DESTROY: Do nothing\n" if ($DEBUG);
	}
}

#####################################################
# Finally 1; ########################################
#####################################################
1;
