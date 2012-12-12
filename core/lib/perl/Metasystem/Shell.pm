package Metasystem::Shell;

#
# Portable support for executing shell commands, and capturing STDOUT
# and STERR output;
#

use strict;
use IO::CaptureOutput qw(capture_exec);
use Metasystem::Exception();


#------------------------------------------------------------------------------
# Public API
#------------------------------------------------------------------------------

# Static function
sub Execute
	{
	my ($stdout, $stderr, $success, $exit_code) = capture_exec(@_);
	return new Metasystem::Shell($stdout, $stderr, $success, $exit_code);
	}
	
	
# Static function
sub ExecuteThrow
	{
	my $result = Metasystem::Shell::Execute(@_);
	
	unless($result->Success())
		{
		if($result->ExitCode() != 0)
		  {
    		my $message = sprintf
    			"Execution of '@_' failed with exit code %d:\n%s", 
    			$result->ExitCode(), $result->Stderr();
    		throw Metasystem::Exception::IO($message);
          }
		}
	
	return $result;
	}


#------------------------------------------------------------------------------
# Private functions
#------------------------------------------------------------------------------

sub new($)
	{
	my ($self, $stdout, $stderr, $success, $exit_code) = @_;

	$self = 
		{
		stdout			=> $stdout,
		stderr			=> $stderr,
		success			=> $success,
		exit_code		=> $exit_code
		};

	bless $self;
	return $self;
	}


sub Stdout($)
	{
	my ($self) = @_;
	return $self->{stdout};
	}


sub Stderr($)
	{
	my ($self) = @_;
	return $self->{stderr};
	}


sub Success($)
	{
	my ($self) = @_;
	return $self->{success};
	}


sub ExitCode($)
	{
	my ($self) = @_;
	return $self->{exit_code};
	}


1;
