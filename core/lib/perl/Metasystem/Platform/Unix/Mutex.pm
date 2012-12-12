package Metasystem::Platform::Unix::Mutex;

#
# Unix implementation of Metasystem::Platform::Mutex
# Implemented using named Sys V semaphores
#

use strict;

use Metasystem::Platform::Mutex();
our @ISA = qw(Metasystem::Platform::Mutex);

use Metasystem::Exception();
use Digest::MD5 qw(md5_hex);


#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

# Flags
my $IPC_CREAT	= 0001000;	# Create if key does not exist
my $IPC_EXCL	= 0002000;	# Fail if ky exists
my $IPC_NOWAIT	= 0004000;	# Return error on wait
my $SEM_UNDO	= 0100000;	# Release if process ends

# Operations
my $IPC_RMID	= 0000000;	# Remove resource
my $IPC_SET		= 0000001;	# Set ipc_perm options
my $IPC_STAT	= 0000002;	# Get ipc_perm options


#------------------------------------------------------------------------------
# Public API
#------------------------------------------------------------------------------

sub Create($)
	{
	my ($name) = @_;
	Metasystem::XREF::Utils::LogDebug("Unix::Mutex::Create $name");
	return new Metasystem::Platform::Unix::Mutex($name, $IPC_CREAT|$IPC_EXCL);
	}
	
	
sub Open($)
	{
	my ($name) = @_;
	Metasystem::XREF::Utils::LogDebug("Unix::Mutex::Open $name");
	return new Metasystem::Platform::Unix::Mutex($name, 0);
	}
	
	
sub Destroy($)
	{
	my ($name) = @_;
	Metasystem::XREF::Utils::LogDebug("Unix::Mutex::Destroy $name");
	eval
		{
		my $mutex = Open($name);
		$mutex->DoDestroy();
		};
	}


sub GetName($)
	{
	my ($self) = @_;
	return $self->{name};
	}


sub Wait
	{
	my ($self, $timeout) = @_;
	
	Metasystem::XREF::Utils::LogDebug("Unix::Mutex::Wait " . $self->{name} . " $timeout");

	my $semNum = 0;		# First semaphore in the list
	my $semFlag = $IPC_NOWAIT;

	# Wait until semaphore is zero
	my $semOp = 0;
	my $waitOpString = pack('sss', $semNum, $semOp, $semFlag);

	# Increase count by one
	$semOp = $IPC_SET;
	$semFlag = $SEM_UNDO;
	
	if($timeout == 0)
		{
		$semFlag = $IPC_NOWAIT | $SEM_UNDO;
		}
		
	my $incOpString = pack('sss', $semNum, $semOp, $semFlag);

	my $err = semop($self->{'semaphore'}, $waitOpString . $incOpString);
	if($err != 1 and $err != 0)	
		{
		throw Metasystem::Exception("Wait failed");
		}
		
	$self->{held} = 1;
	}


sub Release($)
	{
	my ($self) = @_;

	Metasystem::XREF::Utils::LogDebug("Unix::Mutex::Release " . $self->{name});

	my $semNum = 0;		# First semaphore in the list
	my $semFlag = 0;

	my $semOp = -1;
	my $opString = pack('sss', $semNum, $semOp, $semFlag);
	
	my $err = semop($self->{'semaphore'}, $opString);
	if($err != 1 and $err != 0)
		{
		throw Metasystem::Exception("Release failed");
		}	
		
	$self->{held} = undef;
	}


#------------------------------------------------------------------------------
# Private functions
#------------------------------------------------------------------------------

# Objects of this class are created by Metasystem::Platform::OpenMutex()
sub new
	{
	my ($class, $name, $mask) = @_;

	my $self = 
		{
		name 		=> $name,
		semaphore	=> undef,
		held		=> undef
		};

	bless $self, $class;

	my $key = Key($name);
	
	Metasystem::XREF::Utils::LogDebug("Unix::Mutex::new $name key $key mask $mask");

	$self->{semaphore} = semget($key, 1, 0644|$mask);

	unless(defined $self->{semaphore})
		{
		undef $self;
		throw Metasystem::Exception("Failed to open/create Sys V semaphore '$name'");
		}

	return $self;
	}
	
	
sub Key($)	
	{
	my ($name) = @_;
	# Hash the name to generate a numeric key, required by semget
	# We have to throw away all but 8 hex digits - clearly this 
	# increases the risk of collision but it still gives us a hash space
	# of 2^32 values.

	my $hexKey = md5_hex($name);
	my $key = hex(substr($hexKey, 0, 8));
	
	return $key;
	}
	

sub DESTROY
	{
	my ($self) = @_;
	my $name = $self->{name};
	Metasystem::XREF::Utils::LogDebug("Unix::Mutex::DESTROY $name");	
	
	if($self->{held})	
		{
		$self->Release();
		$self->DoDestroy();
		}
	}


sub DoDestroy($)
	{
	my ($self) = @_;
	my $name = $self->{name};
	if(my $semaphore = $self->{semaphore})
		{
		my $err = semctl($semaphore, 0, $IPC_RMID, 0);
		Metasystem::XREF::Utils::LogDebug("Unix::Mutex::DoDestroy $name $semaphore err $err");
		}
	}
	

#------------------------------------------------------------------------------
# Required at the end of each Perl module
#------------------------------------------------------------------------------

1;
