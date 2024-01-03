#!/bin/bash
##proc/build_probe: Guess the build type
##@copyright GPL-2.0+
if [ -z "$ABTYPE" ]; then
	for i in "${AB_TEMPLATES[@]}"; do
		# build are all plugins now.
		if "build_${i}_probe"; then
			export ABTYPE=$i
			break
		fi
	done
fi

if [ -z "$ABTYPE" ]; then
	abdie "Cannot determine build type."
fi

if [ "$ABTYPE" = 'self' ]; then
	abinfo 'Using free-formed build script'
else
	abinfo "Build template selected: $ABTYPE"
fi
