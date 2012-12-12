package Metasystem::Platform::Unix::Semaphore;

#
# Unix implementation of Metasystem::Platform::Semaphore
#

use strict;

use Metasystem::Platform::Semaphore();
our @ISA = qw(Metasystem::Platform::Semaphore);

use Metasystem::Exception();

#------------------------------------------------------------------------------
# Static constants
#------------------------------------------------------------------------------



#------------------------------------------------------------------------------
# Public API
#------------------------------------------------------------------------------

# This class is not yet implemented.  If required, it is straightforward to
# do so using the Sys V semaphore API.  It would then make sense to implement
# Metasystem::Platform::Unix::Mutex in terms of this class.

sub Count($)
	{
	my ($self) = @_;
	throw Metasystem::Exception::Logic("Not implemented yet...");
	}


sub GetName($)
	{
	my ($self) = @_;
	return $self->{name};
	}


sub Increment($)
	{
	my ($self) = @_;
	throw Metasystem::Exception::Logic("Not implemented yet...");
	}


sub Decrement($)
	{
	my ($self) = @_;
	throw Metasystem::Exception::Logic("Not implemented yet...");
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

	Metasystem::XREF::Utils::LogDebug("Unix::Semaphore::new $name");

	return $self;
	}
	
	
sub DESTROY
	{
	my ($self) = @_;
	throw Metasystem::Exception::Logic("Not implemented yet...");
	}
	

#------------------------------------------------------------------------------
# Required at the end of each Perl module
#------------------------------------------------------------------------------

1;
