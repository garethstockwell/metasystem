package Metasystem::Platform::Win32;

#
# Win32-specific functions
#

use strict;
use Cwd;
use IO::File();
use Win32();
use Win32::OLE qw(in);
use Win32::Process qw(CREATE_NO_WINDOW);

use Metasystem::Exception();
use Metasystem::Shell();
use Metasystem::Platform::Win32::Mutex();
use Metasystem::Platform::Win32::Semaphore();

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
	return 'Win32';
	}



sub ForkDetach
	{
	my $self = shift @_;
	
	my $processObj;
	my $command = "@_";

	Metasystem::XREF::Utils::LogDebug("Win32::ForkDetach @_");

	Win32::Process::Create
		(
		$processObj,
    	$^X,			# Path to Perl executable
    	$command,
   		0,
    	CREATE_NO_WINDOW, 
    	# previously, we specified DETACHED_PROCESS here. However, this caused problems when 
    	# invoking abld from the Daemon (launched here). When abld invoked make, it failed thus:
    	#
    	#	process_easy: DuplicateHandle(In) failed (e=6)
    	#
       	#	Unhandled exception filter called from program make
    	#	ExceptionCode = c0000005
    	#	ExceptionFlags = 0
    	#	ExceptionAddress = 4166e4
    	#	Access violation: read operation at address 3f
    	#
    	# It's not clear exactly why changing this flag to CREATE_NO_WINDOW causes
    	# the build then to work, but it does. Specifying CREATE_NEW_CONSOLE also
    	# works, but this results in a console window being present on the screen
    	# which could be accidentally closed, causing the daemon to be terminated.
    	cwd()
		) 
	or throw Metasystem::Exception(Win32::FormatMessage( Win32::GetLastError() ) );
	}	
	
	
sub KillProcess
	{
	my ($self, $pid) = @_;
	my $processObj;
	my $err = Win32::Process::Open($processObj, $pid, 0);
	if($err == 0)
		{
		throw Metasystem::Exception("Failed to open handle to process $pid: $err");
		}
	$processObj->Kill(-1);
	}


sub OpenSemaphore($$)
	{
	my ($self, $name) = @_;
	return new Metasystem::Platform::Win32::Semaphore($name);
	}
	

sub CreateMutex($$)
	{
	my ($self, $name) = @_;
	return Metasystem::Platform::Win32::Mutex::Create($name);
	}
	

sub OpenMutex($$)
	{
	my ($self, $name) = @_;
	return Metasystem::Platform::Win32::Mutex::Open($name);
	}
	
	
sub DestroyMutex($$)
	{
	my ($self, $name) = @_;
	# Does nothing on Win32
	}


# Symbolic link manipulation relies on junction.exe, taken from
# http://technet.microsoft.com/en-us/sysinternals/bb896768.aspx

sub DoCreateSymbolicLink($$$)
	{
	my ($self, $link, $target) = @_;
	my $command = "junction.exe $link $target";
	Metasystem::Shell::ExecuteThrow($command);
	}
	

sub DoSymbolicLinkTarget($$)
	{
	my ($self, $link) = @_;
	my $command = "junction.exe $link";

	my $result = Metasystem::Shell::ExecuteThrow($command);
		
	if($result->Stdout() =~ /Substitute Name: (.*)/)
		{
		return $1;
		}
	throw Metasystem::Exception::IO("Failed to parse junction.exe output");
	}


sub DoRemoveSymbolicLink($$)
	{
	my ($self, $link) = @_;
	my $command = "junction.exe -d $link";
	Metasystem::Shell::ExecuteThrow($command);
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
