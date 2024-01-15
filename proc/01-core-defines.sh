#!/bin/bash
##defines: First we need the defines
##@copyright GPL-2.0+

export ABBLPREFIX="$AB"/lib

BUILD_START(){ true; }
BUILD_READY(){ true; }
BUILD_FINAL(){ true; }

# build-specific variables
export SRCDIR="$PWD"
export BLDDIR="$SRCDIR/abbuild"
export PKGDIR="$SRCDIR/abdist"
export SYMDIR="$SRCDIR/abdist-dbg"

# early check
[ -d "autobuild" ] || abdie "Did not find autobuild directory!"

shopt -s expand_aliases extglob globstar nullglob

# Autobuild settings
# Allow $ABHOST to override standard paths
load_strict "$AB"/lib/default-paths.sh
load_strict "$AB/arch/_common.sh"
load_strict "$AB/arch/${ABHOST//\//_}.sh"
load_strict "$AB"/lib/default-defines.sh

export AB ABBUILD ABHOST ABTARGET

ab_parse_set_modifiers

arch_loaddefines -2 defines || abdie "Failed to source defines file: $?."

if abisdefined FAIL_ARCH && abisdefined ALLOW_ARCH; then
	abdie "Can not define FAIL_ARCH and ALLOW_ARCH at the same time."
fi

# shellcheck disable=SC2053
if [ -n "$ALLOW_ARCH" ] && [ "${ABBUILD%%\/*}" != $ALLOW_ARCH ]; then
	abdie "This package can only be built on $ALLOW_ARCH, not including $ABHOST."
fi
# shellcheck disable=SC2053
[[ ${ABHOST%%\/*} != $FAIL_ARCH ]] ||
	abdie "This package cannot be built for $FAIL_ARCH, e.g. $ABHOST."

if ! bool "$ABSTRIP" && bool "$ABSPLITDBG"; then
	abwarn "QA: ELF stripping is turned OFF."
	abwarn "    Won't package debug symbols as they are shipped in ELF themselves."
	ABSPLITDBG=0
fi

if [[ $ABHOST == noarch ]]; then
	abinfo "Architecture-agnostic (noarch) package detected, disabling -dbg package split ..."
	ABSPLITDBG=0
fi

abisdefined PKGREL || PKGREL=0

load_strict "$AB/arch/_common_switches.sh"
load_strict "$AB"/lib/builtin.sh
