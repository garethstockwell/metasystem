package Metasystem::Utils;

#
# Miscellaneous utility functions
#

use strict;
use FileHandle;
use DirHandle;
use Term::ReadKey;		# for password reading
use File::Path;


# Turn on flushing
$| = 1;


#------------------------------------------------------------------------------
# Global data
#------------------------------------------------------------------------------

# Initial verbosity levels
# If a LogXxx function is called with a verbosity which is lower than the
# current verbosity level for that logging category, the logging is printed.
our $DEFAULT_ERROR_VERBOSITY    = 1;
our $DEFAULT_EVENT_VERBOSITY    = 1;
our $DEFAULT_DETAIL_VERBOSITY   = 1;
our $DEFAULT_DEBUG_VERBOSITY    = 0;

our $VERSION = '1.0.0';


#------------------------------------------------------------------------------
# Static variables
#------------------------------------------------------------------------------

BEGIN
	{
	my $GLOBAL = { };

	sub SetGlobal($$)
		{
		my ($key, $value) = @_;
		$GLOBAL->{$key} = $value;
		}

	sub GetGlobal($)
		{
		my ($key) = @_;
		return $GLOBAL->{$key};
 		}	
 		
 	sub UnsetGlobal($)
 		{
 		my ($key) = @_;
		undef $GLOBAL->{$key};
 		}
 		
 	sub GlobalKeys()
 		{
 		my @keys = keys %$GLOBAL;
 		return \@keys;
 		}
	}


#------------------------------------------------------------------------------
# Public functions: Initialization
#------------------------------------------------------------------------------

sub SignalHandler()
	{
	LogDebug("Utils::SignalHandler");
	CleanUp();
	exit 1;
	}


# All scripts should call this at the top
sub Initialize()
	{
	# Install signal handlers
	# This ensures lock will be correctly released if user presses Ctrl-C
	$SIG{INT} = \&SignalHandler;
	$SIG{QUIT} = \&SignalHandler;

	SetGlobal('Metasystem_INITIALIZED', 1);	

	SetErrorVerbosity($DEFAULT_ERROR_VERBOSITY);
	SetEventVerbosity($DEFAULT_EVENT_VERBOSITY);
	SetDetailVerbosity($DEFAULT_DETAIL_VERBOSITY);
	SetDebugVerbosity($DEFAULT_DEBUG_VERBOSITY);

	SetLogToConsole(undef);
	}


sub AssertInitialized()
	{
	unless(defined GetGlobal('Metasystem_INITIALIZED'))
		{
		throw Metasystem::Exception::Logic('System not initialized');
		}
	}


# All scripts should call this at the end
sub CleanUp()
	{
	
	}


#------------------------------------------------------------------------------
# File management
#------------------------------------------------------------------------------

sub OpenFileRead($)
	{
	my ($fname) = @_;
	my $fh = new FileHandle($fname);
	unless($fh)
		{
		throw Metasystem::Exception::IO("Failed to open file '$fname' for reading: $@");
		}
	return $fh;
	}


sub OpenFileWrite($)
	{
	my ($fname) = @_;
	my $fh = new FileHandle(">$fname");
	unless($fh)
		{
		throw Metasystem::Exception::IO("Failed to open file '$fname' for writing: $@");
		}
	return $fh;
	}


sub OpenFileAppend($)
	{
	my ($fname) = @_;
	my $fh = new FileHandle(">>$fname");
	unless($fh)
		{
		throw Metasystem::Exception::IO("Failed to open file '$fname' for appending: $@");
		}
	return $fh;
	}


sub LockedAppend($$)
	{
	my ($file, $line) = @_;
throw Metasystem::Exception::Logic("Lock not implemented");
	my $fh = Metasystem::Utils::OpenFileAppend($file);
	print $fh "$line\n";
	}


