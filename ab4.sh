#!/bin/bash
# ab3.sh: the starting point
##@copyright GPL-2.0+

# Basic environment declarations
export ABVERSION=4
export ABSET=/etc/autobuild

if [ ! "$AB" ]; then
	AB=$(cat "$ABSET/prefix" || dirname "$(readlink -e "$0")")
fi

export ABBLPREFIX="$AB"/lib
export AB ABBUILD ABHOST ABTARGET

# build-specific variables
export SRCDIR="$PWD"
export BLDDIR="$SRCDIR/abbuild"
export PKGDIR="$SRCDIR/abdist"
export SYMDIR="$SRCDIR/abdist-dbg"

enable -f "${AB}"/libautobuild.so autobuild
autobuild
