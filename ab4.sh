#!/bin/bash
# ab3.sh: the starting point
##@copyright GPL-2.0+

# Basic environment declarations
export ABSET=/etc/autobuild

if [ ! "$AB" ]; then
	AB=$(cat "$ABSET/prefix" || dirname "$(readlink -e "$0")")
fi

enable -f "${AB}"/libautobuild.so autobuild
autobuild