# This should be done on a locked file
sub RemoveLastLine($)
	{
	my ($file) = @_;
	my @lines;

	my $fh1 = Metasystem::Utils::OpenFileRead($file);
	while(<$fh1>)
		{
		push @lines, $_;
		}
	$fh1 = undef;

	my $lastLine = pop @lines;
	chomp $lastLine;

	my $fh2 = Metasystem::Utils::OpenFileWrite($file);
	foreach my $line (@lines)
		{
		print $fh2 $line;
		}

	return $lastLine;
	}


sub MkDir($)
	{
	my ($dir) = @_;
	if (-e $dir)
		{
		return;
		}

	eval { mkpath $dir };
	if($@)
		{
		throw Metasystem::Exception::IO("Error creating directory '$dir': $@");
		}
	}


sub CheckedMkdir($)
	{
	my ($dir) = @_;
	if (-e $dir)
		{
		if(Metasystem::Utils::Ask("$dir already exists - remove and recreate?"))
			{
			rmtree $dir;
    	    }
		else
			{
			return undef;
			}
		}
		
	my @error;

	eval { mkpath $dir };
	if($@)
		{
		throw Metasystem::Exception::IO("Error creating directory '$dir': $@");
		}
	}


sub RmDir($)
	{
	my ($dir) = @_;
	
	unless(-e $dir)
		{
		return;
		}
	
	eval { rmtree $dir };
	if($@)
		{
		throw Metasystem::Exception::IO("Failed to remove directory '$dir': $@");
		}
		
	if(-e $dir)
		{
		throw Metasystem::Exception::IO("Failed to remove directory '$dir': $@");
		}
	}
	
	
sub RmFile($)
	{
	my ($file) = @_;
	
	unless(-e $file)
		{
		return;
		}
	
	eval { unlink $file };
	if($@)
		{
		throw Metasystem::Exception::IO("Failed to remove file '$file': $@");
		}
		
	if(-e $file)
		{
		throw Metasystem::Exception::IO("Failed to remove file '$file': $@");
		}
	}


sub ReadCsvFile($$$)
	{
	my ($file, $n_columns, $allow_spaces) = @_;
	my $fh = Metasystem::Utils::OpenFileRead($file);
	my @data;
	my $line = 0;

	while(<$fh>)
		{
		chomp;
		++$line;
		s/^\s+//;
		s/\s+$//;
		s/#.*//;
		next if $_ eq "";
		my @tokens = split /\t+/;

		unless(scalar @tokens == $n_columns)
			{
			throw Metasystem::Exception::IO("Incorrect number of columns at line $line of file '$file'");
			}

		unless($allow_spaces == 1)
			{
			foreach my $token (@tokens)
				{
				if($token =~ /\s+/)
					{
					throw Metasystem::Exception::IO("Space in token '$token' at line $line of file '$file'");
					}
				}
			}
		
		push @data, \@tokens;
		}

	return \@data;
	}


#------------------------------------------------------------------------------
# Misc functions
#------------------------------------------------------------------------------

sub Version()
    {
    return $VERSION;
    }


sub TimeStamp()
	{
	return Metasystem::Utils::FormatTime(time);
	}


sub FormatTime($)
	{
	my ($time) = @_;
	
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);

	$year += 1900;
	$mon++;

	return sprintf("%02d/%02d/%4d %02d:%02d:%02d", $mday, $mon, $year, $hour, $min, $sec);
	}


sub FormatDate($)
	{
	my ($time) = @_;
	
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);

	$year += 1900;
	$mon++;

	return sprintf("%02d/%02d/%4d", $mday, $mon, $year);
	}


#------------------------------------------------------------------------------
# User input
#------------------------------------------------------------------------------

sub DoGetPassword()
	{
	my $password;
	ReadMode 4;
	while(1)
		{
		my $key = undef;
		while(not defined ($key = ReadKey(-1)))
			{
			}
		if($key eq "\b")
			{
			if(length($password))
				{
				print "\b \b";
				$password = substr($password, 0, length($password)-1);
				}
			}
		else 	
			{
			last if $key eq "\n" or $key eq "\r";
			print '*';
			$password .= $key;
			}
		}
	ReadMode 0;
	print "\n";
	return $password;
	}


