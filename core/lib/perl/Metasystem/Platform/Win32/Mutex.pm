package Metasystem::Platform::Win32::Mutex;

#
# Win32 implementation of Metasystem::Platform::Mutex
# This is just a wrapper around Win32::Mutex
#

use strict;
use Win32::Mutex();
use Win32::WinError qw(ERROR_ALREADY_EXISTS);

use Metasystem::Platform::Mutex();
our @ISA = qw(Metasystem::Platform::Mutex);

use Metasystem::Exception();


#------------------------------------------------------------------------------
# Public API
#------------------------------------------------------------------------------

sub Create($)
	{
	my ($name) = @_;
	Metasystem::XREF::Utils::LogDebug("Win32::Mutex::Create $name");
	my $mutex = new Metasystem::Platform::Win32::Mutex($name);
	throw Metasystem::Exception("Failed to create mutex '$name'") unless $mutex->{created};
	return $mutex;
	}
	
	
sub Open($)
	{
	my ($name) = @_;
	Metasystem::XREF::Utils::LogDebug("Win32::Mutex::Open $name");
	return new Metasystem::Platform::Win32::Mutex($name);
	}


sub GetName($)
	{
	my ($self) = @_;
	return $self->{name};
	}


sub Wait
	{
	my ($self, $timeout) = @_;
	Metasystem::XREF::Utils::LogDebug("Win32::Mutex::Wait " . $self->{name} . " $timeout");
	my $err = $self->{mutex}->wait($timeout);
	if($err == 0)
		{
		if($timeout == 0)
			{
			throw Metasystem::Exception("Failed to acquire mutex");
			}
		else
			{
			throw Metasystem::Exception("Failed to acquire mutex: timed out");
			}
		}
	elsif($err != 1)
		{
		throw Metasystem::Exception("Failed to acquire mutex: error $err: $^E")
		}
	$self->{held} = 1;
	}


sub Release($)
	{
	my ($self) = @_;
	Metasystem::XREF::Utils::LogDebug("Win32::Mutex::Release " . $self->{name});
	$self->{mutex}->release();
	$self->{held} = undef;
	}


#------------------------------------------------------------------------------
# Private functions
#------------------------------------------------------------------------------

# Objects of this class are created by Metasystem::Platform::OpenMutex()
sub new
	{
	my ($class, $name) = @_;

	my $self = 
		{
		name 		=> $name,
		mutex		=> undef,
		created		=> undef,
		held		=> undef
		};

	bless $self, $class;

	Metasystem::XREF::Utils::LogDebug("Win32::Mutex::new $name");

	$self->{mutex} = Win32::Mutex->new(undef, $name);
	$self->{created} = 1 unless ($^E == ERROR_ALREADY_EXISTS); 

	return $self;
	}
	
	
sub DESTROY
	{
	my ($self) = @_;
	if($self->{held})	
		{
		$self->Release();
		}
	}	
	
	

#------------------------------------------------------------------------------
# Required at the end of each Perl module
#------------------------------------------------------------------------------

1;
