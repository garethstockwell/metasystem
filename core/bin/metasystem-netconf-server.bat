REM For service installation, see
REM http://agiletesting.blogspot.co.uk/2005/09/running-python-script-as-windows.html

set METASYSTEM_HOME=c:\Users\garsto01\work\sync\git\github\metasystem

c:\apps\python\2.7\python.exe %METASYSTEM_HOME%\core\bin\metasystem-netconf-server.py start --fg

