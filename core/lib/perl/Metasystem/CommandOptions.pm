package Metasystem::CommandOptions;

#
# This class implements a command line parser. 
#


use strict;
use Getopt::Long();

use Metasystem::Exception();
use Metasystem::Options::Command();
use Metasystem::Options::CommandGroup();
use Metasystem::Options::OptionList();


#---------------------------------------------
# Constructor 
#---------------------------------------------

sub new($$)
	{
	my ($self, $title) = @_;

	$self = 
		{
		title				=> $title,
		executable			=> undef,

		# Description of valid command line syntax
		commandGroups		=> [ ],
		ungroupedCommands	=> new Metasystem::Options::CommandGroup,
		globalOptions		=> new Metasystem::Options::OptionList,

		# Input from user
		commandLineOptions	=> undef,	# Raw, unprocessed input
		command				=> undef,
		options				=> { },		# Provided on command line
		arguments			=> [ ]		# Provided on command line
		};

	bless $self;
	
	$self->{globalOptions}->AddFlag('help', 'Print usage message and exit');

	return $self;
	}


#---------------------------------------------
# Modifiers
#---------------------------------------------

# Takes an Metasystem::Options::Command object
sub AddCommand($$)
	{
	my ($self, $commandObj) = @_;

	my $command;

	if(UNIVERSAL::isa($commandObj, 'Metasystem::Options::Command'))
		{
		foreach my $option (@{$commandObj->GetOptions()})
			{
			throw Metasystem::Build::Exception::IO("Global option or flag '$option' already exists")
				if($self->{globalOptions}->OptionOrFlagExists($option));
			}

		foreach my $flag (@{$commandObj->GetFlags()})
			{
			throw Metasystem::Build::Exception::IO("Global option or flag '$flag' already exists")
				if($self->{globalOptions}->OptionOrFlagExists($flag));
			}

		$command = $commandObj->GetCommand();
		}
	else
		{
		$command = $commandObj;
		}

	throw Metasystem::Exception::IO("Command '$command' already exists")
		if($self->CommandExists($command));

	unless(UNIVERSAL::isa($commandObj, 'Metasystem::Options::Command'))
		{
		$commandObj = new Metasystem::Options::Command($commandObj);
		}

	$self->{ungroupedCommands}->AddCommand($commandObj);	

	return $commandObj;
	}


# Takes an Metasystem::Options::CommandGroup object
sub AddCommandGroup($$)
	{
	my ($self, $commandGroup) = @_;
	my $title = $commandGroup->GetTitle();
	throw Metasystem::Build::Exception::IO("Command group '$title' already exists")
		if($self->CommandGroupExists($title));

	push @{$self->{commandGroups}}, $commandGroup;
	return $commandGroup;
	}


# Add a global option
# Arguments:
#	1. option name
#	2. option type (GetOpt format)
#	3. description
sub AddGlobalOption($$$$)
	{
	my ($self, $option, $type, $description) = @_;

	throw Metasystem::Build::Exception::IO("Option '$option' already exists")
		if($self->OptionOrFlagExists($option));

	$self->{globalOptions}->AddOption($option, $type, $description);
	}


