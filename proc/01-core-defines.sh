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
load_strict "$AB"/lib/default-defines.sh
load_strict "$AB/arch/_common.sh"

export AB ABBUILD ABHOST ABTARGET

ab_parse_set_modifiers

arch_loaddefines -2 defines || abdie "Failed to source defines file: $?."

if [[ "$ABBUILD" == "$ABHOST" ]]; then
	if [ -d /opt/pseudo-multilib/bin ]; then
		export PATH="/opt/pseudo-multilib/bin:$PATH"
	else
		if bool "$USECLANG"; then
			export CC=clang CXX=clang++ OBJC=clang OBJCXX=clang++
		else
			export CC=gcc CXX=g++ OBJC=gcc OBJCXX=g++
		fi
	fi
elif [[ "$ABHOST" == "optenv32" ]]; then
	if bool "$USECLANG"; then
		# FIXME: LLVM must be patched to recognize libdirs and
		# includedirs of optenvs in order to get them to compile.
		abdie "Sorry, optenv targets currently can not handle USECLANG=1."
	else
		export \
			CC=i686-aosc-linux-gnu-gcc CXX=i686-aosc-linux-gnu-g++ \
			OBJC=i686-aosc-linux-gnu-gcc OBJCXX=i686-aosc-linux-gnu-g++ \
			LD=i686-aosc-linux-gnu-ld
	fi
# Possible optenvx64 in the future.
elif [[ "$ABHOST" != 'noarch' ]]; then
	abdie "Cross-compilation is no longer supported."
fi

load_strict "$AB/arch/${ABHOST//\//_}.sh"
load_strict "$AB"/lib/default-flags.sh

if ! abisdefined DPKG_ARCH ; then
	export DPKG_ARCH="$ABHOST"
fi
if abisdefined FAIL_ARCH && abisdefined ALLOW_ARCH; then
	abdie "Can not define FAIL_ARCH and ALLOW_ARCH at the same time."
fi

if bool "$AB_SKIP_ALLMAINTSCRIPTS" ; then
	abinfo "Will not install maintscripts in this build."
	AB_SKIP_MAINTSCRIPTS=('prerm' 'postrm' 'preinst' 'postinst')
fi

# Avoid using for loops to test if a string is in an array.
# Convert the (indexed) array to an (assodiative) array.
declare -A _AB_SKIP_MAINTSCRIPTS_
for ele in "${AB_SKIP_MAINTSCRIPTS[@]}" ; do
	_AB_SKIP_MAINTSCRIPTS_["$ele"]="$ele"
done

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
abisdefined PKGEPOCH || PKGEPOCH=0

# load builtins early: _common_switches may require some builtins
load_strict "$AB"/lib/builtin.sh
load_strict "$AB/arch/_common_switches.sh"
