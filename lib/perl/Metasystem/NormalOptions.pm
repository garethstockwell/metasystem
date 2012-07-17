package Metasystem::NormalOptions;

#
# Metasystem
#
# Copyright (c) 2008 Symbian Ltd.  All rights reserved.
#
# Options.pm
#

use strict;
use Getopt::Long;

use Metasystem::Exception();
use Metasystem::Options::ArgumentList();
use Metasystem::Options::OptionList();


#------------------------------------------------------------------------------
# Public functions
#------------------------------------------------------------------------------

sub new($$)
	{
	my ($self, $title) = @_;

	$self = 
		{
		title			=> $title,
		executable		=> undef,

		# Description of valid command line syntax
		arguments		=> new Metasystem::Options::ArgumentList,
		options			=> new Metasystem::Options::OptionList,

		# Input from user
		commandLineOptions	=> undef,	# Raw, unprocessed input
		inputOptions		=> { },		# Provided on command line
		inputArguments		=> [ ]		# Provided on command line
		};

	bless $self;
	
	$self->{options}->AddFlag('help', 'Print usage message and exit');

	return $self;
	}


# Add an argument
# # Arguments:
#	1. option name
#	2. description
sub AddArgument($$$$)
	{
	my ($self, $label, $description) = @_;

	$self->{arguments}->AddArgument($label, $description);
	}


# Add an option
# Arguments:
#	1. option name
#	2. option type (GetOpt format)
#	3. description
sub AddOption($$$$)
	{
	my ($self, $option, $type, $description) = @_;

	throw Metasystem::Exception::IO("Option '$option' already exists")
		if($self->OptionOrFlagExists($option));

	$self->{options}->AddOption($option, $type, $description);
	}


# Add a flag
# Arguments:
#	1. flag name
#	2. description
sub AddFlag($$$)
	{
	my ($self, $flag, $description) = @_;

	throw Metasystem::Exception::IO("Option or flag '$flag' already exists")
		if($self->OptionOrFlagExists($flag));

	$self->{options}->AddFlag($flag, $description);
	}


# Do the parsing
sub ParseCommandLine($)
	{
	my ($self) = @_;
	$self->DoParseCommandLine();

	if($self->GetFlags()->{help})
		{
		print $self->Usage();
		exit 0;
		}
	}


# Returns command line as typed in
sub GetIOOptions($)
	{
	my ($self) = @_;
	return $self->{commandLineOptions};
	}


# Returns name of executable
sub GetExecutable($)
	{
	my ($self) = @_;
	return $self->{executable};
	}


# Returns a reference to a hash containing flags and options
# which were specified on the command line
sub GetOptions($)
	{
	my ($self) = @_;
	my %options;
	foreach my $option (keys %{$self->{inputOptions}})
		{
		if($self->OptionIsValid($option))
			{
			$options{$option} = $self->{inputOptions}->{$option};
			}	
		}
	return \%options;
	}


sub GetFlags($)
	{
	my ($self) = @_;
	my %flags;
	foreach my $flag (keys %{$self->{inputOptions}})
		{
		if($self->FlagIsValid($flag))
			{
			$flags{$flag} = $self->{inputOptions}->{$flag};
			}	
		}
	return \%flags;
	}


# Returns a reference to the array of arguments 
# which was specified on the command line
sub GetArguments($)
	{
	my ($self) = @_;
	return $self->{inputArguments};
	}


# Return a usage string
sub Usage($)
	{
	my ($self) = @_;

	my $usage = $self->{title} . "\n\n";

	$usage .= "Usage:\n  " . $self->GetExecutable(). " [arguments] <options>\n";

	# Calculate max label length for pretty indentation
	my $maxLabelLength = MaxOptionListOptionLength($self->{options});
	foreach my $label (@{$self->{arguments}->GetLabels()})
		{
		$maxLabelLength = length($label) if length($label) > $maxLabelLength; 
		}

	# Process arguments
	$usage .= $self->ArgumentsUsage($maxLabelLength);

	# Process global options
	$usage .= $self->OptionsUsage("Options", $self->{options}, 0, $maxLabelLength);
	
	return $usage;
	}


sub Print($)
	{
	my ($self) = @_;

	print "Command line options:\n" . $self->ToString();
	}


sub ToString($)
	{
	my ($self) = @_;

	my $string = '';

	my $arguments = "@{$self->GetArguments()}";
	$string .= Metasystem::Utils::FormatKeyValue('Arguments', $arguments) . "\n"; 

	my $options = $self->GetOptions();
	foreach my $option (keys %$options)
		{
		$string .= Metasystem::Utils::FormatKeyValue("Option '$option'", $options->{$option}) . "\n"; 
		}

	my $flags = $self->GetFlags();
	foreach my $flag (keys %$flags)
		{
		my $value = (defined $self->{inputOptions}->{$flag}) ? 'true' : 'false';
		$string .= Metasystem::Utils::FormatKeyValue("Flag '$flag'", $value) . "\n"; 
		}

	
	return $string;
	}


