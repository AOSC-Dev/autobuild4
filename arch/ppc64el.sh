#!/bin/bash
##arch/ppc64el.sh: Build definitions for ppc64el.
##@copyright GPL-2.0+
CFLAGS_COMMON_ARCH=('-mcpu=power8' '-mtune=power9' '-msecure-plt' '-mvsx' '-mabi=ieeelongdouble')
RUSTFLAGS_COMMON_ARCH=('-Ctarget-cpu=pwr8' '-Ctarget-feature=+vsx,+altivec,+secure-plt' '-Clink-arg=-mabi=ieeelongdouble')
