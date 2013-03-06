#!/usr/bin/env bash

# Wrapper for repo

case $1 in
	sync)
		shift
		android-repo-sync.sh "$@"
		;;
	*)
		repo "$@"
		;;
esac

