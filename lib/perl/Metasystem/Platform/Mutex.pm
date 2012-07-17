package Metasystem::Platform::Mutex;

#
# Abstract base class for semaphores
#

use strict;

use Metasystem::Exception();


#------------------------------------------------------------------------------
# Pure virtual functions
#------------------------------------------------------------------------------

sub GetName($)
	{
	my ($self) = @_;
	throw Metasystem::Exception::Logic("Virtual function not implemented");
	}


sub Wait
	{
	my ($self, $timeout) = @_;
	throw Metasystem::Exception::Logic("Virtual function not implemented");
	}


sub Release($)
	{
	my ($self) = @_;
	throw Metasystem::Exception::Logic("Virtual function not implemented");
	}
	


#------------------------------------------------------------------------------
# Required at the end of each Perl module
#------------------------------------------------------------------------------

1;
