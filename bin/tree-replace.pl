#!/usr/bin/env perl

use File::Find;
use FileHandle;
use strict;

#--------------------------------------------
# Global variables
#--------------------------------------------

my ($fromDir, $toDir);
my ($fromString, $toString);

my ($baseDir);

#--------------------------------------------
# Global constants
#--------------------------------------------


#--------------------------------------------
# Subroutines
#--------------------------------------------

sub translateFileName($)
	{
	my $from = $_[0];
	my $to = $from;
	$to =~ s/^$fromDir//i;
	$to = $toDir . $to;
#	$to =~ tr/[A-Z]/[a-z]/;
	return $to;
	}

sub doIt()
	{
	my $findDir = $File::Find::dir;
	my $findFile = $File::Find::name;

	my $srcFile = "$baseDir/$findFile";
	my $destDir = "$baseDir/" . translateFileName($findDir);
	my $destFile = "$baseDir/" . translateFileName($findFile);

	if(!-d $destDir)
		{
		print "DIR $destDir\n";
		die "Failed to make directory $destDir" unless mkdir $destDir ;
		}

	if(-f $srcFile)
		{
		print "FILE $findDir $findFile\t$srcFile\t->\t$destFile\n";
		my $fromFh = new FileHandle($srcFile) or die "Failed to read $srcFile";
		if(defined $fromFh)
			{
			my $toFh = new FileHandle(">$destFile") or die "Failed to write $destFile";
			while(<$fromFh>)
				{
				s/$fromString/$toString/g;
				print $toFh $_;
				}
			}
		}
	}


#--------------------------------------------
# Main
#--------------------------------------------

($fromDir, $fromString, $toDir, $toString) = @ARGV;

$baseDir = `pwd`;
chomp $baseDir;

find(\&doIt, $fromDir);

