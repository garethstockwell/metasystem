package Metasystem::Options::OptionList;

#
# Metasystem
#
# Copyright (c) 2008 Symbian Ltd.  All rights reserved.
#
# OptionList.pm
# Encapsulates a list of options.
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
		options		=> { },
		flags		=> { }
		};

	bless $self;
	return $self;
	}


sub AddOption($$$$)
	{
	my ($self, $option, $type, $description) = @_;
	throw Metasystem::Build::Exception::IO("Option '$option' already exists")
		if defined $self->{options}->{$option};

	my $data = [$type, $description];
	$self->{options}->{$option} = $data;
	return $self;
	}


sub AddFlag($$$)
	{
	my ($self, $flag, $description) = @_;
	throw Metasystem::Build::Exception::IO("Flag '$flag' already exists")
		if defined $self->{flags}->{$flag};

	$self->{flags}->{$flag} = $description;
	return $self;
	}


# Returns a reference to an array containing option names
sub GetOptions($)
	{
	my ($self) = @_;
	my @options = keys %{$self->{options}};
	return \@options;
	}


# Returns a reference to an array containing option names
sub GetFlags($)
	{
	my ($self) = @_;
	my @flags = keys %{$self->{flags}};
	return \@flags;
	}


sub OptionExists($$)
	{
	my ($self, $option) = @_;
	if(defined $self->{options}->{$option})
		{
		return 1;
		}
	return undef;
	}


sub FlagExists($$)
	{
	my ($self, $flag) = @_;
	if(defined $self->{flags}->{$flag})
		{
		return 1;
		}
	return undef;
	}


sub OptionOrFlagExists($$)
	{
	my ($self, $optionOrFlag) = @_;
	if($self->OptionExists($optionOrFlag) or $self->FlagExists($optionOrFlag))
		{
		return 1;
		}
	return undef;
	}


sub GetOptionType($$)
	{
	my ($self, $option) = @_;
	my $data = $self->{options}->{$option};
	if(defined $data)
		{
		return $data->[0];
		}
	else
		{
		throw Metasystem::Exception::Logic("Option '$option' not found");
		}
	}


sub GetOptionDescription($$)
	{
	my ($self, $option) = @_;
	my $data = $self->{options}->{$option};
	if(defined $data)
		{
		return $data->[1];
		}
	else
		{
		throw Metasystem::Exception::Logic("Option '$option' not found");
		}
	}


sub GetFlagDescription($$)
	{
	my ($self, $flag) = @_;
	my $description = $self->{flags}->{$flag};
	if(defined $description)
		{
		return $description;
		}
	else
		{
		throw Metasystem::Exception::Logic("Flag '$flag' not found");
		}
	}



1;