sub GetPassword()
	{
	return Metasystem::Utils::DoGetPassword();
	}


sub GetPasswordVerified()
	{
	print "Enter password: ";
	my $password1 = Metasystem::Utils::DoGetPassword();
	print "Re-type password: ";
	my $password2 = Metasystem::Utils::DoGetPassword();
	unless($password1 eq $password2)
		{
		throw Metasystem::Exception::IO('Passwords do not match');
		}	
	return $password1;
	}


sub Ask($)
	{
	my ($question) = @_;

	for(my $i=0; $i<3; ++$i)
		{
		print "$question [y|n] ";
		my $ans = <STDIN>;
		chomp $ans;
		return 1 if ($ans eq 'y');
		return 0 if ($ans eq 'n');
		}

	print "Invalid response\n";
	return undef;
	}



#------------------------------------------------------------------------------
# Logging
#------------------------------------------------------------------------------

sub SetLogToConsole($)
	{
	my ($value) = @_;
	Metasystem::Utils::SetGlobal('LOG_TO_CONSOLE', $value);
	}


sub GetLogToConsole
	{
	return Metasystem::Utils::GetGlobal('LOG_TO_CONSOLE');
	}


sub SetErrorVerbosity($)
	{
	my ($verbosity) = @_;
	Metasystem::Utils::SetGlobal('ERROR_VERBOSITY', $verbosity);
	}


sub SetEventVerbosity($)
	{
	my ($verbosity) = @_;
	Metasystem::Utils::SetGlobal('EVENT_VERBOSITY', $verbosity);
	}


sub SetDetailVerbosity($)
	{
	my ($verbosity) = @_;
	Metasystem::Utils::SetGlobal('DETAIL_VERBOSITY', $verbosity);
	}


sub SetDebugVerbosity($)
	{
	my ($verbosity) = @_;
	Metasystem::Utils::SetGlobal('DEBUG_VERBOSITY', $verbosity);
	}


sub LogError
	{
	my ($message, $verbosity) = @_;
	$verbosity = 0 unless defined $verbosity;
	Metasystem::Utils::XLog($message, $verbosity, 'error');
	}


sub LogEvent
	{
	my ($message, $verbosity) = @_;
	$verbosity = 0 unless defined $verbosity;
	Metasystem::Utils::XLog($message, $verbosity, 'event');
	}


sub LogDetail
	{
	my ($message, $verbosity) = @_;
	$verbosity = 0 unless defined $verbosity;
	Metasystem::Utils::XLog($message, $verbosity, 'detail');
	}


sub LogDebug
	{
	my ($message, $verbosity) = @_;
	$verbosity = 0 unless defined $verbosity;
	Metasystem::Utils::XLog($message, $verbosity, 'debug');
	}


sub XLog($$$)
	{
	my ($message, $verbosity, $type) = @_;

	my $thresholdKey = $type . '_VERBOSITY';
	$thresholdKey =~ tr/[a-z]/[A-Z]/;
	my $threshold = Metasystem::Utils::GetGlobal($thresholdKey);

	if($verbosity < $threshold)
		{
		if(defined Metasystem::Utils::GetLogToConsole())
			{
			print "$message\n";
			}

		# Wrapped in an eval block so that a failure to access the
		# log file does not cause an exception.
		eval
			{
			my $dir = Metasystem::Utils::GetGlobal('Metasystem_LOGDIR');
			my $fname = File::Spec->catdir($dir, 'log.txt');
			my $fh = Metasystem::Utils::OpenFileAppend($fname);
			printf $fh "%s\t%s\t%s\n", Metasystem::Utils::TimeStamp(), $type, $message;
			};
		}
	}



#------------------------------------------------------------------------------
# Required at end of Perl module
#------------------------------------------------------------------------------

1;


