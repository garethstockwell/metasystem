package Metasystem::Platform::Unix;

#
# Unix-specific functions
#

use strict;
use Cwd;
use IO::File();

use Metasystem::Exception();
use Metasystem::Platform::Unix::Mutex();
use Metasystem::Platform::Unix::Semaphore();

use Metasystem::Platform;
our @ISA = qw(Metasystem::Platform);

my $hostname = undef;

#------------------------------------------------------------------------------
# Public API
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Implementation of pure virtual functions
#------------------------------------------------------------------------------

# Returns name of platform
sub Name
	{
	return 'Unix';
	}


sub ForkDetach
	{
	my $self = shift @_;
	
	if(my $pid = fork)
		{
		Metasystem::XREF::Utils::LogDetail("Unix::ForkDetach parent @_ PID $pid");
		}
	else
		{
		Metasystem::XREF::Utils::LogDetail("Unix::ForkDetach child @_ PID $$");
		exec(@_);
		}
	}
	
	
sub KillProcess
	{
	my ($self, $pid) = @_;
	Metasystem::Shell::ExecuteThrow("kill -9 $pid");
	}


sub OpenSemaphore($$)
	{
	my ($self, $name) = @_;
	return new Metasystem::Platform::Unix::Semaphore($name);
	}
	

sub CreateMutex($$)
	{
	my ($self, $name) = @_;
	return Metasystem::Platform::Unix::Mutex::Create($name);
	}
	

sub OpenMutex($$)
	{
	my ($self, $name) = @_;
	return Metasystem::Platform::Unix::Mutex::Open($name);
	}


sub DestroyMutex($$)
	{
	my ($self, $name) = @_;
	Metasystem::Platform::Unix::Mutex::Destroy($name);
	}


sub DoCreateSymbolicLink($$$)
	{
	my ($self, $link, $target) = @_;
	my $err = symlink($target, $link);
	unless($err == 1)
		{
		throw Metasystem::Exception::IO("Failed to create link '$link' -> '$target': $err");
		}
	}
	

sub DoSymbolicLinkTarget($$)
	{
	my ($self, $link) = @_;
	my $target = readlink($link);
	unless(defined $target)
		{
		throw Metasystem::Exception::IO("Failed to read link '$link': $!");
		}
	return $target;
	}


sub DoRemoveSymbolicLink($$)
	{
	my ($self, $link) = @_;
	my $numDeleted = unlink($link);
	unless($numDeleted == 1)
		{
		throw Metasystem::Exception::IO("Failed to remove link '$link'");
		}
	}

	
#------------------------------------------------------------------------------
# Private functions
#------------------------------------------------------------------------------

# Objects of this class are created by Metasystem::Platform::Create()
sub new
	{
	my ($self) = @_;

	$self = 
		{

		};

	bless $self;
	return $self;
	}


#------------------------------------------------------------------------------
# Required at the end of each Perl module
#------------------------------------------------------------------------------

1;
