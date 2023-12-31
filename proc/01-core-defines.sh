#!/bin/bash
##defines: First we need the defines
##@copyright GPL-2.0+

BUILD_START(){ true; }
BUILD_READY(){ true; }
BUILD_FINAL(){ true; }

# Autobuild settings
load_strict /etc/autobuild/ab3_defcfg.sh
load_strict "$AB/arch/_common.sh"
load_strict "$AB/arch/${ABHOST//\//_}.sh"

arch_loaddefines -2 defines || abdie "Failed to source defines file: $?."

if abisdefined FAIL_ARCH && abisdefined ALLOW_ARCH; then
	abdie "Can not define FAIL_ARCH and ALLOW_ARCH at the same time."
fi

# shellcheck disable=SC2053
[[ ${ABHOST%%\/*} = $ALLOW_ARCH ]] ||
	abdie "This package can only be built on $ALLOW_ARCH, not including $ABHOST."
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
