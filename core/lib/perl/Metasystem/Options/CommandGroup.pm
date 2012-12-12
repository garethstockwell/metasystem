package Metasystem::Options::CommandGroup;

#
# Encapsulates a group of commands.
#

use strict;
use Metasystem::Exception();
use Metasystem::Options::Command();


#---------------------------------------------
# Constructor 
#---------------------------------------------

sub new($$)
	{
	my ($self, $title) = @_;

	$self = 
		{
		title			=> $title,
		commands		=> [ ]
		};

	bless $self;
	return $self;
	}


#---------------------------------------------
# Modifiers
#---------------------------------------------

# Takes an Metasystem::Options::Command object
sub AddCommand($$)
	{
	my ($self, $command) = @_;
	my $commandObj;
	if(UNIVERSAL::isa($command, 'Metasystem::Options::Command'))
		{
		$commandObj = $command;
		}
	else
		{
		$commandObj = Metasystem::Options::Command->new($command); 
		}
	push @{$self->{commands}}, $commandObj;	
	return $commandObj;
	}


sub GetCommandObject($$)
	{
	my ($self, $command) = @_;
	foreach my $commandObj (@{$self->{commands}})
		{
		return $commandObj if $commandObj->GetCommand() eq $command;
		}
	throw Metasystem::Exception::IO("Command '$command' not found");
	}


#---------------------------------------------
# Accessors
#---------------------------------------------

sub GetTitle($)
	{
	my ($self) = @_;
	return $self->{title};
	}


# Returns a reference to an array containing commands 
sub GetCommands($)
	{
	my ($self) = @_;
	return $self->{commands}; 
	}


sub CommandExists($$)
	{
	my ($self, $command) = @_;
	foreach my $commandObj (@{$self->GetCommands()})
		{
		if($commandObj->GetCommand() eq $command)
			{
			return 1;		
			}
		}
	return undef;
	}


sub OptionExists($$)
	{
	my ($self, $option) = @_;
	foreach my $command (@{$self->GetCommands()})
		{
		if($command->OptionExists($option))
			{
			return 1;		
			}
		}
	return undef;
	}


sub FlagExists($$)
	{
	my ($self, $flag) = @_;
	foreach my $command (@{$self->GetCommands()})
		{
		if($command->FlagExists($flag))
			{
			return 1;		
			}
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

1;
