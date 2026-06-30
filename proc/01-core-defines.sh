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

# Load defines for ABHOST.
# NOTE: optenv32 is defined as an architecture.
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
		export CC=i686-aosc-linux-gnu-clang CXX=i686-aosc-linux-gnu-clang++ \
		    OBJC=i686-aosc-linux-gnu-clang OBJCXX=i686-aosc-linux-gnu-clang++ \
			LD=i686-aosc-linux-gnu-ld
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

load_strict "$AB/arch/${ABHOST}.sh"
load_strict "$AB"/lib/default-flags.sh

if ! abisdefined DPKG_ARCH ; then
	export DPKG_ARCH="$ABHOST"
fi
if abisdefined ALLOW_ARCH; then
	abdie "ALLOW_ARCH is deprecated, please remove it from your defines file."
fi

# NOTE: Some defines may override AB_FLAGS_* defined in an arch-specific
# manner.
# Take AB_FLAGS_Y2038 for example, some packages may need to disable this
# flag in order to build, such as v4l-utils.
arch_loaddefines -2 defines || abdie "Failed to source defines file: $?."

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
# Now, we need to match not only the ARCH itself, we also have to match every
# ABHOST_GROUPs (e.g. retro, mainline, etc.).
# Three types of expressions are handled:
# - "!(a|b|c)", matching anything except a, b and c, so the build is only
#   available to a, b and c.
# - "@(a|b|c)", matching a, b and c, so the build is not available to a,
#   b and c.
# - "arch" or "group", disallowing build for one arch/group.
# NOTE:
# - Expressions such as "a|b|c" or "(a|b|c)" are invalid.
last_status=0
if [ "${FAIL_ARCH##\!}" != "$FAIL_ARCH" ] ; then
	chk_op="!="
else
	chk_op="=="
fi
for match in "$ABHOST" "${ABHOST_GROUP[@]}" ; do
	if eval "[[ \$match $chk_op \$FAIL_ARCH ]]" ; then
		last_status=0
		break
	else
		last_status=1
	fi
done
if [ "$chk_op" = "==" ] ; then
	last_status="$(( !last_status ))"
fi
if [ "$last_status" != "0" ] ; then
	abdie "This package cannot be built for $FAIL_ARCH, e.g. $ABHOST."
fi
unset last_status chk_op

if ! bool "$ABSTRIP" && bool "$ABSPLITDBG"; then
	abwarn "QA: ELF stripping is turned OFF."
	abwarn "    Won't package debug symbols as they are shipped in ELF themselves."
	ABSPLITDBG=0
fi

if [[ $ABHOST == noarch ]]; then
	abinfo "Architecture-agnostic (noarch) package detected, disabling -dbg package split ..."
	ABSPLITDBG=0
fi

if bool "$__AB_BOOTSTRAP" ; then
	if ! bool "$ABSTAGE2" ; then
		abdie "__AB_BOOTSTRAP should be enabled along with ABSTAGE2."
	fi
	# apt is installed; this switch should be disabled from now on
	if [ -e /var/lib/dpkg/info/apt.list ] ; then
		abdie "APT is present on this environment - refuse to proceed with bootstrapping mode on."
	fi
	if [ -e /var/lib/dpkg/info/"$PKGNAME".list ] ; then
		abdie "Package is already being built - Disable __AB_BOOTSTRAP to proceed."
	fi
	abwarn "WARNING! WARNING! WARNING!"
	abwarn "BOOTSTRAPPING MODE ACTIVATED!"
	abwarn "All unauthorized personell should evacuate immidiately!"

	# Ignore PKGDEP and BUILDDEP.
	PKGDEP=""
	BUILDDEP=""
fi

# Disable HWCAPS builds if stage 2 mode is on.
if bool "$ABSTAGE2" && bool "$AB_HWCAPS" ; then
	abinfo "Disabling HWCAPS builds on stage 2 ..."
	AB_HWCAPS=0
fi

abisdefined PKGREL || PKGREL=0
abisdefined PKGEPOCH || PKGEPOCH=0

# load builtins early: _common_switches may require some builtins
load_strict "$AB"/lib/builtin.sh
load_strict "$AB/arch/_common_switches.sh"
