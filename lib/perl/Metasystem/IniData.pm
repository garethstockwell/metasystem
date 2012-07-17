package Metasystem::IniData;

#
# Parser for INI files
#

use strict;
use Metasystem::Exception();
use Metasystem::Utils();


#------------------------------------------------------------------------------
# Public API
#------------------------------------------------------------------------------

sub new($)
	{
	my ($self) = @_;

	$self = 
		{
		data		=> { },
		sectionNames	=> ( )
		};

	bless $self;
	return $self;
	}


sub ReadFile($$)
	{
	my ($self, $fileName) = @_;

	my $fh = Metasystem::Utils::OpenFileRead($fileName);

	my $section;
	my $sectionName;
	my $lineNumber = 0;

	while(<$fh>)
		{
		++$lineNumber;

		s/#.*//;
		s/^\s+//;
		s/\s+$//;
		next if $_ eq '';

		if(/\[(.*)\]/)
			{
			$sectionName = $1;
			unless(defined $self->{data}->{$sectionName})
				{
				$self->{data}->{$sectionName} = 
					{ 
					keyNames	=> [ ],
					data		=> { }
					};
				push @{$self->{sectionNames}}, $sectionName;
				}
			$section = $self->{data}->{$sectionName};
			}
		else
			{
			if(/(\S+)\s*=\s*(.*)/)
				{
				my $keyName = $1;
				my $value = $2;

				if($self->KeyExists($sectionName, $keyName))
					{
					throw Metasystem::Exception::IO
						(
							"INI file $fileName contains duplicate values for key $keyName "
						.	"in section $sectionName (line $lineNumber)"
						);
					}

				$section->{data}->{$keyName} = $value;
				push @{$section->{keyNames}}, $keyName;
				}
			else
				{
				throw Metasystem::Exception::IO
					(
					"Unrecognised value at line $lineNumber of INI file $fileName"
					);
				}
			}
		}
	}


sub WriteFile($$)
	{
	my ($self, $fileName) = @_;

	my $fh = Metasystem::Utils::OpenFileWrite($fileName);

	my $sectionNames = $self->SectionNames();
	foreach my $sectionName (@$sectionNames)
		{
		print $fh "[$sectionName]\n";

		my $keyNames = $self->KeyNames($sectionName);
		foreach my $key (@$keyNames)
			{
			my $value = $self->Value($sectionName, $key);
			print $fh "$key = $value\n";
			}
		}
	}


# Returns reference to array of strings
sub SectionNames($)
	{
	my ($self) = @_;
	return $self->{sectionNames};
	}


sub SectionExists($$)
	{
	my ($self, $sectionName) = @_;
	foreach my $name (@{$self->SectionNames()})
		{
		return 1 if $name eq $sectionName;
		}
	return undef;
	}


# Returns reference to array of strings
sub KeyNames($$)
	{
	my ($self, $sectionName) = @_;
	unless($self->SectionExists($sectionName))
		{
		throw Metasystem::Exception("Section '$sectionName' does not exist");
		}
	return $self->{data}->{$sectionName}->{keyNames};
	}


sub KeyExists($$$)
	{
	my ($self, $sectionName, $keyName) = @_;
	my $keyNames = $self->KeyNames($sectionName);
	foreach my $name (@$keyNames)
		{
		return 1 if $name eq $keyName;
		}
	return undef;
	}


sub Value($$$)
	{
	my ($self, $sectionName, $keyName) = @_;
	unless($self->KeyExists($sectionName, $keyName))
		{
		throw Metasystem::Exception("Key '$keyName' does not exist in section '$sectionName'");
		}
	return $self->{data}->{$sectionName}->{data}->{$keyName};
	}



#------------------------------------------------------------------------------
# Private functions
#------------------------------------------------------------------------------



1;
