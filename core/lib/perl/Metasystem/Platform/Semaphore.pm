package Metasystem::Platform::Semaphore;

#
# Abstract base class for semaphores
#

use strict;

use Metasystem::Exception();


#------------------------------------------------------------------------------
# Pure virtual functions
#------------------------------------------------------------------------------

sub Count($)
	{
	my ($self) = @_;
	throw Metasystem::Exception::Logic("Virtual function not implemented");
	}


sub GetName($)
	{
	my ($self) = @_;
	throw Metasystem::Exception::Logic("Virtual function not implemented");
	}


sub Increment($)
	{
	my ($self) = @_;
	throw Metasystem::Exception::Logic("Virtual function not implemented");
	}


sub Decrement($)
	{
	my ($self) = @_;
	throw Metasystem::Exception::Logic("Virtual function not implemented");
	}


#------------------------------------------------------------------------------
# Required at the end of each Perl module
#------------------------------------------------------------------------------

1;
