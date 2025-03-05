#!/bin/bash
##arch/ppc64el.sh: Build definitions for ppc64el.
##@copyright GPL-2.0+
CFLAGS_COMMON_ARCH_BASE=('-msecure-plt' '-mabi=ieeelongdouble')
CFLAGS_COMMON_ARCH=('-mcpu=power8' '-mtune=power10' '-mvsx')
RUSTFLAGS_COMMON_ARCH=('-Ctarget-cpu=pwr8' '-Ctarget-feature=+vsx,+altivec,+secure-plt' '-Clink-arg=-mabi=ieeelongdouble')

HAS_HWCAPS=1

# List of HWCAPS subtargets in ppc64el, excluding power8 itself:
#
# power9 - Based on PowerISA v3.0, with enhanced VSX instructions.
# power10 - Based on PowerISA v3.1, with Matrix-Multiply Assist (MMA) engines.
HWCAPS=('power9' 'power10')

# Compiler flags for each subtarget.
CFLAGS_HWCAPS_power9=("${CFLAGS_COMMON_ARCH_BASE[@]}" '-mcpu=power9' '-mtune=power9' '-mvsx')
CFLAGS_HWCAPS_power10=("${CFLAGS_COMMON_ARCH_BASE[@]}" '-mcpu=power10' '-mtune=power10' '-mvsx' '-mmma')

# ABI flags in CPPFLAGS confuses autoconf's compile test routines.
# AC_LANG_PROGRAM calls $CC with the following arguments:
#    $CC $CFLAGS $CPPFLAGS
# When configure.ac tries to add something to CFLAGS, the resulting
# combination will still be overridden by CPPFLAGS.
CPPFLAGS_HWCAPS_power9=('-mcpu=power9' '-mtune=power9' '-mvsx')
CPPFLAGS_HWCAPS_power10=('-mcpu=power10' '-mtune=power10' '-mvsx' '-mmma')

RUSTFLAGS_HWCAPS_power9=('-Ctarget-cpu=pwr9' '-Ctarget-feature=+vsx,+altivec,+secure-plt' '-Clink-arg=-mabi=ieeelongdouble')
RUSTFLAGS_HWCAPS_power10=('-Ctarget-cpu=pwr10' '-Ctarget-feature=+mma,+vsx,+altivec,+secure-plt' '-Clink-arg=-mabi=ieeelongdouble')
