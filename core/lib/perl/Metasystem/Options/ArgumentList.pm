package Metasystem::Options::ArgumentList;

#
# Metasystem
#
# Copyright (c) 2008 Symbian Ltd.  All rights reserved.
#
# ArgumentList.pm
# Encapsulates a list of arguments.
#

use strict;
use Metasystem::Exception();


#------------------------------------------------------------------------------
# Public functions
#------------------------------------------------------------------------------

sub new($)
	{
	my ($self) = @_;

	$self = 
		{
		argumentList		=> [ ],
		argumentHash		=> { }
		};

	bless $self;
	return $self;
	}


sub AddArgument($$$$)
	{
	my ($self, $label, $description) = @_;
	throw Metasystem::Build::Exception::IO("Argument '$label' already exists")
		if defined $self->{argumentHash}->{$label};

	my $value = undef;
	my $data = [$label, $description, $value];
	push @{$self->{argumentList}}, $data;
	$self->{argumentHash}->{$label} = $data;
	return $self;
	}


sub SetValues($$)
	{
	my ($self, $values) = @_;
	for(my $i=0; $i<scalar @$values; ++$i)
		{
		$self->{argumentList}->[$i]->[2] = $values->[$i];
		}
	}


sub Count($)
	{
	my ($self) = @_;
	return scalar @{$self->{argumentList}};
	}


# Returns a reference to an array containing argument labels in order
sub GetLabels($)
	{
	my ($self) = @_;
	my @labels;
	foreach my $data (@{$self->{argumentList}})
		{
		my ($label, $description, $value) = @$data;
		push @labels, $label;
		}
	return \@labels;
	}


sub GetArgumentDescriptionByLabel($$)
	{
	my ($self, $label) = @_;
	my $data = $self->{argumentHash}->{$label};
	if(defined $data)
		{
		my ($label, $description, $value) = @$data;
		return $description;
		}
	else
		{
		throw Metasystem::Exception::Logic("Argument '$label' not found");
		}
	}


sub GetArgumentDescriptionByIndex($$)
	{
	my ($self, $index) = @_;
	if($index < scalar @{$self->{argumentList}})
		{
		my $data = $self->{argumentList}->[$index];
		my ($label, $description, $value) = @$data;
		return $description;
		}
	else
		{
		throw Metasystem::Exception::Logic("Argument index $index out of bounds");
		}
	}


sub GetArgumentValueByLabel($$)
	{
	my ($self, $label) = @_;
	my $data = $self->{argumentHash}->{$label};
	if(defined $data)
		{
		my ($label, $description, $value) = @$data;
		return $value;
		}
	else
		{
		throw Metasystem::Exception::Logic("Argument '$label' not found");
		}
	}


sub GetArgumentValueByIndex($$)
	{
	my ($self, $index) = @_;
	if($index < scalar @{$self->{argumentList}})
		{
		my $data = $self->{argumentList}->[$index];
		my ($label, $description, $value) = @$data;
		return $value;
		}
	else
		{
		throw Metasystem::Exception::Logic("Argument index $index out of bounds");
		}
	}


1;
