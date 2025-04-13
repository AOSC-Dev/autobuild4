#!/bin/bash
##arch/_common_switches.sh: Switches sourced after defines.
##@copyright GPL-2.0+
if ((AB_FLAGS_SSP)); then CFLAGS_COMMON+=('-fstack-protector-strong' '--param=ssp-buffer-size=4'); fi
if ((AB_FLAGS_SCP)); then CFLAGS_GCC_COMMON+=('-fstack-clash-protection'); fi
if ((AB_FLAGS_RRO)); then LDFLAGS_COMMON+=('-Wl,-z,relro'); fi
if ((AB_FLAGS_NOW)); then LDFLAGS_COMMON+=('-Wl,-z,now'); fi
if ((AB_FLAGS_FTF)); then CPPFLAGS_COMMON+=('-U_FORTIFY_SOURCE' '-D_FORTIFY_SOURCE=3'); fi
if ((AB_FLAGS_SPECS)); then CFLAGS_GCC_OPTI+=('-specs=/usr/lib/gcc/specs/hardened-cc1'); fi
if ((AB_FLAGS_O3)); then CFLAGS_COMMON_OPTI="${CFLAGS_COMMON_OPTI/O2/O3}"; fi
if ((AB_FLAGS_OS)); then CFLAGS_COMMON_OPTI="${CFLAGS_COMMON_OPTI/O2/Os}"; fi
if ((AB_FLAGS_EXC)); then CFLAGS_COMMON+=('-fexceptions'); fi
# Only functions (via compiler and/or kernel, and hardware) on ...
#
#   - amd64 (x86-64): Intel CET (compiler: -fcf-protection=full,
#     kernel: CONFIG_CET).
#   - arm64 (AArch64): PAC + BTI (compiler: -mbranch-protection=standard,
#     kernel: CONFIG_ARM64_BTI + ARM64_PTR_AUTH).
if ((AB_FLAGS_CFP)); then
	if ab_match_arch amd64; then
		CFLAGS_COMMON+=('-fcf-protection=full')
	elif ab_match_arch arm64; then
		CFLAGS_COMMON+=('-mbranch-protection=standard')
	fi
fi

# Clang can handle PIE and PIC properly, let it do the old job.
if bool "$USECLANG"; then
	if ((AB_FLAGS_PIC)); then LDFLAGS_COMMON+=('-fPIC') CFLAGS_COMMON+=('-fPIC'); fi
        # The following is not a typo, when specifying PIE for clang, -fPIE should not be specified
        # for CFLAGS, because clang will mark all functions as dso_local if -fPIE is specified
        # However, clang/LLVM internally will enable PIE if you specified -fPIC
	if ((AB_FLAGS_PIE)); then LDFLAGS_COMMON+=('-fPIE') CFLAGS_COMMON+=('-fPIC'); fi
elif ((AB_FLAGS_SPECS)); then LDFLAGS_COMMON+=("-specs=/usr/lib/gcc/specs/hardened-ld");
fi

if bool "$ABSPLITDBG"; then
	CFLAGS_COMMON+=("${CFLAGS_DBG_SYM[@]}")
	CXXFLAGS_COMMON+=("${CFLAGS_DBG_SYM[@]}")
fi

if ! bool "$NOSTATIC"; then
	LDFLAGS_COMMON_OPTI_LTO=("${LDFLAGS_COMMON_OPTI_LTO[@]}" '-ffat-lto-objects')
fi

if ((AB_SAN_ADD)); then CFLAGS_COMMON+=('-fsanitize=address'); fi
if ((AB_SAN_THR)); then CFLAGS_COMMON+=('-fsanitize=thread'); fi
if ((AB_SAN_LEK)); then CFLAGS_COMMON+=('-fsanitize=leak'); fi
