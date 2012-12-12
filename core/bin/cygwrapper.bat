@echo off
REM This is necessary to avoid confusion with Cygwin Perl installation
set Path=C:\apps\Perl\bin\;%PATH%
@echo on
%*
