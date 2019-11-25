Overview
--------

metasystem is a repository of files intended to be deployed to a user's home directory on a Unix or Unix-like system (e.g. Cygwin), thereby replicating a familiar development environment.

For installation / setup instructions, refer to INSTALL.txt


Features
--------

metasystem includes the following features:

* BASH configuration files (bashrc, profile) which define
  * Aliases and various utility functions
  * For information on both of the above, run 'help' from the shell
* Environment variables
  * Hooks which are executed when changing directory, enabling:
    * Information-rich command line prompt
    * Dynamic behaviour (e.g. automatically switching compilers when navigating between different project source trees)
* Configuration files for programs including git, hg, vi
* Utility scripts
  * Text processing tools
  * Tools for managing the shell environment
  * Tools for switching between different identities (for SCM tools)
  * A synchronisation wrapper script
* Special-purpose scripts
  * Various scripts for Symbian development
  * Various scripts for Qt development
* Perl and Python libraries
* Firefox Ubiquity scripts

More information on some of these features is provided below.


cd hooks
--------

The problem

The user is working on various different projects, each located in its own area on the filesystem (e.g. ~/work/project-1, ~/work/project-2).  Prior to starting work on a given project, the shell environment needs to be appropriately set up - this may include:

* Adding project-specific tools to the PATH
* Setting other environment variables
* Defining shell functions
* Executing scripts or programs
* Assuming a particular identity (see 'Identity management' below)
Remembering to do all this manually is cumbersome.

The solution

A 'cd' alias is defined, which checks for a directory-specific metadata file, and if found, carries out the relevant setup.  The metadata is stored in two files:

.metasystem-dirinfo - this can be used to:

* Assume an identity (see 'Identity management' below)
* Alter the PATH to add/remove specific tools
* Specify the location of one or more child projects (see 'Project shortcuts' below)

smartcd scripts

metasystem used the smartcd (git://github.com/cxreg/smartcd.git) project to trigger execution of shell scripts when directories are entered/left.  In addition to allowing execution of arbitrary shell commands, smartcd provides a 'stashing' mechanism for setting environment variables.

Files

* templates/smartcd


Shell environment management
----------------------------

The problem

When switching between different physical locations, environment variables (e.g. HTTP_PROXY; LM_LICENSE_FILE) need to be updated to match the local network configuration

The solution

A config file is populated with

* Information which can be used to identify on which network the machine is currently running - for example IP address ranges or FQDNs
* Values which should be assigned to environment variables when the location changes

This config file is parsed by a python script which writes out a shell script; the shell script is then sourced to set the relevant environment variables.

Files

* modules/profile/bin/metasystem-profile.py
* core/templates/local/config/profile.ini

Shell aliases

* profile-get
* profile
* profile-update


Identity management
-------------------

The problem

When committing code to different repositories, the user may wish to assume different identities - for example joe.bloggs@work.com when committing to work projects, and joe.bloggs@personal-email.com when committing to open-source projects.  These identities are stored in config files (e.g. ~/.gitconfig), which the user may forget to update prior to making and pushing a commit.

The solution

The different identities (name and email address) are stored in a
configuration file.  The current identity in use are specified via an environment variable (e.g. METASYSTEM_ID_GIT=work).  The SCM tools (git, hg) are invoked via a wrapper script which first checks the environment variable, and updates relevant fields in the SCM tool's config file.

Shell aliases are provided to allow the user to switch identity, and the current active identities are displayed in the shell prompt.

By using a cd hook, the identity can automatically be set when navigating into a project directory, ensuring that the correct identity is always used when committing to that project.

Files

* core/bin/metasystem-id.py
* core/bin/scm-wrapper.sh
* core/templates/local/config/id.ini

Shell aliases

* ids-get
* ids
* id-set
* ids-reset


Synchronisation
---------------

The problem

The user works on a number of different machines, and wishes to synchronise various content between them.  This content may be stored in a distributed SCM system (git, hg), or it may be stored as a directory of raw files.  A simple command ('sync <project>') is required which, for SCM projects, does

	cd <project_dir>
	git pull
	git push

and for raw-file projects, executes the appropriate to synchronise the directory with a remote copy using a tool such as unison

The solution

Metadata about each project (its name; where on the local filesystem it lives; its storage type; the location of remote server(s)) is stored in a config file.  A python script parses this file, and executes the required external programs to perform the synchronisation.

Files

* core/bin/metasystem-sync.py
* core/templates/local/config/sync.ini


Variable and function naming conventions
----------------------------------------

All capitals
e.g. METASYSTEM_FOO
Exported environment variable

Leading underscore
e.g. _metasystem_foo
Non-exported function name, used only by the scripts inside $METASYSTEM_CORE_SHELL/home

Lower case, underscore-separated
e.g. metasystem_foo
Exported function name, used by scripts in $METASYSTEM_CORE_BIN

Lower case, hyphen-separated
e.g. foo-bar
Alias, intended for use directly from the command prompt
e.g. id-set, profile-update


Environment variables
---------------------

Some important environment variables set during login are:

METASYSTEM_HOSTNAME

METASYSTEM_OS
OS on which the system is running.
e.g. linux, windows

METASYSTEM_PLATFORM
Variable which distinguishes the various Linux compatibility layers which run on top of Windows.
e.g. cygwin, mingw

PS1
Bash shell prompt command string.
