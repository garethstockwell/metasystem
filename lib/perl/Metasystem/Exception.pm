package Metasystem::Exception;

#
# This package declares a hierarchy of exception classes for use
# in the Metasystem system 
#

use Exception::Class 
	(
	Metasystem::Exception =>
		{
		description		=> 'Base'
		},

	Metasystem::Exception::Logic =>
		{
		isa 			=> 'Metasystem::Exception',
		description		=> 'Logic'
		},

	Metasystem::Exception::IO =>
		{
		isa 			=> 'Metasystem::Exception',
		description		=> 'I/O'
		},

	Metasystem::Exception::Net =>
		{
		isa 			=> 'Metasystem::Exception::IO',
		description		=> 'Network'
		},

	Metasystem::Exception::XML =>
		{
		isa 			=> 'Metasystem::Exception::IO',
		description		=> 'XML'
		},

	Metasystem::Exception::IPC =>
		{
		isa 			=> 'Metasystem::Exception',
		description		=> 'IPC'
		},

	Metasystem::Exception::IPC::Connection =>
		{
		isa 			=> 'Metasystem::Exception::IPC',
		description		=> 'IPC Connection'
		},

	Metasystem::Exception::DB =>
		{
		isa 			=> 'Metasystem::Exception',
		description		=> 'Database'
		}
	
	);



1;
