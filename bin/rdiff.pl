#!/usr/bin/env perl

#
# Tool for comparing two directory trees
#
# It shows:
#	- which files/directories were added/removed
#	- which filenames changed case
#	- which files changed content
#

#----------------------------------------------------------
# Standard packages
#----------------------------------------------------------

use strict;
use File::Find;
use FileHandle;


#----------------------------------------------------------
# Algorithm::Diff
# This is a CPAN package but it has been copied inline into
# this script to improve portability
#----------------------------------------------------------

{ # Start of package Diff block

package Diff;

use integer;

# Create a hash that maps each element of $aCollection to the set of positions
# it occupies in $aCollection, restricted to the elements within the range of
# indexes specified by $start and $end.
# The fourth parameter is a subroutine reference that will be called to
# generate a string to use as a key.
# Additional parameters, if any, will be passed to this subroutine.
#
# my $hashRef = _withPositionsOfInInterval( \@array, $start, $end, $keyGen );

sub _withPositionsOfInInterval
{
	my $aCollection = shift;    # array ref
	my $start       = shift;
	my $end         = shift;
	my $keyGen      = shift;
	my %d;
	my $index;
	for ( $index = $start ; $index <= $end ; $index++ )
	{
		my $element = $aCollection->[$index];
		my $key = &$keyGen( $element, @_ );
		if ( exists( $d{$key} ) )
		{
			unshift ( @{ $d{$key} }, $index );
		}
		else
		{
			$d{$key} = [$index];
		}
	}
	return wantarray ? %d : \%d;
}

# Find the place at which aValue would normally be inserted into the array. If
# that place is already occupied by aValue, do nothing, and return undef. If
# the place does not exist (i.e., it is off the end of the array), add it to
# the end, otherwise replace the element at that point with aValue.
# It is assumed that the array's values are numeric.
# This is where the bulk (75%) of the time is spent in this module, so try to
# make it fast!

sub _replaceNextLargerWith
{
	my ( $array, $aValue, $high ) = @_;
	$high ||= $#$array;

	# off the end?
	if ( $high == -1 || $aValue > $array->[-1] )
	{
		push ( @$array, $aValue );
		return $high + 1;
	}

	# binary search for insertion point...
	my $low = 0;
	my $index;
	my $found;
	while ( $low <= $high )
	{
		$index = ( $high + $low ) / 2;

		#		$index = int(( $high + $low ) / 2);		# without 'use integer'
		$found = $array->[$index];

		if ( $aValue == $found )
		{
			return undef;
		}
		elsif ( $aValue > $found )
		{
			$low = $index + 1;
		}
		else
		{
			$high = $index - 1;
		}
	}

	# now insertion point is in $low.
	$array->[$low] = $aValue;    # overwrite next larger
	return $low;
}

# This method computes the longest common subsequence in $a and $b.

# Result is array or ref, whose contents is such that
# 	$a->[ $i ] == $b->[ $result[ $i ] ]
# foreach $i in ( 0 .. $#result ) if $result[ $i ] is defined.

# An additional argument may be passed; this is a hash or key generating
# function that should return a string that uniquely identifies the given
# element.  It should be the case that if the key is the same, the elements
# will compare the same. If this parameter is undef or missing, the key
# will be the element as a string.

# By default, comparisons will use "eq" and elements will be turned into keys
# using the default stringizing operator '""'.

# Additional parameters, if any, will be passed to the key generation routine.

sub _longestCommonSubsequence
{
	my $a      = shift;    # array ref
	my $b      = shift;    # array ref
	my $keyGen = shift;    # code ref
	my $compare;           # code ref

	# set up code refs
	# Note that these are optimized.
	if ( !defined($keyGen) )    # optimize for strings
	{
		$keyGen = sub { $_[0] };
		$compare = sub { my ( $a, $b ) = @_; $a eq $b };
	}
	else
	{
		$compare = sub {
			my $a = shift;
			my $b = shift;
			&$keyGen( $a, @_ ) eq &$keyGen( $b, @_ );
		};
	}

	my ( $aStart, $aFinish, $bStart, $bFinish, $matchVector ) =
	  ( 0, $#$a, 0, $#$b, [] );

	# First we prune off any common elements at the beginning
	while ( $aStart <= $aFinish
		and $bStart <= $bFinish
		and &$compare( $a->[$aStart], $b->[$bStart], @_ ) )
	{
		$matchVector->[ $aStart++ ] = $bStart++;
	}

	# now the end
	while ( $aStart <= $aFinish
		and $bStart <= $bFinish
		and &$compare( $a->[$aFinish], $b->[$bFinish], @_ ) )
	{
		$matchVector->[ $aFinish-- ] = $bFinish--;
	}

	# Now compute the equivalence classes of positions of elements
	my $bMatches =
	  _withPositionsOfInInterval( $b, $bStart, $bFinish, $keyGen, @_ );
	my $thresh = [];
	my $links  = [];

	my ( $i, $ai, $j, $k );
	for ( $i = $aStart ; $i <= $aFinish ; $i++ )
	{
		$ai = &$keyGen( $a->[$i], @_ );
		if ( exists( $bMatches->{$ai} ) )
		{
			$k = 0;
			for $j ( @{ $bMatches->{$ai} } )
			{

				# optimization: most of the time this will be true
				if ( $k and $thresh->[$k] > $j and $thresh->[ $k - 1 ] < $j )
				{
					$thresh->[$k] = $j;
				}
				else
				{
					$k = _replaceNextLargerWith( $thresh, $j, $k );
				}

				# oddly, it's faster to always test this (CPU cache?).
				if ( defined($k) )
				{
					$links->[$k] =
					  [ ( $k ? $links->[ $k - 1 ] : undef ), $i, $j ];
				}
			}
		}
	}

	if (@$thresh)
	{
		for ( my $link = $links->[$#$thresh] ; $link ; $link = $link->[0] )
		{
			$matchVector->[ $link->[1] ] = $link->[2];
		}
	}

	return wantarray ? @$matchVector : $matchVector;
}

sub traverse_sequences
{
	my $a                 = shift;                                  # array ref
	my $b                 = shift;                                  # array ref
	my $callbacks         = shift || {};
	my $keyGen            = shift;
	my $matchCallback     = $callbacks->{'MATCH'} || sub { };
	my $discardACallback  = $callbacks->{'DISCARD_A'} || sub { };
	my $finishedACallback = $callbacks->{'A_FINISHED'};
	my $discardBCallback  = $callbacks->{'DISCARD_B'} || sub { };
	my $finishedBCallback = $callbacks->{'B_FINISHED'};
	my $matchVector = _longestCommonSubsequence( $a, $b, $keyGen, @_ );

	# Process all the lines in @$matchVector
	my $lastA = $#$a;
	my $lastB = $#$b;
	my $bi    = 0;
	my $ai;

	for ( $ai = 0 ; $ai <= $#$matchVector ; $ai++ )
	{
		my $bLine = $matchVector->[$ai];
		if ( defined($bLine) )    # matched
		{
			&$discardBCallback( $ai, $bi++, @_ ) while $bi < $bLine;
			&$matchCallback( $ai,    $bi++, @_ );
		}
		else
		{
			&$discardACallback( $ai, $bi, @_ );
		}
	}

	# The last entry (if any) processed was a match.
	# $ai and $bi point just past the last matching lines in their sequences.

	while ( $ai <= $lastA or $bi <= $lastB )
	{

		# last A?
		if ( $ai == $lastA + 1 and $bi <= $lastB )
		{
			if ( defined($finishedACallback) )
			{
				&$finishedACallback( $lastA, @_ );
				$finishedACallback = undef;
			}
			else
			{
				&$discardBCallback( $ai, $bi++, @_ ) while $bi <= $lastB;
			}
		}

		# last B?
		if ( $bi == $lastB + 1 and $ai <= $lastA )
		{
			if ( defined($finishedBCallback) )
			{
				&$finishedBCallback( $lastB, @_ );
				$finishedBCallback = undef;
			}
			else
			{
				&$discardACallback( $ai++, $bi, @_ ) while $ai <= $lastA;
			}
		}

		&$discardACallback( $ai++, $bi, @_ ) if $ai <= $lastA;
		&$discardBCallback( $ai, $bi++, @_ ) if $bi <= $lastB;
	}

	return 1;
}

sub traverse_balanced
{
	my $a                 = shift;                                  # array ref
	my $b                 = shift;                                  # array ref
	my $callbacks         = shift || {};
	my $keyGen            = shift;
	my $matchCallback     = $callbacks->{'MATCH'} || sub { };
	my $discardACallback  = $callbacks->{'DISCARD_A'} || sub { };
	my $discardBCallback  = $callbacks->{'DISCARD_B'} || sub { };
	my $changeCallback    = $callbacks->{'CHANGE'};
	my $matchVector = _longestCommonSubsequence( $a, $b, $keyGen, @_ );

	# Process all the lines in match vector
	my $lastA = $#$a;
	my $lastB = $#$b;
	my $bi    = 0;
	my $ai    = 0;
	my $ma    = -1;
	my $mb;

	while (1)
	{

		# Find next match indices $ma and $mb
		do { $ma++ } while ( $ma <= $#$matchVector && !defined $matchVector->[$ma] );

		last if $ma > $#$matchVector;    # end of matchVector?
		$mb = $matchVector->[$ma];

		# Proceed with discard a/b or change events until
		# next match
		while ( $ai < $ma || $bi < $mb )
		{

			if ( $ai < $ma && $bi < $mb )
			{

				# Change
				if ( defined $changeCallback )
				{
					&$changeCallback( $ai++, $bi++, @_ );
				}
				else
				{
					&$discardACallback( $ai++, $bi, @_ );
					&$discardBCallback( $ai, $bi++, @_ );
				}
			}
			elsif ( $ai < $ma )
			{
				&$discardACallback( $ai++, $bi, @_ );
			}
			else
			{

				# $bi < $mb
				&$discardBCallback( $ai, $bi++, @_ );
			}
		}

		# Match
		&$matchCallback( $ai++, $bi++, @_ );
	}

	while ( $ai <= $lastA || $bi <= $lastB )
	{
		if ( $ai <= $lastA && $bi <= $lastB )
		{

			# Change
			if ( defined $changeCallback )
			{
				&$changeCallback( $ai++, $bi++, @_ );
			}
			else
			{
				&$discardACallback( $ai++, $bi, @_ );
				&$discardBCallback( $ai, $bi++, @_ );
			}
		}
		elsif ( $ai <= $lastA )
		{
			&$discardACallback( $ai++, $bi, @_ );
		}
		else
		{

			# $bi <= $lastB
			&$discardBCallback( $ai, $bi++, @_ );
		}
	}

	return 1;
}

sub LCS
{
	my $a = shift;                                           # array ref
	my $matchVector = _longestCommonSubsequence( $a, @_ );
	my @retval;
	my $i;
	for ( $i = 0 ; $i <= $#$matchVector ; $i++ )
	{
		if ( defined( $matchVector->[$i] ) )
		{
			push ( @retval, $a->[$i] );
		}
	}
	return wantarray ? @retval : \@retval;
}

sub diff
{
	my $a      = shift;    # array ref
	my $b      = shift;    # array ref
	my $retval = [];
	my $hunk   = [];
	my $discard = sub { push ( @$hunk, [ '-', $_[0], $a->[ $_[0] ] ] ) };
	my $add = sub { push ( @$hunk, [ '+', $_[1], $b->[ $_[1] ] ] ) };
	my $match = sub { push ( @$retval, $hunk ) if scalar(@$hunk); $hunk = [] };
	traverse_sequences( $a, $b,
		{ MATCH => $match, DISCARD_A => $discard, DISCARD_B => $add }, @_ );
	&$match();
	return wantarray ? @$retval : $retval;
}

sub sdiff
{
	my $a      = shift;    # array ref
	my $b      = shift;    # array ref
	my $retval = [];
	my $discard = sub { push ( @$retval, [ '-', $a->[ $_[0] ], "" ] ) };
	my $add = sub { push ( @$retval, [ '+', "", $b->[ $_[1] ] ] ) };
	my $change = sub {
		push ( @$retval, [ 'c', $a->[ $_[0] ], $b->[ $_[1] ] ] );
	};
	my $match = sub {
		push ( @$retval, [ 'u', $a->[ $_[0] ], $b->[ $_[1] ] ] );
	};
	traverse_balanced(
		$a,
		$b,
		{
			MATCH     => $match,
			DISCARD_A => $discard,
			DISCARD_B => $add,
			CHANGE    => $change,
		},
		@_
	);
	return wantarray ? @$retval : $retval;
}


} # End of package Diff block


#----------------------------------------------------------
# Chunk package
#----------------------------------------------------------

{ # Start of package Chunk

package Chunk;

} # End of package Chunk


#----------------------------------------------------------
# Global constants
#----------------------------------------------------------

my $SEP = '/';


#----------------------------------------------------------
# Global variables
#----------------------------------------------------------

my $SOURCE;
my $DEST;
my $VERBOSE = 0;
my $SHOW_CHANGES = 0;
my $CONTEXT_LINES = 0;



#----------------------------------------------------------
# Private functions
#----------------------------------------------------------

# Static argument for do_search function
my $search_remove;
my $search_result;
my $search_pwd;

sub do_search($$) {

	my $path = $File::Find::name;
	my $dir = $File::Find::dir;

	my $file = $path;
	$file =~ s/^$dir//;
	$file =~ s/\///g;

	# Unless entry is a directory...
	unless(-d "$search_pwd/$path") {

		$dir =~ s/^$search_remove//;
		$dir =~ s/^\///;
		my @entry = ($dir, $file);
		push @$search_result, \@entry;
	}
}

#----------------------------------------------------------
# Public functions
#---------------------------------------------------------

sub search($) {

	my @result;
	$search_remove = $_[0];
	$search_result = \@result;
	$search_pwd = $ENV{'PWD'};
	find(\&do_search, $_[0]);
	undef $search_remove;
	undef $search_result;
	return \@result;
}


sub lower_case($) {

	my $x = $_[0];
       	$x =~ tr/[A-Z]/[a-z]/;
	return $x;
}


sub find_only_in_src($$) {

	my($src, $dest) = @_;
	my @result;

	foreach my $src_entry (@$src) {

		my $src_dir = lower_case($src_entry->[0]);
		my $src_file = lower_case($src_entry->[1]);

		my $found = 0;
		foreach my $dest_entry (@$dest) {

			my $dest_dir = lower_case($dest_entry->[0]);
			my $dest_file = lower_case($dest_entry->[1]);

			if($src_dir eq $dest_dir and $src_file eq $dest_file) {

				$found = 1;
				last;
			}
		}

		push @result, $src_entry unless $found;
	}

	return \@result;
}


sub compose_path($) {

	my $entry = $_[0];
	my $path;
	$path = $entry->[0] . "/" unless ($entry->[0] eq "");
	$path .= $entry->[1];
}


sub print_entries($) {

	my ($entries) = @_;
	foreach my $entry (@$entries) {

		print compose_path($entry), "\n";
	}
}


sub print_changes($) {

	my ($changes) = @_;
	foreach my $change (@$changes) {

		print compose_path($change->[0]), 
			" -> ", compose_path($change->[1]), "\n";
	}
}


sub help() {

	print qq(
Usage: $0 <source> <dest>
Options:
    -v    verbose output
    -c    show changes
);
}


sub find_changed_case($$) {

	my($src, $dest) = @_;
	my @result;
	my $dest_entry;

	foreach my $src_entry (@$src) {

		my $src_dir = $src_entry->[0];
		my $src_file = $src_entry->[1];
		my $lc_src_dir = lower_case($src_dir);
		my $lc_src_file = lower_case($src_file);

		my $changed = 0;
		foreach my $x (@$dest) {

			$dest_entry = $x;

			my $dest_dir = $dest_entry->[0];
			my $dest_file = $dest_entry->[1];
			my $lc_dest_dir = lower_case($dest_dir);
			my $lc_dest_file = lower_case($dest_file);

			if($lc_src_dir eq $lc_dest_dir and $lc_src_file eq $lc_dest_file) {

				# Filenames (case-insensitive) match
				# Now check whether they still match with case-sensitivity

				$changed = 1 unless ($src_dir eq $dest_dir);
				$changed = 1 unless ($src_file eq $dest_file);

				last;
			}
		}

		if($changed) {

			my @change = ($src_entry, $dest_entry);
			push @result, \@change;
		}
		
	}

	return \@result;
}


sub read_file($) {

	my $fname = $_[0];
	my $fh = new FileHandle($fname) or die "Error: cannot read $fname";
	my @result;
	while(<$fh>) {

		push @result, $_;
	}
	return \@result;
}


sub find_changes($$) {

	my($src, $dest) = @_;
	my @result;
	my($src_path, $dest_path);

	foreach my $src_entry (@$src) {

		$src_path = compose_path($src_entry);

		my $src_dir = $src_entry->[0];
		my $src_file = $src_entry->[1];
		my $lc_src_dir = lower_case($src_dir);
		my $lc_src_file = lower_case($src_file);

		my $detail;

		foreach my $dest_entry (@$dest) {

			$dest_path = compose_path($dest_entry);

			my $dest_dir = $dest_entry->[0];
			my $dest_file = $dest_entry->[1];
			my $lc_dest_dir = lower_case($dest_dir);
			my $lc_dest_file = lower_case($dest_file);

			if($lc_src_dir eq $lc_dest_dir and $lc_src_file eq $lc_dest_file) {

				# Read in the two files
				my $src_lines = read_file("$SOURCE/$src_path");
				my $dest_lines = read_file("$DEST/$dest_path");
				my $diffs = Diff::diff($src_lines, $dest_lines);

				foreach my $chunk (@$diffs) {

					my $start_line = 0;
					my $prev_line = 0;
					my $count = 0;
					my $output;
					foreach my $line (@$chunk) {

						my ($sign, $lineno, $text) = @$line;
#printf "%d %s %s", $lineno, $sign, $text;
						$start_line = $lineno if $start_line == 0;
						++$count;
						my $symbol = ($sign eq '+') ? '>' : '<';
						$output .= "$symbol $text";
						last unless($prev_line == 0 or $lineno == $prev_line+1);
						$prev_line = $lineno;
					}

					$output = sprintf("%d,%d\n", $start_line, $count) . $output;
					$detail .= $output;
				}

				last;
			}
		}

		unless($detail eq "") {

			my @change = ($src_path, $dest_path, $detail);
			push @result, \@change;
		}
		
	}

	return \@result;
}


#----------------------------------------------------------
# Main
#----------------------------------------------------------

unless(scalar @ARGV >= 2) { help; die; }

my @args;
while(my $arg = shift @ARGV) {

	if($arg eq "-v") { $VERBOSE = 1; }
	if($arg eq "-c") { $SHOW_CHANGES = 1; }
	else { push @args, $arg; }
}

$SOURCE = shift @args;
$DEST = shift @args;

$SOURCE =~ s/\/\//\//g;
$DEST =~ s/\/\//\//g;
$SOURCE =~ s/\/$//;
$DEST =~ s/\/$//;

die "Error: $SOURCE not found" unless -e $SOURCE;
die "Error: $DEST not found" unless -e $DEST;
die "Error: $SOURCE not a directory" unless -d $SOURCE;
die "Error: $DEST not a directory" unless -d $DEST;

my $src_entries = search($SOURCE);
my $dest_entries = search($DEST);
my $only_in_src = find_only_in_src($src_entries, $dest_entries);
my $only_in_dest = find_only_in_src($dest_entries, $src_entries);
my $changed_case = find_changed_case($src_entries, $dest_entries);

if($VERBOSE) {

	print "\nFiles in $SOURCE:\n";
	print_entries($src_entries);
	print "\nFiles in $DEST:\n";
	print_entries($dest_entries);
}

print "\nFiles only in $SOURCE:\n";
print_entries($only_in_src);
print "\nFiles only in $DEST:\n";
print_entries($only_in_dest);

print "\nFiles changed case:\n";
print_changes($changed_case);

print "\nFile contents changed:\n";
my $changes = find_changes($src_entries, $dest_entries);

foreach my $change (@$changes) {

	my ($from, $to, $detail) = @$change;

	print "\n" if $SHOW_CHANGES;
	print "$from -> $to\n";
	print "------------------------\n$detail\n" if $SHOW_CHANGES;
}
