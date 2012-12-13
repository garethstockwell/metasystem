#!/system/bin/sh

uri=$1

am start -n com.android.music/com.android.music.MediaPlaybackActivity -d $uri

