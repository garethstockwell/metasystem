package Metasystem::Platform::Win32::Semaphore;

#
# Win32 implementation of Metasystem::Platform::Semaphore
# This is just a wrapper around Win32::Mutex
#

use strict;
use Win32::Semaphore();

use Metasystem::Platform::Semaphore();
our @ISA = qw(Metasystem::Platform::Semaphore);

use Metasystem::Exception();

#------------------------------------------------------------------------------
# Static constants
#------------------------------------------------------------------------------

my $MAX_COUNT = 9999;


#------------------------------------------------------------------------------
# Public API
#------------------------------------------------------------------------------

sub Count($)
	{
	my ($self) = @_;
	my $count;
	$self->{semaphore}->release(1, $count) or die;
	$self->{semaphore}->wait();
	return $count;
	}


sub GetName($)
	{
	my ($self) = @_;
	return $self->{name};
	}


sub Increment($)
	{
	my ($self) = @_;
	
	++$self->{inc_count};
	Metasystem::XREF::Utils::LogDebug("Semaphore::Increment " . $self->{name} . " (" . $self->{inc_count}. ")");
	
	$self->{semaphore}->release(1)
		or throw Metasystem::Exception("Failed to increment semaphore '" . $self->{name} . "'");
	}


sub Decrement($)
	{
	my ($self) = @_;
	
	Metasystem::XREF::Utils::LogDebug("Semaphore::Decrement " . $self->{name} . " (" . $self->{inc_count}. ")");
	--$self->{inc_count};
	
	$self->{semaphore}->wait();
	}


#------------------------------------------------------------------------------
# Private functions
#------------------------------------------------------------------------------

# Objects of this class are created by Metasystem::Platform::OpenSemaphore()
sub new
	{
	my ($class, $name) = @_;

	my $self = 
		{
		name 		=> $name,
		semaphore	=> undef,
		inc_count	=> 0
		};

	bless $self, $class;

	Metasystem::XREF::Utils::LogDebug("Win32::Semaphore::new $name");

	$self->{semaphore} = Win32::Semaphore->new(0, $MAX_COUNT, $name);
	throw Metasystem::Exception("Failed to open semaphore '$name'") unless defined $self->{semaphore};

	return $self;
	}
	
	
sub DESTROY
	{
	my ($self) = @_;
	
	Metasystem::XREF::Utils::LogDebug("Semaphore::DESTROY " . $self->{name} . " (" . $self->{inc_count}. ")");
	
	for( ; $self->{inc_count}; --$self->{inc_count})	
		{
		
		}
	}
	

#------------------------------------------------------------------------------
# Required at the end of each Perl module
#------------------------------------------------------------------------------

1;
