#!/bin/bash
##arch/ppc64el.sh: Build definitions for ppc64el.
##@copyright GPL-2.0+
CFLAGS_GCC_ARCH=('-mcpu=power8' '-mtune=power9' '-msecure-plt' '-mvsx' '-mabi=ieeelongdouble')
CFLAGS_CLANG_ARCH=('-mcpu=power8' '-mtune=power9' '-msecure-plt' '-mvsx' '-mabi=ieeelongdouble')
RUSTFLAGS_COMMON_ARCH=('-Ctarget-cpu=pwr8' '-Ctarget-feature=+vsx,+altivec,+secure-plt' '-Clink-arg=-mabi=ieeelongdouble')

# ppc64el only supports power8 and power9. The default is power8.
HWCAPS=('power9')
