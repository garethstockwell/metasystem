#!/system/bin/sh

for arg in "$@"; do
	case $arg in
		*)
			echo "Warning: ignoring unrecognized argument $arg" >&2
			;;
	esac
done

while true; do
	input keyevent 7
	input keyevent 23
done

