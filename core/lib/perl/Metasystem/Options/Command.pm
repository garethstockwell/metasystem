package Metasystem::Options::Command;

#
# Encapsulates a valid command which may be passed to an Metasystem script.
# Objects of this class are added to an Metasystem::Options object which is then
# used to parse the command line.
#

use strict;
use Metasystem::Exception();
use Metasystem::Options::OptionList();

our @ISA = qw(Metasystem::Options::OptionList);


#---------------------------------------------
# Constructor 
#---------------------------------------------

sub new
	{
	my ($class, $command) = @_;

	my $self = new Metasystem::Options::OptionList;

	$self->{command}	= $command;
	$self->{arguments}	= { };

	bless $self, $class;
	return $self;
	}


#---------------------------------------------
# Modifiers
#---------------------------------------------

sub AddArgument($$$)
	{
	my ($self, $argument, $description) = @_;
	
	throw Metasystem::Exception::IO("Argument '$argument' already exists")
		if defined $self->{arguments}->{$argument};
	
	my $count = scalar keys %{$self->{arguments}};
	my $data = [$description, $count+1];
	$self->{arguments}->{$argument} = $data;

	return $self;
	}


sub AddFlag($$$$)
	{
	my ($self, $flag, $description) = @_;

	eval
		{
		$self->Metasystem::Options::OptionList::AddFlag($flag, $description);
		};

	if($@)
		{
		throw Metasystem::Exception::IO
			("Flag '$flag' already exists for command '" . $self->GetCommand() . "'")
		}

	return $self;
	}


sub AddOption($$$$)
	{
	my ($self, $option, $type, $description) = @_;

	eval
		{
		$self->Metasystem::Options::OptionList::AddOption($option, $type, $description);
		};

	if($@)
		{
		throw Metasystem::Exception::IO
			("Option '$option' already exists for command '" . $self->GetCommand() . "'")
		}

	return $self;
	}


#---------------------------------------------
# Accessors
#---------------------------------------------

sub GetCommand($)
	{
	my ($self) = @_;
	return $self->{command};
	}


# Returns a reference to an array containing arguments
# in the order in which they were specified
sub GetArguments($)
	{
	my ($self) = @_;

	my @arguments = sort 
		{ $self->{arguments}->{$a}->[1] <=> $self->{arguments}->{$b}->[1] }
		keys %{$self->{arguments}};

	return \@arguments;
	}


sub GetArgumentDescription($$)
	{
	my ($self, $argument) = @_;
	my $data = $self->{arguments}->{$argument};
	if(defined $data)
		{
		return $data->[0];
		}
	else
		{
		throw Metasystem::Exception::Logic
			("Argument '$argument' not found for command '" . $self->{command} . "'");
		}
	}


sub GetOptionType($$)
	{
	my ($self, $option) = @_;

	my $type;

	# Call base class function
	eval
		{
		$type = $self->Metasystem::Options::OptionList::GetOptionType($option);
		};

	if($@)
		{
		throw Metasystem::Exception::Logic
			("Option '$option' not found for command '" . $self->{command} . "'");
		}

	return $type;
	}


sub GetOptionDescription($$)
	{
	my ($self, $option) = @_;

	my $description;

	# Call base class function
	eval
		{
		$description = $self->Metasystem::Options::OptionList::GetOptionDescription($option);
		};

	if($@)
		{
		throw Metasystem::Exception::Logic
			("Option '$option' not found for command '" . $self->{command} . "'");
		}

	return $description;
	}


sub GetFlagDescription($$)
	{
	my ($self, $flag) = @_;

	my $description;

	# Call base class function
	eval
		{
		$description = $self->Metasystem::Options::OptionList::GetFlagDescription($flag);
		};

	if($@)
		{
		throw Metasystem::Exception::Logic
			("Flag '$flag' not found for command '" . $self->{command} . "'");
		}

	return $description;
	}




1;
