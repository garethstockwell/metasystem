#!/usr/bin/env perl

# Find long lines

use strict;

my $max_length = 80;
my $mode = "";
my $mark = "";
my $count = 0;
my $number = 0;
my $tabs_to_spaces = 0;

sub help() {

	print qq(
Usage: $0
  --max X           set max length to X
  --list-long       list only long lines
  --list-all        list all lines
  --tabs-to-spaces  convert each tab to 4 spaces
  --modify          add carriage returns
  --mark X          insert [X] into long lines when using list-*
  --number          show line numbers when using list-*
);
}


sub process($) {

	my ($line) = @_;
	++$count;

	my $line_no_tabs = $line;
	$line_no_tabs =~ s/\t/    /g;
	my $length = length $line_no_tabs;

#print "LINE $line\n";

	if($mode =~ /^list/) {

		printf "%4d : ", $count if ($number == 1);

		if($length > $max_length) {

			my $x = $tabs_to_spaces ? $line_no_tabs : $line;

			my $left = substr $x, 0, $max_length;
			my $right = substr $x, $max_length;
			printf "%s%s%s\n", $left, $mark, $right;
		}
		elsif($mode eq "list-all") {

			if($tabs_to_spaces)
			{ print $line_no_tabs, "\n"; }

			else { print $line, "\n"; }
		}
	}

	elsif($mode == "modify") {

		# Find out how many tabs at start of line
		$line =~ /^(\t+)(.*)/;
		my $after_tabs = $2;
		my $n_tabs = length $1;

		if($n_tabs == 0) {

			print "$line\n";
		}
		else {

			my $tabs = "\t" x $n_tabs;
			my $new_string = $tabs;

			# Tokenize the string
			my $remain = $after_tabs;
			while(length $remain) {

				$remain =~ /^(\S+)(\s+)(.*)/;
				my $chunk = $1;
				my $space = $2;
				my $after = $3;

				if(length $new_string + length $chunk > $max_length) {

					$new_string .= "\n" . $tabs . $chunk . $space;
				}
				elsif(length $new_string + length $chunk + length $space > $max_length) {

					$new_string .= $chunk . "\n" . $tabs . $space;
				}
				else {

					$new_string .= $chunk . $space;
				}

#print "NEW_STRING $new_string\n";

				$remain = $after;
			}

			print $new_string, "\n";

		}
	}
}


#
# Main
#

for(my $i=0; $i<scalar @ARGV; ++$i) {

	my $arg = $ARGV[$i];

	if($arg eq "--list-long") 	{ $mode = "list-long"; }

	elsif($arg eq "--list-all") 	{ $mode = "list-all"; }

	elsif($arg eq "--modify") 	{ $mode = "modify"; }

	elsif($arg eq "--mark") 	{ $mark = " [" . $ARGV[++$i] . "] "; }

	elsif($arg eq "--number")	{ $number = 1; }

	elsif($arg eq "--max")		{ $max_length = $ARGV[++$i]; }

	elsif($arg eq "--tabs-to-spaces")
	{ $tabs_to_spaces = 1; }

	elsif($arg eq "--help" or $arg eq "-h")
	{ help; die; }
}

if($mode eq "") { help; die; }

while(<STDIN>) {

	chomp;
	process($_);
}
