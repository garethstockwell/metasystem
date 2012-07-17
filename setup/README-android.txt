-----------------------------------------------------------------------
Setup instructions for Android development machine
-----------------------------------------------------------------------

Host platform: Ubuntu 11.10

Install Eclipse WST server adapters
* Help | Install New Software | Add
* http://download.eclipse.org/releases/indigo/
* Select "Web, XML, Java EE and OSGi Enterprise Development | WST server adapters"

Install ADT
* Help | Install New Software | Add
* https://dl-ssl.google.com/android/eclipse/
* Select "Developer Tools"

Setup metasystem to add SDK/tools to $PATH
shell export ANDROID_SDK_DIR=~/work/local/android/sdks/r17
shell export PATH=$ANDROID_SDK_DIR/tools:$PATH

Install SDK components
* android


