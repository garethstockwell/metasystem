#!/usr/bin/env bash

device-sync.sh \
	  --host android-adb \
	  --shell /system/bin/sh \
	  --script-dir /sdcard \
	  "$@"

