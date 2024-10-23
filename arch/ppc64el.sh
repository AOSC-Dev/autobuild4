#!/bin/bash
##arch/ppc64el.sh: Build definitions for ppc64el.
##@copyright GPL-2.0+
CFLAGS_COMMON_ARCH_BASE=('-msecure-plt' '-mvsx' '-mabi=ieeelongdouble')
CFLAGS_COMMON_ARCH=('-mcpu=power8' '-mtune=power8')
RUSTFLAGS_COMMON_ARCH=('-Ctarget-cpu=pwr8' '-Ctarget-feature=+vsx,+altivec,+secure-plt' '-Clink-arg=-mabi=ieeelongdouble')

HAS_HWCAPS=1
# ppc64el only supports power8 and power9. The default is power8.
HWCAPS=('power9')
CFLAGS_HWCAPS_power9=("${CFLAGS_COMMON_ARCH_BASE[@]}" '-mcpu=power9' '-mtune=power9')
CPPFLAGS_HWCAPS_power9=("${CFLAGS_COMMON_ARCH_BASE[@]}" '-mcpu=power9' '-mtune=power9')
RUSTFLAGS_HWCAPS_power9=('-Ctarget-cpu=pwr9' '-Ctarget-feature=+vsx,+altivec,+secure-plt' '-Clink-arg=-mabi=ieeelongdouble')
