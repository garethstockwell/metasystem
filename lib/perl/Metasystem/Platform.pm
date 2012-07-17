package Metasystem::Platform;

#
# Abstraction layer for platform-dependent code.
# This is intended to make it easier to port the system to different
# platforms if required.
#

use strict;
use Metasystem::Utils();

#------------------------------------------------------------------------------
# Public API
#------------------------------------------------------------------------------

# Static factory function which implements singleton pattern
sub Instance()
	{
	# Lazy initialization
	my $instance = Metasystem::Utils::GetGlobal('Metasystem_PLATFORM');
	unless(defined $instance)
		{
		$instance = Metasystem::Platform::Create();
		Metasystem::Utils::SetGlobal('Metasystem_PLATFORM', $instance);	
		}
	return $instance;
	}


#------------------------------------------------------------------------------
# Public API
#------------------------------------------------------------------------------

sub HostName()
	{
	my $hostname = `hostname`;
	chomp $hostname;
	return $hostname;
	}


# Returns name of platform
sub Name
	{
	throw Metasystem::Exception::Logic("Virtual function not implemented");
	}


# Create a new process, and detach it from the parent.  This
# means that, even after the parent dies, the process will
# continue running in the background.
sub ForkDetach
	{
	throw Metasystem::Exception::Logic("Virtual function not implemented");
	}
	
	
# Arguments: 
#	1. PID
sub KillProcess
	{
	throw Metasystem::Exception::Logic("Virtual function not implemented");
	}


# Arguments: 
#	1. semaphore name
# Returns:
#	semaphore object, derived from Metasystem::Platform::Semaphore
# If the semaphore does not exist, it is created.
sub OpenSemaphore($$)
	{
	throw Metasystem::Exception::Logic("Virtual function not implemented");
	}
	
	
# Arguments:
#	1. mutex name
# Returns:
#	mutex object, derived from Metasystem::Platform::Mutex
# Throws exception if mutex already exists.
sub CreateMutex($$)
	{
	throw Metasystem::Exception::Logic("Virtual function not implemented");
	}
	
	
# Arguments:
#	1. mutex name
# Returns:
#	mutex object, derived from Metasystem::Platform::Mutex
# If the mutex does not exist, it is created.
sub OpenMutex($$)
	{
	throw Metasystem::Exception::Logic("Virtual function not implemented");
	}
	
	
# Arguments:
#	1. mutex name
sub DestroyMutex($$)
	{
	throw Metasystem::Exception::Logic("Virtual function not implemented");
	}



# Arguments:
#	1. link path
#	2. target path
sub CreateSymbolicLink($$$)
	{	
	my ($self, $link, $target) = @_;
	
	if(-e $link)
		{
		throw Metasystem::Exception::IO("Link '$link' already exists");
		}
	
	if(-e $target)
		{
		if(-d $target)
			{
			$self->DoCreateSymbolicLink($link, $target);
			}
		else
			{
			throw Metasystem::Exception::IO("Symbolic link for non-director target '$target' cannot be created");
			}
		}
	else
		{
		throw Metasystem::Exception::IO("Symbolic link target '$target' not found");
		}
	}
	

# Arguments:
#	1. link path
# Returns:
#	target path, if the argument is a link, otherwise undef
sub SymbolicLinkTarget($$)
	{
	my ($self, $link) = @_;
		
	if(-e $link)
		{
		return $self->DoSymbolicLinkTarget($link);
		}
	else
		{
		throw Metasystem::Exception::IO("Link '$link' not found");	
		}
	}
	
	
sub IsSymbolicLink($$)
	{
	my ($self, $link) = @_;
	eval { $self->SymbolicLinkTarget($link) };
	return $@ ? undef : 1;
	}
	
	
# Arguments:
#	1. link path
sub RemoveSymbolicLink($$)
	{
	my ($self, $link) = @_;
	
	if(-e $link)
		{
		$self->DoRemoveSymbolicLink($link);
		}
	else
		{
		throw Metasystem::Exception::IO("Link '$link' not found");	
		}
	}


#------------------------------------------------------------------------------
# Pure virtual functions
#------------------------------------------------------------------------------

sub DoCreateSymbolicLink($$$)
	{		
	throw Metasystem::Exception::Logic("Virtual function not implemented");	
	}
	
	
sub DoSymbolicLinkTarget($$)
	{		
	throw Metasystem::Exception::Logic("Virtual function not implemented");	
	}
	
	
sub DoRemoveSymbolicLink($$)
	{		
	throw Metasystem::Exception::Logic("Virtual function not implemented");	
	}
	

#------------------------------------------------------------------------------
# Private functions
#------------------------------------------------------------------------------

sub Create
	{
	my $PLATFORM;

	# Load the implementation required for the current platform
	
	my $platform = undef;

	if($^O =~ /win32/i)
		{
		$platform = 'Win32';
		}
	elsif($^O eq 'linux')
		{
		$platform = 'Unix';
		}

	throw Metasystem::Exception("Platform '$^O' is not supported") unless defined $platform;

	my $package = "Metasystem/Platform/$platform.pm";
	require $package;

	my $class = "Metasystem::Platform::$platform";
	return $class->new();
	}



#------------------------------------------------------------------------------
# Required at the end of each Perl module
#------------------------------------------------------------------------------

1;
