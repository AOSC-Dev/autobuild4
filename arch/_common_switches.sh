#!/bin/bash
##arch/_common_switches.sh: Switches sourced after defines.
##@copyright GPL-2.0+
if ((AB_FLAGS_SSP)); then CFLAGS_COMMON+=('-fstack-protector-strong' '--param=ssp-buffer-size=4'); fi
if ((AB_FLAGS_SCP)); then CFLAGS_GCC_COMMON+=('-fstack-clash-protection'); fi
if ((AB_FLAGS_RRO)); then LDFLAGS_COMMON+=('-Wl,-z,relro'); fi
if ((AB_FLAGS_NOW)); then LDFLAGS_COMMON+=('-Wl,-z,now'); fi
if ((AB_FLAGS_FTF)); then CPPFLAGS_COMMON+=('-D_FORTIFY_SOURCE=2'); fi
# AB_FLAGS_HARDEN is backwards compatible with AB_FLAGS_{PIE,SPECS}.
if ! bool "$USECLANG" && \
   (((AB_FLAGS_HARDEN)) || \
    ((AB_FLAGS_SPECS)) || \
    ((AB_FLAGS_PIE))); then
	# GCC has an `-fhardened' flag or a spec-driven (pre-14) system to
	# automatically enable code hardening.
	#
	# Test if we are on GCC >= 14.
	if [ "$(echo __GNUC__ | gcc -E -xc - | tail -n 1)" -ge 14 ]; then
		CFLAGS_GCC_OPTI+=('-fhardened')
	else
		# Use the old behavior if we are not.
		CFLAGS_GCC_OPTI+=('-specs=/usr/lib/gcc/specs/hardened-cc1')
	fi
	LDFLAGS_GCC_OPTI+=("-specs=/usr/lib/gcc/specs/hardened-ld")
else
	# Clang can handle PIE and PIC properly, let it do the old job.
	if ((AB_FLAGS_PIC)); then LDFLAGS_COMMON+=('-fPIC') CFLAGS_COMMON+=('-fPIC'); fi
	# The following is not a typo, when specifying PIE for clang, -fPIE
	# should not be specified for CFLAGS, because clang will mark all
	# functions as dso_local if -fPIE is specified. However, clang/LLVM
	# will implicitly enable PIE if you specified -fPIC.
	#
	# Also make AB_FLAGS_PIE backwards compatible with AB_FLAGS_HARDEN and
	# AB_FLAGS_SPECS to avoid confusion.
	if ((AB_FLAGS_HARDEN)) || ((AB_FLAGS_SPECS)) || ((AB_FLAGS_PIE)); then
		CFLAGS_CLANG_OPTI+=('-fPIC')
		LDFLAGS_CLANG_OPTI+=('-fPIE')
	fi
fi
if ((AB_FLAGS_O3)); then CFLAGS_COMMON_OPTI="${CFLAGS_COMMON_OPTI/O2/O3}"; fi
if ((AB_FLAGS_OS)); then CFLAGS_COMMON_OPTI="${CFLAGS_COMMON_OPTI/O2/Os}"; fi
if ((AB_FLAGS_EXC)); then CFLAGS_COMMON+=('-fexceptions'); fi

if bool "$ABSPLITDBG"; then
	CFLAGS_COMMON+=("${CFLAGS_DBG_SYM[@]}")
	CXXFLAGS_COMMON+=("${CFLAGS_DBG_SYM[@]}")
fi

if ((AB_SAN_ADD)); then CFLAGS_COMMON+=('-fsanitize=address'); fi
if ((AB_SAN_THR)); then CFLAGS_COMMON+=('-fsanitize=thread'); fi
if ((AB_SAN_LEK)); then CFLAGS_COMMON+=('-fsanitize=leak'); fi