#------------------------------------------------------------------------------
# Private functions
#------------------------------------------------------------------------------

sub DoParseCommandLine($)
	{
	my ($self) = @_;

	$self->{executable} = $0;
	$self->{commandLineOptions} = "@ARGV";

	my %getOptHash;

	$self->AddOptionsToHash($self->{options}, \%getOptHash);

	Getopt::Long::GetOptions(%getOptHash);

	if(scalar @ARGV < $self->{arguments}->Count())
		{
		throw Metasystem::Exception::IO("Insufficient arguments provided");	
		}

	$self->{inputArguments} = \@ARGV;
	}


sub OptionIsValid($$)
	{
	my ($self, $option) = @_;
	return 1 if $self->{options}->OptionExists($option);
	return undef;
	}


sub FlagIsValid($$)
	{
	my ($self, $option) = @_;
	return 1 if $self->{options}->FlagExists($option);
	return undef;
	}


sub AddOptionsToHash($$$)
	{
	my ($self, $optionList, $hash) = @_;

	foreach my $option (@{$optionList->GetOptions()})
		{
		if(defined $self->{inputOptions}->{$option})
			{
			throw Metasystem::Exception::IO("Option or flag '$option' is specified more than once");
			}

		my $type = $optionList->GetOptionType($option);
		my $getOptString = "$option=$type";
		$hash->{$getOptString} = \$self->{inputOptions}->{$option};
		}

	foreach my $flag (@{$optionList->GetFlags()})
		{
		if(defined $self->{inputOptions}->{$flag})
			{
			throw Metasystem::Exception::IO("Option or flag '$flag' is specified more than once");
			}

		my $getOptString = "$flag!";
		$hash->{$getOptString} = \$self->{inputOptions}->{$flag};
		}
	}


# Non-member helper function
sub CleanupTag($)
	{
	my ($tag) = @_;
	$tag =~ s/\W*$//;
	$tag =~ s/=.*$//;
	return $tag;
	}


sub ArgumentsUsage($$)
	{
	my ($self, $maxLength) = @_;

	my $usage = '';

	if($self->{arguments}->Count() > 0)
		{
		$usage .= "\nArguments:\n";
		}

	my $labels = $self->{arguments}->GetLabels();
	foreach my $label (@$labels)
		{
		my $comment = $self->{arguments}->GetArgumentDescriptionByLabel($label);
		$usage .= "  $label";				
		$usage .= (' ' x ($maxLength - length($label) + 8));
		$usage .= "$comment\n";
		}

	return $usage;
	}


sub OptionsUsage($$$$$)
	{
	my ($self, $title, $optionList, $indent, $maxOptionLength) = @_;

	my $usage = '';

	if(@{$optionList->GetOptions()} or @{$optionList->GetFlags()})
		{
		$usage .= "\n" . (' ' x $indent) . "$title:\n";
		
		foreach my $option (@{$optionList->GetOptions()})
			{
			my $comment = $optionList->GetOptionDescription($option);
			my $tag = CleanupTag($option);

			my $first = substr $tag, 0, 1;
			$usage .= (' ' x $indent) . "  -$first|--$tag";				
			$usage .= (' ' x ($maxOptionLength + 8 - (length($tag) + 5)));
			$usage .= "$comment\n";
			}

		foreach my $flag (@{$optionList->GetFlags()})
			{
			my $comment = $optionList->GetFlagDescription($flag);
			my $tag = CleanupTag($flag);

			my $first = substr $tag, 0, 1;
			$usage .= (' ' x $indent) . "  -$first|--$tag";				
			$usage .= (' ' x ($maxOptionLength + 8 - (length($tag) + 5)));
			$usage .= "$comment\n";
			}

		}

	return $usage;
	}


sub OptionExists($$)
	{
	my ($self, $option) = @_;
	return $self->{options}->OptionExists($option);
	}


sub FlagExists($$)
	{
	my ($self, $flag) = @_;
	return $self->{options}->FlagExists($flag);
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


sub MaxOptionListOptionLength($)
	{
	my ($optionsObj) = @_;
	my $maxLength = 0;	

	foreach my $option (@{$optionsObj->GetOptions()})
		{
		$maxLength = length($option) if length($option) > $maxLength;
		}

	foreach my $flag (@{$optionsObj->GetFlags()})
		{
		$maxLength = length($flag) if length($flag) > $maxLength;
		}

	return $maxLength;
	}	


1;
