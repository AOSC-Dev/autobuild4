#!/bin/bash
##defines: First we need the defines
##@copyright GPL-2.0+

BUILD_START(){ true; }
BUILD_READY(){ true; }
BUILD_FINAL(){ true; }

# Autobuild settings
. "$AB"/etc/autobuild/ab3_defcfg.sh

. "$AB/arch/_common.sh"

arch_loaddefines -2 defines || abdie "Failed to source defines file: $?."

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
