package Metasystem::Table;

#
# Metasystem Build System
# Helper for printing formatted tables
#

use strict;


#---------------------------------------------
# Constructor 
#---------------------------------------------

sub new($)
	{
	my ($self) = @_;

	$self = 
		{
		data		=> [ ],
		header		=> undef,
		caption		=> undef,
		padding		=> 2
		};

	bless $self;
	return $self;
	}


#---------------------------------------------
# Modifiers
#---------------------------------------------

sub AppendRow($$)
	{
	my ($self, $rowRef) = @_;
	my @row = @$rowRef;
	push @{$self->{data}}, \@row;
	}


sub SetHeader($$)
	{
	my ($self, $rowRef) = @_;
	my @row = @$rowRef;
	$self->{header} = \@row;
	}


sub SetCaption($$)
	{
	my ($self, $caption) = @_;
	$self->{caption} = $caption;
	}


sub SetPadding($$)
	{
	my ($self, $padding) = @_;
	$self->{padding} = $padding;
	}


#---------------------------------------------
# Accessors
#---------------------------------------------

sub ToString($)
	{
	my ($self) = @_;
	my $columnWidths = $self->CalculateColumnWidths();

	my $format;
	foreach my $width (@$columnWidths)
		{
		$format .= "%-" . ($width + $self->{padding}) . 's';
		}

	my $string;
	my $totalWidth = 0;

	# Build a horizontal rule
	my $rule;
	for(my $i=0; $i<@$columnWidths; ++$i)
		{
		my $width = $columnWidths->[$i];
		$rule .= '-' x $width;
		$rule .= '-' x $self->{padding} unless $i+1 == @$columnWidths;

		$totalWidth += ($width + $self->{padding});
		}
	$rule .= "\n";
	
	$string .= $rule;

	# Print column headings
	if(defined $self->{header})
		{
		$string .= sprintf "$format\n", @{$self->{header}};
		$string .= $rule;
		}

	# Print data
	foreach my $row (@{$self->{data}})
		{
		$string .= sprintf "$format\n", @$row;
		}	

	$string .= $rule;

	# Print caption
	if(defined $self->{caption})
		{
		my $pos = 0;
		while($pos < length($self->{caption}))
			{
			$string .= substr($self->{caption}, $pos, $totalWidth) . "\n";
			$pos += $totalWidth;
			}
	
		$string .= $rule;
		}

	return $string;
	}


#---------------------------------------------
# Private helpers
#---------------------------------------------

sub CalculateColumnWidths($)
	{
	my ($self) = @_;
	my @widths;

	my @rows;
	push @rows, $self->{header} if defined $self->{header};
	foreach my $row(@{$self->{data}})
		{
		push @rows, $row;
		}

	foreach my $row (@rows)
		{
		for(my $i=0; $i<@$row; ++$i)
			{
			my $length = length($row->[$i]);
			my $width = $widths[$i];
			if(!$width or ($length > $width))
				{
				$widths[$i] = $length;
				}
			}
		}

	return \@widths;
	}




1;