# Add a global option
# Arguments:
#	1. option name
#	2. description
sub AddGlobalFlag($$$)
	{
	my ($self, $flag, $description) = @_;

	throw Metasystem::Build::Exception::IO("Option or flag '$flag' already exists")
		if($self->OptionOrFlagExists($flag));

	$self->{globalOptions}->AddFlag($flag, $description);
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


sub GetCommandObject($$)
	{
	my ($self, $command) = @_;

	foreach my $commandObj (@{$self->{ungroupedCommands}->GetCommands()})
		{
		return $commandObj if $commandObj->GetCommand() eq $command;
		}

	foreach my $commandGroup (@{$self->{commandGroups}})
		{
		foreach my $commandObj (@{$commandGroup->GetCommands()})
			{
			return $commandObj if $commandObj->GetCommand() eq $command;
			}
		}
	
	throw Metasystem::Exception::Logic("Command object '$command' not found");
	}


#---------------------------------------------
# Accessors
#---------------------------------------------

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


# Returns command (first argument)
sub GetCommand($)
	{
	my ($self) = @_;
	return $self->{command};
	}


# Returns a reference to a hash containing flags and options
# which were specified on the command line
sub GetOptions($)
	{
	my ($self) = @_;
	my %options;
	foreach my $option (keys %{$self->{options}})
		{
		if($self->OptionIsValid($option))
			{
			$options{$option} = $self->{options}->{$option};
			}	
		}
	return \%options;
	}


sub GetFlags($)
	{
	my ($self) = @_;
	my %flags;
	foreach my $flag (keys %{$self->{options}})
		{
		if($self->FlagIsValid($flag))
			{
			$flags{$flag} = $self->{options}->{$flag};
			}	
		}
	return \%flags;
	}


# Returns a reference to the array of arguments 
# which was specified on the command line
sub GetArguments($)
	{
	my ($self) = @_;
	return $self->{arguments};
	}


# Return a usage string
sub Usage($)
	{
	my ($self) = @_;

	my $usage = $self->{title} . "\n\n";

	$usage .= "Usage:\n  " . $self->GetExecutable(). " [command] [arguments] <options>\n\nCommands:\n";

	# Compute indenting
	my $maxCommandLength = $self->MaxCommandLength();
	my $maxCommandOptionLength = $self->MaxCommandOptionLength();
	
	# Process commands
	foreach my $commandGroup (@{$self->{commandGroups}})
		{
		$usage .= $self->CommandGroupUsage($commandGroup, $maxCommandLength, $maxCommandOptionLength);
		}
	$usage .= $self->CommandGroupUsage($self->{ungroupedCommands}, $maxCommandLength, $maxCommandOptionLength);
	
	# Process global options
	my $maxGlobalOptionLength = MaxOptionListOptionLength($self->{globalOptions});
	$usage .= "\n" . $self->OptionsUsage("Global options", $self->{globalOptions}, 0, $maxGlobalOptionLength);
	
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

	$string .= Metasystem::Build::Utils::FormatKeyValue('Command', $self->GetCommand()) . "\n"; 

	my $arguments = "@{$self->GetArguments()}";
	$string .= Metasystem::Build::Utils::FormatKeyValue('Arguments', $arguments) . "\n"; 

	my $options = $self->GetOptions();
	foreach my $option (keys %$options)
		{
		$string .= Metasystem::Build::Utils::FormatKeyValue("Option '$option'", $options->{$option}) . "\n"; 
		}

	my $flags = $self->GetFlags();
	foreach my $flag (keys %$flags)
		{
		my $value = (defined $self->{options}->{$flag}) ? 'true' : 'false';
		$string .= Metasystem::Build::Utils::FormatKeyValue("Flag '$flag'", $value) . "\n"; 
		}

	
	return $string;
	}


#---------------------------------------------
# Private member functions
#---------------------------------------------

sub DoParseCommandLine($)
	{
	my ($self) = @_;

	$self->{executable} = $0;
	$self->{commandLineOptions} = "@ARGV";

	my %getOptHash;

	foreach my $commandGroup(@{$self->{commandGroups}})
		{
		foreach my $command (@{$commandGroup->GetCommands()})
			{
			$self->AddOptionsToHash($command, \%getOptHash);
			}
		}

	foreach my $command (@{$self->{ungroupedCommands}->GetCommands()})
		{
		$self->AddOptionsToHash($command, \%getOptHash);
		}

	$self->AddOptionsToHash($self->{globalOptions}, \%getOptHash);

	Getopt::Long::GetOptions(%getOptHash);

	if(@ARGV)
		{
		my $command = shift @ARGV;
		$self->{command} = $command;

		my $commandObj = $self->GetCommandObject($command);
		my $commandArguments = $commandObj->GetArguments();
		my $commandOptions = $commandObj->GetOptions();

		if(@ARGV < @$commandArguments)
			{
			throw Metasystem::Exception::IO("Insufficient arguments for command '$command'");
			}

		if(@ARGV > @$commandArguments)
			{
			print "\nWarning: the following extra arguments will be ignored:\n\t";
			for(my $i=@$commandArguments; $i<@ARGV; ++$i)
				{
				print "$ARGV[$i] ";
				} 
			print "\n\n";
			}

		$self->{arguments} = \@ARGV;
		}
	else
		{
		throw Metasystem::Exception::IO("No command specified") 
			unless (@{$self->{commandGroups}} + @{$self->{ungroupedCommands}->GetCommands()}) == 0;
		}

	}


sub OptionIsValid($$)
	{
	my ($self, $option) = @_;
	return 1 if $self->{globalOptions}->OptionExists($option);
	return $self->GetActiveCommandObject()->OptionExists($option);
	}


sub FlagIsValid($$)
	{
	my ($self, $option) = @_;
	return 1 if $self->{globalOptions}->FlagExists($option);
	return $self->GetActiveCommandObject()->FlagExists($option);
	}


sub AddOptionsToHash($$$)
	{
	my ($self, $optionList, $hash) = @_;

	foreach my $option (@{$optionList->GetOptions()})
		{
		if(defined $self->{options}->{$option})
			{
			throw Metasystem::Exception::IO("Option or flag '$option' is specified more than once");
			}

		my $type = $optionList->GetOptionType($option);
		my $getOptString = "$option=$type";
		$hash->{$getOptString} = \$self->{options}->{$option};
		}

	foreach my $flag (@{$optionList->GetFlags()})
		{
		if(defined $self->{options}->{$flag})
			{
			throw Metasystem::Exception::IO("Option or flag '$flag' is specified more than once");
			}

		my $getOptString = "$flag!";
		$hash->{$getOptString} = \$self->{options}->{$flag};
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


sub CommandGroupUsage($$$$)
	{
	my ($self, $commandGroup, $maxCommandLength, $maxCommandOptionLength) = @_;
	my $usage = '';

	my $title = $commandGroup->GetTitle();
	my $commands = $commandGroup->GetCommands();

	my $indent = 2;
	if(defined $title)
		{
		$usage .= "\n  $title:\n";
		$indent += 2;
		}

	my $previousOptions = undef;
	foreach my $commandObj (@$commands)
		{
		my $command		= $commandObj->GetCommand();
		my $arguments	= $commandObj->GetArguments();
		my $options		= $commandObj->GetOptions();
	
		$usage .= "\n" if (@$options or $previousOptions);
		$usage .= (' ' x $indent) . $command . (' ' x ($maxCommandLength + 5 - length($command)));

		foreach my $argument (@$arguments)
			{
			$usage .= "[$argument] ";
			}

		$usage .= "\n";
		$usage .= $self->OptionsUsage("Options", $commandObj, $indent+2, $maxCommandOptionLength);
		$previousOptions = undef;
		$previousOptions = 1 if @$options;
		}

	return $usage;
	}


sub OptionsUsage($$$$$)
	{
	my ($self, $title, $optionList, $indent, $maxOptionLength) = @_;

	my $usage = '';

	if(@{$optionList->GetOptions()} or @{$optionList->GetFlags()})
		{
		$usage .= (' ' x $indent) . "$title:\n";
		
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


sub CommandExists($$)
	{
	my ($self, $command) = @_;
	foreach my $commandGroup (@{$self->{commandGroups}})
		{
		return 1 if $commandGroup->CommandExists($command);
		}

	return $self->{ungroupedCommands}->CommandExists($command);	
	}


sub OptionExists($$)
	{
	my ($self, $option) = @_;
	foreach my $commandGroup (@{$self->{commandGroups}})
		{
		return 1 if $commandGroup->OptionExists($option);
		}

	return 1 if $self->{ungroupedCommands}->OptionExists($option);	

	return $self->{globalOptions}->OptionExists($option);
	}


sub FlagExists($$)
	{
	my ($self, $flag) = @_;
	foreach my $commandGroup (@{$self->{commandGroups}})
		{
		return 1 if $commandGroup->FlagExists($flag);
		}

	return 1 if $self->{ungroupedCommands}->FlagExists($flag);	

	return $self->{globalOptions}->FlagExists($flag);
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


sub CommandGroupExists($$)
	{
	my ($self, $title) = @_;
	foreach my $commandGroup (@{$self->{commandGroups}})
		{
		if($title eq $commandGroup->GetTitle())
			{
			return 1; 
			}
		}

	return undef;
	}


sub GetActiveCommandObject($)
	{
	my ($self) = @_;

	throw Metasystem::Exception::Logic("Command is undefined")
		unless defined $self->{command};

	return $self->GetCommandObject($self->{command});
	}


sub MaxCommandLength($)
	{
	my ($self) = @_;
	
	my $maxLength = 0;

	foreach my $commandObj (@{$self->{ungroupedCommands}->GetCommands()})
		{
		my $command = $commandObj->GetCommand();
		$maxLength = length($command) if length($command) > $maxLength;
		}

	foreach my $commandGroup (@{$self->{commandGroups}})
		{
		foreach my $commandObj (@{$commandGroup->GetCommands()})
			{
			my $command = $commandObj->GetCommand();
			$maxLength = length($command) if length($command) > $maxLength;
			}
		}

	return $maxLength;
	}


sub MaxCommandOptionLength($)
	{
	my ($self) = @_;
	
	my $maxLength = 0;

	foreach my $commandObj (@{$self->{ungroupedCommands}->GetCommands()})
		{
		my $length = MaxOptionListOptionLength($commandObj);
		$maxLength = $length if $length > $maxLength;	
		}

	foreach my $commandGroup (@{$self->{commandGroups}})
		{
		foreach my $commandObj (@{$commandGroup->GetCommands()})
			{
			my $length = MaxOptionListOptionLength($commandObj);
			$maxLength = $length if $length > $maxLength;	
			}
		}

	return $maxLength;
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
